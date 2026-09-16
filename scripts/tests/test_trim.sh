#!/usr/bin/env bash
# test_trim.sh — RED before fix: trim() doesn't remove trailing whitespace
# GREEN after fix: both leading and trailing whitespace are stripped
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/lint-content.sh"

# Extract the trim() function from the real script and evaluate it
eval "$(awk '/^trim\(\) *\{/{f=1} f{print} f && /^\} *$/{f=0}' "$SCRIPT")"

fail=0

check() {
  local input="$1" expected="$2" label="$3"
  local result
  result=$(trim "$input")
  if [ "$result" = "$expected" ]; then
    echo "  PASS: $label"
  else
    echo "  FAIL: $label — got '$result', expected '$expected'"
    fail=1
  fi
}

check "  hello  " "hello" "leading+trailing whitespace"
check "hello  "  "hello" "trailing whitespace only"
check "  hello"  "hello" "leading whitespace only"
check "hello"    "hello" "no whitespace"
check ""         ""      "empty string"

exit "$fail"
