#!/usr/bin/env bash
# test_self_links.sh — RED before fix: self-links appear in broken links report
# GREEN after fix: self-links are not reported as broken
# Tests the awk link-resolution block directly (avoids full script subprocess issues).
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/lint-content.sh"

# Extract the awk block from lint-content.sh: lines between the two sentinel
# comments that bracket the link-resolution pass.
AWK_BLOCK="$(awk '/^awk -F.*$/{f=1} f{print} /^\x27 \"\$CANDIDATES\" \"\$LINKS\"$/{f=0}' "$SCRIPT")"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/test-self-links-XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

CANDIDATES="$WORKDIR/candidates.tsv"
LINKS="$WORKDIR/links.tsv"
RESOLVED_LINKS="$WORKDIR/resolved_links.tsv"
BROKEN_LINKS="$WORKDIR/broken_links.tsv"
LINKED_RELPATHS="$WORKDIR/linked_relpaths.txt"
touch "$RESOLVED_LINKS" "$BROKEN_LINKS" "$LINKED_RELPATHS"

# foo.md links to [[Foo]] — its own basename (self-link)
printf 'foo.md\tFoo\n' >> "$CANDIDATES"
printf 'foo.md\tFoo\n' >> "$LINKS"

# Run the awk block verbatim via the resolved variables
eval "$AWK_BLOCK"

if grep -q 'foo.md' "$BROKEN_LINKS"; then
  echo "FAIL: self-link written to broken_links (should be ignored)"
  cat "$BROKEN_LINKS"
  exit 1
else
  echo "PASS: self-link not written to broken_links"
  exit 0
fi
