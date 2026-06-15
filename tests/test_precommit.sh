#!/usr/bin/env bash
# tests/test_precommit.sh
# Deterministic unit tests for hooks/pre-commit (Layer 1).
# Verifies the F2 fix: skills/ and commands/ are exempt from the personal-content
# scan (PASS 2), bare "do not use" no longer blocks, but secrets (PASS 1) and
# first-person preference prose still block everywhere.
#
# Each case spins up a throwaway git repo, stages one file, runs the hook, and
# asserts the exit code. No network, no tokens, no side effects outside /tmp.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/hooks/pre-commit"

PASS=0
FAIL=0

# run_case <name> <relpath> <expected_exit> <content...>
run_case() {
  local name="$1" relpath="$2" expected="$3" content="$4"
  local tmp; tmp="$(mktemp -d)"
  (
    cd "$tmp" || exit 99
    git init -q
    git config user.email t@t.t
    git config user.name t
    mkdir -p "$(dirname "$relpath")"
    printf '%s\n' "$content" > "$relpath"
    git add "$relpath"
    bash "$HOOK" >/dev/null 2>&1
  )
  local got=$?
  rm -rf "$tmp"
  if [[ "$got" -eq "$expected" ]]; then
    printf '  PASS  %s (exit %s)\n' "$name" "$got"
    PASS=$((PASS+1))
  else
    printf '  FAIL  %s (expected %s, got %s)\n' "$name" "$expected" "$got"
    FAIL=$((FAIL+1))
  fi
}

echo "pre-commit hook tests"
echo

# --- F2: skill / command prose must NOT be blocked by PASS 2 -----------------
run_case "skill with 2nd-person imperative passes" \
  "skills/deploy-check/SKILL.md" 0 \
  "When you ask Claude to deploy, run preflight. Do not use the staging token in prod."

run_case "command with 'do not use' passes" \
  "commands/foo.md" 0 \
  "Do not use the cache when the flag is set."

# --- regression: bare 'do not use' in shared memory no longer blocks ----------
run_case "shared-memory 'do not use' passes (tightened pattern)" \
  "shared-memory/flags.md" 0 \
  "Do not use deprecated flags in the deploy script."

run_case "shared-memory plain fact passes" \
  "shared-memory/fact.md" 0 \
  "The deploy pipeline uses blue-green releases across two clusters."

# --- PASS 2 still blocks genuine personal content in shared scope ------------
run_case "first-person 'when i say' blocks" \
  "shared-memory/pref.md" 1 \
  "When I say ship it, just deploy without asking."

run_case "first-person 'i prefer claude' blocks" \
  "shared-memory/identity.md" 1 \
  "I prefer Claude to keep responses terse with no preamble."

# --- PASS 1 secrets still scan EVERY file, including exempt skill paths -------
run_case "secret in shared-memory blocks" \
  "shared-memory/leak.md" 1 \
  "token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

run_case "secret in skill path still blocks (exemption is PASS2-only)" \
  "skills/leaky/SKILL.md" 1 \
  "token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

echo
echo "pre-commit: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
