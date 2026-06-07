---
name: explain-brain
description: >
  The discovery and operating-model tour for the Claude Team Brain. Use whenever someone
  wants to understand what the brain is, what is loaded right now, what the skills do, and
  how to operate it well. Triggers: "explain how the brain works", "what's in the brain",
  "walk me through the brain", "give me a tour", "I just set up the brain, what now", or any
  close paraphrase pairing an explain/describe/tour verb with "brain". Reads live brain
  state and brain.config.json at every invocation, so the tour reflects the current brain
  and is adapted to this deployment's actual settings (sync mode, governance, solo vs team).
  Read-only: never modifies brain content, never runs Git operations.
---

# Explain brain

The tour someone gets in their first real session after setup, and any time they want a
current picture of the brain. The job is not to inventory files. It is to orient someone in
how to **operate well**: what is loaded, what the skills are for, and the few habits that
make the brain pay off. Everything below is read from live state and from
`brain.config.json`, so the tour stays true as the brain grows and matches this specific
deployment.

## Core principles

- **Dynamic, not static.** Read the INDEX files, the marketplace manifest, and
  `brain.config.json` every time. Reflect current state, not the snapshot this was written
  against.
- **Teach operation, do not just list.** The point is how to use the brain well, adapted to
  the user's actual config, not a catalogue of files.
- **Topic-level, not file enumeration.** Summarize topics and how to reach them. The user
  should not have to memorize file names.
- **Adapt to scale.** Solo and team read differently. Render the team features as dormant,
  not absent, when the user is solo.

## What this skill does NOT do

- Does NOT modify brain content. Read-only, no Git.
- Does NOT walk through setup. That was `setup-brain`.
- Does NOT enumerate every file or skill in detail. Topic summaries; users drill in by
  asking.

## Step 1: Read state (in parallel)

Resolve `<brain>` from the `@import` line in `~/.claude/CLAUDE.md` (default
`~/.claude/brain`). Read, in parallel:

- `<brain>/brain.config.json` → `name`, `governance`, `syncMode`, `repo`.
- `<brain>/shared-memory/INDEX.md` → topic groupings (the `##` headers) and entries.
- `<brain>/perspectives/INDEX.md` → entries, and count them.
- `<brain>/project-memory/INDEX.md` → empty or populated.
- `<brain>/.claude-plugin/marketplace.json` and the skill frontmatter → available skills.

If a file is missing or malformed, render what you can and note the gap inline. Do not fail
the whole tour on one missing index.

**Determine scale.** Treat the brain as **solo** if there is at most one perspective and no
sign of multiple contributors (single author in recent history, placeholder or single-name
config). Otherwise treat it as **team**. This switches the framing in Steps 2 and 5.

## Step 2: What the brain is (adapted)

Open in plain peer-to-peer voice. Use the config `name`.

- **Team framing:** "This is [name]: your Claude, plus everything the team has taught it.
  Shared facts, the way teammates think, and the team's skills, all loading into your
  sessions and syncing as people learn."
- **Solo framing:** "This is [name]: your Claude with a memory that follows you across
  devices. What you teach it on one machine shows up on the next. The team features are here
  and dormant; they wake up the moment someone else joins."

State the one rule plainly: personal preferences stay local and private; shared knowledge
lives in the brain. The pre-commit guard keeps that boundary for you.

## Step 3: What's loaded right now

From the INDEX reads, render topic-level summaries:

- **Shared memory:** the topic groupings and roughly what each covers. Not a file list.
- **Perspectives:** how many, and how to use one ("review this from the [name]
  perspective"). If solo with only the example perspective, say so and frame perspectives as
  a lens to add when useful.
- **Project memory:** if populated, the projects covered. If empty, one line that it is
  opt-in and wakes up when a project needs its own slice.

## Step 4: The skills, grouped by purpose

Group rather than dump. For each, one line on when to reach for it:

- **Stay in sync:** `sync-with-brain` (pull + drift check), `push-to-brain` (commit +
  share a batch), `share-with-brain` (promote one item up).
- **Session rituals:** `handoff`, `log`, `reflect`, and `/wrap` (reflect then log then an
  optional handoff).
- **Manage the brain:** `setup-brain` (re-runnable for a new machine), `disconnect-brain`
  (clean reversal).

## Step 5: How to operate well (adapted to this config)

This is the part that matters. Translate the config into concrete habits:

- **Sync:**
  - `syncMode: auto` → "Your edits sync on their own: pushed when you make them, pulled at
    session start. You do not have to think about it."
  - `syncMode: reminded` → "You will get a nudge to sync at natural moments. Run
    `sync-with-brain` to pull and `push-to-brain` to share."
  - `syncMode: manual` → "Nothing syncs unless you ask. Run `sync-with-brain` to pull,
    `push-to-brain` to share."
- **Governance:**
  - `governance: open` → "Pushing shares straight to the brain. No ceremony."
  - `governance: governed` → "Pushing opens a PR for review. Do not self-merge; that human
    gate is the point of governed mode."
- **The boundary, restated as a habit:** when you learn something the whole team (or your
  other devices) would want, share it. When it is about how Claude should talk to *you*,
  keep it local. If you are unsure, `share-with-brain` runs the heuristics and tells you.
- **Team-only, shown as dormant for solo:** if solo, name the team habits as things that
  switch on later ("when a teammate joins, their perspective becomes a lens you can apply,
  and shared facts start flowing both ways"), rather than omitting them silently.

## Step 6: Contributing back

Three ways, lightest first:

1. **Signal:** hit something missing or stale? Ask Claude to log it in `meta/signals.md`.
   Append-only, compounds over time.
2. **A fact or reference:** add a file from `shared-memory/_TEMPLATE.md`, update the INDEX,
   run `share-with-brain`.
3. **A perspective:** capture a role's reasoning lens from
   `perspectives/_TEMPLATE.md`.

Close in voice. Team: "That's the brain. It gets better every time someone teaches it
something." Solo: "That's the brain. It already follows you everywhere; it gets sharper
every time you teach it something, and it is ready for your team whenever they arrive."
