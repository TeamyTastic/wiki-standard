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
grep -q 'Follow \[AGENT.md\]' "$TARGET/AGENTS.md" || fail "AGENTS.md is not a thin adapter"
grep -q 'Follow \[AGENT.md\]' "$TARGET/CLAUDE.md" || fail "CLAUDE.md is not a thin adapter"
bash "$TARGET/scripts/check-standard.sh" "$TARGET" "$REPO_DIR" >/dev/null || fail "profile check failed after install"
pass "neutral profile installs without touching content"

# A local infrastructure conflict must be backed up before replacement.
printf '%s\n' 'local agent policy' > "$TARGET/AGENT.md"
bash "$REPO_DIR/scripts/install-standard.sh" "$TARGET" >/dev/null
backup_agent="$(find "$TARGET" -path '*/.wiki-standard-backup-*/AGENT.md' -type f | head -1)"
[ -n "$backup_agent" ] || fail "conflicting AGENT.md was not backed up"
grep -q 'local agent policy' "$backup_agent" || fail "backup did not preserve the local value"
pass "conflicting infrastructure is recoverable"

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
lint_output="$(bash "$REPO_DIR/scripts/lint-content.sh" "$BUNDLE" 2>&1 || true)"
printf '%s\n' "$lint_output" | grep -q 'gamma.md -> concepts/missing.md' || fail "missing Markdown target was not reported"
printf '%s\n' "$lint_output" | grep -q 'alpha.md -> concepts/beta.md' && fail "valid Markdown target reported broken"
printf '%s\n' "$lint_output" | grep -q 'alpha.md -> Gamma' && fail "valid legacy target reported broken"
pass "linter resolves Markdown and legacy links"

# Bundle conformance is checked at an explicit content boundary.
bash "$REPO_DIR/scripts/check-okf.sh" "$BUNDLE" >/dev/null || fail "valid content bundle failed OKF minimum check"
if bash "$REPO_DIR/scripts/check-okf.sh" "$TARGET" >/dev/null 2>&1; then
  fail "workspace infrastructure was incorrectly accepted as an OKF bundle"
fi
pass "profile and OKF bundle boundaries remain separate"

echo "All tests passed."
