#!/usr/bin/env bash
# sync-personal-build.sh — keep this wiki-standard clone current with upstream
# and re-install it into every workspace that has adopted it.
#
# Mapping onto the personalize-software SYNC loop:
#   upstream source  -> origin/main of this repo
#   "the build"      -> the profile assets declared in .wiki-standard.json
#   "installed copy" -> each adopting workspace (found by .wiki-standard-version)
#   local divergence -> each workspace's `standard_pinned` paths, preserved
#
# Never installs on a failed verify. Quiet when nothing changed.
set -euo pipefail

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-origin}"
BRANCH="${BRANCH:-main}"
# Search roots for adopting workspaces. Deliberately not $HOME — that also
# sweeps up archived/scratchpad copies of old wikis.
ADOPTER_ROOTS="${ADOPTER_ROOTS:-$HOME/Library/Mobile Documents:$HOME/Projects}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_DIR"

say() { printf 'SYNC: %s\n' "$*"; }
die() { printf 'SYNC ERROR: %s\n' "$*" >&2; exit 1; }

[ -e .git ] || die "not a git repository: $REPO_DIR"

BASE_HEAD="$(git rev-parse HEAD)"
CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)"

# --- never propagate an unfinished edit -----------------------------------
# install-standard.sh copies from the working tree, but the version marker it
# writes records HEAD. A dirty standard asset would be installed into every
# adopter while every adopter claimed to be at an unmodified commit.
# shellcheck source=manifest-paths.sh
source "${SCRIPT_DIR}/manifest-paths.sh"
MANIFEST_ITEMS="$(wiki_standard_manifest_array "${REPO_DIR}/.wiki-standard.json" standard)" \
  || die "cannot read ownership.standard from .wiki-standard.json"
STANDARD_PATHS=()
while IFS= read -r item; do
  [ -z "$item" ] && continue
  STANDARD_PATHS[${#STANDARD_PATHS[@]}]="$item"
done <<< "$MANIFEST_ITEMS"
[ "${#STANDARD_PATHS[@]}" -gt 0 ] || die "ownership.standard is empty"

DIRTY_STANDARD="$(git status --porcelain -- "${STANDARD_PATHS[@]}")"
if [ -n "$DIRTY_STANDARD" ]; then
  printf '%s\n' "$DIRTY_STANDARD" >&2
  die "standard assets have uncommitted changes — commit or stash them before propagating"
fi

# --- fetch upstream -------------------------------------------------------
git fetch --tags --quiet "$UPSTREAM_REMOTE" || die "failed to fetch $UPSTREAM_REMOTE"
REMOTE_CANON="${UPSTREAM_REMOTE}/${BRANCH}"
git rev-parse --verify --quiet "$REMOTE_CANON" >/dev/null || die "no ref $REMOTE_CANON"

# --- take upstream, without ever discarding local work --------------------
# Unlike a personal tool fork, local divergence here lives in the ADOPTING
# workspaces (standard_pinned), not in this clone. So this clone should track
# upstream cleanly. Anything unmerged locally is a human's in-flight work:
# report it and still propagate what is already committed here, rather than
# rebasing someone's branch out from under them.
if [ -n "$(git status --porcelain)" ]; then
  say "working tree dirty — skipped upstream merge, propagating current HEAD"
elif [ "$CURRENT_BRANCH" = "$BRANCH" ]; then
  if ! git merge --ff-only --quiet "$REMOTE_CANON" 2>/dev/null; then
    say "cannot fast-forward $BRANCH to $REMOTE_CANON (local commits ahead, or diverged)"
    say "  -> propagating local HEAD; merge or push $BRANCH to clear this"
  fi
else
  say "on branch '$CURRENT_BRANCH', not '$BRANCH' — propagating this branch, not upstream"
fi

HEAD_NOW="$(git rev-parse HEAD)"

# --- verify before installing anything ------------------------------------
for s in scripts/*.sh; do
  bash -n "$s" || die "syntax error in $s — nothing installed"
done
# Smoke test: a dry-run install into a scratch dir exercises the manifest,
# the path validation, and the installer end to end. (check-standard.sh is
# not the right check here — the source repo has no version marker by design.)
SMOKE_DIR="$(mktemp -d)"
if ! bash scripts/install-standard.sh --dry-run "$SMOKE_DIR" >/dev/null 2>&1; then
  rm -rf "$SMOKE_DIR"
  die "dry-run install failed — nothing installed"
fi
rm -rf "$SMOKE_DIR"

# --- install into every adopter ------------------------------------------
OLD_IFS="$IFS"; IFS=':'; read -r -a ROOTS <<< "$ADOPTER_ROOTS"; IFS="$OLD_IFS"
EXISTING=()
for r in "${ROOTS[@]}"; do
  if [ -d "$r" ]; then
    EXISTING[${#EXISTING[@]}]="$r"
  fi
done
[ "${#EXISTING[@]}" -gt 0 ] || die "no adopter search roots exist: $ADOPTER_ROOTS"

if ! OUT="$(bash "${SCRIPT_DIR}/update-adopters.sh" "${EXISTING[@]}" 2>&1)"; then
  printf '%s\n' "$OUT" >&2
  die "one or more adopters failed to update"
fi

# awk, not `grep -c`: grep exits 1 on zero matches, which set -e would treat
# as a failure of the whole sync.
CHANGED="$(printf '%s\n' "$OUT" | awk '/^  installed: /{n++} END{print n+0}')"
FOUND="$(printf '%s\n' "$OUT" | sed -n 's/^Adopters found: \([0-9]*\).*/\1/p')"

if [ "$HEAD_NOW" = "$BASE_HEAD" ] && [ "$CHANGED" = "0" ]; then
  exit 0   # nothing upstream, nothing drifted — stay silent
fi

say "standard at $(git rev-parse --short HEAD); ${FOUND:-0} adopters, ${CHANGED} files installed"
printf '%s\n' "$OUT" | awk '/^===/ || /skipped \(pinned/ || /backed up:/'
