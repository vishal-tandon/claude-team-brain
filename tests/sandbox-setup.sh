#!/usr/bin/env bash
# tests/sandbox-setup.sh
# Preps an ISOLATED environment to test the brain install like a cold new user,
# WITHOUT polluting your real ~/.claude and WITHOUT losing working credentials.
#
# Isolation model:
#   - HOME is overridden to /tmp/brain-e2e for the test session.
#   - That sandbox HOME symlinks ONLY credentials (ssh, gh, gitconfig, the Claude
#     Code login token). It does NOT carry your CLAUDE.md, memory, skills, or
#     settings, so the test Claude runs cold = an honest new-user simulation.
#   - A throwaway PRIVATE repo is the brain under test, so owner standup (config
#     write + manifest push + collaborator add) runs for real without touching
#     your actual claude-team-brain repo.
#
# Run this from your normal shell (real HOME). It is idempotent: re-run to reset.

set -euo pipefail

REAL_HOME="${HOME:?}"
SB=/tmp/brain-e2e
DEV_REPO="/home/vishal/claude-projects/claude-team-brain"
SCRATCH_NAME="brain-sandbox"
CLONE_DIR="$SB/dev/brain-test"

GH_USER="$(gh api user --jq .login)"
SCRATCH="$GH_USER/$SCRATCH_NAME"

echo ">> wiping sandbox HOME at $SB"
rm -rf "$SB"
mkdir -p "$SB/.claude" "$SB/dev" "$SB/.config"

echo ">> symlinking credentials only (no CLAUDE.md / memory / skills / settings)"
ln -s "$REAL_HOME/.ssh"                       "$SB/.ssh"
ln -s "$REAL_HOME/.config/gh"                 "$SB/.config/gh"
[ -f "$REAL_HOME/.gitconfig" ] && ln -s "$REAL_HOME/.gitconfig" "$SB/.gitconfig"
ln -s "$REAL_HOME/.claude/.credentials.json"  "$SB/.claude/.credentials.json"

echo ">> ensuring throwaway private repo $SCRATCH exists"
if gh repo view "$SCRATCH" >/dev/null 2>&1; then
  echo "   exists, will reseed"
else
  gh repo create "$SCRATCH" --private --description "throwaway brain install sandbox" >/dev/null
  echo "   created"
fi

echo ">> seeding $SCRATCH from current brain content (placeholders intact = new-owner state)"
SEED="$(mktemp -d)"
git clone -q "$DEV_REPO" "$SEED/seed"
(
  cd "$SEED/seed"
  git remote remove origin
  git remote add origin "git@github.com:$SCRATCH.git"
  git push -q -f origin HEAD:main
)
rm -rf "$SEED"

echo ">> cloning the throwaway into the sandbox at $CLONE_DIR"
HOME="$SB" git clone -q "git@github.com:$SCRATCH.git" "$CLONE_DIR"

cat <<EOF

================================================================
SANDBOX READY.

Throwaway repo : $SCRATCH (private)
Sandbox HOME   : $SB  (cold: no CLAUDE.md / memory / skills)
Brain clone    : $CLONE_DIR

WHAT TO DO (in a brand-new terminal, do NOT mention this work):

  export HOME=$SB
  cd $CLONE_DIR
  claude

Then paste this cold prompt (this is the README's own instruction, nothing more):

  set up my brain

This deliberately does NOT point Claude at the skill file. A cold Claude in the
clone should discover setup-brain on its own (the repo's CLAUDE.md names it). If it
flails instead of running setup-brain, that is a real bootstrap finding, note it.

DURING THE RUN it is fine to say YES to the config-commit/push and to skip
adding teammates (or add a throwaway handle). It is a scratch repo.

JUDGE IT AS A NEW USER WOULD: did it ask you to edit any file? did it explain
things in plain language? did the skills install? open a SECOND sandbox session
afterwards and check the brain loads + a skill triggers by name.

CLEANUP when done:
  rm -rf $SB
  gh repo delete $SCRATCH --yes      # needs delete_repo scope; else delete in browser
================================================================
EOF
