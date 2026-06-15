#!/usr/bin/env bash
# tests/test_primitives.sh
# Layer 2 deterministic primitives. These lock the LOGIC the zero-config installer
# must follow (setup-brain is markdown, so this tests reference implementations of
# its rules, catching logic errors and pinning expected behavior):
#   - F5: derive repo from the git remote, never from a placeholder
#   - F10: derive marketplaceName from the repo name (kebab)
#   - F6: write the context-import line, read the clone path back out of it
#   - autoUpdate: merge the extraKnownMarketplaces block into settings.json correctly
# No network, no tokens. Runs in /tmp.

set -uo pipefail
PASS=0; FAIL=0
ok()   { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
no()   { printf '  FAIL  %s (got: %s)\n' "$1" "$2"; FAIL=$((FAIL+1)); }
eq()   { [[ "$2" == "$3" ]] && ok "$1" || no "$1" "$2"; }

# --- F5: derive owner/name from a git remote URL -----------------------------
derive_repo() { # <remote-url> -> owner/name
  local u="$1"
  u="${u%.git}"
  u="${u#git@github.com:}"
  u="${u#https://github.com/}"
  u="${u#ssh://git@github.com/}"
  printf '%s' "$u"
}

echo "primitive logic tests"
echo
eq "derive repo from ssh remote"   "$(derive_repo 'git@github.com:alex-co/team-brain.git')" "alex-co/team-brain"
eq "derive repo from https remote" "$(derive_repo 'https://github.com/alex-co/team-brain.git')" "alex-co/team-brain"
eq "derive repo without .git"      "$(derive_repo 'https://github.com/alex-co/team-brain')" "alex-co/team-brain"

# placeholder must be detectable and rejected
is_placeholder() { [[ "$1" == "your-org/your-brain" || "$1" == */your-brain ]]; }
if is_placeholder "your-org/your-brain"; then ok "placeholder repo is rejected"; else no "placeholder repo is rejected" "not detected"; fi

# --- F10: marketplaceName from repo name (kebab, lowercase) -------------------
derive_mkt() { # <owner/name> -> kebab name
  local n="${1##*/}"
  n="$(printf '%s' "$n" | tr '[:upper:] ' '[:lower:]-' )"
  printf '%s' "$n"
}
eq "marketplaceName from repo" "$(derive_mkt 'alex-co/Team Brain')" "team-brain"
eq "marketplaceName already kebab" "$(derive_mkt 'alex-co/team-brain')" "team-brain"

# --- F6: import-line round-trip (write, then read clonePath back) -------------
parse_clonepath() { # reads stdin (a CLAUDE.md), echoes resolved clonePath
  # match a bare @<path>/CLAUDE.md line, tolerate optional legacy 'import '
  local line
  line="$(grep -E '^@(import )?.*CLAUDE\.md' | head -n1)"
  line="${line#@}"; line="${line#import }"
  printf '%s' "${line%/CLAUDE.md}"
}
TMP="$(mktemp -d)"
CLONE="/home/alex/dev/team-brain"   # deliberately NON-default path (F6 core case)
printf '# user config\n@%s/CLAUDE.md\n' "$CLONE" > "$TMP/CLAUDE.md"
GOT="$(parse_clonepath < "$TMP/CLAUDE.md")"
eq "F6 round-trip resolves non-default clone path" "$GOT" "$CLONE"
# legacy form with 'import ' still parses
printf '@import %s/CLAUDE.md\n' "$CLONE" > "$TMP/legacy.md"
eq "F6 tolerates legacy '@import' form" "$(parse_clonepath < "$TMP/legacy.md")" "$CLONE"
rm -rf "$TMP"

# --- autoUpdate: merge extraKnownMarketplaces into settings.json --------------
TMP="$(mktemp -d)"
printf '{"theme":"dark"}\n' > "$TMP/settings.json"
python3 - "$TMP/settings.json" team-brain alex-co/team-brain <<'PY'
import json,sys
p,mkt,repo=sys.argv[1],sys.argv[2],sys.argv[3]
d=json.load(open(p))
d.setdefault("extraKnownMarketplaces",{})[mkt]={
  "source":{"source":"github","repo":repo},"autoUpdate":True}
json.dump(d,open(p,"w"),indent=2)
PY
VAL="$(python3 -c "import json;d=json.load(open('$TMP/settings.json'));print(d['extraKnownMarketplaces']['team-brain']['autoUpdate'], d['extraKnownMarketplaces']['team-brain']['source']['repo'], d['theme'])")"
eq "autoUpdate block merged, existing keys preserved" "$VAL" "True alex-co/team-brain dark"
rm -rf "$TMP"

# --- F4: manifest name must equal marketplaceName before install -------------
TMP="$(mktemp -d)"
printf '{"name":"your-team-brain","plugins":[{"name":"brain","source":"."}]}\n' > "$TMP/marketplace.json"
python3 - "$TMP/marketplace.json" team-brain <<'PY'
import json,sys
p,mkt=sys.argv[1],sys.argv[2]
d=json.load(open(p)); d["name"]=mkt; json.dump(d,open(p,"w"))
PY
eq "manifest name propagated before install" \
  "$(python3 -c "import json;print(json.load(open('$TMP/marketplace.json'))['name'])")" "team-brain"
rm -rf "$TMP"

echo
echo "primitives: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
