---
name: setup-brain
description: >
  Post-clone bootstrap, onboarding, AND self-heal for the Claude Team Brain. Use when
  someone wants to set up, install, connect to, onboard onto, repair, or re-validate the
  brain on a machine. Triggers: "set up my brain", "set up the team brain", "connect me to
  the brain", "install the claude brain", "onboard me to the brain", "I just cloned the
  brain, now what", "fix my brain setup", "my brain isn't working", or any close paraphrase.
  ALSO handles a pasted GitHub repo link with no clone yet (the lazy Path 1): "set up this
  brain <link>", "clone and set up this brain <link>", "can you set up this brain project
  for my claude <link>", "connect me to this brain <link>". In that case it clones the repo
  (or forks the template first for a brand-new owner), then runs the normal flow.
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

There are two entry paths, both land in the same flow:

- **Path 1 (lazy / pasted link):** the user drops a GitHub repo link into their existing
  Claude and says "set this brain up." The repo is NOT on disk yet. Step 0 gets it there
  (clone, or fork-then-clone for a new owner), then the flow continues.
- **Path 2 (manual):** the user already forked, cloned, and opened Claude in the folder.
  The repo IS on disk. Step 0 is a no-op; jump to Step 1.

Either way, once the repo is on disk the rest is identical.

## Core principles

- **Zero-config. Derive, do not ask; write, do not make them edit.** The user should never
  open `brain.config.json` or any JSON. Derive everything derivable from the git remote and
  `gh`. Ask only the two or three things that are genuine choices, in plain language, with a
  default already picked. Then WRITE the config yourself.
- **One consent, then run end to end.** The user said "set up my brain." That is consent
  for the whole install. After the short interview, state in plain language the handful of
  things you are about to do, then do them all in one pass. Do NOT stop for per-step
  approval. Surface only genuine forks: an access failure, a real conflict, a decision a
  human must make. Stop-start permission prompts are the single thing that makes setup feel
  technical and slow, avoid them.
- **Plain language, hide the machinery.** Narrate the outcomes the user cares about, never
  the mechanism. Say "Saving your settings", "Installing the skills", "Making sure you
  always get the latest automatically", "Done, your brain's live." Do NOT put file paths,
  JSON keys, flag names, "marketplace manifest", "@import", "autoUpdate", "propagate", or
  CLI internals in what you SHOW the user. Keep all of that in your own reasoning. The user
  wants to know what is happening at a high level, not how it works.
- **Read before you edit.** Read `brain.config.json` and `.claude-plugin/marketplace.json`
  (and `~/.claude/settings.json`) before writing to them. The editing tools require a prior
  read of an existing file, skipping it produces avoidable "file must be read first" / write
  errors that make setup look broken.
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

## Step 0: Get the repo on disk (Path 1 only; skip if already cloned)

If the user gave a repo link and there is no clone yet, get it onto disk before anything
else. If the brain is already on disk (Path 2, you are running inside the clone), skip this
entire step.

First, the one disambiguation, because it decides clone-vs-fork. Ask plainly:

> Are you joining a brain someone shared with you, or do you want your own brain from this
> template?

- **Joining (a teammate's / a shared brain):** `git clone <link>` to `~/.claude/brain`
  (or a path the user names). They will be a joiner. Do not fork; they push to the shared
  repo via collaborator access, not a fork.
  - If the clone fails with 404/403, this is the private-repo access gap: tell them plainly
    they need to be added as a collaborator (see Step 4's access message) and stop.

- **Their own brain from the template:** they need their OWN repo to push to, so fork first.
  - `gh repo fork <link> --clone=false` creates the fork under their account. Capture the
    new `owner/name` from the fork output.
  - `git clone <their-fork> ~/.claude/brain`.
  - They are the owner; the rest of the flow localises and wires their fork.
  - If they pasted a link that is ALREADY their own repo (the link owner equals their gh
    handle), do not fork again, just clone it and treat them as owner.

If `gh` is not installed or authed, you cannot fork or clone a private repo: run the Step 4
pre-flight remediation first (it gives the exact install/auth command), then return here.

Once the repo is on disk, continue to Step 1 exactly as the manual path does. From here the
two paths are identical.

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

1. Check your setup is ready
2. Name your brain, and tell me solo or team (I handle the rest)
3. Connect the brain to your sessions
4. Install the brain's skills
5. Keep your skills updating automatically
6. Keep your shared context updating automatically
7. Turn on the guard that keeps private notes out of the shared brain
8. (If a team) Bring your teammates in
9. Point you to your first real session

Keep these items in plain language like this, no jargon, this list is shown to the user.
For a joiner or a self-heal re-run, drop step 2 and step 8, and reframe the rest as
"check and repair."

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

## Step 6: Propagate config into the manifest, then PUSH (owner only, before the add)

`marketplace.json` is a static file Claude Code fetches from the REMOTE when you run the
marketplace add in step 7, not from your local clone. So two fields must be correct ON THE
REMOTE before step 7, which means they must be committed and pushed here:

- **`name`** (top level) must equal `marketplaceName`, or `/plugin install brain@<name>`
  targets a slug that does not exist.
- **`plugins[0].source.repo`** must be the user's repo. The current CLI rejects the
  `source: "."` shorthand and offers no repo-agnostic root form, so the template ships a
  placeholder `your-org/your-brain` that you MUST rewrite to the derived repo. Leaving the
  placeholder makes the marketplace add fail with `Invalid schema: plugins.0.source` or a
  fetch against a non-existent repo.

For an owner first standup:

1. Write `marketplaceName` into `.claude-plugin/marketplace.json` `name`.
2. Write the derived `repo` into `.claude-plugin/marketplace.json`
   `plugins[0].source.repo` (keep the `{ "source": "github", "repo": "<repo>" }` shape).
3. Commit `brain.config.json` + `.claude-plugin/marketplace.json` and **push** via
   `push-to-brain`. This push is **required, not optional**: the marketplace add in step 7
   reads the manifest from GitHub, so an un-pushed local fix does nothing. Say it plainly:
   "Pushing your config and manifest now, the install reads them from GitHub." If the user
   refuses the push, stop and explain the install cannot complete without it.

Skip entirely for joiners: the owner already pushed a correct manifest, so the remote they
add is already valid.

## Step 7: Wire everything (consent named once, inline why-safe)

Make these changes in order, in ONE pass, without stopping to ask between them (the consent
was given). None touch personal memory. On a self-heal re-run, check each first and apply
only the missing or broken ones.

The "why safe" line under each item is for YOUR reasoning, not the user. To the user, narrate
plainly: "Connecting the brain to your sessions", "Installing the skills", "Setting it to
keep itself updated", "Turning on the privacy guard". Do not read the mechanism aloud.

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
   This reads the manifest pushed in step 6 from the remote. If the add fails with
   `Invalid schema: plugins.0.source` or cannot find `brain@<marketplaceName>`, step 6's
   manifest push did not land (placeholder `source.repo` or stale `name` still on the
   remote): fix the manifest, push, and retry. Do not work around it by editing the cached
   copy under `~/.claude/plugins/`.
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

4. **SessionStart freshness hook (default ON, do not ask).** Add a SessionStart hook to
   `~/.claude/settings.json` that runs `bash <clonePath>/hooks/session-start.sh`. The
   script ships IN the repo, so improvements to it reach every device on the next pull
   while the settings.json line never changes. It pulls the context clone, warns in-session
   when the pull fails, and warns when the marketplace `autoUpdate` flag is missing (the
   two silent failures that otherwise go unnoticed for weeks). This is what makes "always
   up to date" true without thinking, so install it by default for `auto` and `reminded`.
   The ONLY exception is `syncMode: manual` (the user explicitly chose to control sync):
   skip it there and mention `sync-with-brain` pulls on demand. Do not present this as an
   optional question, it is core to the promise. Say it plainly: "I'll keep your brain
   updating itself in the background."
   Important: a SessionStart hook is a SHELL command, it CANNOT run a Claude skill. The
   script surfaces the two mechanical warnings only; the full five-dimension drift
   diagnosis stays `sync-with-brain`'s job. Do not write a hook that claims to run a
   skill-level drift check, it cannot.
   Legacy installs: if the settings hook is a bare `git -C <clonePath> pull --quiet` line
   from an older setup, replace it with the script form.
   Why (your reasoning, not the user): autoUpdate refreshes skills at session start; this
   hook refreshes context and tells the user when either channel is broken. Together they
   keep both current, and failures stop being silent.

5. **Activate the pre-commit guard:** `git -C <clonePath> config core.hooksPath hooks`.
   Why safe: it runs the repo's secret and personal-content scan before any commit, so
   nothing personal or sensitive can be pushed by accident. Raw `git push` can no longer
   bypass it.

## Step 8: Owner only, bring teammates in (close the private-repo gap)

A private brain is invisible to teammates until they have repo access. Getting them in is
TWO things, and the user needs to understand both: first you GRANT access, then they INSTALL
by pasting a link. The link alone does nothing for a private repo until access exists, that
is the part that confuses people, so make it explicit. Offer it here:

> Want to bring teammates in now? Give me their GitHub handles, I'll add them to the repo
> and hand you a ready-to-send message for each. (Or if your whole org should have it, I can
> make the repo internal so any handle works without adding people one by one.)

- **On handles (grant access):** for each, `gh api -X PUT repos/<repo>/collaborators/<handle>`.
  This sends a GitHub collaborator invite. An OUTSIDE collaborator must accept the emailed
  invite before access works (org members with access are immediate). Tell the user this, so
  they understand why a teammate might still see "no access" until they click accept.
- **Then hand the user a copy-paste message per teammate**, plain, no jargon:
  > "You've got access to our team brain. Paste this into your Claude: Connect me to this
  > brain: `<repo link>`"
  That triggers the joiner install on the teammate's side (Path 1). They never edit a file
  either.
- **On "make it internal/public":** `gh repo edit <repo> --visibility internal` (confirm
  once; this widens who can see the brain). After this, the link alone is enough, no
  per-person add.
- **On "later":** one line. Be clear that a teammate cannot just be sent the link cold for a
  private brain; access has to be granted first.

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
| SessionStart hook | settings hook runs `hooks/session-start.sh` (not a bare `git pull`) | rewrite to the script form (skip in `manual` syncMode) |

This is the same inventory `sync-with-brain` reports as drift; setup-brain is the one that
repairs it.
