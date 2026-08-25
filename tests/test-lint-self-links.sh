#!/usr/bin/env bash
# tests/test-lint-self-links.sh
#
# RED/GREEN test: a note that wikilinks to itself must NOT appear in
# the broken-links section of lint-content.sh output.
#
# The bug (before fix): when the only candidate for a link target is the
# source note itself, the resolver skips the self-match (correct, self-
# links don't count as inbound links), leaves matched=0, and incorrectly
# writes the link to BROKEN_LINKS.
#
# Usage: bash tests/test-lint-self-links.sh
# Exit 0 = PASS, Exit 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$SCRIPT_DIR/scripts/lint-content.sh"

# ---- build a minimal wiki in a temp dir ----
WIKI="$(mktemp -d "${TMPDIR:-/tmp}/wiki-lint-test.XXXXXX")"
trap 'rm -rf "$WIKI"' EXIT

# Required wiki-standard structure
mkdir -p "$WIKI/conventions" "$WIKI/templates" "$WIKI/scripts" \
         "$WIKI/_archive" "$WIKI/_staging"

# The note under test: only links to itself — no other note links to it
# by the self-ref name, so the ONLY candidate is the note itself.
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

# A second note so the wiki has a second content note.
# Deliberately does NOT link to self-ref, to isolate the self-link scenario.
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

# ---- run lint ----
OUTPUT="$("$LINT" "$WIKI" 2>&1 || true)"

# ---- assertions ----
FAIL=0

# The broken-links section header in lint-content.sh is:
# "## Broken links (wikilink target resolves to no note in the wiki)"
# Any [RED LINK] line for self-ref.md -> [[self-ref]] is the bug.
if grep -qF "[RED LINK]  self-ref.md -> [[self-ref]]" <<< "$OUTPUT"; then
  echo "FAIL: self-ref.md self-link [[self-ref]] was incorrectly reported as a broken link"
  echo "--- Full output ---"
  echo "$OUTPUT"
  FAIL=1
fi

if [ $FAIL -eq 0 ]; then
  echo "PASS: self-link [[self-ref]] correctly NOT reported as broken"
fi

exit $FAIL
