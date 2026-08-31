#!/usr/bin/env bash
# Debug script: shows raw lint output AND tests the grep pattern
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$SCRIPT_DIR/scripts/lint-content.sh"

WIKI="$(mktemp -d "${TMPDIR:-/tmp}/wiki-lint-debug.XXXXXX")"
trap 'rm -rf "$WIKI"' EXIT

mkdir -p "$WIKI/conventions" "$WIKI/templates" "$WIKI/scripts" "$WIKI/_archive" "$WIKI/_staging"

cat > "$WIKI/self-ref.md" <<'EOF'
---
title: Self Reference
type: concept
created: 2025-01-01
updated: 2025-06-01
status: active
---
This note links to itself: [[self-ref]].
EOF

cat > "$WIKI/unrelated.md" <<'EOF'
---
title: Unrelated Note
type: concept
created: 2025-01-01
updated: 2025-06-01
status: active
---
This note does not link to self-ref.
EOF

OUTPUT="$("$LINT" "$WIKI" 2>&1; true)"
echo "=== OUTPUT captured ==="
echo "$OUTPUT"
echo "=== END OUTPUT ==="

echo ""
echo "=== grep test ==="
if echo "$OUTPUT" | grep -q "\[RED LINK\].*self-ref.*self-ref"; then
  echo "GREP MATCHED - bug would be caught"
else
  echo "GREP DID NOT MATCH - bug would NOT be caught"
fi
echo "=== end ==="
