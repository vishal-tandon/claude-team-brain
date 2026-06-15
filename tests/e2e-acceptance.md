# E2E Acceptance Harness (Layer 2/3)

The conversational install path runs through a live model + Claude Code + GitHub,
so it cannot be unit-tested. This is the by-hand harness: a scripted walk with an
explicit assertion at every step, mapped to the findings it proves fixed. Layer 1
(`tests/run.sh`) must be green before running this.

## Isolation strategy (mandatory — never touch the real config)

`setup-brain` edits `~/.claude/CLAUDE.md` and `~/.claude/settings.json`. Those are
the operator's PRIMARY config. Every run here uses a throwaway environment:

1. **Sandbox HOME.** `export HOME=/tmp/brain-e2e` (fresh each run). Install/copy a
   Claude Code config skeleton there. All `~/.claude/...` writes land in the
   sandbox, not the real home.
2. **Throwaway GitHub repo.** `gh repo create <you>/brain-e2e --private` from the
   public template. Delete it after: `gh repo delete <you>/brain-e2e --yes`.
3. **Second identity for the joiner.** A second `gh auth` profile (or a colleague /
   a deliberately non-collaborator account) to exercise the access-denied path.
4. Never run an unfenced setup against the real `$HOME` until Layer 4.

## Act-by-act assertions

### Act 1-2 — Discovery + owner standup  (proves F5, F10, F4, F6, zero-config)
- Clone the throwaway repo to a NON-default path (e.g. `$HOME/dev/brain-e2e`).
- New session: "I just cloned this brain, set it up."
- ASSERT: Claude never asks you to edit `brain.config.json`. It derives `repo` from
  the git remote (F5), `marketplaceName` from the repo name (F10), asks at most
  name + solo/team, then writes the config itself.
- ASSERT: `marketplace.json` `name` is updated BEFORE the `/plugin install` runs,
  and the install targets the same slug (F4).
- ASSERT: `$HOME/.claude/CLAUDE.md` contains `@$HOME/dev/brain-e2e/CLAUDE.md` (bare
  @, non-default path persisted in the line) (F6).
- ASSERT: `extraKnownMarketplaces.<slug>.autoUpdate == true` in sandbox
  settings.json.

### Act 2b — Sync as owner  (proves F1)
- New session: "sync with brain, am I current?"
- ASSERT: NO false "@import line not found / context not loading" alarm. The drift
  check reads the bare-@ line correctly and reports green.

### Act 3 — Context sharing  (proves clone-path resolution end to end)
- From a real project dir, "share this project with the brain."
- ASSERT: writes land in `$HOME/dev/brain-e2e/project-memory/<slug>/` (the
  non-default clone resolved from the import line), INDEX updated, push succeeds.

### Act 4 — Skill sharing  (proves F2, F8)
- Author `skills/deploy-check/SKILL.md` with normal prose ("When you ask Claude to
  deploy… Do not use the staging token…"). "Push my brain changes."
- ASSERT: the pre-commit guard does NOT block it (F2). Commit + push succeed.
- ASSERT: Claude states the skill lands next session, not mid-session (F8).

### Act 5 — Joiner onboarding  (proves F3)
- As the second identity (NOT a collaborator), "connect me to this brain" with the
  repo link.
- ASSERT: setup surfaces the plain access message ("you're not a collaborator yet,
  ask the owner to add <handle>"), NOT a raw git 404.
- As owner: "add <handle> to my brain." ASSERT: `gh` collaborator add runs; report
  names who was added.
- Re-run joiner setup: ASSERT it now completes (clone, marketplace, install,
  autoUpdate, import all wired); resumes from where it stopped.

### Act 6 — Auto-update propagation  (proves the autoUpdate fix + F7)
- As owner, push another skill. As joiner, open a FRESH session.
- ASSERT: the new skill is present without any manual install.
- F7 negative test: break the joiner's git auth (e.g. revoke token in sandbox),
  open a session. ASSERT: if the optional drift hook is enabled, one line flags the
  staleness; it is not silent. `sync-with-brain` also reports it (check B + E).

### Self-heal  (proves the re-run path)
- Corrupt one wiring point in the sandbox (e.g. point the @import line at a stale
  path, or flip autoUpdate to false). "Fix my brain."
- ASSERT: setup-brain inventories, repairs ONLY the broken point, reports it in one
  line, does not re-run the full standup or re-interview.

## Layer 3 — Naive-user acceptance (the real bar)

One uninterrupted run, scored pass/fail on a single criterion: **did the user touch
anything technical?**
1. Clone, "set it up", answer at most name + solo/team in plain words.
2. "share this project with the brain."
3. "push" / author + share a skill.
4. New session: pushed skill auto-appears.

PASS = zero JSON edits, zero skill names typed by the user, zero git/plugin
commands run by the user, zero "learn how the brain works" required. Claude drives;
the user talks to it like any other chat.

## Layer 4 — Gated live smoke (real machine)

Only after Layers 1-3 are green. One dry-run narration of side effects, confirm,
then one live run on the real `$HOME`. State every file touched before touching it.

## Exit criteria

- `tests/run.sh` green (Layer 1).
- Every Act assertion above passes against the sandbox (Layer 2).
- Layer 3 naive-user run passes clean.
- All 12 findings in `meta/e2e-simulation-findings.md` flip to resolved.
