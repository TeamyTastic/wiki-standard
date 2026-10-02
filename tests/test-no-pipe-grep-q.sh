#!/usr/bin/env bash
# Under `set -o pipefail`, `cmd | grep -q` can fail via SIGPIPE when grep exits
# early. Test scripts must use a here-string instead.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
if hits="$(grep -nE '\|[[:space:]]*grep -q' "$D/test-standard.sh")"; then
  echo "FAIL: pipe into grep -q in test-standard.sh:"
  echo "$hits"
  exit 1
fi
echo "PASS: no pipe-into-grep -q in test-standard.sh"
