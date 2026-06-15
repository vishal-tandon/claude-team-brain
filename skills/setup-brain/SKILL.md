---
name: setup-brain
description: >
  Post-clone bootstrap, onboarding, AND self-heal for the Claude Team Brain. Use when
  someone wants to set up, install, connect to, onboard onto, repair, or re-validate the
  brain on a machine. Triggers: "set up my brain", "set up the team brain", "connect me to
  the brain", "install the claude brain", "onboard me to the brain", "I just cloned the
  brain, now what", "fix my brain setup", "my brain isn't working", or any close paraphrase.
  Zero-config: the user never edits a file. This skill DERIVES identity from the git remote
  and gh, INTERVIEWS for the few real choices, WRITES brain.config.json itself, then wires
  everything. Detects owner vs joiner from repo permissions, branches voice accordingly, and
  on re-run inventories the wiring and repairs only what is broken. Wires the context import,
  installs the skills via the marketplace, enables auto-update, persists the clone path,
  optionally adds a SessionStart hook, and activates the pre-commit guard. Never touches
  personal memory in ~/.claude/memory/.
---

# Set up brain

The first-contact experience for the Claude Team Brain, and its self-heal path. Takes a
user from "the repo is on my disk" to "the brain loads into every session, the skills are
installed, and my context syncs," without ever asking them to edit a file or learn how the
brain works. This is a config playbook AND a designed onboarding moment: the cold open, the
pacing, and the closing handoff are load-bearing. They make setup feel like being handed
something alive, not like running a wizard.

This skill assumes the repo is already cloned (that is the cold-start truth: Claude knows
nothing about the brain until the repo is on disk). If the user pasted a repo link and the
clone has not happened yet, clone it first (to `~/.claude/brain` by default), then run this
flow.

## Core principles

- **Zero-config. Derive, do not ask; write, do not make them edit.** The user should never
  open `brain.config.json` or any JSON. Derive everything derivable from the git remote and
  `gh`. Ask only the two or three things that are genuine choices, in plain language, with a
  default already picked. Then WRITE the config yourself.
- **Trust after the principle is named.** The user said "set up my brain." That is the
  consent. Do not re-ask permission for every routine write. Surface only real choices or
  genuine forks (an existing skill conflict, an access failure).
- **Information does the work.** Each step states what happened and why it is safe inline,
  so trust comes from the message, not from a permission gate.
- **Self-heal on re-run.** Re-running must be safe and idempotent. On a brain that is
  already localised, skip the interview, inventory the wiring, and repair only the gaps.
  "Fix my brain" and "set up my brain" land in the same skill.
- **Personal memory is sacred.** Never read, write, or move anything in `~/.claude/memory/`.

## What this skill does NOT do

- Does NOT make the user edit `brain.config.json` or any file. It writes config for them.
- Does NOT touch `~/.claude/memory/` (personal preferences are off-limits).
- Does NOT install Claude Code itself (the user must already have it).
- Does NOT install `gh` or Git (it detects the OS and tells the user the exact command,
  then waits).
- Does NOT push anything. Setup is local wiring only. (The one exception is the optional
  owner-side commit of a freshly written `brain.config.json` + manifest, and only with a
  yes.)

## Identity: derive it, do not read placeholders

`brain.config.json` in a fresh template clone holds PLACEHOLDERS (`your-org/your-brain`,
`your-team-brain`). Never trust those at runtime. Derive the real values from ground truth:

| Value | Derive from | Never from |
|---|---|---|
| `clonePath` | the directory this repo sits in (resolve the cwd / clone target) | a hardcoded path |
| `repo` (`owner/name`) | `git -C <clonePath> remote get-url origin`, parsed | `brain.config.json` placeholder |
| `marketplaceName` | the repo name, kebab-cased (e.g. `alex-co/team-brain` → `team-brain`) | the `your-team-brain` placeholder |
| owner gh handle | `gh api user --jq .login` | assumption |
| owner-vs-joiner | `gh repo view <repo> --json viewerPermission` (ADMIN/WRITE = owner-capable) | content emptiness alone |

If `git remote get-url origin` fails or returns nothing, stop with a plain message: "This
folder has no GitHub remote yet. If you forked the template, clone YOUR fork (not the
template) and run this again." Never proceed to a marketplace add against a placeholder.

The clone path becomes a persisted fact the moment the context-import line is written (see
the wiring step): that line literally contains `<clonePath>/CLAUDE.md`, and every other
skill reads the clone path back out of it. There is no separate pointer file to keep in
sync.

---

## Step 1: Cold open

Render the banner exactly. It names the product; do not rebrand it.

```
 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║█████╗
██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═════╝
██████╗ ██████╗  █████╗ ██╗███╗   ██╗
██╔══██╗██╔══██╗██╔══██╗██║████╗  ██║
██████╔╝██████╔╝███████║██║██╔██╗ ██║
██╔══██╗██╔══██╗██╔══██║██║██║╚██╗██║
██████╔╝██║  ██║██║  ██║██║██║ ╚████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
```

## Step 2: Derive identity, detect the moment

Run the derivations in the table above. Then classify which of three moments this is:

- **Owner, first standup:** `viewerPermission` is ADMIN, and the brain content is still
  fresh (only the `_TEMPLATE.md` and example files in `shared-memory/` and `perspectives/`,
  config still placeholder). They are building something.
- **Owner, returning / second device:** ADMIN, but config is already localised (real
  `repo`/`marketplaceName`, not placeholders) or content is populated. Skip the interview;
  go straight to self-heal.
- **Joiner:** `viewerPermission` is WRITE or READ, or the gh handle differs from the repo
  owner. They are being handed something that already works. Joiners never run the localise
  interview; the config in the repo is already correct, just derive `clonePath` and wire.

If permission cannot be read (e.g. `gh` not yet authed), fall back to the content + config
heuristic, and if still genuinely ambiguous ask one question: "Are you setting up a brain
of your own, or connecting to one your team already has?"

Set the voice:

- **Owner voice:** "Let's get your brain stood up."
- **Joiner voice:** "Let's get you connected. The brain already knows things; in a minute
  so will your Claude."

## Step 3: Show the journey (TodoWrite)

Render the path upfront so the user sees it before any change. Use TodoWrite. Owner first
standup:

1. Pre-flight: Git, `gh` installed, `gh` authenticated, access to the repo
2. Localise: name it, solo or team (I write the config, you don't touch a file)
3. Wire the context import so the brain loads every session
4. Install the skills via the marketplace
5. Enable auto-update so new skills install themselves on later sessions
6. (Optional) Add a SessionStart hook to keep context current
7. Activate the pre-commit guard
8. (Owner) Offer to bring teammates in
9. Hand off to the discovery session

For a joiner or a self-heal re-run, drop step 2 (localise) and step 8, and reframe the rest
as "check and repair."

## Step 4: Pre-flight (silent if all pass)

Check, remediate with the lightest touch, consolidate gaps into one trip.

- **Git present:** `git --version`.
- **`gh` present:** `gh --version`. If missing, detect the OS and give the exact command,
  then wait:
  - macOS: `brew install gh`
  - Debian/Ubuntu: `sudo apt install gh`
  - Fedora: `sudo dnf install gh`
  - Windows: `winget install --id GitHub.cli`
  - Otherwise: point to https://cli.github.com
- **`gh` authenticated:** `gh auth status`. If `authValidation` (once config exists) is
  non-null, check the handle matches the regex and name the expected account if it does not.
- **Repo access:** confirm the clone exists and `gh repo view <repo>` succeeds. **If it
  returns a 404/403 for a joiner,** this is the private-repo access gap, surface it plainly,
  do not dump a raw git error:

  > I can see the link but not the repo itself. It's private and your GitHub account
  > (`<handle>`) isn't a collaborator yet. Ask the brain's owner to add you (`<handle>`) on
  > GitHub, or to make the repo internal/public, then run this again. Nothing else is needed
  > from you.

  Then stop cleanly. Re-running after access is granted picks up exactly here.

If everything passes, say so in one line. Do not narrate each green check.

## Step 5: Localise (owner first standup only): I write the config, you don't

This is where "localise to your needs" happens, as a short conversation, not a file edit.
Ask only what is a real choice. Each has a default already chosen, so a one-word answer (or
silence) is enough.

1. **Name.** "What do you want to call your brain? (default: `<TitleCased repo name>`)"
2. **Scale.** "Just you across your devices, or a team?" Default solo. This sets the sync
   default (solo → `auto`, team → `reminded`) and nothing the user has to understand.

Governance defaults to `open` (direct push, no ceremony). Do not surface it as a question
during first standup; it is changeable later and asking about PR gates violates "don't make
them learn the brain." Mention in the close that governed mode exists for teams who want
review.

Then **write `brain.config.json`** from derived + answered values:

```json
{
  "name": "<answered or derived name>",
  "marketplaceName": "<derived from repo name>",
  "repo": "<derived owner/name>",
  "branch": "main",
  "defaultClonePath": "~/.claude/brain",
  "governance": "open",
  "syncMode": "<auto if solo, reminded if team>",
  "authValidation": null
}
```

Report it in one line: "Wrote your config: `<name>`, repo `<repo>`, <solo/team>, auto-sync.
You can change any of this later by just telling me." Never show raw JSON unless asked.

## Step 6: Propagate config into the manifest (BEFORE the marketplace add)

`marketplace.json` and `plugin.json` are static files Claude Code parses directly; they
cannot read `brain.config.json` at runtime. The manifest `name` must match the
`marketplaceName` the install will target, and this MUST happen before step 7 installs, or
the install resolves a marketplace slug that does not exist.

- Write `marketplaceName` into `.claude-plugin/marketplace.json` `name`.
- For an owner first standup, this plus the freshly written `brain.config.json` are real
  repo changes. Offer once: "Commit your config and manifest so your other devices and
  teammates inherit them? (yes / later)". On yes, this is the single sanctioned setup-time
  push, via `push-to-brain`. On later, leave them staged.

Skip entirely for joiners; their manifest already matches the repo.

## Step 7: Wire everything (consent named once, inline why-safe)

Make these changes in order. Each carries a one-line "why this is safe" inline. None touch
personal memory. On a self-heal re-run, check each first and apply only the missing or
broken ones.

1. **Add the context-import line** to `~/.claude/CLAUDE.md`:
   `@<clonePath>/CLAUDE.md`
   This is a BARE `@path` (Claude Code's import syntax), not `@import path`. It is also the
   persisted record of the clone path that every other brain skill reads back. If a brain
   import line already exists pointing at a different path, replace it, do not duplicate.
   Why safe: it only loads the brain's shared runtime rules into your sessions; it changes
   nothing about how Claude talks to you.

2. **Add the marketplace and install the plugin:**
   - `/plugin marketplace add <repo>`
   - `/plugin install brain@<marketplaceName>`
   Why safe: skills install into the plugin cache, isolated from your local skills.

3. **Enable auto-update for the brain marketplace (load-bearing, not optional).**
   This is what makes new skills actually reach the user. Third-party marketplaces have
   auto-update OFF by default, so without this step a skill pushed later never installs on
   its own. Declare the marketplace in `extraKnownMarketplaces` in `~/.claude/settings.json`
   with `autoUpdate` on. The entry needs a `source` block; `autoUpdate` sits beside it:

   ```jsonc
   "extraKnownMarketplaces": {
     "<marketplaceName>": {
       "source": { "source": "github", "repo": "<repo>" },
       "autoUpdate": true
     }
   }
   ```

   (Verified to work at the user level, no admin/managed-settings.json needed. The manual
   equivalent is `/plugin` → Marketplaces → select the brain → Enable auto-update.)

   With this set, Claude Code pulls the marketplace and updates the plugin at session start.
   The plugin ships with no pinned `version`, so every commit counts as newer; `autoUpdate`
   is what applies it. Version omission alone does nothing.
   Why safe: it only pulls and updates the brain plugin; it touches no other marketplace and
   never pushes.

4. **(Optional, ask) SessionStart context + drift hook.** A real choice, so ask. If
   accepted, add a SessionStart hook to `~/.claude/settings.json` that runs
   `git -C <clonePath> pull` (keeps the `@import` context clone current) and a quiet
   `sync-with-brain` drift check (surfaces one line only if skills or context are stale, so
   an autoUpdate failure is never silent). If `syncMode` is `auto`, recommend it. If
   `manual`, skip and mention `sync-with-brain` covers it on demand.
   Why safe: it only pulls and reports; it never pushes or overwrites your local edits.

5. **Activate the pre-commit guard:** `git -C <clonePath> config core.hooksPath hooks`.
   Why safe: it runs the repo's secret and personal-content scan before any commit, so
   nothing personal or sensitive can be pushed by accident. Raw `git push` can no longer
   bypass it.

## Step 8: Owner only, bring teammates in (close the private-repo gap)

A private brain is invisible to teammates until they have repo access. Do not leave the
owner to discover this when a joiner hits a 404. Offer it here:

> Want to bring teammates in now? Tell me their GitHub handles and I'll add them as
> collaborators so the repo link actually works for them. Or I can make the repo internal
> if your whole org should have it.

- On handles: `gh api -X PUT repos/<repo>/collaborators/<handle>` per teammate. Report who
  was added.
- On "make it internal/public": `gh repo edit <repo> --visibility internal` (confirm once,
  this widens who can see the brain).
- On "later": one line, "When you're ready, just tell me their handles." Note that sending
  the bare repo link alone will not work until access is granted.

Skip for joiners and self-heal.

## Step 9: Close, and hand off to discovery

**Owner close:**

> Your brain's alive. It loads into every session now, and the skills are installed. You
> never have to think about it again, just talk to Claude like always.
>
> From here: bring in your other devices (same flow, they connect as joiners), or add
> teammates (tell me their handles any time). When you teach Claude something the team or
> your other devices should have, just say "share this with the brain."
>
> To see what's wired up, open a fresh session and say: **"Explain how the brain works."**
> (Teams who want a review gate on shared changes can ask me to switch to governed mode.)

**Joiner close:**

> You're in. The brain's context is loading into your sessions and the skills are installed.
> Anything the team has shared, your Claude now knows, and new skills the team pushes will
> install themselves the next time you open Claude.
>
> Open a fresh session and say **"Explain how the brain works"** for the quick tour.

**Self-heal close:** report what was repaired in one line ("Fixed: context import was
pointing at an old path; re-enabled auto-update. Everything else was already good.") and
stop. No banner re-render, no discovery handoff.

Do not dump discovery content into this message. Session 1 is setup; the next session is the
first real use. The handoff line is the bridge.

## Self-heal inventory (the re-run / "fix my brain" path)

When the brain is already localised (real config) or the user asks to fix/repair, run this
instead of the full standup. Check each, repair only the broken:

| Component | Healthy when | Repair |
|---|---|---|
| Context import | a line `@<clonePath>/CLAUDE.md` exists in `~/.claude/CLAUDE.md` | add it / fix a stale path |
| Clone path | the import line resolves to a real git repo | re-point to the actual clone |
| Marketplace + plugin | registered and installed | re-add / re-install |
| autoUpdate | `extraKnownMarketplaces.<marketplaceName>.autoUpdate` is `true` | write the block |
| Manifest name | `marketplace.json` `name` == `marketplaceName` | propagate |
| Pre-commit guard | `core.hooksPath` == `hooks` | set it |

This is the same inventory `sync-with-brain` reports as drift; setup-brain is the one that
repairs it.
