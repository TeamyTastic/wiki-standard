#!/usr/bin/env bash
# install-standard.sh [--dry-run] <target-wiki-dir>
#
# Installs the wiki-standard profile, neutral agent contract, compatibility
# adapters, conventions, templates, and deterministic checks into a target
# knowledge directory.
#
# - Copies ONLY the standard assets declared by `.wiki-standard.json`. Never
#   touches any other file or folder in the target wiki.
# - Idempotent: safe to re-run. If the target already has a conflicting
#   local copy of standard infrastructure (i.e. it differs from what's about
#   to be installed), the existing copy is backed up first rather than
#   silently overwritten.
# - Writes/updates .wiki-standard-version in the target with this repo's
#   current commit hash, or "unknown" when this is an installed copy without
#   Git metadata of its own.
#
# macOS/BSD-safe: no GNU-only flags, all paths quoted.

set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $(basename "$0") [--dry-run] <target-wiki-dir>" >&2
  exit 1
fi

TARGET_DIR_ARG="$1"

# Resolve this repo's root (parent of the scripts/ dir this file lives in),
# so the script works correctly whether run from the source repo or from a
# copy that was itself installed into a target wiki.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${REPO_DIR}/.wiki-standard.json"
MANIFEST_READER="${REPO_DIR}/scripts/manifest-paths.sh"

if [ ! -f "$MANIFEST" ] || [ ! -f "$MANIFEST_READER" ]; then
  echo "Error: wiki-standard ownership manifest or reader is missing." >&2
  exit 1
fi

# shellcheck source=manifest-paths.sh
source "$MANIFEST_READER"

if [ "$(wiki_standard_manifest_integer "$MANIFEST" manifest_version 2>/dev/null || true)" != "1" ]; then
  echo "Error: unsupported or malformed ownership manifest version." >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR_ARG" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Error: dry-run target '$TARGET_DIR_ARG' must already exist." >&2
    exit 1
  fi
  echo "Target directory '$TARGET_DIR_ARG' does not exist — creating it."
  mkdir -p "$TARGET_DIR_ARG"
fi

TARGET_DIR="$(cd "$TARGET_DIR_ARG" && pwd)"

if [ "$TARGET_DIR" = "$REPO_DIR" ]; then
  echo "Error: target directory is the wiki-standard repo itself. Refusing to install onto itself." >&2
  exit 1
fi

echo "wiki-standard source: $REPO_DIR"
echo "install target:       $TARGET_DIR"
echo ""

# A workspace may pin standard paths it has deliberately customised, via
# `standard_pinned` in its own .wiki-standard.local.json. Pinned paths are
# skipped by the installer instead of being backed up and replaced. This
# narrows installer authority; it can never expand it.
PINNED=()
LOCAL_MANIFEST="${TARGET_DIR}/.wiki-standard.local.json"
if [ -f "$LOCAL_MANIFEST" ] && [ ! -L "$LOCAL_MANIFEST" ]; then
  if LOCAL_PINNED="$(wiki_standard_manifest_array "$LOCAL_MANIFEST" standard_pinned 2>/dev/null)"; then
    while IFS= read -r pinned; do
      [ -z "$pinned" ] && continue
      if ! wiki_standard_validate_relative_path "$pinned"; then
        echo "Error: unsafe standard_pinned path in local manifest: '$pinned'." >&2
        exit 1
      fi
      PINNED[${#PINNED[@]}]="$pinned"
    done <<< "$LOCAL_PINNED"
  fi
fi

is_pinned() {
  local candidate="$1" pinned
  for pinned in ${PINNED+"${PINNED[@]}"}; do
    if [ "$candidate" = "$pinned" ]; then
      return 0
    fi
  done
  return 1
}

# Relative paths (from REPO_DIR) installed into the same target paths.
# This array is derived from the manifest rather than maintained separately.
ITEMS=()
if ! MANIFEST_ITEMS="$(wiki_standard_manifest_array "$MANIFEST" standard)"; then
  echo "Error: ownership.standard is missing or malformed." >&2
  exit 1
fi
while IFS= read -r item; do
  [ -z "$item" ] && continue
  if ! wiki_standard_validate_relative_path "$item"; then
    echo "Error: unsafe standard path in manifest: '$item'." >&2
    exit 1
  fi
  if [ ! -e "${REPO_DIR}/${item}" ]; then
    echo "Error: declared standard asset is missing from source: '$item'." >&2
    exit 1
  fi
  ITEMS[${#ITEMS[@]}]="$item"
done <<< "$MANIFEST_ITEMS"

if [ "${#ITEMS[@]}" -eq 0 ]; then
  echo "Error: ownership.standard is empty or unreadable." >&2
  exit 1
fi

if ! VERSION_MARKER_REL="$(wiki_standard_manifest_scalar "$MANIFEST" version_marker)" || \
   ! wiki_standard_validate_relative_path "$VERSION_MARKER_REL"; then
  echo "Error: ownership.generated.version_marker is missing or unsafe." >&2
  exit 1
fi
if ! BACKUP_PATTERN="$(wiki_standard_manifest_scalar "$MANIFEST" backup_pattern)"; then
  echo "Error: ownership.generated.backup_pattern is missing or malformed." >&2
  exit 1
fi
case "$BACKUP_PATTERN" in
  *\*) BACKUP_PREFIX="${BACKUP_PATTERN%\*}" ;;
  *) echo "Error: backup_pattern must end in '*'." >&2; exit 1 ;;
esac
if ! wiki_standard_validate_relative_path "$BACKUP_PREFIX"; then
  echo "Error: ownership.generated.backup_pattern is unsafe." >&2
  exit 1
fi

assert_no_symlink_components() {
  local rel_path="$1"
  local current="$TARGET_DIR"
  local part
  local old_ifs="$IFS"

  IFS='/'
  for part in $rel_path; do
    current="${current}/${part}"
    if [ -L "$current" ]; then
      echo "Error: standard path '${rel_path}' traverses symlink '${current}'." >&2
      echo "Resolve that path explicitly before installing." >&2
      IFS="$old_ifs"
      return 1
    fi
  done
  IFS="$old_ifs"
}

# Refuse rather than follow links that could escape the declared target.
for item in "${ITEMS[@]}"; do
  assert_no_symlink_components "$item"
done
assert_no_symlink_components "$VERSION_MARKER_REL"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR=""
UNCHANGED=0

ensure_backup_dir() {
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="${TARGET_DIR}/${BACKUP_PREFIX}${TIMESTAMP}"
    if [ -L "$BACKUP_DIR" ]; then
      echo "Error: generated backup path is a symlink: '$BACKUP_DIR'." >&2
      exit 1
    fi
    mkdir -p "$BACKUP_DIR"
    echo "Local differences detected — backing up conflicting files to:"
    echo "  $BACKUP_DIR"
  fi
}

# Returns 0 (true) if src and dst differ. Callers must guard against a missing
# dst before calling this function — it may return 0 for missing dst too.
paths_differ() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ]; then
    return 0
  fi

  if [ -d "$src" ]; then
    if [ ! -d "$dst" ]; then
      return 0
    fi
    if diff -rq "$src" "$dst" >/dev/null 2>&1; then
      return 1
    else
      return 0
    fi
  else
    if [ -d "$dst" ]; then
      return 0
    fi
    if cmp -s "$src" "$dst"; then
      return 1
    else
      return 0
    fi
  fi
}

backup_if_conflicting() {
  local rel_path="$1"
  local src="${REPO_DIR}/${rel_path}"
  local dst="${TARGET_DIR}/${rel_path}"

  if [ ! -e "$dst" ]; then
    return 0
  fi

  if paths_differ "$src" "$dst"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  would back up conflict: ${rel_path}"
      return 0
    fi
    ensure_backup_dir
    local backup_target="${BACKUP_DIR}/${rel_path}"
    mkdir -p "$(dirname "$backup_target")"
    cp -R "$dst" "$backup_target"
    echo "  backed up: ${rel_path}"
  fi
}

install_item() {
  local rel_path="$1"
  local src="${REPO_DIR}/${rel_path}"
  local dst="${TARGET_DIR}/${rel_path}"

  # Already byte-identical: a re-run must be a genuine no-op, so that a
  # scheduled sync stays silent when there is nothing to propagate.
  if [ -e "$dst" ] && ! paths_differ "$src" "$dst"; then
    UNCHANGED=$((UNCHANGED + 1))
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  would install: ${rel_path}"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"

  if [ -d "$src" ]; then
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -R "$src/." "$dst/"
  else
    cp "$src" "$dst"
  fi

  if [[ "$rel_path" == *.sh ]]; then
    chmod +x "$dst"
  fi

  echo "  installed: ${rel_path}"
}

echo "Checking for local conflicts..."
for item in "${ITEMS[@]}"; do
  is_pinned "$item" && continue
  backup_if_conflicting "$item"
done
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Previewing wiki-standard assets..."
else
  echo "Installing wiki-standard assets..."
fi
for item in "${ITEMS[@]}"; do
  if is_pinned "$item"; then
    echo "  skipped (pinned by workspace): ${item}"
    continue
  fi
  install_item "$item"
done
if [ "$UNCHANGED" -gt 0 ]; then
  echo "  already current: ${UNCHANGED} path(s)"
fi
echo ""

COMMIT_HASH="unknown"
if [ -e "$REPO_DIR/.git" ] && \
   RESOLVED_COMMIT_HASH="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)"; then
  COMMIT_HASH="$RESOLVED_COMMIT_HASH"
fi
if [ "$DRY_RUN" -eq 1 ]; then
  echo "  would write: ${VERSION_MARKER_REL} -> ${COMMIT_HASH}"
else
  echo "$COMMIT_HASH" > "${TARGET_DIR}/${VERSION_MARKER_REL}"
  echo "Version marker written: ${TARGET_DIR}/${VERSION_MARKER_REL} -> ${COMMIT_HASH}"
fi
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete. No files were changed."
else
  echo "Done. wiki-standard installed at commit ${COMMIT_HASH}."
fi
if [ -n "$BACKUP_DIR" ]; then
  echo "Prior local files were preserved at: $BACKUP_DIR"
fi
echo ""
echo "Only ownership.standard paths from .wiki-standard.json and the generated"
echo "version marker declared there were touched in the target workspace."
