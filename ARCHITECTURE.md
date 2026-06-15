# Architecture: Your Team Brain

This document describes how this brain works for someone operating it daily.
It is not the design spec (that lives in the repo that produced this template).
It is the living reference for what is here and why.

---

## What this is

A git-synced operating layer that gives a team, or one person across devices
and accounts, shared Claude context: product knowledge, ways of thinking, and
reusable skills. GitHub is the sync transport; the skills hide git entirely.
You say "sync with brain" or "share with brain" and never touch a git command.

**Solo across devices is a first-class use case**, equal to team. The word
"team" in the name means "anyone sharing context from one origin repo," not
"must have multiple humans."

---

## Two local materializations, one origin

Every user ends up with the brain in two places locally, both fed from one
GitHub repo:

| Materialization | What it holds | Kept fresh by | Stable path? |
|---|---|---|---|
| **Clone** (`~/.claude/brain/`) | CLAUDE.md + memory indexes (the `@import` context) | SessionStart `git pull` (or `sync-with-brain`) | Yes, it is your clone |
| **Plugin cache** (`~/.claude/plugins/cache/...`) | Skills + commands | marketplace auto-update at startup, gated on the `autoUpdate` flag setup-brain writes (version-less plugin, so every commit is latest once the flag applies it) | No, version dir changes on update |

This split is deliberate. Each mechanism does what it is good at:

- Context wants a stable, `@import`-able path where yesterday's session notes
  are still at the same address. The clone provides that.
- Skills want versioned, auto-updating distribution. The marketplace provides that.

**Critical rule:** never `@import` a path inside the plugin cache. That path
moves on every skill update. Context is always imported from the clone.

**Deployment note (sandboxed setups):** the clone defaults to `~/.claude/brain`.
If your environment confines Claude to a single project directory (a security
sandbox, an allowlist of writable paths), `~/.claude/brain` may sit outside it,
so brain skills that write to the clone will prompt or be denied. Either relocate
the clone inside the sandbox (setup-brain records wherever it actually lives via
the context-import line, so a non-default path works everywhere) or add
`~/.claude/brain` to the writable allowlist.

### The riskiest assumption

Two distinct drift modes exist. First: the two local copies can diverge because
SessionStart pull can fail silently while marketplace auto-update succeeds, so a
skill could reference memory the context copy does not have yet. Second, and more
dangerous: marketplace auto-update is OFF by default for third-party marketplaces,
so if the `autoUpdate` flag is not set (or gets removed), new skills never reach
the user at all. Version omission alone does not fix this; it only defines what
counts as a newer version. `autoUpdate` is what makes Claude Code apply it at
session start. setup-brain writes that flag, and it is load-bearing: without it
the whole "freshness by default" promise is false.

`sync-with-brain` is the dedicated drift detector. It reads clone-commit vs
origin, plugin version, `@import` presence, and the `autoUpdate` flag, reports
staleness in one line, and offers a one-click resync. The autoUpdate check is the
root-cause check: a missing flag is the single most common reason a pushed skill
never shows up for a teammate. Run it when something feels stale, or add it to
your SessionStart sequence.

---

## Four content tiers

The brain's most important design decision is the hard boundary between what
is personal and what is shared.

| Tier | Location | Syncs? | Rule |
|---|---|---|---|
| **1 · Personal local** | `~/.claude/memory/` | Never | Interaction preferences, identity, career context, 1:1 coaching. If it tells Claude how to talk to YOU, it lives here. |
| **2 · Shared memory** | `shared-memory/` | Always | Facts, references, and context useful to any team member on any device. Atomic: one fact per file. |
| **3 · Project memory** | `project-memory/<slug>/` | Opt-in | Project-scoped context for active projects. Starts empty. Add a sub-directory when a project needs it. |
| **4 · Perspectives** | `perspectives/` | Always | Role-based reasoning lenses. Used as lenses only; never adopted as interaction style. |

**The boundary rule is the most important rule in the system.** Personal content
(how Claude talks to you) must never enter the shared brain. Facts and
capabilities (useful to anyone) must not stay siloed in personal memory.

The pre-commit hook in `hooks/pre-commit` enforces this mechanically by scanning
for personal-preference patterns before every commit. `push-to-brain` runs the
same scan and refuses `--no-verify`.

### Atomic memory (Tier 2 and 3)

Shared memory uses **one fact per file** rather than fat topic documents. This
design makes concurrent edits conflict-free by construction: two people touching
different facts are touching different files. When someone touches the same
atomic fact, the diff is small and legible.

INDEX files (`shared-memory/INDEX.md` etc.) are pointer lists only, one line
per fact file. They are marked `merge=union` in `.gitattributes` so concurrent
appends from different contributors land cleanly without a conflict.

---

## Configuration externalization

Every deployment-specific value lives in `brain.config.json` at the repo root.
No skill contains a hardcoded path, repo slug, or org name. Change
`brain.config.json` and the whole template retargets.

Key fields:

| Field | Purpose |
|---|---|
| `name` | Human label, used in onboarding copy |
| `marketplaceName` | Marketplace slug for `/plugin install` |
| `repo` | `owner/repo` on GitHub |
| `branch` | Single working branch (default: `main`) |
| `defaultClonePath` | Where to clone locally (default: `~/.claude/brain`) |
| `governance` | `"open"` or `"governed"`, controls push-to-brain routing |
| `syncMode` | `"auto"`, `"reminded"`, or `"manual"`, controls sync nudges |
| `authValidation` | `null` = any authed `gh` account. Regex string = enterprise handle validation. |

---

## Governance modes

### Open (default)

One branch (`main`), direct push. Zero setup. Fits solo use and high-trust
teams. `push-to-brain` commits and pushes directly.

### Governed (opt-in)

Protect `main`, work on short-lived branches. `push-to-brain` commits to a
branch and opens a PR instead of pushing. Human merge is required. The review
gate is the entire point.

To enable governed mode:
1. Set `"governance": "governed"` in `brain.config.json`.
2. Follow `docs/governed-mode.md` to configure branch protection and CODEOWNERS.

---

## Skills and the plugin marketplace

Skills are distributed via Claude Code's native plugin marketplace
(`/plugin marketplace add owner/repo`), not symlinks. The plugin ships with no
pinned `version`, so Claude Code treats each new commit as the latest version.
That alone is not enough: third-party marketplaces have auto-update OFF by
default, so setup-brain writes `autoUpdate: true` for this marketplace into the
user's settings. With the flag set, Claude Code refreshes skills at session
start. Freshness by default: a push to the repo is live for everyone on their
next session, no version bump required. Without the flag, new skills never
install on their own, which is exactly the failure `sync-with-brain` check E
diagnoses.

Skills are grouped by purpose:

**Setup:** `setup-brain`, `explain-brain`, `disconnect-brain`
**Brain updates:** `push-to-brain`, `share-with-brain`, `sync-with-brain`
**Session rituals:** `handoff`, `log`, `reflect`, `wrap` (command)

`setup-brain` wires both materializations in one flow after clone: adds the
marketplace, installs skills, enables `autoUpdate` for the marketplace so new
skills install themselves, writes the `@import` to your CLAUDE.md, and optionally
adds the SessionStart pull hook for the context clone.

---

## Robustness model: context is not code

GitHub here is a context bus, not a code pipeline. Code best practices are
applied only where they actually serve context management.

| Code norm | Brain call | Reason |
|---|---|---|
| Rebase for clean history | Merge / union | History tidiness is irrelevant. Never block, never lose content. |
| Atomic curated commits | Frequent, coarse commits | Commit granularity is noise. Freshness beats tidiness. |
| PR review gate | Optional (governed only) | Review throttles context flow. Trust by default. |
| Rigorous conflict resolution | Additive auto-merge | Context conflicts are almost always two appends. |
| .gitignore artifacts | .gitignore personal/secrets | Different threat: leak, not bloat. |

The `.gitattributes` `merge=union` setting, atomic memory design, and
pre-commit guard are the three structural robustness features. They address
the three most likely failure modes: merge conflicts on append-only files,
conflicting edits to shared facts, and accidental personal/secret content leaks.

---

## Extension seams

The brain stays context-only. It is not a code repo. Three named extension
points exist without requiring architectural change:

1. **New memory or pointers:** add atomic fact files to `shared-memory/` and
   update `INDEX.md`. Zero coordination needed.
2. **New skills:** add to `skills/`, register in `.claude-plugin/marketplace.json`.
3. **New perspectives:** add to `perspectives/`, update `perspectives/INDEX.md`.

Code lives in its own repos. The brain can reference them via a shared-memory
pointer (e.g. `reference_design_system_repo.md`). A code repo can independently
`@import` the brain or register its marketplace, fully decoupled.

---

## Self-improvement loop

`meta/` is the brain's feedback layer:

- `meta/signals.md`: append-only friction journal. No structure required.
  Log anything slow, broken, or confusing. Union-merged, so concurrent
  appends are conflict-free.
- `meta/decisions.md`: architectural decision records. Significant choices
  with context, options considered, and rationale. Supersede entries with new
  ones; do not delete history.

When `signals.md` has enough entries (rough guide: 5-10), read them as a
cluster and ask: "What does this pattern mean for the architecture?" If an ADR
should change, write a new entry. Decisions accumulate, not overwrite.
