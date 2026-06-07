---
name: reflect
description: >
  Analyzes the session for learnings: what worked, what did not, what would
  have been faster. Proposes memory saves, enforcing the local-vs-shared
  boundary (facts to shared-memory/, interaction prefs to personal local only).
  Shows proposed saves before writing. Invoked when the user types /reflect,
  "reflect on this", "reflect on the last task", "what did we learn",
  "what went well", or "let's reflect". Two modes: full session (default)
  or last task only.
triggers:
  - /reflect
  - reflect on this
  - reflect on the last task
  - what did we learn
  - what went well
  - let's reflect
---

# reflect: Session Reflection Skill

## Purpose

Surface what this session taught the team about their tools, processes, and
working patterns. Identify what to save and where. Enforce the
local-vs-shared boundary before writing anything.

---

## Step 1: Determine mode

If the user said "last task" or "last task only", scope to the most recent
discrete task (the last identifiable unit of work before this invocation).
Otherwise default to full session.

---

## Step 2: Analyze the session (or last task)

Read the conversation autonomously. Do not ask the user questions during
analysis. Surface the findings, then ask for approval.

Identify:

**What worked well**
Patterns, tools, or approaches that produced results efficiently. These are
worth encoding.

**What did not work / friction points**
Anything that took longer than expected, required multiple correction rounds,
or hit a dead end. What was the root cause?

**What would have been faster**
Given what you now know: what should have been the first move? What information
would have prevented the longest detour?

**Candidate memory saves**
Facts, decisions, or patterns worth keeping. For each candidate, classify it:

- `shared`: a fact or decision useful to any team member or on any device.
  Target: `shared-memory/<slug>.md` as a new atomic file, or an edit to an
  existing one.
- `personal`: an interaction preference, working style, or individual context.
  Target: personal local memory (`~/.claude/memory/`). These NEVER go into the
  shared brain.
- `project`: context scoped to one project. Target: `project-memory/<slug>/`.
- `meta`: a signal about the brain itself (friction, architectural insight).
  Target: `meta/signals.md` (append) or `meta/decisions.md` (new ADR).

Apply the boundary rule from CLAUDE.md strictly:
> "If content tells Claude how to talk to YOU, it is personal.
>  If it would help anyone working on this project, it is shared."

Never write interaction preferences, tone adjustments, or personal coaching
notes into `shared-memory/`. Flag any candidate that sits on the boundary and
state your classification reasoning.

---

## Step 3: Present findings

Output the reflection in this structure:

```
## Reflection: [full session | last task]

### What worked
[Prose or short bullets]

### Friction / what did not work
[Prose or short bullets, include root cause]

### What would have been faster
[Prose or short bullets, the first-move insight]

### Proposed memory saves

**[slug] -> shared-memory/[filename].md**
> [One-sentence content summary]
[Full proposed file content, formatted per shared-memory/_TEMPLATE.md]

**[slug] -> personal local memory**
> [One-sentence content summary, content shown to user only, not written to shared brain]
[Proposed content, user writes this to their own ~/.claude/memory/ files]

**[slug] -> meta/signals.md (append)**
> [One-line friction signal to append]
```

Show ALL proposed saves before writing any of them.

---

## Step 4: Wait for approval

After presenting, ask once:
"Write these saves? Reply with which to keep (all / numbers / none)."

Wait for the response. Do not write until approved.

---

## Step 5: Write approved saves

For each approved save:

**Shared memory save:**
1. Create `<brainClonePath>/shared-memory/<slug>.md` using the `_TEMPLATE.md`
   frontmatter format (name, description, type, added date, tags).
2. Append a pointer line to `<brainClonePath>/shared-memory/INDEX.md`:
   `[filename](filename.md): one-line description`
3. Confirm: "Wrote shared-memory/[filename].md and updated INDEX."

**Personal local memory save:**
Do NOT write to the shared brain. Instead, output the content formatted and
ready to paste, with the instruction: "Add this to your personal memory files
at `~/.claude/memory/`." Never write to `~/.claude/memory/` automatically.
Personal memory is the user's to manage.

**meta/signals.md append:**
Append the one-line signal to `<brainClonePath>/meta/signals.md`.
Confirm: "Appended to meta/signals.md."

**meta/decisions.md new ADR:**
Append a new ADR entry to `<brainClonePath>/meta/decisions.md` with:
date, decision, context, rationale, trade-offs.
Confirm: "Appended new ADR to meta/decisions.md."

---

## Step 6: Close

After writes are complete, report what was saved and where.
Suggest running `/log` if a session chronicle has not been written yet.
Suggest `/handoff` if the work continues in a new context window.

---

## Boundary enforcement: hard rules

These are non-negotiable:

1. Interaction preferences → personal local only. Never to `shared-memory/`.
2. Personal career context → personal local only. Never to `shared-memory/`.
3. One fact per file in `shared-memory/`. No grab-bag files.
4. INDEX.md must be updated whenever a new file lands in `shared-memory/`.
5. If unsure of tier, classify as personal and flag it explicitly.
