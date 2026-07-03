# Personal (solo tier)

Single-owner content that syncs across ONE person's own devices: voice files,
interaction preferences, a personal global instruction layer, personal memory
mirrors. Never relevant to a team.

**Team mode (default): this tier stays empty and untracked.** Personal content
lives in `~/.claude/memory/` and never enters the repo. The `.gitignore` entry
and the pre-commit guard both enforce that.

**Solo mode: this tier syncs.** A solo brain has no teammates to leak to, only
your own other devices, and the personal layer is exactly the context you want
travelling with you. To enable:

1. Set `"mode": "solo"` in `brain.config.json`.
2. Comment out the `personal/*` line in `.gitignore`.
3. Keep the repo PRIVATE. A solo brain with a synced personal tier must never
   go public as-is.

The pre-commit guard reads the mode flag: in solo mode it permits personal
content under `personal/` ONLY (every other tier still blocks it) and still
scans this tier for secrets.

## Keeping snapshots fresh (the drift trap)

Hand-copied snapshots of live files (your global CLAUDE.md, memory indexes) go
stale within days. Declare the live source next to each entry so `push-to-brain`
can refresh the copy before every push, and `sync-with-brain` can offer to apply
pulled updates back to the live location on your other devices:

```
- [global-CLAUDE.md](global-CLAUDE.md): global instruction layer
  source: ~/.claude/CLAUDE.md
```

## Entries

<!-- Solo mode only. Add one line per file, with a `source:` line when the file
     mirrors a live location outside the repo. -->
