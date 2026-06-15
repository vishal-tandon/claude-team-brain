---
name: sync-with-brain
description: >
  Use this skill when the user wants to pull the latest brain context and skills,
  or when they want to check whether their local clone and plugin cache are in
  sync. The pull side of the brain's bidirectional sync. Reports staleness in one
  line ("context 3 commits behind, pull the brain") and offers a one-click fix.
  Also the dedicated drift detector: reads clone-commit-vs-origin, plugin version,
  and @import presence to surface any divergence between the two local
  materializations (clone and plugin cache). Trigger phrases: "sync with brain",
  "sync the brain", "pull the brain", "update the brain", "am I up to date with
  the brain", "check brain drift", "is my brain stale", or any close paraphrase.
  Reads all constants from brain.config.json. Respects syncMode: auto / reminded
  / manual. Diagnostic and one-click resync, NOT a background daemon.
---

# Sync with brain

The pull side of the brain's bidirectional sync. Pulls context from the brain
clone, surfaces any staleness in one line, and offers a one-click fix. Also the
dedicated drift detector: compares the two local materializations (the git clone
that supplies `@import` context, and the plugin cache that supplies skills) to
surface divergence before it causes problems.

Reads all runtime constants from `brain.config.json` at the repo root.

**Core principle: diagnostic and one-click resync, not an autonomous daemon.**
Report state clearly in one line. Offer the fix. Let the user confirm.

## Before doing anything: read brain.config.json

Locate and read `brain.config.json` from the brain clone root. Extract:

- `clonePath`: resolve it by reading the context-import line in
  `~/.claude/CLAUDE.md` (the bare `@<clonePath>/CLAUDE.md` line setup-brain wrote)
  and taking the directory it points at. That import line is the persisted record
  of where the clone lives. Fall back to `defaultClonePath` (`~/.claude/brain`)
  only if no import line is found.
- `branch`: the working branch (default `main`).
- `syncMode`: `"auto"`, `"reminded"`, or `"manual"`. Controls nudge behavior
  (see below). Does NOT change what this skill checks, only how proactively it
  acts.
- `marketplaceName`: the marketplace slug (e.g. `your-team-brain`). Used to
  locate the plugin cache for drift detection.

Use `git -C <clonePath> ...` for all git commands. Never rely on a persistent cwd.

## What this skill checks

### A. Clone staleness (context)

The git clone at `<clonePath>` is the `@import` target. It feeds context into
every session. If it is behind origin, teammates' pushes and your own pushes from
other devices are not loading yet.

```
git -C <clonePath> fetch origin <branch>
git -C <clonePath> rev-list HEAD..origin/<branch> --count
```

Outcomes:
- Count is 0: clone is current. No action needed on this dimension.
- Count > 0: clone is N commits behind origin. Report and offer `git pull`.

### B. Plugin cache version (skills)

The plugin cache holds the installed skills. The brain plugin ships with NO
pinned `version`, so Claude Code treats the source commit as the version: every
new commit on the repo counts as a newer version. Those newer versions only
install automatically when `autoUpdate` is enabled for this marketplace in
`~/.claude/settings.json` (`extraKnownMarketplaces.<marketplaceName>.autoUpdate`).
Third-party marketplaces default to autoUpdate OFF, so if setup-brain did not set
it (or it was removed), new skills never reach the user on their own. The drift to
detect is therefore "the installed skills are built from an older commit than
origin," not a semver gap, and the root cause is almost always a missing
autoUpdate flag.

Locate the installed plugin commit:
- Look for `~/.claude/plugins/cache/<marketplaceName>/` (or the platform-appropriate
  plugin cache path). The version directory inside is named for the source commit
  the installed skills were built from.
- Compare it against the latest commit on origin (the same fetch from check A
  already has this: `git -C <clonePath> rev-parse origin/<branch>`).

Outcomes:
- Installed commit matches origin HEAD: skills are current.
- Installed commit is behind origin: skills are stale (the session-start
  auto-update has not run since the last push). Offer `/plugin marketplace update
  <marketplaceName>` then `/plugin update <marketplaceName>` as the immediate fix.
  Then check whether `autoUpdate` is set for this marketplace (check E). If it is
  missing, this staleness will recur every time a skill is pushed: name that as
  the real cause and recommend re-running `setup-brain` to restore the flag, not
  just a one-off update.
- Plugin cache not found: skills may not be installed at all. Report and offer
  the install command.

### C. @import presence (wiring check)

Verify the context-import line pointing at the brain clone is present in the
user's active Claude settings (typically `~/.claude/CLAUDE.md` or equivalent). If
it is missing, context is not loading even if the clone is current.

The import directive Claude Code uses is a BARE `@path`, not `@import path`.
`setup-brain` writes `@<clonePath>/CLAUDE.md`. Match on that shape, never on a
literal `import` token (an earlier version of this check grepped for `@import`,
which never matches what setup writes and produced a permanent false alarm).

Check for a line matching the regex `^@.*<clonePath>.*CLAUDE\.md` (tolerate an
optional legacy `import ` token after the `@` so old installs still register).

Outcomes:
- Present: wiring is correct.
- Missing: report: "@import line not found in your Claude config. Context is not
  loading. Run setup-brain to restore it."

### D. SessionStart pull hook (optional check)

If `syncMode` is `"auto"` or `"reminded"`, check whether a SessionStart hook that
runs `git pull` on the clone is present in Claude settings. A missing hook in these
modes means the clone only updates when the user explicitly runs `sync-with-brain`.

This check is informational only. Do not modify the hook without explicit user
request.

### E. autoUpdate flag (skills-distribution check)

This is the root-cause check behind B. Read `~/.claude/settings.json` and look for
`extraKnownMarketplaces.<marketplaceName>.autoUpdate`.

Outcomes:
- Present and `true`: new skills install themselves at session start. This is the
  intended state.
- Missing or `false`: new skills pushed to the brain will NOT reach this user
  automatically. Each push leaves their skills stale until they manually update.
  Report: "autoUpdate is off for the brain marketplace. New skills will not install
  on their own. Run setup-brain to restore it." This is the single most common
  reason a pushed skill never shows up for a teammate.

This check is what distinguishes a one-off stale cache (fixed by `/plugin update`)
from a systemic distribution gap (fixed by enabling autoUpdate).

## syncMode behavior

The `syncMode` config flag governs how proactively this skill acts:

- **`auto`**: pull without confirmation if clone is behind. Report outcome. Also
  trigger `sync-with-brain` automatically at session start if a SessionStart hook
  is wired (the hook is what actually fires it; this skill is the implementation).
- **`reminded`**: report staleness and offer the pull as a one-click action.
  Do not pull without confirmation. This is the default for teams.
- **`manual`**: report state only. Do not offer or initiate any pull. The user
  controls when sync happens.

In all modes, the drift report is the same. Only the action taken differs.

## Workflow

### 1. Pre-flight: locate the brain

- Read `brain.config.json` and resolve the clone path.
- If the clone does not exist or is not a git repo, report:
  "Brain clone not found at `<clonePath>`. Run setup-brain to initialize."
  and stop.

### 2. Run all five checks (A-E above) in parallel

Gather results before reporting anything. All checks are read-only at this stage.

### 3. Compose the drift report (always one line, then detail)

**Lead with a single-sentence verdict.** Examples:

- All clear: `Brain is current. Context, skills, and wiring all up to date.`
- Clone behind: `Context is N commit(s) behind. Pull the brain to catch up.`
- Skills stale: `Skills may be stale. Plugin cache is built from an older commit than origin.`
- Clone behind + skills stale: `Context N commit(s) behind and skills stale. Pull and update.`
- @import missing: `@import line not found. Context is not loading. Run setup-brain to restore.`
- Multiple issues: Lead with the most impactful, list the rest.

Then, if issues exist, show the detail and the fix action(s):

```
Brain sync status

  Context:    3 commits behind origin/main             [needs pull]
  Skills:     built from an older commit than origin    [needs update]
  autoUpdate: off for brain marketplace                 [root cause - run setup-brain]
  @import:    present                                   [ok]
  Hook:       SessionStart pull hook not found          [informational]

Fix:
  (a) Pull context now  (git pull origin main)
  (b) Update skills now  (/plugin update your-team-brain)
  (c) Both
  (d) Skip
```

### 4. Apply the fix (per syncMode)

**auto mode:**
- If there are issues: apply fix (a), (b), or (c) automatically based on what
  is needed. Report outcome. Do not ask for confirmation.

**reminded mode:**
- Present the fix menu. Wait for user selection. Apply the chosen option.

**manual mode:**
- Report the status only. Do not offer or initiate any fix. Print the raw git
  commands the user can run themselves if they want.

### 5. Pull the clone (if pulling)

- `git -C <clonePath> pull --rebase origin <branch>`
- If the pull applies cleanly: report the new commit count or a sha summary.
- If conflicts occur: surface them using the same conflict resolution sub-flow
  as `push-to-brain` (propose a merge, offer approve/refine/abort). Context
  conflicts are rare (most files are append-only) but handle them gracefully.
- After a clean pull, report how many files changed:
  `Pulled. Context updated (N files changed, M commits ahead of where you were).`

### 6. Update skills (if updating)

Run the appropriate marketplace update command for the platform. If `gh` or the
Claude Code CLI is available:
```
/plugin update <marketplaceName>
```
or equivalent. Report the version after update.

If the update command is not available in the current environment, print the
command and ask the user to run it manually.

### 7. Final report

After all fixes are applied (or if everything was already current), close with
one line:

```
Sync complete. Context current, skills at origin HEAD, wiring ok.
```

If anything could not be fixed automatically (e.g. @import missing requires
`setup-brain`, or manual mode means no action was taken), name the remaining
items explicitly.

## Edge cases

- **Clone not found.** Report and point to `setup-brain`. Do not attempt to clone
  inline. That is setup-brain's job.
- **No network access.** `git fetch` will fail. Catch the error, report
  "Could not reach origin. Check connectivity", and skip checks A and B. Check C
  and D still run locally.
- **Plugin cache path not found.** Skills may not be installed. Report and offer
  the install command.
- **@import line present but pointing at a different path.** Report the mismatch
  and suggest the user run `setup-brain` or correct the path manually.
- **syncMode: auto at session start.** If a SessionStart hook fires this skill
  automatically, keep the output minimal: one line if all is well, or the drift
  report if not. Do not flood the session open with a lengthy status block when
  everything is fine.
- **Large number of commits behind.** If the clone is > 20 commits behind, flag it
  as unusual: "Context is N commits behind. This is more than expected. Confirm
  you want to pull all N commits?" then proceed per syncMode.

## Common pitfalls

- **Pulling without checking for local uncommitted changes.** Before running
  `git pull`, check `git -C <clonePath> status --porcelain`. If there are
  uncommitted local brain changes, warn the user: "You have uncommitted brain
  changes. Pull could conflict. Run push-to-brain first, or pull anyway?"
- **Conflating the two materializations.** The clone and the plugin cache are
  updated by different channels and can drift. Report their states separately.
  Never say "the brain is up to date" if only one of the two has been checked.
- **Acting as a daemon.** This skill runs once on demand (or once at session start
  if a hook fires it). It does not watch for changes, poll, or schedule itself.
- **Hardcoding the clone path or marketplace name.** Always read `brain.config.json`.
- **Skipping the @import check.** A current clone with a missing @import still
  means context is not loading. Check all five dimensions every time.
- **Force-pulling.** Never `git pull --force` or `git reset --hard`. If the pull
  has conflicts, use the conflict resolution sub-flow. Content is never discarded
  without user confirmation.

## Composing with other skills

- **`push-to-brain`**: the push side. `sync-with-brain` is the pull side. Together
  they are the bidirectional sync. If the user runs both in a session: pull first,
  push second, to minimize conflicts.
- **`setup-brain`**: handles first install and wiring. If `sync-with-brain` finds
  that @import is missing or the clone does not exist, the fix is to run `setup-brain`,
  not to patch inline.
- **`disconnect-brain`**: the clean uninstall. If the user wants to stop syncing
  entirely, `disconnect-brain` removes the wiring that `sync-with-brain` checks.
