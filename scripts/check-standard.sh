#!/usr/bin/env bash
# check-standard.sh <target-wiki-dir> [wiki-standard-repo-dir]
#
# Verifies a target wiki has the expected wiki-standard files present, and
# (when a source repo is available) reports any that have been locally
# modified relative to the source, by sha256 checksum.
#
# Source repo resolution order: second positional arg, then
# $WIKI_STANDARD_HOME, then $HOME/Projects/wiki-standard.
#
# Exit code: 0 if everything present and matching; non-zero if anything is
# missing or modified.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $(basename "$0") <target-wiki-dir> [wiki-standard-repo-dir]" >&2
  exit 1
fi

TARGET_DIR_ARG="$1"
SOURCE_DIR_ARG="${2:-${WIKI_STANDARD_HOME:-$HOME/Projects/wiki-standard}}"

if [ ! -d "$TARGET_DIR_ARG" ]; then
  echo "Error: target directory '$TARGET_DIR_ARG' does not exist." >&2
  exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR_ARG" && pwd)"

SOURCE_DIR=""
if [ -d "$SOURCE_DIR_ARG" ]; then
  SOURCE_DIR="$(cd "$SOURCE_DIR_ARG" && pwd)"
else
  echo "Warning: wiki-standard source repo '$SOURCE_DIR_ARG' not found." >&2
  echo "         Will check presence only, skipping modification checks." >&2
fi

# Relative paths (from the wiki root) expected to exist.
FILES=(
  "CLAUDE.md"
  "conventions/naming.md"
  "conventions/metadata.md"
  "conventions/linking.md"
  "conventions/editing-rules.md"
  "templates/concept.md"
  "templates/person.md"
  "templates/project.md"
  "templates/decision.md"
  "templates/meeting.md"
  "scripts/check-standard.sh"
)

checksum() {
  shasum -a 256 "$1" | awk '{print $1}'
}

echo "wiki-standard check"
echo "  target: $TARGET_DIR"
if [ -n "$SOURCE_DIR" ]; then
  echo "  source: $SOURCE_DIR"
else
  echo "  source: (none — presence-only check)"
fi
echo ""

OK_COUNT=0
MODIFIED_COUNT=0
MISSING_COUNT=0

for rel in "${FILES[@]}"; do
  target_file="${TARGET_DIR}/${rel}"

  if [ ! -f "$target_file" ]; then
    printf '[MISSING]  %s\n' "$rel"
    MISSING_COUNT=$((MISSING_COUNT + 1))
    continue
  fi

  if [ -z "$SOURCE_DIR" ]; then
    printf '[FOUND]    %s (not compared, no source repo)\n' "$rel"
    OK_COUNT=$((OK_COUNT + 1))
    continue
  fi

  source_file="${SOURCE_DIR}/${rel}"
  if [ ! -f "$source_file" ]; then
    printf '[UNKNOWN]  %s (no matching file in source repo to compare)\n' "$rel"
    continue
  fi

  target_sum="$(checksum "$target_file")"
  source_sum="$(checksum "$source_file")"

  if [ "$target_sum" = "$source_sum" ]; then
    printf '[OK]       %s\n' "$rel"
    OK_COUNT=$((OK_COUNT + 1))
  else
    printf '[MODIFIED] %s\n' "$rel"
    MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
  fi
done

# .wiki-standard-version: existence-only check (it's a per-wiki marker, not
# something with a matching source-repo copy to diff against).
version_file="${TARGET_DIR}/.wiki-standard-version"
if [ -f "$version_file" ]; then
  version_hash="$(cat "$version_file")"
  printf '[OK]       .wiki-standard-version (%s)\n' "$version_hash"
  OK_COUNT=$((OK_COUNT + 1))
else
  printf '[MISSING]  .wiki-standard-version\n'
  MISSING_COUNT=$((MISSING_COUNT + 1))
fi

echo ""
echo "Summary: ${OK_COUNT} ok, ${MODIFIED_COUNT} modified, ${MISSING_COUNT} missing."

if [ "$MISSING_COUNT" -gt 0 ] || [ "$MODIFIED_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
