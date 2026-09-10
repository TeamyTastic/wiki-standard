#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

# The shell reader must expose the exact standard array from valid JSON.
python3 - "$REPO_DIR/.wiki-standard.json" > "$TEST_TMP/manifest-expected.txt" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)

assert manifest["manifest_version"] == 1
paths = manifest["ownership"]["standard"]
assert paths and len(paths) == len(set(paths))
for path in paths:
    assert isinstance(path, str) and path and not path.startswith("/")
    assert ".." not in path.split("/")
    print(path)
PY
bash "$REPO_DIR/scripts/manifest-paths.sh" \
  "$REPO_DIR/.wiki-standard.json" standard > "$TEST_TMP/manifest-actual.txt"
cmp -s "$TEST_TMP/manifest-expected.txt" "$TEST_TMP/manifest-actual.txt" || fail "shell manifest reader disagrees with JSON"
VERSION_MARKER="$(bash "$REPO_DIR/scripts/manifest-paths.sh" --scalar \
  "$REPO_DIR/.wiki-standard.json" version_marker)"
BACKUP_PATTERN="$(bash "$REPO_DIR/scripts/manifest-paths.sh" --scalar \
  "$REPO_DIR/.wiki-standard.json" backup_pattern)"
[ "$(bash "$REPO_DIR/scripts/manifest-paths.sh" --integer \
  "$REPO_DIR/.wiki-standard.json" manifest_version)" = "1" ] || fail "unsupported manifest version"
[ "$VERSION_MARKER" = ".wiki-standard-version" ] || fail "unexpected version marker declaration"
[ "$BACKUP_PATTERN" = ".wiki-standard-backup-*" ] || fail "unexpected backup pattern declaration"
pass "ownership manifest is valid and deterministic"

# Installation scope must be derived from the manifest, not a hidden shell list.
SOURCE_COPY="$TEST_TMP/source-copy"
DERIVED_TARGET="$TEST_TMP/derived-target"
mkdir -p "$SOURCE_COPY" "$DERIVED_TARGET"
cp -R "$REPO_DIR/." "$SOURCE_COPY/"
printf '%s\n' 'manifest-derived asset' > "$SOURCE_COPY/extra-standard.txt"
python3 - "$SOURCE_COPY/.wiki-standard.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)
manifest["ownership"]["standard"].append("extra-standard.txt")
with open(path, "w", encoding="utf-8") as manifest_file:
    json.dump(manifest, manifest_file, indent=2)
    manifest_file.write("\n")
PY
bash "$SOURCE_COPY/scripts/install-standard.sh" "$DERIVED_TARGET" >/dev/null
[ -f "$DERIVED_TARGET/extra-standard.txt" ] || fail "manifest-declared asset was not installed"
pass "installer scope is manifest-derived"

# Dry-run must be a true read-only preview.
TARGET="$TEST_TMP/target"
mkdir -p "$TARGET/notes"
printf '%s\n' '# Existing content' > "$TARGET/notes/existing.md"
before="$(find "$TARGET" -type f -print | sort)"
dry_output="$(bash "$REPO_DIR/scripts/install-standard.sh" --dry-run "$TARGET")"
after="$(find "$TARGET" -type f -print | sort)"
[ "$before" = "$after" ] || fail "dry-run changed the target"
printf '%s\n' "$dry_output" | grep -q 'Dry run complete. No files were changed.' || fail "dry-run did not report read-only completion"
pass "installer dry-run is read-only"

# Installation must preserve content and install the neutral canonical contract.
bash "$REPO_DIR/scripts/install-standard.sh" "$TARGET" >/dev/null
[ -f "$TARGET/notes/existing.md" ] || fail "installer removed content"
[ -f "$TARGET/AGENT.md" ] || fail "canonical AGENT.md missing"
[ -f "$TARGET/.wiki-standard.json" ] || fail "ownership manifest missing"
[ -x "$TARGET/scripts/manifest-paths.sh" ] || fail "manifest reader missing or not executable"
grep -q 'Follow \[AGENT.md\]' "$TARGET/AGENTS.md" || fail "AGENTS.md is not a thin adapter"
grep -q 'Follow \[AGENT.md\]' "$TARGET/CLAUDE.md" || fail "CLAUDE.md is not a thin adapter"
bash "$TARGET/scripts/check-standard.sh" "$TARGET" "$REPO_DIR" >/dev/null || fail "profile check failed after install"
pass "neutral profile installs without touching content"

# A local infrastructure conflict must be backed up before replacement.
printf '%s\n' 'local agent policy' > "$TARGET/AGENT.md"
bash "$REPO_DIR/scripts/install-standard.sh" "$TARGET" >/dev/null
backup_agent="$(find "$TARGET" -path "*/${BACKUP_PATTERN}/AGENT.md" -type f | head -1)"
[ -n "$backup_agent" ] || fail "conflicting AGENT.md was not backed up"
grep -q 'local agent policy' "$backup_agent" || fail "backup did not preserve the local value"
pass "conflicting infrastructure is recoverable"

# A pin below a directory item must survive, without freezing its siblings.
PIN_TARGET="$TEST_TMP/pin-target"
mkdir -p "$PIN_TARGET"
bash "$REPO_DIR/scripts/install-standard.sh" "$PIN_TARGET" >/dev/null
cat > "$PIN_TARGET/.wiki-standard.local.json" <<'EOF'
{
  "manifest_version": 1,
  "standard_pinned": [
    "conventions/ownership.md"
  ]
}
EOF
printf '%s\n' 'workspace-owned ownership rules' > "$PIN_TARGET/conventions/ownership.md"
printf '%s\n' 'stale' > "$PIN_TARGET/conventions/capture-on-demand.md"
pin_output="$(bash "$REPO_DIR/scripts/install-standard.sh" "$PIN_TARGET")"
grep -q 'workspace-owned ownership rules' "$PIN_TARGET/conventions/ownership.md" \
  || fail "installer replaced a file pinned below a directory item"
cmp -s "$REPO_DIR/conventions/capture-on-demand.md" "$PIN_TARGET/conventions/capture-on-demand.md" \
  || fail "installer skipped an unpinned sibling of a pinned file"
printf '%s\n' "$pin_output" | grep -q 'skipped (pinned by workspace): conventions/ownership.md' \
  || fail "installer did not report the descendant pin as skipped"
pass "pins below a directory item are honoured"

# A dirty standard asset must never be propagated to adopters.
SYNC_REPO="$TEST_TMP/sync-repo"
mkdir -p "$SYNC_REPO"
cp -R "$REPO_DIR/." "$SYNC_REPO/"
rm -rf "$SYNC_REPO/.git"
git -C "$SYNC_REPO" init --quiet -b main
git -C "$SYNC_REPO" config user.email test@example.com
git -C "$SYNC_REPO" config user.name "wiki-standard test"
git -C "$SYNC_REPO" add -A
git -C "$SYNC_REPO" commit --quiet -m "test baseline"
git -C "$SYNC_REPO" remote add origin "$SYNC_REPO"
mkdir -p "$TEST_TMP/no-adopters"
printf '%s\n' 'unfinished edit' >> "$SYNC_REPO/AGENT.md"
if sync_output="$(ADOPTER_ROOTS="$TEST_TMP/no-adopters" \
  bash "$SYNC_REPO/scripts/sync-personal-build.sh" 2>&1)"; then
  fail "sync propagated a dirty standard asset"
fi
printf '%s\n' "$sync_output" | grep -q 'uncommitted changes' \
  || fail "sync failed for the wrong reason: $sync_output"
pass "sync refuses to propagate uncommitted standard assets"

# Standard paths must not traverse symlinks outside the workspace.
LINK_TARGET="$TEST_TMP/link-target"
LINK_WORKSPACE="$TEST_TMP/link-workspace"
mkdir -p "$LINK_TARGET" "$LINK_WORKSPACE"
printf '%s\n' 'outside value' > "$LINK_TARGET/AGENT.md"
ln -s "$LINK_TARGET/AGENT.md" "$LINK_WORKSPACE/AGENT.md"
if bash "$REPO_DIR/scripts/install-standard.sh" "$LINK_WORKSPACE" >/dev/null 2>&1; then
  fail "installer accepted a symlinked standard path"
fi
grep -q 'outside value' "$LINK_TARGET/AGENT.md" || fail "installer changed a symlink target outside the workspace"
pass "installer refuses symlink traversal"

# Markdown and legacy links must both resolve; a missing Markdown path is reported.
BUNDLE="$TEST_TMP/bundle"
mkdir -p "$BUNDLE/concepts"
cat > "$BUNDLE/concepts/alpha.md" <<'EOF'
---
type: concept
title: Alpha
created: 2099-01-01
updated: 2099-01-01
---
[Beta](/concepts/beta.md) and [[Gamma]].
EOF
cat > "$BUNDLE/concepts/beta.md" <<'EOF'
---
type: concept
title: Beta
created: 2099-01-01
updated: 2099-01-01
---
[Alpha](alpha.md)
EOF
cat > "$BUNDLE/concepts/gamma.md" <<'EOF'
---
type: concept
title: Gamma
created: 2099-01-01
updated: 2099-01-01
---
[Missing](/concepts/missing.md)
EOF
mkdir -p "$BUNDLE/generated"
cat > "$BUNDLE/generated/derived.md" <<'EOF'
# Derived implementation output
EOF
cat > "$BUNDLE/.wiki-standard.local.json" <<'EOF'
{
  "manifest_version": 1,
  "implementation_owned": [],
  "generated": [
    "generated"
  ]
}
EOF
mkdir -p "$BUNDLE/scripts"
cp "$REPO_DIR/scripts/manifest-paths.sh" "$BUNDLE/scripts/manifest-paths.sh"
lint_output="$(bash "$REPO_DIR/scripts/lint-content.sh" "$BUNDLE" 2>&1 || true)"
printf '%s\n' "$lint_output" | grep -q 'gamma.md -> concepts/missing.md' || fail "missing Markdown target was not reported"
printf '%s\n' "$lint_output" | grep -q 'alpha.md -> concepts/beta.md' && fail "valid Markdown target reported broken"
printf '%s\n' "$lint_output" | grep -q 'alpha.md -> Gamma' && fail "valid legacy target reported broken"
printf '%s\n' "$lint_output" | grep -q 'generated/derived.md' && fail "locally generated content was linted"
pass "linter resolves Markdown and legacy links"

# Bundle conformance is checked at an explicit content boundary.
bash "$REPO_DIR/scripts/check-okf.sh" "$BUNDLE/concepts" >/dev/null || fail "valid content bundle failed OKF minimum check"
if bash "$REPO_DIR/scripts/check-okf.sh" "$TARGET" >/dev/null 2>&1; then
  fail "workspace infrastructure was incorrectly accepted as an OKF bundle"
fi
pass "profile and OKF bundle boundaries remain separate"

echo "All tests passed."
