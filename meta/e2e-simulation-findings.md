# End-to-End Simulation Findings — 2026-06-15

Two-user dry run of the brain: a stranger (Alex) finds the GitHub page, installs
the brain as owner, then onboards a teammate (Sam). Four workflows exercised:
onboarding, context sharing, skill sharing, auto-updates. This log captures every
point where the architecture breaks or degrades, ranked by severity, with repro
and proposed fix. No code changed by this pass; it is a findings register.

Severity scale: **BLOCKER** (workflow cannot complete), **HIGH** (silent or
confusing failure that defeats the feature's promise), **MEDIUM** (degraded but
recoverable), **LOW** (polish / waste).

---

## F1 — `@import` detector and remover look for a string setup never writes  (BLOCKER)

**Workflows:** onboarding, auto-update drift detection, disconnect.

**What happens:** `setup-brain` writes the context import as `@<brain>/CLAUDE.md`
(the real Claude Code import syntax is a bare `@path`). But `sync-with-brain`
check C searches for `@import <clonePath>/CLAUDE.md`, and `disconnect-brain`
searches for `@import.*<clonePath>.*CLAUDE.md`. Neither matches a line that has no
literal `import` token.

**Consequences:**
- `sync-with-brain` always reports "@import line not found. Context is not loading.
  Run setup-brain to restore." even on a correct install. Permanent false alarm
  that tells the user to re-run setup forever.
- `disconnect-brain` never finds the line, so a clean uninstall silently leaves the
  brain loading into every session after the user thinks they removed it.

**Root cause:** `setup-brain/SKILL.md` step 5 item 1 (`@<brain>/CLAUDE.md`) vs
`sync-with-brain/SKILL.md` check C and `disconnect-brain/SKILL.md` step 1A / step 2
(both use the literal `@import`).

**Fix:** pick one canonical syntax (the bare `@path` is correct for Claude Code)
and make all three skills match on it. Detectors should grep for
`^@.*<clonePath>.*CLAUDE\.md` and tolerate an optional legacy `import` token.

---

## F2 — Pre-commit personal-content guard blocks legitimate skill pushes  (BLOCKER for skill sharing)

**Workflow:** skill sharing.

**What happens:** `hooks/pre-commit` PASS 2 scans every staged file, including
`skills/**/SKILL.md`, for second-person imperative phrasing. Skill instructions are
written in exactly that voice. Real matches:
- `when (i|you) (say|write|ask|tell)` hits any skill that says "when you ask Claude
  to…", "when you say deploy…".
- `(do not|don't) (address me|call me|use)` hits any skill containing "do not use
  X" — extremely common in skill prose.

So the moment Alex authors a new skill and runs `push-to-brain`, the commit is
blocked by the guard meant for personal memory. The skill-sharing workflow cannot
complete through the sanctioned path.

**Root cause:** `hooks/pre-commit` lines 66-90 apply PASS 2 to all text files with
no path exemption. `push-to-brain` correctly refuses `--no-verify`, so there is no
escape hatch by design — which turns a false positive into a hard block.

**Fix:** exempt `skills/` and `commands/` from PASS 2 (personal-preference scan).
Keep PASS 1 (secrets) and PASS 3 (denylist) on every file. Tighten PASS 2 patterns
so `do not use` requires a personal object (`do not use my`, `do not call me`).

---

## F3 — Private-repo joiner has no access path  (BLOCKER for team onboarding)

**Workflow:** onboarding (joiner / second user).

**What happens:** the brain repo is private by default. Alex "invites the team by
sending the repo link" (per README). Sam pastes the link, Claude tries to clone and
`/plugin marketplace add owner/repo` — both 404, because Sam is not a collaborator
on Alex's private repo. Nothing in `setup-brain`'s joiner flow provisions or even
mentions repo access.

**Consequences:** the headline team path ("send them the link") dead-ends. The
joiner cannot clone, cannot add the marketplace, cannot install skills.

**Root cause:** `setup-brain` joiner branch assumes the clone succeeds; README
"invite your team (send them the repo link)" omits the access grant.

**Fix:** owner-side step in `setup-brain` close + README: "add teammates as repo
collaborators (or make the repo internal/public) before sending the link." Joiner
pre-flight should detect a clone/auth 404 and surface "you may not have access to
this repo yet — ask the owner to add you as a collaborator" instead of a raw git
error.

---

## F4 — Owner config propagation runs AFTER the install that depends on it  (HIGH)

**Workflow:** onboarding (owner).

**What happens:** `setup-brain` step 5 adds the marketplace and runs
`/plugin install brain@<marketplaceName>`. Step 6 (owner only) then propagates
`marketplaceName` from `brain.config.json` into `marketplace.json` `name`. If the
owner set `marketplaceName: acme-brain` in config but `marketplace.json` still has
the template default `your-team-brain`, the marketplace registers under
`your-team-brain` while the install targets `brain@acme-brain` → install fails or
silently installs nothing. The propagation that would reconcile them happens one
step too late.

**Root cause:** ordering in `setup-brain/SKILL.md` (step 5 before step 6).

**Fix:** move owner propagation before the marketplace add/install, or have step 5
read the marketplace name from `marketplace.json` (the file Claude Code actually
parses) rather than from `brain.config.json`.

---

## F5 — `setup-brain` trusts `brain.config.json.repo` without validating it  (HIGH)

**Workflow:** onboarding (owner).

**What happens:** the template ships `repo: "your-org/your-brain"`. If Alex clones
their fork and runs setup without editing config first (a very likely cold-start
order — "I just cloned it, now what"), `setup-brain` runs
`/plugin marketplace add your-org/your-brain` against a repo that does not exist.

**Root cause:** `setup-brain` reads `repo` from config and never cross-checks it
against the clone's real origin or rejects placeholder values.

**Fix:** derive `repo` from `git -C <clone> remote get-url origin` (the ground
truth), or validate `config.repo` matches the remote and hard-stop on the
`your-org/your-brain` placeholder with "edit brain.config.json first."

---

## F6 — The actual clone path is never persisted  (HIGH)

**Workflows:** every skill that runs after setup.

**What happens:** `push-to-brain`, `sync-with-brain`, `share-with-brain`,
`disconnect-brain` all say "use the user's recorded clone path if recorded, else
default `~/.claude/brain`." Nothing ever records it. `setup-brain` clones (possibly
to a non-default path) but writes the path nowhere a later skill reads. A user who
clones anywhere but `~/.claude/brain` has every subsequent skill silently look in
the wrong place and report "brain clone not found."

**Root cause:** no persistence of the resolved clone path; the "if recorded"
branch in four skills has no writer.

**Fix:** `setup-brain` writes the resolved clone path into a known location (e.g. a
`clonePath` field appended to the user's settings, or a small `~/.claude/brain.lock`
pointer). All skills read it there before falling back to the default.

---

## F7 — autoUpdate failure at session start is invisible  (HIGH)

**Workflow:** auto-update.

**What happens:** with the autoUpdate fix in place, skills refresh at session start
— but only if the session-start update succeeds. For a private repo with expired
git/gh credentials, or offline, autoUpdate fails silently. The joiner keeps running
stale skills with no signal. Only a manual `sync-with-brain` check E surfaces it.
This is the same invisible-staleness class as the original work-edition bug; the fix
makes the happy path work but leaves the failure path silent.

**Root cause:** no proactive surfacing of autoUpdate success/failure; detection is
manual-only.

**Fix:** optional SessionStart hook that runs the `sync-with-brain` drift check
quietly and prints one line only when something is stale. Pairs with the existing
optional context-pull hook.

---

## F8 — New skill reaches users only on the NEXT session, including its author  (MEDIUM)

**Workflow:** skill sharing, auto-update.

**What happens:** autoUpdate runs at session start. Alex authors a skill, pushes it,
but cannot use it in the same session — the marketplace cache updates at the next
session start, not live. Same for Sam. There is no in-session "skill just landed"
path. Acceptable, but undocumented, and the close copy ("live for everyone on their
next session") undersells the restart requirement.

**Root cause:** plugin refresh is session-start-scoped; docs imply immediacy.

**Fix:** document the one-restart latency explicitly in `explain-brain` and the
skill-sharing copy. Optionally mention `/plugin marketplace update` +
`/reload-plugins` for same-session pickup.

---

## F9 — Plugin source `.` duplicates the entire brain into the plugin cache  (MEDIUM)

**Workflows:** auto-update, storage hygiene.

**What happens:** `marketplace.json` sets the plugin `source: "."`, so the plugin
cache contains the whole repo — `shared-memory/`, `perspectives/`, `project-memory/`
— not just `skills/` and `commands/`. Context therefore exists in two local copies:
the clone (which `@import` reads) and the plugin cache (which nothing reads for
context). Every commit to any memory file bumps the plugin "version" (commit sha),
so autoUpdate re-pulls the full plugin on every session after any push, even a
one-line memory note. Wasteful and a confusion vector (two copies of shared-memory,
only one authoritative).

**Root cause:** `source: "."` with no narrowing to the executable surface.

**Fix:** if the plugin schema supports a narrower source/component scoping, point
the plugin at `skills/` + `commands/` only, leaving memory exclusively in the clone.
If not supported, document that the cache copy of memory is inert and must never be
`@import`ed (already a rule, but the duplication remains).

---

## F10 — `marketplaceName` collisions on unedited template  (MEDIUM)

**Workflows:** onboarding, plugin-cache location.

**What happens:** default `marketplaceName: your-team-brain`. Two people who fork
without renaming, or one person trying two brains, collide on the same marketplace
slug in `~/.claude/`. `sync-with-brain` and `explain-brain` locate the plugin cache
by `marketplaceName`, so a collision points drift detection at the wrong cache.

**Root cause:** placeholder slug that works if left unchanged, so people leave it.

**Fix:** `setup-brain` owner flow should require a non-default `marketplaceName`
(refuse `your-team-brain`), or derive it from the repo name.

---

## F11 — explain-brain solo/team detection misreads a fresh fork  (LOW)

**Workflow:** first-session tour.

**What happens:** `explain-brain` infers solo vs team partly from "single author in
recent history." A fresh fork carries the template author's commit history, so a
genuinely solo new owner may be framed as a team (or vice versa).

**Fix:** base scale detection on contributor count in the populated content tiers
(shared-memory / perspectives authors) rather than raw git history, or on an
explicit `scale` hint in config.

---

## F12 — Security boundary: brain clone lives outside the project sandbox  (LOW, deployment-specific)

**Workflow:** all (Vishal's own machine specifically).

**What happens:** `~/.claude/CLAUDE.md` (claude-projects) declares
`/home/vishal/claude-projects/` the security boundary. The brain clone defaults to
`~/.claude/brain`, outside it, so every brain skill write triggers a permission
prompt or violates the stated boundary on Vishal's setup.

**Fix:** deployment note — either relocate the clone under the sandbox or add an
explicit allow for `~/.claude/brain` in settings. Generic users unaffected.

---

## Resolution status (patched 2026-06-15, branch fix/auto-update-skills-distribution)

| # | Status | Fix location | Test |
|---|---|---|---|
| F1 | FIXED | bare-@ regex in `sync-with-brain` check C + `disconnect-brain` 1A | `lint_import_syntax.sh` |
| F2 | FIXED | `hooks/pre-commit` PASS 2 exempts `skills/`+`commands/`, patterns tightened | `test_precommit.sh` (8 cases) |
| F3 | FIXED | `setup-brain` step 8 (owner `gh` collaborator add) + step 4 joiner access message; README | e2e Act 5 |
| F4 | FIXED | `setup-brain` step 6 propagates manifest name BEFORE step 7 install | `test_primitives.sh` + e2e Act 1-2 |
| F5 | FIXED | `setup-brain` derives `repo` from git remote, rejects placeholder | `test_primitives.sh` |
| F6 | FIXED | clone path read from the import line; 4 skills updated to resolve it | `test_primitives.sh` round-trip |
| F7 | FIXED | optional SessionStart drift hook in `setup-brain` step 7 item 4 | e2e Act 6 negative test |
| F8 | FIXED | next-session latency documented in README auto-update bullet | e2e Act 4 |
| F9 | MITIGATED | explicit `skills`/`commands` in manifest + documented cache copy is inert (no clean exclude exists per docs) | n/a |
| F10 | FIXED | `setup-brain` derives `marketplaceName` from repo name, rejects default | `test_primitives.sh` |
| F11 | FIXED | `explain-brain` scale detection uses content authors, not git history | e2e (manual) |
| F12 | DOCUMENTED | ARCHITECTURE deployment note on clone vs sandbox | n/a |

Plus the central reframe: `setup-brain` is now a zero-config self-installer that
derives + interviews + writes config + self-heals, so F4/F5/F6/F10 cannot recur by
construction rather than being patched one by one.

Remaining verification owed: Layers 2-4 of `tests/e2e-acceptance.md` (live model +
sandbox HOME + throwaway repo). Layer 1 (`tests/run.sh`) is green.
</content>
</invoke>
