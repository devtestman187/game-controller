#!/usr/bin/env bash
# m17 board3b g3d1s: runs every tools/sim/*_test.dart with `dart run` and prints PASS or FAIL per file.
# Exits 1 when any file fails, and 1 when there is no such file.
#
#   bash tools/tests/sim-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 1
failed=0
count=0
for f in tools/sim/*_test.dart; do
  [ -e "$f" ] || continue
  count=$((count + 1))
  if out=$(dart run "$f" 2>&1); then
    printf '%s\n' "$out"
    echo "PASS $f"
  else
    printf '%s\n' "$out"
    echo "FAIL $f"
    failed=1
  fi
done
if [ "$count" -eq 0 ]; then
  echo "FAIL no tools/sim/*_test.dart found"
  exit 1
fi
exit "$failed"
