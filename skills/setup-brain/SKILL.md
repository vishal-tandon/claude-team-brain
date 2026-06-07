---
name: setup-brain
description: >
  Post-clone bootstrap and onboarding for the Claude Team Brain. Use when someone wants to
  set up, install, connect to, or onboard onto the brain on a machine, or re-validate an
  existing setup. Triggers: "set up my brain", "set up the team brain", "connect me to the
  brain", "install the claude brain", "onboard me to the brain", "I just cloned the brain,
  now what", or any close paraphrase. Detects whether this is an owner standing up a new
  brain or a joiner connecting to one that already exists, and branches the flow and voice
  accordingly. Runs cross-platform pre-flight checks, then wires the @import, installs the
  skills via the marketplace, optionally adds a SessionStart pull hook, and activates the
  pre-commit guard. Reads all constants from brain.config.json. Never touches personal
  memory in ~/.claude/memory/.
---

# Set up brain

The first-contact experience for the Claude Team Brain. Takes a user from "the repo is on
my disk" to "the brain loads into every session, the skills are installed, and my context
syncs." This is a config playbook AND a designed onboarding moment: the cold open, the
pacing, and the closing handoff are load-bearing. They make setup feel like being handed
something alive, not like running a wizard.

This skill assumes the repo is already cloned (that is the cold-start truth: Claude knows
nothing about the brain until the repo is on disk). If the user pasted a repo link and the
clone has not happened yet, clone it first (to `defaultClonePath` from `brain.config.json`,
default `~/.claude/brain`), then run this flow.

## Core principles

- **Trust after the principle is named.** The user said "set up my brain." That is the
  consent. Do not re-ask permission for every routine write. Surface only real choices (the
  optional SessionStart hook) or genuine forks (an existing skill conflict).
- **Information does the work.** Each step states what happened and why it is safe inline,
  so trust comes from the message, not from a permission gate.
- **Read state, do not assume.** Detect owner vs joiner from the actual repo and config
  state. Re-running this skill must be safe and idempotent.
- **Personal memory is sacred.** Never read, write, or move anything in `~/.claude/memory/`.

## What this skill does NOT do

- Does NOT touch `~/.claude/memory/` (personal preferences are off-limits).
- Does NOT install Claude Code itself (the user must already have it).
- Does NOT install `gh` or Git (it detects the OS and tells the user the exact command,
  then waits).
- Does NOT push anything. Setup is local wiring only.

## Constants (read from brain.config.json)

Read these from `<brain>/brain.config.json` at the start. Never hardcode them.

```
name              → human label used in copy
marketplaceName   → marketplace slug
repo              → owner/repo (for the marketplace add)
branch            → working branch
defaultClonePath  → clone location (default ~/.claude/brain)
governance        → open | governed
syncMode          → auto | reminded | manual
authValidation    → null, or a regex the gh account handle must match
```

Resolve `<brain>` as the directory this repo was cloned to.

---

## Step 1: Cold open

Render the banner exactly. It names the product; do not rebrand it.

```
 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║█████╗
██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
██████╗ ██████╗  █████╗ ██╗███╗   ██╗
██╔══██╗██╔══██╗██╔══██╗██║████╗  ██║
██████╔╝██████╔╝███████║██║██╔██╗ ██║
██╔══██╗██╔══██╗██╔══██║██║██║╚██╗██║
██████╔╝██║  ██║██║  ██║██║██║ ╚████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
```

## Step 2: Detect owner vs joiner

Read the brain state to decide which moment this is:

- **Owner** (standing up a new brain): the brain looks fresh. `shared-memory/` holds only
  the template and example files, `perspectives/` holds only the template and example, and
  `brain.config.json` still has placeholder values (`your-org/your-brain`,
  `your-team-brain`) or was just edited by this user. No populated remote history beyond the
  template.
- **Joiner** (connecting to a brain that exists): the brain is populated. Real shared
  memory, real perspectives, a real `repo` in config pointing at a remote with history. This
  is a teammate, or the owner setting up a second device.

If it is genuinely ambiguous, ask one question: "Are you setting up a new brain of your
own, or connecting to one your team already has?"

Set the voice for the rest of the flow from this:

- **Owner voice:** you are building something. "Let's get your brain stood up."
- **Joiner voice:** you are being handed something that already works. "Let's get you
  connected. The brain already knows things; in a minute so will your Claude."

## Step 3: Show the journey (TodoWrite)

Render the checklist upfront so the user sees the whole path before any change. Use
TodoWrite:

1. Pre-flight: Git, `gh` installed, `gh` authenticated, repo cloned
2. Wire the `@import` so the brain loads every session
3. Install the skills via the marketplace
4. (Optional) Add a SessionStart hook to auto-pull on start
5. Activate the pre-commit guard
6. (Owner only) Propagate your config into the marketplace manifest
7. Hand off to the discovery session

## Step 4: Pre-flight (silent if all pass)

Check, and remediate with the lightest touch. Consolidate any gaps into one trip for the
user rather than bouncing them back repeatedly.

- **Git present:** `git --version`.
- **`gh` present:** `gh --version`. If missing, detect the OS and give the exact command,
  then wait:
  - macOS: `brew install gh`
  - Debian/Ubuntu: `sudo apt install gh`
  - Fedora: `sudo dnf install gh`
  - Windows: `winget install --id GitHub.cli`
  - Otherwise: point to https://cli.github.com
- **`gh` authenticated:** `gh auth status`. If `authValidation` is non-null, check the
  handle matches the regex and tell the user which account is expected if it does not. If
  `authValidation` is null, any authenticated account passes.
- **Repo cloned:** confirm `<brain>` exists and is this repo. If the user only pasted a
  link and nothing is cloned, clone it to `defaultClonePath` now.

If everything passes, say so in one line and move on. Do not narrate each green check.

## Step 5: Config writes (consent named once, inline why-safe)

Make these changes. Each carries a one-line "why this is safe" inline. None of them touch
personal memory.

1. **Add the `@import` line** to `~/.claude/CLAUDE.md`:
   `@<brain>/CLAUDE.md`
   Why safe: it only loads the brain's shared runtime rules into your sessions; it changes
   nothing about how Claude talks to you.

2. **Add the marketplace and install the plugin:**
   - `/plugin marketplace add <repo>`
   - `/plugin install brain@<marketplaceName>`
   Why safe: skills install into the plugin cache, isolated from your local skills. The
   plugin ships without a pinned version, so it stays fresh on every session start.

3. **(Optional, ask) SessionStart pull hook.** This is a real choice, so ask. If accepted,
   add a SessionStart hook to `~/.claude/settings.json` that runs `git -C <brain> pull` so
   context is always current. If `syncMode` is `auto`, recommend it. If `manual`, skip and
   mention `sync-with-brain` covers pulling on demand.
   Why safe: it only pulls; it never pushes or overwrites your local edits.

4. **Activate the pre-commit guard:** set `git -C <brain> config core.hooksPath hooks`.
   Why safe: it runs the repo's secret and personal-content scan before any commit, so
   nothing personal or sensitive can be pushed by accident. It is the same guard the skills
   use; raw `git push` can no longer bypass it.

## Step 6: Owner only: propagate config into the manifest

`marketplace.json` and `plugin.json` are static files Claude Code parses directly, so they
cannot read `brain.config.json` at runtime. To keep the promise that the owner edits one
file, do the propagation here:

- Read `marketplaceName` and `repo` from `brain.config.json`.
- Write `marketplaceName` into `.claude-plugin/marketplace.json` `name`.
- Confirm the diff with the user, then it is staged for their first `push-to-brain`.

Skip this entirely for joiners; their manifest is already correct.

## Step 7: Close, and hand off to discovery

**Owner close:**

> Your brain's alive. It loads into every session now, and the skills are installed.
>
> Two things from here: bring in your other devices (same flow, they will connect as
> joiners), or invite your team (send them the repo link). When you make your first real
> edits, run `push-to-brain` to share them.
>
> To see everything that is wired up, open a fresh session and say: **"Explain how the
> brain works."**

**Joiner close:**

> You're in. The brain's context is loading into your sessions, and the skills are
> installed. Anything the team has shared, your Claude now knows.
>
> Open a fresh session and say **"Explain how the brain works"** for the quick tour of
> what's loaded and how to contribute back.

Do not dump the discovery content into this message. Session 1 is setup; the next session
is the first real use. The handoff line is the bridge.
