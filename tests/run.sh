#!/usr/bin/env bash
# tests/run.sh — Layer 1 deterministic suite. Zero network, zero tokens.
# Runs: JSON validity, @import syntax lint, pre-commit hook unit tests.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RC=0

echo "== JSON validity =="
for f in .claude-plugin/marketplace.json .claude-plugin/plugin.json brain.config.json; do
  if python3 -c "import json,sys; json.load(open('$REPO_ROOT/$f'))" 2>/dev/null; then
    echo "  PASS  $f"
  else
    echo "  FAIL  $f"; RC=1
  fi
done
echo

echo "== manifest plugin source form (F13 regression) =="
python3 - "$REPO_ROOT/.claude-plugin/marketplace.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
src=d["plugins"][0].get("source")
ok = isinstance(src,dict) and src.get("source")=="github" and "repo" in src
print(("  PASS  plugins[0].source is github object" if ok
       else f"  FAIL  plugins[0].source must be a github object, got: {src!r}"))
sys.exit(0 if ok else 1)
PY
[[ $? -eq 0 ]] || RC=1
echo

echo "== bash syntax: hooks/pre-commit =="
if bash -n "$REPO_ROOT/hooks/pre-commit"; then echo "  PASS  hooks/pre-commit"; else echo "  FAIL"; RC=1; fi
echo

bash "$SCRIPT_DIR/lint_import_syntax.sh" || RC=1
echo
bash "$SCRIPT_DIR/test_precommit.sh" || RC=1
echo
bash "$SCRIPT_DIR/test_primitives.sh" || RC=1
echo

if [[ "$RC" -eq 0 ]]; then echo "ALL LAYER-1 TESTS PASSED"; else echo "LAYER-1 FAILURES PRESENT"; fi
exit "$RC"
