# Meta: Index

The `meta/` directory is the brain's self-improvement layer. It tracks
friction, records decisions, and accumulates the signal that drives
architectural change.

No permission needed to append here. Just write what you noticed.

## Files

| File | Purpose |
|---|---|
| [signals.md](signals.md) | Append-only friction journal. Log anything that felt slow, broke, or was confusing. No structure required. |
| [decisions.md](decisions.md) | Architectural decision records (ADRs). Significant design choices with context, options considered, and rationale. |

## Review ritual

When `signals.md` accumulates enough entries (rough guide: 5-10), read them
as a cluster and ask: "What does this pattern mean for the architecture?"
If an ADR should change, write a new entry in `decisions.md`. Decisions are
superseded, not deleted.

`review-brain` (roadmap skill) will formalize this ritual once the pattern
is proven.

