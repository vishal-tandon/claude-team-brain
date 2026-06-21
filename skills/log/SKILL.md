---
name: log
description: >
  Chronicles the current session as a human-to-machine interaction log.
  Invoked when the user types /log, "log the session", "write the session log",
  "chronicle this session", or at end-of-session when /wrap runs it automatically.
  Writes to two destinations: the active project's session log and optionally
  a global log path. Uses narrative attribution (who initiated each move),
  not bullet dumps. Append-only, never overwrites existing entries.
triggers:
  - /log
  - log the session
  - write the session log
  - chronicle this session
---

# log: Session Chronicle Skill

## Purpose

Write a durable record of what happened this session: who decided what, what
was built or changed, and what was resolved. The log is the team's memory of
work-in-progress and decisions. It is narrative, not a task list.

---

## Step 1: Resolve log paths

Read `brain.config.json` from the brain clone (default `~/.claude/brain/brain.config.json`).
The brain's clone path is `defaultClonePath`.

Session log destinations:

1. **Project log**: `<project-root>/data/session-log.md`. If `data/` does not
   exist, create it. If no project root is identifiable, ask the user once:
   "Where should I write the session log?"

2. **Global log**: `<defaultClonePath>/meta/session-log.md`. Append here as
   well so the brain accumulates a cross-session record.

Both are append-only. Never truncate or rewrite existing content.

---

## Step 2: Reconstruct the session narrative

Scan the conversation from the top. Identify:

- What the user came in wanting to accomplish (the opening intent)
- The main moves: decisions made, code written, problems hit, pivots taken
- Who initiated each significant move (user or Claude)
- What was resolved vs what was left open
- Any locked decisions that a future session should not re-litigate

Do NOT reproduce every message. Distill into a coherent narrative of the work.
Three to eight paragraphs is the right length for a typical session. Longer
sessions may warrant more; a five-minute check-in may warrant two paragraphs.

---

## Step 3: Write the log entry

Format for each entry:

```
---
## Session: [YYYY-MM-DD] [brief descriptor, e.g. "wired auth flow"]

[Narrative paragraphs. Name who initiated each move.
 Example: "The user opened with a request to... Claude proposed... After
 reviewing the output, the user redirected toward... The session closed with
 X resolved and Y deferred."]

**Open items**: [bullet list, or "none"]
**Locked decisions**: [bullet list of anything that should not be re-opened, or "none"]

---
```

Use prose paragraphs for the body. Reserve bullets only for open items and
locked decisions. No headers inside the narrative paragraphs.

---

## Step 4: Append to both destinations

Append the formatted entry to:
1. `<project-root>/data/session-log.md` (create file + `# Session Log\n\n` header if new)
2. `<defaultClonePath>/meta/session-log.md` (create file + `# Global Session Log\n\n` header if new)

Confirm both writes. Report: "Session logged to [project path] and [global path]."

If the brain clone path is not reachable (brain not installed), write only to
the project log and note: "Brain clone not found. Wrote project log only."

---

## Notes

- `meta/session-log.md` in the brain repo is marked `merge=union` in
  `.gitattributes`, so concurrent appends from multiple team members are
  conflict-free.
- Do not include personal interaction preferences, career context, or anything
  that belongs in personal local memory (`~/.claude/memory/`). The log records
  work, not people's individual styles.
- The log is a chronicle, not a report. Write it so a teammate reading cold
  can understand what happened and why, not just what changed.
