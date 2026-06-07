# Governed Mode Setup Guide

Governed mode adds PR-based review to brain contributions. It is opt-in.
Open mode (the default) requires none of this. Skip this document unless
you want human review on every brain change.

**When to use governed mode:**
- Your team wants an audit trail of what was added to the brain and why.
- You are in a regulated environment where changes to shared context need sign-off.
- Your team has a designated brain maintainer who reviews contributions.

---

## Step 1: Enable governed mode in config

In `brain.config.json`, set:

```json
"governance": "governed"
```

This single flag routes `push-to-brain` from direct push to open-a-PR. All
other behavior is unchanged.

---

## Step 2: Protect the main branch on GitHub

In your repo on GitHub:

1. Go to **Settings → Branches → Add branch ruleset** (or **Add branch
   protection rule** depending on your GitHub plan).
2. Target the `main` branch.
3. Enable: **Require a pull request before merging**.
4. Set required approvals to 1 (or more, depending on team size).
5. Optionally enable: **Require status checks to pass** if you add CI later.
6. Save.

After this, no one can push directly to `main`. All changes must come through
a PR. This is the entire point of governed mode.

---

## Step 3: Add CODEOWNERS (optional but recommended)

CODEOWNERS designates who is notified for review when a PR touches specific
paths. Create `.github/CODEOWNERS` in your repo:

```
# .github/CODEOWNERS
# Require review for all brain changes
*   @your-github-username

# Or scope by path, require a specific person for shared memory
shared-memory/   @your-github-username
perspectives/    @your-github-username
```

With CODEOWNERS set, GitHub auto-requests review from the designated reviewer
when `push-to-brain` opens a PR.

---

## Step 4: How push-to-brain works in governed mode

When `governance: governed` is set, `push-to-brain`:

1. Creates a short-lived branch (`brain-update/<date>-<slug>`).
2. Commits the changes to that branch.
3. Opens a PR to `main` with a description of what changed and why.
4. **Leaves the PR open for human merge.** The human gate is the entire
   point. Auto-merge on green would defeat governed mode.

The contributor gets a link to the open PR. The reviewer gets a GitHub
notification (or CODEOWNERS auto-request). Merge happens in GitHub.

---

## Step 5: Merging a brain PR

The reviewer:

1. Reads the PR description (written by `push-to-brain`).
2. Checks the diff for the local-vs-shared boundary: no personal preferences,
   no credentials, no interaction-style content in the shared brain.
3. Merges to `main`.
4. Deletes the branch.

Other team members pick up the change at their next `sync-with-brain` or
SessionStart pull.

---

## Switching back to open mode

Set `"governance": "open"` in `brain.config.json` and remove the branch
protection rule in GitHub. Done. All existing history is preserved.

---

## Summary

| Step | Where |
|---|---|
| Set `governance: governed` | `brain.config.json` |
| Protect `main` branch | GitHub repo settings |
| Add CODEOWNERS (optional) | `.github/CODEOWNERS` |
| Contributors run `push-to-brain` | Opens PR automatically |
| Reviewer merges in GitHub | Leaves PR open until reviewed |
