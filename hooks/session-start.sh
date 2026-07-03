#!/usr/bin/env bash
# hooks/session-start.sh: SessionStart freshness hook for the brain.
#
# setup-brain wires this into ~/.claude/settings.json as a SessionStart hook:
#   bash <clonePath>/hooks/session-start.sh
# Because the script lives IN the clone, improvements to it ship to every
# device on the next pull; the settings.json line never changes.
#
# What it does (deterministic, no Claude skill can run here):
#   1. Pulls the context clone so @import'd context is current.
#   2. Warns when the pull fails (offline, auth) instead of failing silently.
#   3. Warns when the autoUpdate flag for this brain's marketplace is missing
#      from ~/.claude/settings.json: without it, pushed skills NEVER install
#      themselves, the single most common silent failure in the system.
#
# Output contract: SILENT when everything is healthy (stdout becomes session
# context; do not spend it on good news). One line per problem otherwise, each
# pointing at sync-with-brain or setup-brain as the fix.

set -u

CLONE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1 + 2: pull the context clone, surface failure.
if ! git -C "$CLONE_DIR" pull --quiet --rebase 2>/dev/null; then
  echo "brain: context pull FAILED (offline, auth, or local conflict). Context may be stale. Run sync-with-brain."
fi

# 3: autoUpdate flag check (best-effort text scan, no jq dependency).
SETTINGS="$HOME/.claude/settings.json"
MARKETPLACE=""
if [ -f "$CLONE_DIR/brain.config.json" ]; then
  MARKETPLACE=$(grep -oE '"marketplaceName"[[:space:]]*:[[:space:]]*"[^"]+"' "$CLONE_DIR/brain.config.json" | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/')
fi
if [ -n "$MARKETPLACE" ] && [ -f "$SETTINGS" ]; then
  # Look for the marketplace block and an autoUpdate: true within a few lines
  # of it. Coarse but dependency-free; sync-with-brain does the precise check.
  if ! grep -A4 "\"$MARKETPLACE\"" "$SETTINGS" | grep -qE '"autoUpdate"[[:space:]]*:[[:space:]]*true'; then
    echo "brain: autoUpdate is OFF for marketplace '$MARKETPLACE'. Pushed skills will not install themselves. Run setup-brain (or sync-with-brain) to restore it."
  fi
fi

exit 0
