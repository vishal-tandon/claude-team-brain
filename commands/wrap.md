---
name: wrap
description: End-of-session ritual. Orchestrates reflect → log → optional handoff in sequence.
---

Run the end-of-session ritual in order:

1. Run `/reflect`: surface what worked, what did not, and proposed memory saves. Write approved saves to CLAUDE.md before continuing.
2. Run `/log`: chronicle the session to the project session log and the global session log.
3. Ask: "Want a `/handoff` doc for the next session?"
   - If yes: run `/handoff`.
   - If no: close cleanly.

Keep each step sequential. Do not start the next until the current one is complete and any approvals from the user are captured.
