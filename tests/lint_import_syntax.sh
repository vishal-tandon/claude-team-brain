#!/usr/bin/env bash
# tests/lint_import_syntax.sh
# Layer 1 lint for the F1 fix: the context-import directive is a BARE @path, and
# the detectors (sync-with-brain, disconnect-brain) must NOT grep for a literal
# "@import <path>" token that setup-brain never writes. This locks the regression.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETUP="$REPO_ROOT/skills/setup-brain/SKILL.md"
SYNC="$REPO_ROOT/skills/sync-with-brain/SKILL.md"
DISC="$REPO_ROOT/skills/disconnect-brain/SKILL.md"

PASS=0
FAIL=0

assert_absent() { # <file> <fixed-string> <label>
  if grep -qF "$2" "$1"; then
    printf '  FAIL  %s (found buggy literal: %s)\n' "$3" "$2"; FAIL=$((FAIL+1))
  else
    printf '  PASS  %s\n' "$3"; PASS=$((PASS+1))
  fi
}

assert_present() { # <file> <ere> <label>
  if grep -qE "$2" "$1"; then
    printf '  PASS  %s\n' "$3"; PASS=$((PASS+1))
  else
    printf '  FAIL  %s (missing pattern: %s)\n' "$3" "$2"; FAIL=$((FAIL+1))
  fi
}

echo "@import syntax lint"
echo

# The old buggy match strings must be gone.
assert_absent "$SYNC" '@import <clonePath>/CLAUDE.md' "sync: no literal '@import <path>' match"
assert_absent "$DISC" '@import.*<clonePath>.*CLAUDE.md' "disconnect: no literal '@import.*' match"

# The corrected bare-@ regex must be present in both detectors.
assert_present "$SYNC" '\^@\.\*<clonePath>\.\*CLAUDE' "sync: uses bare-@ regex"
assert_present "$DISC" '\^@\.\*<clonePath>\.\*CLAUDE' "disconnect: uses bare-@ regex"

# setup-brain must write the bare form.
assert_present "$SETUP" '@<clonePath>/CLAUDE\.md' "setup: writes bare @<clonePath>/CLAUDE.md"

echo
echo "import-lint: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
