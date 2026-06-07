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

