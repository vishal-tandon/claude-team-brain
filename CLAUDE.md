# Team Brain: Operating Rules

This file is the `@import` target. It loads into every session where the brain
is active. Keep it focused on operating rules, not background context.

> **Bootstrap (read first if the brain is not set up yet).** If this file is
> loaded because Claude is sitting in a freshly cloned brain repo and the user
> asks to set up, install, connect to, onboard onto, or fix the brain, do not
> improvise: read and follow `skills/setup-brain/SKILL.md` to the letter. That
> skill is the install. (If the brain is already wired, ignore this; the user
> will not be asking to set up.)

---

## The single most important rule

**Personal content never enters the shared brain. Shared content never stays
siloed in personal memory.**

| Content type | Where it lives | Syncs? |
|---|---|---|
| How Claude talks to you (style, tone, preferences) | `~/.claude/memory/` | Never |
| Your career history, 1:1 coaching, identity | `~/.claude/memory/` | Never |
| Facts useful to anyone on the team / any device | `shared-memory/` | Always |
| Project-specific context | `project-memory/<slug>/` | Opt-in |
| Role-based reasoning lenses | `perspectives/` | Always |

Cross-contaminating these breaks teammates' sessions. The pre-commit hook
enforces this mechanically on every device where setup-brain ran, and the
`brain-guard` GitHub Action re-runs the same scan server-side on every push,
so a clone without the hook is still covered. When in doubt: if content tells
Claude how to talk to YOU, it is personal. If it would help anyone working on
this project, it is shared.

---

## Four content tiers

**Tier 1: Personal local** (`~/.claude/memory/`)
Your interaction preferences, identity, career context, 1:1 coaching. Never
synced. Claude reads these to talk to you the way you want to be talked to.

**Tier 2: Shared memory** (`shared-memory/`)
Atomic facts: one file per concept. Useful to every team member and on every
device. Use `shared-memory/_TEMPLATE.md` to add a new fact. Update
`shared-memory/INDEX.md` with a pointer line after adding any file.

**Tier 3: Project memory** (`project-memory/<slug>/`)
Opt-in. Add a sub-directory when a project accumulates enough context to
warrant its own slice. Starts empty. Do not add overhead you do not need.

**Tier 4: Perspectives** (`perspectives/`)
Role-based reasoning lenses. Load with: "Review this from the [name]
perspective." Perspectives change what Claude looks for. They do NOT change
how Claude talks to you. See `perspectives/_TEMPLATE.md` and
`perspectives/example-perspective.md`.

**Solo mode exception (`personal/`)**
A single-owner brain (`"mode": "solo"` in `brain.config.json`) may sync Tier 1
content across the owner's own devices, but ONLY under `personal/`, and the
repo must stay private. In team mode (the default) that directory is ignored
and the guard blocks personal content everywhere. See `personal/INDEX.md` for
how to enable and how to keep the copies fresh.

---

## Push and sync habits

**Sharing something new with the brain:**
Run `share-with-brain` from your session. It runs a divergence check and
content heuristics before promoting. For a batch of changes, use
`push-to-brain`.

**Pulling the latest from the brain:**
Run `sync-with-brain`. It pulls context, checks for drift between your clone
and the plugin cache, and reports staleness in one line. If your config has
`syncMode: auto`, this runs automatically at session start.

**Sync modes** (set in `brain.config.json`):
- `auto`: push on change + pull on start. Best for solo cross-device use.
- `reminded`: four-layer nudge cadence. Best for teams. Default.
- `manual`: no nudges. You control when sync happens.

---

## Governance awareness

**Open mode** (default): `push-to-brain` commits directly to `main`. No
ceremony. Fits solo and high-trust teams.

**Governed mode** (opt-in): `push-to-brain` opens a PR. Human merge required.
Check `brain.config.json` (`"governance": "open" | "governed"`) to know which
mode this brain is in. If governed: do not self-merge.

---

## Available skills

| Skill | When to use |
|---|---|
| `setup-brain` | First install on a new machine, or when checking system readiness |
| `explain-brain` | Tour of what is loaded and how the brain operates |
| `push-to-brain` | Commit and sync a batch of brain changes |
| `share-with-brain` | Promote a single piece of local context to the shared brain |
| `sync-with-brain` | Pull latest context + skills; check for clone-cache drift |
| `disconnect-brain` | Clean uninstall (removes @import, marketplace, hook; leaves clone) |
| `handoff` | Write a session handoff doc |
| `log` | Chronicle the session |
| `reflect` | Run a structured reflection; propose memory saves |
| `/wrap` | End-of-session ritual: reflect → log → optional handoff |

---

## Contributing back to the brain

Anyone can add to shared memory or perspectives. The steps:

1. Create a file using the appropriate `_TEMPLATE.md`.
2. Add a pointer line to the relevant `INDEX.md`.
3. Run `push-to-brain` (or `share-with-brain` for a single item).

The pre-commit hook will scan your content before it commits. If it blocks,
read the error: it is telling you the content is in the wrong tier.

---

## Meta and self-improvement

The brain improves itself. When something feels slow or broken:

- Append a note to `meta/signals.md` (no structure needed, just write it).
- When enough signals accumulate, read them as a cluster and ask if an
  architectural decision should change. Record it in `meta/decisions.md`.

The review ritual is how the brain learns about itself.
