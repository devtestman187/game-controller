#!/usr/bin/env bash
# The 8-phone load measurement: how a host copes with eight fake controllers each sending 60 inputs a second
# for 30 s (packages/connection/test/load_eight_phones_test.dart, on the in-process transport), and how big the
# worst-case night snapshot is at 4, 6 and 8 players (packages/puzzle_game/test/snapshot_eight_players_test.dart).
# It prints the two result lines:
#   8 phones: <inputs/s>, <wall ms per 1000 inputs>, max host lag <ms>
#   night frame, most pop-ups and the cat: <bytes at 4, 6, 8 players> (PuzzleSnapshot.maxBytes 2048)
# Measurements only: it changes no game rule and never touches a real device. The plain test runs (no LOAD8)
# only assert; this script sets LOAD8=1 for both.
#
#   bash tools/load8.sh          # run from anywhere; exit 0 when both runs pass
set -u

here="$(cd "$(dirname "$0")" && pwd)" || exit 3
root="$here/.."
export LOAD8=1
status=0

run() { # <package folder> <command...>: runs it there under LOAD8=1 and prints only its result lines
  local dir="$1" log rc
  shift
  log="$(mktemp)" || exit 3
  (cd "$root/$dir" && "$@") > "$log" 2>&1
  rc=$?
  grep -E '^(8 phones:|night frame)' "$log"
  if [ "$rc" != 0 ]; then
    echo "FAILED $dir (exit $rc); the last lines:"
    tail -n 20 "$log"
    status=1
  fi
  rm -f "$log"
}

run packages/connection dart test test/load_eight_phones_test.dart
run packages/puzzle_game flutter test test/snapshot_eight_players_test.dart
exit "$status"
