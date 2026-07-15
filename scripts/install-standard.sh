#!/usr/bin/env bash
# install-standard.sh <target-wiki-dir>
#
# Installs the wiki-standard shared assets (CLAUDE.md, conventions/,
# templates/, scripts/check-standard.sh, scripts/lint-content.sh) into a
# target wiki directory.
#
# - Copies ONLY the standard assets listed in ITEMS below. Never touches any
#   other file or folder in the target wiki.
# - Idempotent: safe to re-run. If the target already has a conflicting
#   local copy of CLAUDE.md or templates/ (i.e. it differs from what's about
#   to be installed), the existing copy is backed up first rather than
#   silently overwritten.
# - Writes/updates .wiki-standard-version in the target with this repo's
#   current commit hash.
#
# macOS/BSD-safe: no GNU-only flags, all paths quoted.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $(basename "$0") <target-wiki-dir>" >&2
  exit 1
fi

TARGET_DIR_ARG="$1"

# Resolve this repo's root (parent of the scripts/ dir this file lives in),
# so the script works correctly whether run from the source repo or from a
# copy that was itself installed into a target wiki.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ ! -d "$TARGET_DIR_ARG" ]; then
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

# Relative paths (from REPO_DIR) to install into the same relative path under TARGET_DIR.
ITEMS=(
  "CLAUDE.md"
  "conventions"
  "templates"
  "scripts/check-standard.sh"
  "scripts/lint-content.sh"
)

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR=""

ensure_backup_dir() {
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="${TARGET_DIR}/.wiki-standard-backup-${TIMESTAMP}"
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
  backup_if_conflicting "$item"
done
echo ""

echo "Installing wiki-standard assets..."
for item in "${ITEMS[@]}"; do
  install_item "$item"
done
echo ""

if COMMIT_HASH="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)"; then
  echo "$COMMIT_HASH" > "${TARGET_DIR}/.wiki-standard-version"
  echo "Version marker written: ${TARGET_DIR}/.wiki-standard-version -> ${COMMIT_HASH}"
else
  echo "Warning: $REPO_DIR is not a git repository — version marker not written."
  COMMIT_HASH="(unknown)"
fi
echo ""

echo "Done. wiki-standard installed at commit ${COMMIT_HASH}."
if [ -n "$BACKUP_DIR" ]; then
  echo "Prior local files were preserved at: $BACKUP_DIR"
fi
echo ""
echo "Nothing outside of CLAUDE.md, conventions/, templates/,"
echo "scripts/check-standard.sh, and scripts/lint-content.sh was touched"
echo "in the target wiki."
