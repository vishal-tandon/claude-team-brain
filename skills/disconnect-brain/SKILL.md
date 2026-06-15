---
name: disconnect-brain
description: >
  Use this skill when the user wants to cleanly uninstall or disconnect the brain
  from their Claude setup. Removes the four integration points: the @import line
  in Claude config, the marketplace registration, the SessionStart pull hook, and
  the hooksPath git config. Deliberately LEAVES the brain clone on disk, it is
  the user's data and may contain their own contributions. Confirms before each
  removal. Cross-platform. Reads all constants from brain.config.json before
  acting. Trigger phrases: "disconnect brain", "uninstall brain", "remove brain",
  "stop using the brain", "remove brain integration", or any close paraphrase.
  Also fires on "/disconnect-brain".
---

# Disconnect brain

Clean uninstall of the brain integration. Removes the four wiring points that
connect the brain to Claude. Deliberately non-destructive on the clone, the
user's data stays on disk.

**The intent: undo what setup-brain did, without destroying what the user has
contributed.**

## What this skill removes

| Component | What it is | Removed? |
|---|---|---|
| `@import` line | The line in `~/.claude/CLAUDE.md` (or equivalent) that loads the brain context into every session | Yes, with confirmation |
| Marketplace entry | The `/plugin marketplace add <repo>` registration plus the `extraKnownMarketplaces.<marketplaceName>` block (with `autoUpdate`) in `~/.claude/settings.json` that makes skills available and auto-updating | Yes, with confirmation |
| SessionStart pull hook | The hook in Claude settings that runs `git pull` on the clone at session start | Yes, with confirmation |
| `core.hooksPath` git config | The git config that activates the pre-commit content scan | Yes, with confirmation |
| **Brain clone** | The full git repository at the configured clone path | **Never removed** |

The clone is the user's data. It may contain original contributions, project
memory, and perspectives the user wrote. Removing it without explicit request
would be destructive and irreversible. Leave it on disk.

## What this skill does NOT do

- Does NOT delete the brain clone
- Does NOT delete any files inside the clone
- Does NOT push or commit anything
- Does NOT modify the brain repo on GitHub
- Does NOT remove other users' installations (this only touches the local machine)
- Does NOT operate without confirmation at each removal step

## Before doing anything: read brain.config.json

Locate and read `brain.config.json` from the brain clone root. Extract:

- `clonePath`: resolve it by reading the context-import line in
  `~/.claude/CLAUDE.md` (the bare `@<clonePath>/CLAUDE.md` line setup-brain wrote)
  and taking the directory it points at. That import line is the persisted record
  of where the clone lives. Fall back to `defaultClonePath` (`~/.claude/brain`)
  only if no import line is found. (Note: you are about to remove that import line,
  so resolve the clone path BEFORE removing it.)
- `marketplaceName`: the marketplace slug used at install (e.g. `your-team-brain`).
- `branch`: the working branch (needed to construct the hook reference if checking).

If `brain.config.json` cannot be found at the expected clone path, try the
default clone path. If still not found, ask the user to provide the clone path
manually. It may be in a non-default location.

## Workflow

### 1. Pre-flight: inventory what is actually installed

Before asking the user to confirm any removal, check what is currently active.
Inventory all four components:

**A. @import line**
- Locate the Claude config file that would hold it. Common locations:
  - `~/.claude/CLAUDE.md`
  - `~/.claude/settings/CLAUDE.md`
  - The project-level CLAUDE.md if the brain was wired per-project
- Search for a line matching the regex `^@.*<clonePath>.*CLAUDE\.md`
  (case-insensitive, path may vary). The directive is a BARE `@path`, not
  `@import path`. Do NOT require a literal `import` token, or the line setup
  actually wrote (`@<clonePath>/CLAUDE.md`) will never be found and the uninstall
  will silently leave the brain loading. Tolerate an optional legacy `import `
  token after the `@` so old installs are still matched.
- Status: Present / Not found.

**B. Marketplace entry**
- Check whether `<marketplaceName>` appears in the registered marketplace list.
- On Claude Code: inspect `~/.claude/settings.json` (including the
  `extraKnownMarketplaces.<marketplaceName>` block that carries `autoUpdate`) or
  equivalent for marketplace registrations, or run the equivalent CLI list command
  if available.
- Status: Registered / Not found.

**C. SessionStart pull hook**
- Check Claude settings (e.g. `~/.claude/settings.json`) for a `hooks` entry with
  `event: "sessionStart"` that references `git pull` or the brain clone path.
- Status: Present / Not found.

**D. core.hooksPath git config**
- Run `git -C <clonePath> config --local core.hooksPath` and check whether it
  returns the brain's `hooks/` directory.
- Status: Active / Not set.

Present the inventory before asking anything:

```
Brain integration on this machine:

  @import line:              present   (~/.claude/CLAUDE.md, line 3)
  Marketplace entry:         registered  (your-team-brain)
  SessionStart pull hook:    present
  core.hooksPath git config: active

Brain clone:                 present at ~/.claude/brain
                             (will NOT be removed)

Proceed to remove the integration? I will confirm each step.
```

If nothing is installed (all four show "not found"), report:
`Brain is not integrated on this machine. Nothing to remove.` and exit cleanly.

### 2. Remove the @import line (with confirmation)

If the @import line is present:

```
Remove the @import line from ~/.claude/CLAUDE.md?
This stops the brain context from loading into your sessions.
The clone at <clonePath> will remain untouched.

Confirm? (yes / skip)
```

On yes: edit the Claude config file to remove the line. If the line is the only
content on its line, remove the whole line. If it is embedded in a block, remove
just that line and leave surrounding content intact.

On skip: leave it in place and continue to the next component.

After removal: verify the line is gone. Report: `@import line removed.`

### 3. Remove the marketplace entry (with confirmation)

If the marketplace entry is registered:

```
Remove the marketplace entry for <marketplaceName>?
This removes the installed brain skills from your Claude setup.

Confirm? (yes / skip)
```

On yes: run the appropriate deregistration command. On Claude Code this is
typically modifying `~/.claude/settings.json` to remove the marketplace entry,
or running `/plugin marketplace remove <marketplaceName>` if the CLI supports it.
Also remove the `extraKnownMarketplaces.<marketplaceName>` block from
`~/.claude/settings.json` if setup-brain wrote one: that block carries the
`autoUpdate` flag, and leaving it behind would keep Claude Code trying to refresh
a marketplace the user just disconnected. Parse the JSON, delete the keyed entry,
write it back (never string-replace JSON).

After removal: verify both the marketplace entry and the `extraKnownMarketplaces`
block are gone. Report: `Marketplace entry removed.`

Note: removing the marketplace entry may not immediately remove the plugin cache
files. That is expected. The cache is cleaned by the platform at its own
schedule. The skills will no longer be available in new sessions.

### 4. Remove the SessionStart pull hook (with confirmation)

If the hook is present:

```
Remove the SessionStart pull hook?
This stops the brain from auto-pulling at session start.

Confirm? (yes / skip)
```

On yes: edit the hooks section of `~/.claude/settings.json` (or equivalent) to
remove the entry. If the hooks array becomes empty, leave it as an empty array
(or remove the key entirely if that is the correct schema). Do not corrupt the
settings file.

After removal: report: `SessionStart pull hook removed.`

### 5. Remove the core.hooksPath git config (with confirmation)

If `core.hooksPath` is active in the brain clone's local git config:

```
Remove the core.hooksPath git config from the brain clone?
This deactivates the pre-commit content scan.
(The clone and its hooks/ directory remain on disk.)

Confirm? (yes / skip)
```

On yes: `git -C <clonePath> config --local --unset core.hooksPath`

After removal: report: `core.hooksPath config removed.`

### 6. Final report

Summarise what was removed and what was left:

```
Brain disconnected.

  Removed:
    @import line         (brain context no longer loads)
    Marketplace entry    (brain skills no longer available)
    SessionStart hook    (no longer auto-pulls)
    core.hooksPath       (pre-commit scan deactivated)

  Left on disk:
    Brain clone:  <clonePath>

The clone is your data. To remove it, run: rm -rf <clonePath>
(confirm that path carefully before running)

To reconnect later, run setup-brain.
```

Adjust the "Removed" list based on what was actually removed (vs skipped).

## Edge cases

- **brain.config.json not found.** Ask the user for the clone path. Proceed with
  what can be found. The @import and marketplace checks are independent of the
  clone path.
- **All four components are "not found".** Report `Brain is not integrated on this
  machine. Nothing to remove.` and exit. Do not modify anything.
- **Partial install.** Some components present, others not. Inventory and confirm
  each present component individually. Skip "not found" ones silently.
- **Settings file parse error.** If the Claude settings file cannot be parsed (e.g.
  malformed JSON), surface the error and stop: "Cannot modify settings safely.
  File may be malformed. Check `<path>` manually." Do not write to a file that
  cannot be read cleanly.
- **Multiple @import lines** (e.g. from a botched previous disconnect attempt).
  Remove all matching lines. Report how many were removed.
- **clone path same as cwd.** If the user is currently in the brain clone directory,
  note that the git config removal (`core.hooksPath`) still works, but warn that
  the clone itself is the current directory. They may want to `cd` out before
  considering a manual `rm -rf`.
- **User says "remove everything including the clone".** This is an explicit request
  to go beyond the default. Confirm once more explicitly:
  "This will permanently delete <clonePath> and all its contents. This cannot be
  undone. Type 'delete the clone' to confirm."
  Only proceed on that exact phrase. Then run `rm -rf <clonePath>` and report.

## Common pitfalls

- **Deleting the clone without being asked.** Never. The clone is the user's data.
  Default is always to leave it on disk.
- **Skipping the inventory step.** Confirming removal of something that is not
  there is confusing and erodes trust. Always inventory first, then confirm only
  what is actually present.
- **Corrupting the settings file.** Read the full settings file, parse it, make
  the targeted removal, write it back. Never use sed or string replacement on JSON
  files. It risks silently mangling syntax.
- **Editing before reading.** Always Read `~/.claude/settings.json` (and `CLAUDE.md`)
  before writing to them. The editing tools require a prior read of an existing file;
  skipping it produces an avoidable "error writing file" that makes disconnect look
  broken before it self-recovers.
- **Removing more than the four targeted components.** This skill has a narrow
  scope: these four integration points. Do not clean up or reorganize anything
  else in the user's Claude config.
- **Platform assumptions.** Do not assume macOS-specific paths, Homebrew, or a
  specific OS. Derive all paths from `brain.config.json` and platform-neutral
  defaults. The `~/.claude/` root works on macOS, Linux, and Windows (WSL).

## Composing with other skills

- **`setup-brain`**: the inverse of this skill. If the user wants to reconnect
  after disconnecting, `setup-brain` is the path.
- **`sync-with-brain`**: checks all four integration points. If the user runs
  `sync-with-brain` after `disconnect-brain`, it will report everything as missing
  and recommend `setup-brain`. That is the correct behavior.
- **`push-to-brain`**: does not need to be invoked here. No content changes
  during disconnect.
