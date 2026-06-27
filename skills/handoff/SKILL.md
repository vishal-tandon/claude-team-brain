---
name: handoff
description: >
  Generates a copy-pasteable continuation prompt for a fresh context window.
  Reads active brain state (memory indexes, project memory, recent session
  outcomes) and produces one clean prompt capturing accomplishments, locked
  decisions, open items, and next steps. Invoked when the user types /handoff,
  "write a handoff", "generate a handoff prompt", "continuation prompt",
  or "hand this off to a new window".
triggers:
  - /handoff
  - write a handoff
  - generate a handoff prompt
  - continuation prompt
  - hand this off to a new window
---

# handoff: Continuation Prompt Skill

## Purpose

When a session ends or context is about to be reset, produce a single prompt
the user can paste into a new Claude window to resume exactly where the team
left off, with no context lost.

---

## Step 1: Read brain state

Resolve the brain clone path from `brain.config.json` (`defaultClonePath`,
default `~/.claude/brain`).

Read the following (skip any that do not exist):

1. `<brainClonePath>/CLAUDE.md`: active operating rules
2. `<brainClonePath>/shared-memory/INDEX.md`: what shared facts are loaded
3. `<brainClonePath>/project-memory/INDEX.md`: project memory index
4. `<brainClonePath>/meta/decisions.md`: architectural decisions (last 3 entries)
5. `<brainClonePath>/meta/session-log.md`: last session entry (if exists)
6. Any `project-memory/<slug>/` relevant to the current project (if active)

Also read the current conversation to identify:
- What was accomplished this session
- Decisions that were made and locked
- What is currently in-progress or unresolved
- Explicit next steps the user mentioned

---

## Step 2: Draft the handoff prompt

The output is a single fenced code block (` ```text `) the user can copy and
paste directly into a new Claude Code window.

Structure of the continuation prompt:

```
You are resuming work on [project name or brief description].

## Brain context
The team brain is installed at [brainClonePath]. The brain's CLAUDE.md is
@imported and active. Key shared memory covers: [2-4 line summary from INDEX].

## What was accomplished this session
[Bullet list: 3-6 items, each a concrete outcome, files changed, decisions
made, features shipped, problems resolved.]

## Locked decisions: do not re-open
[Bullet list of decisions that were deliberated and settled. A future session
should proceed from these, not relitigate them.]

## Open items
[Bullet list of anything explicitly deferred, flagged as uncertain, or left
for the next session. If nothing is open, write "None."]

## Where to pick up
[1-3 sentences describing the exact next move. Be specific: what file, what
command, what question to answer first.]

## Context to verify before starting
Before executing anything, verify current state:
- Run `sync-with-brain` to confirm the brain is up to date.
- [Any project-specific state check relevant to the work, e.g. "check git
  status", "confirm the dev server is running", "re-read <specific file>".]
```

Keep the prompt tight. A fresh context window should be able to start
productive work within two exchanges of reading this. Do not include full
file contents. Use pointers and summaries. The brain's `@import` will reload
shared context automatically. Prescribe WHAT and WHY (current state, locked
decisions, next move), not HOW — assume a capable executor that will read the
linked files and the @imported rules rather than needing methodology spelled out.

---

## Step 3: Present the handoff prompt

Output the complete prompt in a single fenced block. Do not add commentary
around it. The block is the deliverable.

Then add one line after the block:
"Copy the block above and paste it into a new Claude Code window to resume."

---

## Step 4: Optional: write to file

If the user says "save it" or "write to file", write the prompt (without the
fence) to:

`<project-root>/data/handoff-[YYYY-MM-DD].md`

Create `data/` if it does not exist. Confirm the path.

---

## Notes

- Handoffs describe **present state**, not aspirational state. Every line
  should reflect what is actually true right now, not what was planned.
- Do not include personal interaction preferences in the handoff. The recipient
  window will load the user's own local memory independently.
- Do not restate operating rules saved to a CLAUDE.md this session — they
  auto-load / reload via `@import`. Repeating them in the handoff is a redundant
  second source of truth that drifts. Include a session-only note ONLY if a fresh
  window reading the @imported rules + the linked files would still miss it.
- The "context to verify" section exists because handoffs describe past state.
  Treat it as a mandatory state-check gate, not optional boilerplate.
- If the brain clone is not found, write the handoff from conversation context
  only and note: "Brain clone not found. Handoff based on session context only.
  Run setup-brain in the new window before starting work."
