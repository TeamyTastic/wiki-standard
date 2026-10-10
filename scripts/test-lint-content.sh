#!/usr/bin/env bash
# Regression tests for lint-content.sh
# Run: bash scripts/test-lint-content.sh
SCRIPT="$(cd "$(dirname "$0")" && pwd)/lint-content.sh"
PASS=0
FAIL=0

check() {
  local desc="$1" result="$2" expected="$3"
  if [ "$result" = "$expected" ]; then
    echo "PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "FAIL: $desc (expected='$expected' got='$result')"
    FAIL=$((FAIL+1))
  fi
}

# --- Setup temp dirs ---
TMPBASE="$(mktemp -d)"
T1="$TMPBASE/t1"
T2="$TMPBASE/t2"
T3="$TMPBASE/t3"
mkdir -p "$T1" "$T2" "$T3"
# shellcheck disable=SC2064
trap "rm -rf '$TMPBASE'" EXIT

# --- Test 1: self-link must NOT appear as a broken [RED LINK] ---
cat > "$T1/alpha.md" <<'EOF'
---
title: Alpha
type: concept
created: 2025-01-01
updated: 2025-01-01
status: active
---
This note links to [[Alpha]].
EOF
out1="$(bash "$SCRIPT" "$T1" 2>/dev/null)" || true
redlinks1="$(printf '%s' "$out1" | grep '\[RED LINK\]')" || true
count1="$(printf '%s\n' "$redlinks1" | grep -c 'Alpha')" || true
check "self-link not reported as broken" "$count1" "0"

# --- Test 2: genuinely missing link IS reported ---
cat > "$T2/beta.md" <<'EOF'
---
title: Beta
type: concept
created: 2025-01-01
updated: 2025-01-01
status: active
---
Links to [[NonExistent]].
EOF
out2="$(bash "$SCRIPT" "$T2" 2>/dev/null)" || true
count2="$(printf '%s' "$out2" | grep -c 'NonExistent')" || true
check "missing link IS reported as broken" "$count2" "1"

# --- Test 3: --stale-months non-numeric exits code 2 ---
cat > "$T3/gamma.md" <<'EOF'
---
title: Gamma
type: concept
created: 2025-01-01
updated: 2025-01-01
status: active
---
Body.
EOF
bash "$SCRIPT" "$T3" --stale-months notanumber >/dev/null 2>&1
code3=$?
check "--stale-months non-numeric exits 2" "$code3" "2"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
