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

# run_case_solo <name> <relpath> <expected_exit> <content...>
# Same as run_case but writes a solo-mode brain.config.json so the hook reads
# BRAIN_MODE=solo. The config is unstaged (the hook reads the working tree).
run_case_solo() {
  local name="$1" relpath="$2" expected="$3" content="$4"
  local tmp; tmp="$(mktemp -d)"
  (
    cd "$tmp" || exit 99
    git init -q
    git config user.email t@t.t
    git config user.name t
    printf '{ "mode": "solo" }\n' > brain.config.json
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

# --- solo mode: personal/ tier is exempt from PASS 2, elsewhere still blocks --
run_case_solo "solo: personal content under personal/ allowed" \
  "personal/voice.md" 0 \
  "When I say ship it, my preference is to deploy without asking."

run_case_solo "solo: personal content under project-memory/ blocked" \
  "project-memory/leak.md" 1 \
  "When I say ship it, my preference is to deploy without asking."

# --- regression: in TEAM mode personal/ is NOT exempt (gating works) ----------
run_case "team: personal content under personal/ blocked (no solo gate)" \
  "personal/voice.md" 1 \
  "When I say ship it, my preference is to deploy without asking."

# --- tests/ fixtures are exempt so the guard can coexist with its own tests ----
run_case "fixture secret under tests/ passes (deliberate fixture exemption)" \
  "tests/fixtures.sh" 0 \
  "token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

# --- 1:1 coaching pattern must not false-positive on timestamps/ratios --------
run_case "timestamp 11:16 in project-memory passes (not 1:1 coaching)" \
  "project-memory/cm/post.md" 0 \
  "Post 002 shipped Thu 11:16 AM with a 16:9 cover ratio."

run_case "genuine 1:1 coaching in shared-memory still blocks" \
  "shared-memory/coach.md" 1 \
  "Notes from our 1:1 session on personal goal setting."


# --- self-describing surfaces are PASS-2 exempt (CI full-tree scan must pass) --
run_case "operating doc quoting guarded vocabulary passes (ARCHITECTURE.md)" \
  "ARCHITECTURE.md" 0 \
  "Tier 1 is personal memory: interaction preferences and 1:1 coaching content."

run_case "docs/ quoting guarded vocabulary passes" \
  "docs/governed-mode.md" 0 \
  "Reviewers check no personal memory or 1:1 coaching content enters shared scope."

run_case "personal/INDEX.md tier doc passes in team mode" \
  "personal/INDEX.md" 0 \
  "This tier holds personal memory mirrors in solo mode only."

run_case "shared-memory personal content STILL blocks (tiers never exempt)" \
  "shared-memory/pref.md" 1 \
  "I prefer claude to answer in lowercase, that is my communication style."

run_case "shipped tier template quoting vocabulary passes (_TEMPLATE.md)" \
  "perspectives/_TEMPLATE.md" 0 \
  "A perspective is a lens, not personal memory or a 1:1 coaching doc."

run_case "user-created perspective with personal content STILL blocks" \
  "perspectives/marketing-lead.md" 1 \
  "I prefer claude to keep my communication style casual in this lens."

echo
echo "pre-commit: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
