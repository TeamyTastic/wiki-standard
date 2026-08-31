#!/usr/bin/env bash
# check-standard.sh <target-wiki-dir> [wiki-standard-repo-dir]
#
# Verifies a target workspace has the expected wiki-standard profile files, and
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

if [ -n "$SOURCE_DIR" ]; then
  CONTROL_DIR="$SOURCE_DIR"
else
  CONTROL_DIR="$TARGET_DIR"
fi

MANIFEST="${CONTROL_DIR}/.wiki-standard.json"
MANIFEST_READER="${CONTROL_DIR}/scripts/manifest-paths.sh"
if [ ! -f "$MANIFEST" ] || [ ! -f "$MANIFEST_READER" ]; then
  echo "Error: ownership manifest or reader is missing from '$CONTROL_DIR'." >&2
  exit 1
fi

# shellcheck source=manifest-paths.sh
source "$MANIFEST_READER"

if [ "$(wiki_standard_manifest_integer "$MANIFEST" manifest_version 2>/dev/null || true)" != "1" ]; then
  echo "Error: unsupported or malformed ownership manifest version." >&2
  exit 1
fi

FILES=()
if ! MANIFEST_ITEMS="$(wiki_standard_manifest_array "$MANIFEST" standard)"; then
  echo "Error: ownership.standard is missing or malformed." >&2
  exit 1
fi
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  if ! wiki_standard_validate_relative_path "$rel"; then
    echo "Error: unsafe standard path in manifest: '$rel'." >&2
    exit 1
  fi
  FILES[${#FILES[@]}]="$rel"
done <<< "$MANIFEST_ITEMS"

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "Error: ownership.standard is empty or unreadable." >&2
  exit 1
fi

if ! VERSION_MARKER_REL="$(wiki_standard_manifest_scalar "$MANIFEST" version_marker)" || \
   ! wiki_standard_validate_relative_path "$VERSION_MARKER_REL"; then
  echo "Error: ownership.generated.version_marker is missing or unsafe." >&2
  exit 1
fi

checksum() {
  shasum -a 256 "$1" | awk '{print $1}'
}

echo "wiki-standard profile infrastructure check"
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

  if [ -L "$target_file" ]; then
    printf '[SYMLINK]  %s (profile infrastructure must be local)\n' "$rel"
    MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    continue
  fi

  if [ ! -e "$target_file" ]; then
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
  if [ ! -e "$source_file" ]; then
    printf '[UNKNOWN]  %s (no matching file in source repo to compare)\n' "$rel"
    continue
  fi

  if [ -d "$source_file" ]; then
    if [ ! -d "$target_file" ]; then
      printf '[MODIFIED] %s (expected directory)\n' "$rel"
      MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    elif diff -rq "$source_file" "$target_file" >/dev/null 2>&1; then
      printf '[OK]       %s/\n' "$rel"
      OK_COUNT=$((OK_COUNT + 1))
    else
      printf '[MODIFIED] %s/\n' "$rel"
      MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    fi
  else
    if [ ! -f "$target_file" ]; then
      printf '[MODIFIED] %s (expected file)\n' "$rel"
      MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    else
      target_sum="$(checksum "$target_file")"
      source_sum="$(checksum "$source_file")"
      if [ "$target_sum" = "$source_sum" ]; then
        printf '[OK]       %s\n' "$rel"
        OK_COUNT=$((OK_COUNT + 1))
      else
        printf '[MODIFIED] %s\n' "$rel"
        MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
      fi
    fi
  fi
done

# .wiki-standard-version: existence-only check (it's a per-wiki marker, not
# something with a matching source-repo copy to diff against).
version_file="${TARGET_DIR}/${VERSION_MARKER_REL}"
if [ -L "$version_file" ]; then
  printf '[SYMLINK]  %s (generated state must be local)\n' "$VERSION_MARKER_REL"
  MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
elif [ -f "$version_file" ]; then
  version_hash="$(cat "$version_file")"
  printf '[OK]       %s (%s)\n' "$VERSION_MARKER_REL" "$version_hash"
  OK_COUNT=$((OK_COUNT + 1))
else
  printf '[MISSING]  %s\n' "$VERSION_MARKER_REL"
  MISSING_COUNT=$((MISSING_COUNT + 1))
fi

echo ""
echo "Summary: ${OK_COUNT} ok, ${MODIFIED_COUNT} modified, ${MISSING_COUNT} missing."

if [ "$MISSING_COUNT" -gt 0 ] || [ "$MODIFIED_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
