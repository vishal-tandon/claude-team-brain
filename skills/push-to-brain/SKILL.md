---
name: push-to-brain
description: >
  Use this skill whenever the user wants to commit and push brain edits back to
  the shared repository so teammates (or their other devices) pick them up on
  next pull. Default mode is AUTONOMOUS, most pushes complete end-to-end with
  no user interruption, one-line success report at the end. The skill surfaces
  to the user ONLY when: (a) a pre-push content scan flags sensitive or personal
  content, (b) the change is unusually large or touches unexpected paths, (c) a
  git conflict occurs during rebase, or (d) the push is rejected after one retry.
  Trigger phrases: "push my brain changes", "push to brain", "commit and push the
  brain", "sync my brain changes", "save these to the brain", or any close
  paraphrase pairing a push/commit/sync verb with the brain. Reads all constants
  from brain.config.json. Routes to direct push (open governance) or opens a PR
  (governed mode) based on the config.
---

# Push to brain (autonomous by default)

The brain's bidirectional sync engine on the push side. Takes local edits in
the brain clone and pushes them to origin so the team (or your other devices)
picks them up on next pull. Reads all runtime constants from `brain.config.json`
at the repo root. No hardcoded paths, repos, or branch names.

**Core principle: silent on success, surfaces only when input is genuinely needed.**
The user said "push". Trust them. Don't ask "are you sure?" at every step. Run
the workflow autonomously and report one line at the end. Interrupt only when the
system cannot safely proceed without human judgement.

## Before doing anything: read brain.config.json

Locate the brain clone. Read `brain.config.json` from the repo root and extract:

- `clonePath`: resolve it by reading the context-import line in
  `~/.claude/CLAUDE.md` (the bare `@<clonePath>/CLAUDE.md` line setup-brain wrote)
  and taking the directory it points at. That import line is the persisted record
  of where the clone lives, so a non-default clone path resolves correctly without
  any separate pointer. Fall back to `defaultClonePath` (`~/.claude/brain`) only if
  no import line is found.
- `branch`: the working branch to commit and push to (default `main`).
- `governance`: `"open"` or `"governed"`. Routes the final push step.
- `syncMode`: `"auto"`, `"reminded"`, or `"manual"`. Informs push behavior (auto
  mode = no confirmation prompts unless a surface condition fires).
- `repo`: `owner/repo` string, used for PR URL construction in governed mode.

Use `git -C <clonePath> ...` for all git commands. Never rely on a persistent cwd.

## When this skill surfaces to the user (the only four cases)

1. **Sensitive content scan flagged something**: personal interaction preferences,
   credentials/tokens, or content patterns indicating a personal-vs-shared boundary
   violation. Halt and offer scrub / move-to-local / override.
2. **Change is unusually large or hits unexpected paths**: diff > 200 lines, OR
   touches paths outside the expected brain content areas (`shared-memory/`,
   `project-memory/`, `perspectives/`, `meta/`, `skills/`, `commands/`,
   `.claude-plugin/`, or top-level `*.md` docs). Show the diff and ask for
   confirmation before staging.
3. **Real git conflict during rebase**: Claude proposes a merged resolution first,
   then asks the user to approve / reject / refine. Default is one-click approval,
   not "you figure it out from scratch".
4. **Push rejected after one retry**: likely a fundamental issue (auth, branch
   state, etc.); surface the git output and stop.

In every other case: run the workflow end-to-end silently. One line at the end.

## What this skill does NOT do

- Does NOT touch files outside the brain clone
- Does NOT open a PR when `governance: "open"`, direct push only
- Does NOT auto-merge the PR in `governance: "governed"` mode. The human gate is
  the entire point of governed mode.
- Does NOT bypass pre-commit hooks with `--no-verify` under any circumstances
- Does NOT bulk-stage with `git add -A` or `git add .`, always explicit paths
- Does NOT force-push under any circumstances

## Triggers

- "push my brain changes"
- "push to brain"
- "commit and push the brain"
- "sync my brain changes"
- "save these to the brain"
- any close paraphrase pairing a push/commit/sync verb with the brain
- can also be invoked at the end of `share-with-brain` as a sub-step

## Workflow

### 1. Pre-flight: locate the brain and check for changes

- Read `brain.config.json` (see above). Resolve the clone path.
- If the clone path does not exist or is not a git repo, tell the user the expected
  path and ask whether the brain lives elsewhere on this machine.
- Check `git -C <clonePath> status --porcelain`. If empty, report
  `Nothing to push. No uncommitted brain changes.` and exit cleanly.
- Check the current branch. If not on the configured `branch`, report which branch
  is checked out and offer to switch. If detached HEAD, report and stop.

### 1.5 Solo mode only: refresh personal snapshots

If `brain.config.json` has `"mode": "solo"`, the `personal/` tier is a synced
tier (see `personal/INDEX.md`). Snapshot copies drift, so refresh them before
every push:

- Read `personal/INDEX.md`. For each entry with a `source:` line, copy the
  live source file over the tracked copy in `personal/` (expand `~`). Skip
  missing sources silently (that entry's source lives on another device).
- Any resulting change is part of this push. No separate confirmation; this
  is the tier working as designed.

In team mode (`"mode": "team"` or absent): skip this step entirely.
`personal/` should not exist as tracked content, and personal material found
in the diff is a scan flag, not a snapshot to refresh.

### 2. Pre-push sensitive content scan (autonomous unless flagged)

Before staging, scan the diff for content that does not belong in the shared brain.
This is the single most important guardrail. Personal content leaking into a shared
repo is hard to undo and breaks teammates' sessions.

**Filename patterns to flag:**
- `feedback_*.md`: personal interaction preferences
- `user_*.md`, `user_profile*`: personal identity or role files
- `.env`, `*.env`, `*.key`, `credentials*`: secrets
- Anything matching `*token*`, `*secret*`, `*api_key*` with non-trivial content

**Frontmatter patterns to flag (in added or modified `.md` files):**
- `type: user`: explicitly marked as personal-scope memory
- `type: feedback`: interaction-style guidance
- `private: true` or `personal: true`

**Content patterns to flag (in added or modified lines only, not existing content):**
- Self-referential preference assertions: "I prefer", "I want", "I don't like",
  "my style is", "I always", "I never" (preceded by a personal subject)
- Common secret patterns: `sk_[a-zA-Z0-9]+`, `ghp_[a-zA-Z0-9]+`,
  `figd_[a-zA-Z0-9]+`, `Bearer [a-zA-Z0-9_-]+`, AWS access keys (`AKIA[0-9A-Z]{16}`)
- Email addresses and phone numbers in close proximity (potential PII)

**Solo-mode scope note:** in solo mode, personal-preference patterns under
`personal/` are expected content, do not flag them there (mirrors the
pre-commit guard's gate). Secret patterns still flag everywhere, including
`personal/`. In team mode there is no exemption.

**If anything is flagged:**

Halt before staging. Surface to the user:

```
Pre-push scan flagged content in the following file(s) that may not belong
in the shared brain:

shared-memory/something.md:
  Line 23: "I prefer terse responses, no preamble"  (personal preference)
  Line 31: "my voice is lowercase, no em dashes"    (interaction style)

shared-memory/api-notes.md:
  Line 8: FIGMA_TOKEN=figd_*****                    (looks like a secret)

How do you want to proceed?
  (a) Scrub flagged content from these files and push the rest
  (b) Move these files to ~/.claude/memory/ (keep them local, push the rest)
  (c) Override: push anyway (requires explicit confirmation)
  (d) Cancel
```

Apply the user's choice. If scrub: edit the files to remove the flagged lines,
then continue. If move: move the files out of the brain clone into `~/.claude/memory/`.
If override: require one explicit "yes, push anyway" before proceeding. If cancel:
stop cleanly without staging.

**If nothing is flagged:** continue to step 3 silently. No "scan passed" message.

### 3. Decide push mode: autonomous vs interactive

Autonomous mode applies when ALL of the following are true:
- Pre-push scan passed (step 2)
- Diff is <= 200 lines total (additions + deletions)
- All changed files are within expected brain paths (`shared-memory/`,
  `project-memory/`, `perspectives/`, `meta/`, `skills/`, `commands/`,
  `.claude-plugin/`, top-level docs like `README.md`, `CLAUDE.md`,
  `ARCHITECTURE.md`, and in solo mode only, `personal/`)
- A commit message can be confidently inferred from the change pattern

Otherwise: interactive mode (show diff + confirm message before staging).

In autonomous mode: no interrupts before the success report. The user does NOT
need to confirm the commit message, see the diff, or approve the push.

In interactive mode: show `git status --short` + diff summary, propose a commit
message, ask one-line confirmation. Then proceed.

Note: 200 lines is a guideline, not a hard rule. A 250-line diff that is clearly
one coherent change (e.g. a new skill being added) is still autonomous-mode. A
100-line diff spanning five unrelated files in unexpected paths leans interactive.
Use judgement on top of the heuristics.

### 4. Compose the commit message

Infer from the change pattern. Examples:

- Updating one memory file: `Update shared-memory/<file>: <one-line summary>`
- Adding a new memory file: `Add shared-memory/<file>: <what it captures>`
- Adding a new skill: `Add skills/<name>: <what it does>`
- Promoting a project (called from `share-with-brain`): `promote <slug>: lift project context into project-memory/`
- Multiple unrelated files: group by area, e.g. `Update shared-memory and meta/signals.md`
- Appending a signal: `Log signal: <signal type>: <one-line>`

In autonomous mode: use the inferred message directly without confirmation.
In interactive mode: show the proposed message and ask `Use this message? (yes / edit)`.

### 5. Stage and commit

- `git -C <clonePath> add <path1> <path2> ...`: list each file explicitly.
  Never `-A` or `.`.
- `git -C <clonePath> commit -m "<message>"`
- If a pre-commit hook fails: ALWAYS surface the full hook output and stop.
  Do not retry with `--no-verify`. The hooks exist for a reason.

### 6. Fetch and rebase from origin

Concurrent updates from teammates (or your other devices) happen. Always rebase
before pushing.

- `git -C <clonePath> fetch origin <branch>`
- `git -C <clonePath> pull --rebase origin <branch>`
- If the rebase applies cleanly: continue to step 7 (silently in autonomous mode).
- If conflicts occur: go to the conflict resolution sub-flow below.

#### Conflict resolution sub-flow

This is one of the four cases where the skill surfaces to the user. The surfacing
is "here's my proposed fix, approve or refine?", NOT "here's a conflict, you
figure it out from scratch."

For each conflicted file:

**a. Analyse both sides.** Read the file with conflict markers. Identify what the
local side was trying to do and what the remote side was trying to do. Use surrounding
context to infer intent.

**b. Propose a merged version:**
- Both sides added different content to different positions: merge both
- Both sides edited the same line: propose the merge that preserves both intents
  where possible; if incompatible, prefer the more recent / specific change and note
  the tradeoff
- One side deleted what the other modified: preserve the modification
- Genuinely incompatible (truly contradictory): say so explicitly and recommend the
  user picks one side

**c. Surface to the user:**

```
Conflict in <file>.

Local change (your edit, just now):
  + <added/changed lines from local>

Remote change (pushed since your last pull):
  + <added/changed lines from remote>

Proposed merge:
  <the merged version>

Reasoning: <one-line explanation>

How would you like to proceed?
  (a) Approve: apply the proposed merge
  (b) Use mine: discard remote, keep local
  (c) Use remote: discard local, keep remote
  (d) Refine: give me more context, I'll re-propose
  (e) Show me the full diff and let me edit it manually
```

**d. Apply the resolution** per the user's choice, then `git -C <clonePath> add <file>`.
Repeat for each conflicted file. Then `git -C <clonePath> rebase --continue`.

If the user aborts entirely: `git -C <clonePath> rebase --abort` and report cleanly.

### 7. Push: governance routing

Read `governance` from `brain.config.json`:

**Open mode (`"governance": "open"`):**
- `git -C <clonePath> push origin <branch>`
- If rejected because the remote moved during the operation (race): retry once from
  step 6 (fetch + rebase + push). In autonomous mode, the retry is silent. In
  interactive mode, tell the user.
- If rejected after one retry: surface the full git output and stop (fourth surface case).
- On network failure: report briefly, suggest re-invoking after checking connectivity.

**Governed mode (`"governance": "governed"`):**
- Create a short-lived feature branch from the current state:
  `git -C <clonePath> checkout -b brain-update/<date>-<slug>`
  where `<slug>` is a 1-3 word kebab summary of the change.
- Push the branch: `git -C <clonePath> push -u origin brain-update/<date>-<slug>`
- Open a PR against `<branch>` (main) using `gh pr create`:
  - Title: the commit message first line
  - Body: file list + one-line rationale
- Leave the PR open. Do NOT merge. Report the PR URL so the human reviewer can act.
- `gh` must be installed and authenticated. If not, surface the requirement and stop.

### 8. Report

**Autonomous mode (the common path), open governance:** one line.

```
Pushed <sha>. N file(s) live on origin/<branch>.
```

**Autonomous mode, governed:** one line.

```
PR opened: <PR URL>, awaiting human merge.
```

**Interactive mode:** full report including commit message, file list, and URL.

## Edge cases

- **Brain clone not found.** Tell the user the expected path (from config) and ask
  whether the brain lives elsewhere on this machine.
- **Wrong branch.** Name the current branch and offer to switch. Do not push from
  a non-configured branch.
- **Detached HEAD.** Report and stop.
- **Untracked files in brain paths.** If `git status` shows untracked files in
  `shared-memory/`, `project-memory/`, `perspectives/`, `skills/`, `commands/`, or
  `meta/`, treat them as new brain content and run the sensitive-content scan on them.
  Do not silently ignore.
- **Pre-commit hook failure.** Always surface (one of the four surface cases).
  Do not retry with `--no-verify`.
- **Network failure.** Report briefly, suggest re-invoking after checking connectivity.
- **Nothing to push after commit.** Possible if a hook reformats content back.
  Report cleanly and exit.
- **User says "push" with no uncommitted changes.** Report `Nothing to push. No
  uncommitted brain changes.` and exit. Do not push an empty commit.
- **`gh` not installed (governed mode only).** Surface the requirement clearly:
  governed mode requires the `gh` CLI, authenticated to the repo. Do not attempt
  workarounds.

## Common pitfalls (read before invoking)

- **Asking when you should just do.** The default is autonomous. Every avoidable
  interrupt is friction. Surface ONLY when the four conditions apply.
- **Skipping the sensitive-content scan.** Non-negotiable. The scan prevents personal
  preferences and secrets from leaking to shared scope. Run it on every push, even
  if the diff looks innocuous.
- **Showing the diff in autonomous mode.** Don't. The user said "push." If the diff
  is small and clean, the only output is the one-line success report.
- **Proposing without proposing.** When a conflict occurs, always propose a merge
  before showing options. Never ask the user to figure it out from scratch.
- **`git add -A` instead of explicit paths.** Bulk staging risks pulling in untracked
  junk. Always stage by explicit path.
- **Force-pushing on rejection.** Never. Other commits would vanish. Always rebase,
  never `--force`.
- **Bypassing hooks with `--no-verify`.** Don't, ever. Surface the failure instead.
- **Using `--no-verify` flag passed by the user.** Refuse explicitly:
  "push-to-brain does not support --no-verify. The pre-commit hook is a safety net."
- **Hardcoding the clone path.** Always read `brain.config.json`. The path is user-
  configured and varies by deployment.

## Composing with other skills

- **`share-with-brain`** invokes this skill as its final step (after staging project
  content into `project-memory/<slug>/`). When called from `share-with-brain`, the
  commit message is supplied by the caller; skip the inference step.
- **`reflect`** may produce memory updates the user then wants to push (if they are
  brain-scoped). Suggesting "push these to the brain?" after `/reflect` writes memories
  is reasonable, and if the user says yes, this skill handles it.
- **`/wrap`** orchestrates `reflect -> log -> handoff`; it does NOT auto-push to brain.
  If wrap-time edits should be pushed, the user invokes this skill explicitly afterward.
