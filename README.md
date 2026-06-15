# Claude Team Brain

A shared Claude context layer for teams and individuals. One Git repo gives every
session, every device, and every teammate the same memory, the same perspectives, and
the same skills, without anyone touching Git directly.

Solo across your own machines is a first-class case here, equal to a team. The whole
thing stands up in a few minutes: fork it, then tell Claude to set it up. Claude asks
you a couple of plain questions, writes its own config, and wires everything. You never
edit a file.

---

## Why I built this

I lead a design team, and everyone on it uses Claude. The problem showed up fast: each
person's Claude knew different things. Product context, the decisions we'd made, the way
we think about problems, all of it lived in one head or on one machine. A new designer
started from zero. When I moved from my laptop to my desktop, my own Claude forgot half
of what we'd built together that week.

That is the real gap. Claude is brilliant in a single session and amnesiac across
sessions, devices, and people. The knowledge that makes Claude useful for *your* work,
your product facts, your conventions, your hard-won decisions, has nowhere shared to
live. So it gets re-explained, or it gets lost.

The brain fixes that with one idea: **put the context in a Git repo and let Git move it
around.** Your clone pulls the latest at the start of every session, so your context is
always current. When you learn something worth keeping, it gets pushed back, and everyone
(or every one of your devices) has it next time. Nobody runs Git commands. Claude does
the syncing; you just work.

### The one insight that makes it work

Git was built for code, and most Git best-practice is exactly wrong for context. Code
wants clean history, curated commits, and review gates. Context wants the opposite:

| Code norm | What context actually wants | Why |
|---|---|---|
| Rebase for clean history | Merge / union | History tidiness is irrelevant. Never block, never lose a note. |
| Atomic curated commits | Auto, frequent, coarse | Commit hygiene is noise. Freshness beats tidiness. |
| Pull-request review gate | Optional (governed mode only) | Review throttles context flow. Trust by default. |
| Resolve every conflict carefully | Additive auto-merge | Context conflicts are almost always two people appending. |

Once you stop treating the brain like a codebase and start treating it like a shared
notebook that syncs itself, the conflicts and the friction mostly disappear. This repo is
GitHub used as a **context bus, not a code pipeline.**

---

## What the brain gives you

Once it is set up, your Claude gains:

- **Shared facts** about your product, your team, your conventions. Stored as atomic
  one-fact files so two people adding notes never collide.
- **Perspectives**: reasoning lenses for any role. Ask "review this from the
  accessibility perspective" (or any role you define) and Claude applies that lens. A
  perspective changes what Claude looks for, never how Claude talks to you.
- **Shared skills**: `setup-brain`, `explain-brain`, `push-to-brain`, `share-with-brain`,
  `sync-with-brain`, `disconnect-brain`, plus the session rituals `handoff`, `log`,
  `reflect`, and the `/wrap` command. Distributed as one plugin through the Claude Code
  marketplace, auto-updating on session start.
- **A self-improving record**: friction signals and architecture decisions logged over
  time, so the brain gets better the more you use it.

## What the brain does NOT do

- It does **not** change how Claude talks to you. Your interaction preferences, your
  voice, your formatting, your pacing, stay in your personal `~/.claude/memory/` and are
  never synced or touched.
- It does **not** hold personal or career content. That stays local to you.
- It does **not** replace foundational knowledge in your field. Learn that from real
  sources; the brain carries *your team's* context, not the textbook.

This boundary (personal stays local, shared goes to the brain) is the single most
important rule in the system, and a pre-commit hook enforces it mechanically so nobody
leaks personal content into the shared repo by accident.

---

## How to adapt it

This repo is a **template**, and making it yours takes no file editing. You fork it, then
tell Claude to set it up. `setup-brain` derives what it can from your fork (the repo, the
marketplace name) and asks you the two things it cannot guess (a name, and solo or team),
then **writes `brain.config.json` for you**. You never open it.

The config it writes ends up looking like this. You do not author it; it is shown so you
know what is under the hood:

```json
{
  "name": "Your Team Brain",
  "marketplaceName": "your-team-brain",
  "repo": "your-org/your-brain",
  "branch": "main",
  "defaultClonePath": "~/.claude/brain",
  "governance": "open",
  "syncMode": "reminded",
  "authValidation": null
}
```

- **`name`** is the human label used in onboarding copy (Claude asks you for it).
- **`marketplaceName`** / **`repo`** point the skills at your fork. Claude derives both from
  your fork's git remote and propagates `marketplaceName` into the marketplace manifest.
- **`governance`**: `open` (push straight to the branch, the default) or `governed` (every
  push opens a PR for human review). Defaults to `open`; just tell Claude "switch my brain
  to governed mode" any time. See [docs/governed-mode.md](./docs/governed-mode.md).
- **`syncMode`**: `auto`, `reminded`, or `manual`. Set from your solo/team answer; change it
  by telling Claude.
- **`authValidation`**: `null` lets any authenticated `gh` account in. Enterprise forks can
  restrict to corporate handles; ask Claude to set it.

Every skill reads its constants from this file, and Claude maintains it. There are no
hardcoded paths, repos, or org names anywhere else. To change anything later, you tell
Claude in plain words; you never hand-edit.

Beyond config, the brain has three clean extension points: add memory and perspectives,
add skills to the same plugin, or point the brain at other repos through a shared-memory
reference. The brain stays context-only; your code lives in its own repos.

---

## Install

The brain ends up in two places on your machine, fed from one repo: a **clone** holds
your context (loaded into every session via an `@import`), and the **plugin cache** holds
the skills (auto-updated through the marketplace). `setup-brain` wires up both. You never
manage either by hand.

There are two ways in, and `setup-brain` detects which one you are.

### Owner: standing up a new brain

1. **Fork this repo** to your own GitHub account (private by default).
2. **Open Claude in the cloned folder (or paste the repo link) and say "set up my brain."**
   Claude runs `setup-brain`, which checks your system is ready, derives your repo and
   marketplace name, asks you for a name and solo-or-team, writes your config, wires the
   context import, installs the skills, enables marketplace auto-update so future skills
   install themselves, propagates the manifest, and turns on the pre-commit guard. It asks
   you nothing technical. About two to three minutes.

You finish with a live brain and a prompt to bring in your other devices or your team. The
repo is private by default, so teammates need access before the link works: just tell Claude
their GitHub handles and it adds them as collaborators (or makes the repo internal for your
whole org). No manual GitHub admin.

### Joiner: connecting to a brain that already exists

A teammate, or you on a second device.

1. **Paste the repo link into Claude** and say you want to connect to the brain.
2. Claude clones it and runs `setup-brain`, which sees a populated brain, switches to the
   joiner flow, pulls the context, and installs the skills. No config edit needed.

If the repo is private and you do not have access yet, Claude tells you exactly that (not a
raw git error) and what to ask the owner for. Once they add your handle, run it again and it
picks up where it left off.

In both cases the headline instruction is the same: **paste the repo into Claude and let
it handle it.** Prefer to clone yourself first? Do that, then point Claude at the folder.
Both paths converge on `setup-brain`.

> Requirements: Claude Code, the GitHub CLI (`gh`) authenticated, and Git. If `gh` is
> missing, `setup-brain` detects your OS and tells you the exact install command, then
> waits. No prior Git knowledge needed at any step.

---

## How it works once installed

- **Pull**: at session start your clone pulls the latest context from GitHub (automatic
  if you accepted the SessionStart hook, otherwise via `sync-with-brain`).
- **Load**: the brain's runtime rules, memory indexes, and perspectives load into your
  session through the `@import` line in `~/.claude/CLAUDE.md`.
- **Push**: when you change brain content, run `push-to-brain` (or `share-with-brain` for
  a single item). In open mode it commits and pushes; in governed mode it opens a PR.
- **Sync and drift**: `sync-with-brain` pulls context, refreshes skills, and reports in
  one line if your clone and your installed skills have drifted apart, with a one-click
  fix.
- **Auto-update skills**: the plugin ships without a pinned version, so every commit counts
  as the newest version, and `setup-brain` turns on `autoUpdate` for the marketplace so
  those commits actually install at the next session start. That flag is what makes a
  pushed skill reach everyone, third-party marketplaces have auto-update off by default, so
  without it new skills would never arrive. Freshness by default, once the flag is set. One
  caveat: updates land at the NEXT session start, not mid-session, including for the person
  who wrote the skill. Open a fresh session to pick up a just-pushed skill (or run
  `/plugin marketplace update` then `/reload-plugins` to grab it in place).

---

## What you can say to Claude

| Say this | What happens |
|---|---|
| "Set up my brain" / "connect me to the brain" | Runs `setup-brain` (owner or joiner, detected) |
| "Explain how the brain works" | Runs `explain-brain`, a tour of what's loaded and how to operate |
| "Push my brain changes" | Runs `push-to-brain` (commit + push, or PR in governed mode) |
| "Share this with the brain" | Runs `share-with-brain`, promotes one local item up |
| "Sync the brain" | Runs `sync-with-brain`, pull + drift check |
| "Review this from the [role] perspective" | Applies that perspective as a reasoning lens |
| "Disconnect the brain" | Runs `disconnect-brain`, clean reversal, leaves your clone |

---

## Structure

```
your-team-brain/
├── README.md                  ← this file (human + Claude entry point)
├── CLAUDE.md                  ← runtime rules, loaded into every session via @import
├── ARCHITECTURE.md            ← how it works under the hood
├── brain.config.json          ← the one file you edit to make it yours
├── .gitattributes             ← merge=union on append-only files (no conflicts)
├── .gitignore                 ← personal/secret patterns (leak prevention)
├── .claude-plugin/
│   ├── marketplace.json        ← marketplace manifest (one plugin: the brain)
│   └── plugin.json             ← plugin manifest (skills auto-discover from skills/)
├── hooks/
│   └── pre-commit              ← secret + personal-content guard
├── shared-memory/              ← team-wide facts, one atomic file each
│   ├── INDEX.md
│   └── _TEMPLATE.md
├── project-memory/             ← opt-in per-project context (starts empty)
│   └── INDEX.md
├── perspectives/               ← reasoning lenses, any role
│   ├── INDEX.md
│   ├── _TEMPLATE.md
│   └── example-perspective.md
├── skills/                     ← the brain's skills (auto-discovered)
│   ├── setup-brain/  explain-brain/  push-to-brain/  share-with-brain/
│   ├── sync-with-brain/  disconnect-brain/
│   └── handoff/  log/  reflect/
├── commands/
│   └── wrap.md                  ← /wrap: reflect → log → optional handoff
├── meta/                        ← self-improvement layer
│   ├── INDEX.md
│   ├── signals.md               ← append-only friction journal
│   └── decisions.md             ← architecture decisions with rationale
└── docs/
    └── governed-mode.md         ← opt-in PR-governance setup
```

---

## Reading order for someone new

1. This file: what it is, why it exists, how to install.
2. [ARCHITECTURE.md](./ARCHITECTURE.md): how it works under the hood.
3. [meta/decisions.md](./meta/decisions.md): why it is built this way.
4. [CLAUDE.md](./CLAUDE.md): the runtime rules that load into your sessions.

## Contributing back

Edit brain content as you work, then run `push-to-brain` and Claude handles the Git. The
simplest contribution is a signal: when something feels missing or stale, ask Claude to
log it in `meta/signals.md`. Signals are append-only and compound into the improvement
backlog over time.

## License

MIT. Fork it, adapt it, make it yours.
