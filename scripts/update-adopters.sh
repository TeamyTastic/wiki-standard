#!/usr/bin/env bash
# update-adopters.sh [--dry-run] [root ...]
#
# Finds every workspace that has adopted wiki-standard (they carry a
# .wiki-standard-version marker) under the given roots, and re-runs
# install-standard.sh against each so standard updates propagate.
#
# Discovery, not a hardcoded list: a wiki adopted anywhere under the search
# roots is picked up automatically. Default root is $HOME.
#
# Workspaces that pinned standard paths via `standard_pinned` in their own
# .wiki-standard.local.json keep their customised copies — see
# conventions/ownership.md.

set -euo pipefail

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN="--dry-run"
  shift
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALLER="${SCRIPT_DIR}/install-standard.sh"

if [ ! -x "$INSTALLER" ] && [ ! -f "$INSTALLER" ]; then
  echo "Error: install-standard.sh not found next to this script." >&2
  exit 1
fi

if [ "$#" -gt 0 ]; then
  ROOTS=("$@")
else
  ROOTS=("$HOME")
fi

echo "wiki-standard source: $REPO_DIR"
echo "searching for adopters under: ${ROOTS[*]}"
echo ""

FOUND=0
FAILED=0

while IFS= read -r marker; do
  target="$(dirname "$marker")"
  # The source repo installs into others, never into itself.
  [ "$target" = "$REPO_DIR" ] && continue
  FOUND=$((FOUND + 1))
  echo "=== $target"
  if bash "$INSTALLER" ${DRY_RUN:+$DRY_RUN} "$target"; then
    :
  else
    echo "  FAILED: $target" >&2
    FAILED=$((FAILED + 1))
  fi
  echo ""
done < <(
  find "${ROOTS[@]}" \
    \( -name .git -o -name node_modules -o -name .Trash -o -name Caches \) -prune \
    -o -type f -name .wiki-standard-version -print 2>/dev/null | sort
)

echo "Adopters found: $FOUND. Failures: $FAILED."
if [ "$FOUND" -eq 0 ]; then
  echo "No .wiki-standard-version markers under the search roots — nothing to update."
fi
[ "$FAILED" -eq 0 ]
