---
name: share-with-brain
description: >
  Use this skill when the user wants to promote a specific piece of local context
  (a project's accumulated knowledge, a decision log, a design doc) up into the
  shared brain's project-memory tier so teammates or other devices can benefit from
  it. Distinct from push-to-brain (which handles only the git workflow): this skill
  decides WHAT to share, runs content heuristics and a drift check, gets a
  file-level confirmation, then delegates the actual git push to push-to-brain.
  Trigger phrases: "share with brain", "share this project with the brain",
  "promote this project to the brain", "lift this project to the brain", "add
  this project to team context", "make this project visible to the team / my other
  devices", or any close paraphrase. Reads all constants from brain.config.json.
  Also fires on "/share-with-brain".
---

# Share with brain

A one-way lift of selected project context from a local environment into the
brain's `project-memory/` tier. Optional and reversible, the user chooses what
to share, file by file. Reads all runtime constants from `brain.config.json` at
the repo root.

**The intent: make project knowledge available everywhere, without leaking
personal content into shared scope.**

## What this skill does NOT do

- Does NOT scan or promote interaction preferences (`feedback_*.md`, voice or
  pacing files in `~/.claude/memory/`). Those are personal by design.
- Does NOT promote credentials, tokens, or anything that looks like a secret.
- Does NOT promote career-growth content or coaching notes.
- Does NOT decide what is worth sharing on the user's behalf. It scans, presents,
  and requires a file-level decision before writing anything.
- Does NOT run the git workflow itself. That is `push-to-brain`'s job. This skill
  stages content in the brain clone, then invokes `push-to-brain` as the final step.

## Before doing anything: read brain.config.json

Locate and read `brain.config.json` from the brain clone root. Extract:

- `clonePath`: resolve it by reading the context-import line in
  `~/.claude/CLAUDE.md` (the bare `@<clonePath>/CLAUDE.md` line setup-brain wrote)
  and taking the directory it points at. That import line is the persisted record
  of where the clone lives. Fall back to `defaultClonePath` (`~/.claude/brain`)
  only if no import line is found.

All filesystem writes go into `<clonePath>/project-memory/<slug>/`. Use absolute
paths throughout. Never rely on a persistent cwd.

## Local-vs-shared boundary (the rule this skill enforces)

Brain content carries **facts and capabilities**, never user-interaction preferences.
Apply this filter to every candidate file:

| Category | Share to brain? |
|---|---|
| Project memory files (decisions, research summaries, project overviews) | Yes |
| Project README or CLAUDE.md (describes the project, not the user's habits) | Yes |
| Design docs, frameworks, artefacts useful to teammates or other devices | Yes |
| Strategy or stakeholder context for the project | Yes |
| Interaction preferences (`feedback_*.md`, voice or pacing files) | Never |
| Credentials, tokens, API keys | Never |
| Career advice or coaching notes | Never |
| Personal session logs (`~/.claude/logs/`) | Never |
| Industry-standard knowledge learnable from authoritative sources | Never |

If unsure about a specific file, default to NOT promoting it and ask the user.

## The promotion manifest

Promotion **copies** files. It does not move them. The brain copy is a
point-in-time snapshot that drifts from the local source as the owner keeps
editing. The manifest detects that drift so a later run re-promotes only what
actually changed, rather than blindly re-copying or silently leaving the brain
stale.

Every promotion writes `<clonePath>/project-memory/<slug>/.manifest.json`:

```json
{
  "slug": "<slug>",
  "schema": 1,
  "files": [
    {
      "source": "~/<path-to-local-project>/CLAUDE.md",
      "dest": "product-context.md",
      "promoted": "YYYY-MM-DD",
      "sha256": "<hash of the content at promote time>"
    }
  ]
}
```

Rules:
- One entry per promoted content file. `source` uses a `~/` prefix so it is
  portable across machines. `dest` is the path relative to the slug directory.
  `sha256` is the hash of the bytes written to the brain.
- `README.md` and `.manifest.json` are never manifest entries. They are
  generated or meta files, not promoted source. Never run them through the
  sensitive-content scan.
- The manifest is owner-scoped: only the machine holding the local `source` files
  can compute drift. On any other machine the sources do not resolve, and the drift
  check no-ops gracefully.

## Workflow when invoked

### 1. Identify the source project

Use the current working directory (cwd):

- **If cwd is a project folder** (has a `CLAUDE.md` or recognisable project
  structure): that is the project. Confirm with the user in one line.
- **If cwd is ambiguous** (home directory, the brain clone itself, etc.): ask
  the user which project they mean. Offer a short list of candidate project folders
  as options if helpful.

### 2. Determine the slug

Generate a kebab-case slug from the project folder name. Examples:
- `~/projects/CheckoutRedesign/` → `checkout-redesign`
- `~/projects/OnboardingFlow/` → `onboarding-flow`
- `~/projects/api-gateway/` → `api-gateway` (already kebab)

Show the proposed slug to the user. Let them override in one line. The slug
determines the directory name in the brain. Lock it before writing anything.

### 3. Check if already promoted: detect drift

Look at `<clonePath>/project-memory/<slug>/`.

- **Does not exist**: first-time promotion. Proceed to step 4.
- **Already exists**: run the divergence check before doing anything else.

**Divergence check.** Read `<slug>/.manifest.json`. For each entry, resolve
`source` on this machine and compare the local source against the brain copy:

| Symbol | Meaning | How to detect |
|---|---|---|
| `=` unchanged | local source byte-identical to the brain copy | source sha == brain-copy sha |
| `~` diverged | local source has been edited since promotion | source sha != brain-copy sha (but brain copy still matches recorded `sha256`) |
| `!` brain-edited | brain copy was hand-edited directly | brain-copy sha != recorded `sha256` |
| `?` source-missing | source path does not resolve here | file not found at `source` |

Also scan for:
- **New local candidates**: promotable files in the project folder with no
  manifest entry yet. Mark `+ new`.
- **Orphans**: manifest entries whose `source` is gone but whose brain copy
  remains. Mark `? source-missing`; the brain copy is now unmaintained.

Present a short divergence report, e.g.:

```
<slug> is already in the brain. Comparing local sources against the brain snapshot:

~ strategy.md           diverged (promoted 2026-06-04, local edited since)
= product-context.md    unchanged
! research/findings.md  brain copy was edited directly since promotion
+ research/new-scan.md  new, not yet in the brain

Re-promote the diverged + new file(s)? Unchanged files will be skipped.
```

Drift-aware defaults: `~ diverged` and `+ new` pre-checked; `=` unchanged
pre-unchecked; `!` brain-edited surfaced explicitly (ask before overwriting,
the brain edit may be deliberate).

**Graceful fallbacks:**
- No `.manifest.json`: legacy promotion. Fall back to additive behaviour (show
  what is in the brain alongside new candidates, let the user pick), and write a
  manifest this run so future runs get drift detection.
- No sources resolve (you are on a machine that does not own this project's source):
  report "nothing to compare on this machine, you do not hold the source for
  `<slug>`" and treat the run as a normal additive update.
- Everything is `=` unchanged: say so and exit cleanly without writing anything.

### 4. Scan for promotable content (with content-level heuristics)

Look in two places:
- **The project folder** (and subfolders): `CLAUDE.md`, `README.md`,
  `decisions/`, `docs/`, any `project_<slug>.md` files, key design docs.
- **The user's personal memory** (`~/.claude/memory/`): any file whose name or
  content clearly references this project (e.g. `project_<slug>.md`). Skip
  everything else. Do NOT open files that are not clearly project-scoped.

Apply the boundary filter from above. Drop anything in the "Never" rows before
showing the list.

**Content-level scan** (in addition to filename filtering):

For every candidate that passes the filename filter, scan actual content for
personal-vs-shared boundary signals:

- **Frontmatter** `type: user`, `type: feedback`, `private: true`,
  `personal: true`: drop the file (clearly personal)
- **Self-referential preference assertions** ("I prefer", "I want", "I don't
  like", "my style is", "I always do X"): flag those specific lines for scrub
  before promotion; promote the rest of the file
- **Secret patterns** (`sk_*`, `ghp_*`, `figd_*`, `Bearer *`,
  `AKIA[0-9A-Z]{16}`, anything that looks like an API key with content): drop
  or scrub; never push secrets to a shared repo
- **PII patterns** (email addresses and phone numbers in close proximity,
  especially of staff): flag for review
- **Interpersonal references** ("as [Name] mentioned during our 1:1", "[Name]
  told me this is the way"): flag; the brain is shared-scope, not interpersonal

For each scrub candidate, surface to the user:

```
File <path> looks promotable but has these lines that may not belong in the
shared brain:

  Line 12: "I prefer using sketches for early ideation"  (personal preference)
  Line 38: "as [Name] mentioned in our 1:1"              (interpersonal reference)

Options for this file:
  (a) Scrub these specific lines and promote the rest
  (b) Promote anyway (override, explicit yes required)
  (c) Skip this file entirely
```

The bias is conservative: when in doubt, default to scrub or skip. Promoting
too much is harder to undo than not promoting enough.

### 5. Present the scan to the user

Show a checklist:

```
Candidates for promotion to project-memory/<slug>/:

  [x] <project>/CLAUDE.md: project overview and structure
  [x] <project>/docs/<file>.md: <one-line description>
  [x] ~/.claude/memory/project_<slug>.md: project memory referencing this project
  [ ] <project>/notes/<file>.md: uncertain, looks more like personal notes
  [ ] <project>/research/<large-file>.md: large file, confirm relevance

Default checked: files that explicitly reference the project by slug or name.
```

Let the user check or uncheck. Treat their final selection as authoritative.

### 6. Confirm the planned writes

Show the planned writes as source → destination before any filesystem changes:

```
About to write to <clonePath>/project-memory/<slug>/:

  <project>/CLAUDE.md             → <slug>/CLAUDE.md
  <project>/docs/<file>.md        → <slug>/<file>.md
  ~/.claude/memory/project_<slug>.md → <slug>/project_<slug>.md
  (new)                           → <slug>/README.md (auto-generated summary)
  (append)                        → project-memory/INDEX.md (pointer line)
```

Get one confirmation before any filesystem changes.

### 7. Apply the writes

In order:

1. `mkdir -p <clonePath>/project-memory/<slug>/`
2. Copy each approved file to its destination. Use the original filename unless
   renaming makes it clearer to a teammate cold-reading (e.g. drop redundant
   project-name prefixes).
3. Write `<slug>/README.md` summarising what is in the directory and linking back
   to the source project. Keep it short. A teammate landing here should know in
   30 seconds what the project is and what is in this folder.
4. Append a pointer line to `<clonePath>/project-memory/INDEX.md` under the
   existing list:
   `- [<Project name>](<slug>/): one-line summary`
   Match the existing format. Do not reorder existing entries.
5. Write or refresh `<slug>/.manifest.json`. For every file just written, set or
   update its entry: `source` (with `~/` prefix), `dest` (relative to the slug
   dir), `promoted` (today's date), and `sha256` (hash of the bytes written). On
   an update run, preserve entries for untouched files, update entries for
   re-promoted files, and drop entries whose source the user confirmed is gone.
   Never list `README.md` or `.manifest.json` as entries.

### 8. Record the promotion in the source project

So future sessions do not re-ask "share with the brain?". The brain's new-project
detection greps for the exact string `## Brain decision`. The marker must use
that header verbatim.

- **If the project has a CLAUDE.md**: append this section at the bottom (skip
  if a `## Brain decision` section already exists; update it instead):

```
## Brain decision

- **Decision:** share
- **Slug:** <slug>
- **Recorded:** <YYYY-MM-DD>

Promoted to the brain as `<slug>`. Lives at `<clonePath>/project-memory/<slug>/`.
Re-run `share-with-brain` to refresh (it will drift-check against the brain copy first).
```

- **If the project has no CLAUDE.md**: write `<project>/.brain-status`
  containing the same `## Brain decision` block in plain text.

### 9. Commit and push via push-to-brain

Invoke `push-to-brain` as a sub-step. Pass the staged files (the new `<slug>/`
directory and the updated `INDEX.md`) and a suggested commit message:

```
promote <slug>: lift project context into project-memory/

Files:
  project-memory/<slug>/<file1>
  project-memory/<slug>/<file2>
  ...
  project-memory/INDEX.md (pointer added)
```

Let `push-to-brain` handle the actual git workflow, staging, committing, pushing,
governance routing. Do not duplicate that logic here.

### 10. Report success

One line:

> Project `<slug>` is now in the brain. Teammates and other devices will see it on
> their next sync.

Plus the brain path so the user can verify: `<clonePath>/project-memory/<slug>/`.

## Edge cases

- **Cwd is not a project folder**: ask which project. Offer a short list of
  candidate folders with `CLAUDE.md` as a hint that they are real projects.
- **Project has no clearly project-scoped files**: tell the user and ask them to
  name 1-3 files they want to share. Do not promote an empty directory.
- **User wants partial share** ("just the CLAUDE.md and the decision log, not the
  research"): the check/uncheck step in step 5 handles this natively.
- **User cancels mid-flow** (after the scan but before approval, or after approval
  but before push): clean up any partial writes. If the `<slug>/` directory was
  created but the user cancels before push, ask: "Delete the brain directory and
  revert, or leave it staged?" Default to deleting. Half-written brain content is
  worse than no brain content.
- **A file looks large or sensitive** (giant transcript dump, anything with
  `secret` / `token` / `password` in the name or content): flag it explicitly:
  "This file looks sensitive. Confirm explicitly to include." Default to excluding.
- **Brain copy was hand-edited directly** (`!` brain-edited in step 3): do not
  silently overwrite. Ask whether to keep the brain edit or replace with the local
  source. The direct edit may be a deliberate team-facing change the local source
  does not have.

## Common pitfalls

- **Promoting personal context.** Interaction preferences, voice files, and
  `feedback_*.md` never belong in the brain. The filter table is non-negotiable.
  If a file is borderline, default to NOT promoting and ask.
- **Promoting too much.** A teammate cold-reading the brain does not want to wade
  through 20 files. Curate. If a file would not help someone else, it does not
  belong here.
- **Forgetting the INDEX update.** Project-memory entries not in the INDEX are
  invisible. They do not load into sessions. Always append the pointer line.
- **Forgetting the local marker.** Without the step 8 marker, new-project nudges
  will re-ask on every fresh session. Always write the marker.
- **Skipping the confirmation step.** Writing to the brain is a shared action.
  Even if the scan looks obvious, get the one explicit confirmation in step 6
  before any filesystem changes.
- **Duplicating the git workflow.** `push-to-brain` exists for a reason. Do not
  inline staging or committing into this skill.
- **Promoting without a slug agreement.** If the slug changes after files are
  written, the INDEX link breaks and the marker file points at the wrong directory.
  Lock the slug in step 2, before any writes.
- **Forgetting the manifest.** If `.manifest.json` is not written or refreshed,
  the next run cannot detect drift. Always write it. Keep `dest` paths relative to
  the slug dir.

## Composing with other skills

- **`push-to-brain`**: invoked as step 9. This skill stages content; push-to-brain
  runs git and handles governance routing. Keep the responsibilities split.
- **`reflect`**: if a session surfaces new patterns or principles worth promoting,
  `reflect` proposes those for the memory layer (personal or brain). `share-with-brain`
  is for whole-project promotion, not individual-learning promotion.
- **`sync-with-brain`**: if the user's clone is out of date before a share, suggest
  running `sync-with-brain` first to avoid conflicts in step 9.
