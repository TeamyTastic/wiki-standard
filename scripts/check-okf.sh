#!/usr/bin/env bash
# check-okf.sh <bundle-root>
#
# Deterministic, read-only check of the minimum OKF v0.2 document contract.
# This intentionally validates an explicit bundle boundary, not the surrounding
# wiki-standard workspace profile.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $(basename "$0") <bundle-root>" >&2
  exit 1
fi

if [ ! -d "$1" ]; then
  echo "Error: bundle root '$1' does not exist." >&2
  exit 1
fi

BUNDLE_ROOT="$(cd "$1" && pwd)"
CHECKED=0
FAILED=0

echo "OKF v0.2 minimum check"
echo "  bundle: $BUNDLE_ROOT"
echo ""

while IFS= read -r -d '' file; do
  rel="${file#"$BUNDLE_ROOT"/}"

  # OKF reserves these two names only at the bundle root.
  case "$rel" in
    index.md|log.md) continue ;;
  esac

  CHECKED=$((CHECKED + 1))

  if [ "$(sed -n '1p' "$file")" != "---" ]; then
    printf '[INVALID] %s (missing YAML frontmatter)\n' "$rel"
    FAILED=$((FAILED + 1))
    continue
  fi

  type_value="$(awk '
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit }
    /^type:[[:space:]]*/ {
      sub(/^type:[[:space:]]*/, "")
      gsub(/^[[:space:]"'\''`]+|[[:space:]"'\''`]+$/, "")
      print
      exit
    }
  ' "$file")"

  if [ -z "$type_value" ]; then
    printf '[INVALID] %s (missing non-empty type)\n' "$rel"
    FAILED=$((FAILED + 1))
  else
    printf '[OK]      %s (type: %s)\n' "$rel" "$type_value"
  fi
done < <(find "$BUNDLE_ROOT" -type f -name '*.md' -print0)

echo ""
echo "Document summary: ${CHECKED} checked, ${FAILED} invalid."

if [ "$FAILED" -gt 0 ]; then
  echo "Bundle result: invalid minimum OKF document set."
  exit 1
fi

echo "Bundle result: valid minimum OKF document set."
