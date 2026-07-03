# Decisions: Architectural Decision Records

Each entry records a significant design choice: context, options considered,
decision made, and rationale. Decisions are superseded by new entries, not
deleted. The history matters.

Format: ADR-NNN, date, title, then the four sections below.

---

## ADR-001: Four tiers, open-default governance, one repo

**Date:** 2026-01-01
**Status:** Accepted

### Context

A shared Claude context layer needs to solve three tensions simultaneously:

1. **Personal vs shared.** Claude's most useful configuration is deeply
   personal (how it talks to you, your career context, your 1:1 coaching).
   None of that should leak to teammates. But factual knowledge (product
   context, design system references, ways of working) benefits everyone.
   A single bucket forces a choice between utility and privacy.

2. **Trust vs oversight.** Some teams want direct push access with no
   ceremony. Others operate in regulated environments and want an audit
   trail and human review on every change. A single governance model
   excludes one group or imposes overhead on the other.

3. **Context distribution vs skill distribution.** Claude context (the
   `@import` chain) wants a stable, addressable path. Skills want
   versioned, auto-updating distribution. These have different update
   cadences and different failure modes. Coupling them into a single
   mechanism creates either stale skills or broken context imports.

### Options considered

**One flat bucket:** All memory in one location, no tiers. Simple, but
forces the personal-vs-shared tradeoff: either everything leaks or
nothing is shared. Rejected.

**Full enterprise model by default:** PR gates, CODEOWNERS, branch
protection from day one. Serves regulated teams but imposes overhead on
solo users and high-trust teams. Rejected as default; kept as opt-in.

**Two repos (context + plugins):** Separates the update channel problem
cleanly. Adds coordination overhead: two repos to maintain, two sources
of truth, two things to clone. Rejected in favour of one repo with two
local materializations.

**Symlinks for skill distribution:** Used in prior enterprise deployment.
Works on macOS/Linux, breaks on Windows (requires elevated permissions).
Deleted in favour of native plugin marketplace.

### Decision

**Four tiers with a hard local-vs-shared boundary.**

- Tier 1 (personal local): never synced. Lives in `~/.claude/memory/`.
  Interaction preferences, identity, career context. The rule: if it tells
  Claude how to talk to YOU, it belongs here.
- Tier 2 (shared memory): always synced. Lives in `shared-memory/`.
  Facts, references, and context useful to any team member or on any device.
- Tier 3 (project memory): opt-in sync. Lives in `project-memory/<slug>/`.
  Project-scoped context for active projects.
- Tier 4 (perspectives): always synced. Lives in `perspectives/`.
  Role-based reasoning lenses. Used as lenses, never adopted as interaction style.

**Open governance by default, governed mode as opt-in.**

One config flag (`governance: open | governed`) routes `push-to-brain` between
direct push and open-a-PR. Open mode has zero ceremony. Fits solo use and
high-trust teams. Governed mode adds PR gates and CODEOWNERS for teams that
want review, audit trail, or compliance. The flag is in `brain.config.json`;
switching governance is a one-line change.

**One repo, two local materializations.**

The same GitHub repo serves as both:
- The `@import` context source (cloned to `~/.claude/brain/`, stable path)
- The plugin marketplace source (cached by Claude Code marketplace, versioned path)

This keeps one source of truth and one thing to contribute back to. The tradeoff
is that the two local copies can drift if one update channel fails. `sync-with-brain`
exists specifically to detect and resolve this drift. See ADR-001-riskiest-assumption
note in ARCHITECTURE.md.

### Rationale

The four-tier design makes the personal-vs-shared boundary **structural**,
not advisory. The sensitive-content scanner (pre-commit hook + push-to-brain)
enforces it mechanically. The governance config makes the trust model explicit
and changeable without changing any other part of the system. One repo reduces
the surface area a new user must understand.

### Consequences

- Skills must read `brain.config.json` for all constants. No hardcoded paths.
- The local-vs-shared boundary must be documented prominently and checked by
  the pre-commit guard.
- `sync-with-brain` is load-bearing: the riskiest assumption (clone-cache drift)
  depends on it for detection and remediation.
- Solo users and team users use the same system; solo is the default, team
  features activate as more people join.


---

## ADR-002: Server-side guard, solo personal tier, freshness surfacing

**Date:** 2026-07-03
**Status:** Accepted

### Context

A live deployment audit (solo fork, 11 days of use) surfaced three failure
classes the original design left open:

1. **The most important rule was enforced client-side only.** The
   personal-content guard ran solely as a pre-commit hook, which protects only
   devices where setup-brain set `core.hooksPath`. Any bare clone could push
   personal content or secrets straight to main.
2. **Freshness failed silently.** The system's "always up to date" promise
   rests on two invisible client flags (the marketplace `autoUpdate` flag and
   the SessionStart pull hook). In the audited deployment the flag was missing
   and the plugin cache sat stale for 11 days with no complaint. The
   self-improvement loop (signals.md, review ritual) had likewise never fired:
   nothing triggers it.
3. **"Solo across devices is first-class" had no mechanism.** Tier 1 was
   defined as never-synced, yet the solo user's personal layer is exactly the
   context that must travel. The audited fork hand-rolled a synced personal
   tier with manual snapshot copies, which drifted ~180 lines from the live
   files within 10 days: proof both that the need is real and that unmanaged
   snapshots fail.

### Options considered

**Keep everything client-side and document harder.** Rejected: the observed
failures were silent; documentation does not surface them.

**An AI agent (scheduled Claude run) to audit freshness and boundaries.**
Rejected as the default: every check involved is deterministic (diff scan,
timestamp math, flag presence). Shell in GitHub Actions does it at zero token
cost and with no billing setup on forks. AI review can be layered on later.

**A separate personal-sync tool outside the brain repo.** Rejected: a second
sync channel to install and keep healthy reintroduces the drift problem it
solves.

### Decision

1. **`brain-guard` workflow** re-runs the exact `hooks/pre-commit` scan
   server-side on every push and PR (soft-reset trick stages the pushed diff,
   then runs the hook verbatim: one scan implementation, two enforcement
   points). Governed mode adds it as a required status check.
2. **`brain-staleness-digest` workflow** runs weekly, deterministically checks
   repo freshness, signals.md activity, and shared-memory adoption, and
   maintains a single digest issue. It is the review ritual's forcing function.
3. **`hooks/session-start.sh`** replaces the bare `git pull` SessionStart
   hook. It ships in the repo (updates via pull), pulls context, and prints
   one-line in-session warnings on pull failure or a missing autoUpdate flag.
4. **Solo mode is now a config flag** (`"mode": "solo"`). It gates a synced
   `personal/` tier: the guard permits personal content there ONLY, still
   scans it for secrets, and blocks it everywhere else. `personal/INDEX.md`
   entries declare `source:` lines; push-to-brain refreshes snapshots before
   every push, sync-with-brain applies pulled updates back outward. Team mode
   keeps `personal/` ignored and fully blocked.

### Consequences

- The boundary rule no longer depends on every device running the installer.
- Freshness failures and a dormant review ritual surface within a week
  instead of never.
- A solo brain with a synced personal tier must stay private; converting to
  team use requires re-ignoring `personal/` and purging its history.
- The guard scan logic must stay in `hooks/pre-commit` (both enforcement
  points execute that file); never fork the patterns into the workflow.
