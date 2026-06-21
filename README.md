# Claude Team Brain

A shared Claude context layer for teams and individuals. One Git repo gives every
session, every device, and every teammate the same memory, perspectives, and skills,
without anyone touching Git directly. Solo across your own machines counts fully, equal
to a team.

---

## Why I built it

Every time you use AI, you train it, and that value flows one way: to the company that
owns the model. Meanwhile everyone you work with is teaching their own AI, in their own
window, all day, and none of it reaches you.

The brain runs that same move, turned around. Put your shared context in a Git repo and
let Git move it around. Every session pulls the latest, so you start a step ahead of where
you left off, and anything worth keeping gets pushed back so everyone (or every one of your
devices) has it next time. Nobody runs Git commands. Claude does the syncing while you just
work. You stop feeding someone else's model and start feeding your own.

One rule holds it together: **personal stays personal.** How Claude talks to you, your
voice, your career context, none of it ever leaves your machine. Only shared knowledge
(team facts, skills, reasoning perspectives) goes into the brain, and a pre-commit hook
enforces that line automatically.

> Full story of how it works under the hood: [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Install

Paste this repo link into Claude Code and say **"set up this brain."** That is the whole
install.

Claude forks the repo, asks you two plain questions (a name, and solo or team), writes its
own config, installs the skills, and wires everything. You never touch Git or edit a file.
About two to three minutes.

Joining a teammate's brain? Paste their link instead and say **"connect me to this
brain."** Claude clones it, pulls the context, and installs the skills.

<details>
<summary>Requirements, and the manual route if you would rather drive</summary>

**Requirements:** Claude Code, the GitHub CLI (`gh`) signed in, and Git. If `gh` is missing
or not signed in, setup detects your OS, tells you the exact command, and waits. No prior
Git knowledge needed.

**Manual route.** A downloaded ZIP will not work; you need a real fork/clone so Claude can
find the GitHub remote.

1. **Fork** this repo to your GitHub account (private is fine). Joining a teammate's brain
   instead? Skip the fork and clone theirs.
2. **Clone** it: `git clone <your-fork-url>`, or use GitHub Desktop, or your IDE's "Clone
   Repository".
3. **Open Claude Code in that folder.** Terminal: `cd` in and run `claude`. VSCode / Cursor
   / JetBrains: install the Claude Code extension, open the folder, open the Claude panel.
4. **Say** "set up my brain" (or "connect me to the brain" if joining). The exact wording
   does not matter.

The repo ships a small permission allowlist so setup runs in one pass. Say yes to the
one-time "trust this folder's settings" prompt, and press **Shift+Tab** to auto-accept file
edits.

</details>

---

## How to use it

After setup you just work. At session start Claude pulls the latest context; when you make
something worth keeping, it nudges you to share it back. You talk to Claude in plain words:

| Say this | What happens |
|---|---|
| "Push my brain changes" | Commits and syncs your changes (or opens a PR in governed mode) |
| "Share this with the brain" | Promotes one local item up to the shared brain |
| "Sync the brain" | Pulls the latest context and checks for drift |
| "Review this from the [role] perspective" | Applies a saved reasoning lens to your work |
| "Explain how the brain works" | A tour of what is loaded and how to operate it |
| "Disconnect the brain" | Clean reversal; leaves your clone in place |

**A note on perspectives.** A perspective is a saved reasoning lens, a role's way of
thinking that Claude can pick up on demand. It changes what Claude looks for, never how it
talks to you. This brain ships with one by default: my own product-design perspective
(Vishal Tandon, @vishx.design), the lens I have built over years of designing products,
generalized so anyone can use it. You get me as a character in your brain: ask Claude to
"review this from Vishal's product-design perspective", or replace me with your team's own.

That is the whole surface. Everything else (memory tiers, perspectives, config, governance)
is documented for when you need it:

- [ARCHITECTURE.md](./ARCHITECTURE.md): how it works under the hood.
- [CLAUDE.md](./CLAUDE.md): the runtime rules that load into every session.
- [perspectives/example-perspective.md](./perspectives/example-perspective.md): a worked
  example perspective to copy or replace.
- [docs/governed-mode.md](./docs/governed-mode.md): opt-in PR-governance setup.

---

## License

MIT. Fork it, adapt it, make it yours.
