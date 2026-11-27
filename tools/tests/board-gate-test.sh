#!/usr/bin/env bash
# m17 board3m g3n: tests tools/board-gate.sh on throw-away git repos (a base branch, then one change commit).
# Allowed paths pass; a path outside the board's folders fails; lib files over their line limit fail; city/ files
# may not import night/ (night_adapter.dart may) or Flutter; bad arguments exit 2.
#
#   bash tools/tests/board-gate-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/board-gate-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0 cases=0 r="" out="" code=0
git_t() { git -c user.name=gate-test -c user.email=gate-test@example.invalid "$@"; }
# new_repo <name>: a repo whose base branch is its first commit; HEAD is that commit until change() runs.
new_repo() {
  r="$tmp/$1"
  git init -q "$r" || exit 2
  git_t -C "$r" commit -q --allow-empty -m base || exit 2
  git -C "$r" branch base || exit 2
}
# put <path> <text>: writes a file in the test repo, one trailing newline added.
put() { mkdir -p "$r/$(dirname "$1")" && printf '%s\n' "$2" > "$r/$1"; }
# lines <n>: n lines of text.
lines() { local i; for ((i = 1; i <= $1; i++)); do echo "// line $i"; done; }
# change: commits everything in the test repo as the branch's change.
change() { git -C "$r" add . && git_t -C "$r" commit -q -m change; }
# gate <args...>: runs the gate and keeps its output and exit code.
gate() { out=$(bash tools/board-gate.sh "$@" 2>&1); code=$?; }
# expect <name> <exit code> <text that must appear, or ->: prints PASS or FAIL for one case.
expect() {
  local ok=1
  cases=$((cases + 1))
  [ "$code" = "$2" ] || ok=0
  if [ "$3" != - ] && ! printf '%s\n' "$out" | grep -qF -- "$3"; then ok=0; fi
  if [ $ok = 1 ]; then
    echo "PASS $1"
  else
    echo "FAIL $1 (exit $code, want $2)"
    printf '%s\n' "$out" | sed 's/^/    | /'
    fails=$((fails + 1))
  fi
}
city=packages/party_host/lib/src/city

new_repo clean
put "$city/rules.dart" "int x = 1;"
put packages/party_host/test/city/rules_test.dart "void main() {}"
put tools/sim/sim_x.dart "void main() {}"
put tools/tests/x-test.sh "exit 0"
put docs/notes.md "notes"
change
gate --root "$r" --base base
expect "clean change in the board folders passes" 0 "RESULT: PASS"

new_repo outside-app
put controller_app/lib/a.dart "int a = 1;"
change
gate --root "$r" --base base
expect "a controller_app path fails and is named" 1 "FAIL paths controller_app/lib/a.dart"

new_repo outside-night
put packages/party_host/lib/src/night/x.dart "int x = 1;"
change
gate --root "$r" --base base
expect "a night/ path fails and is named" 1 "FAIL paths packages/party_host/lib/src/night/x.dart"

new_repo size-over
put "$city/big.dart" "$(lines 381)"
change
gate --root "$r" --base base
expect "a city/ lib file of 381 lines fails with its count" 1 "FAIL size $city/big.dart 381"

new_repo size-edge
put "$city/edge.dart" "$(lines 380)"
change
gate --root "$r" --base base
expect "a city/ lib file of 380 lines passes" 0 "RESULT: PASS"

new_repo test-over
put packages/party_host/test/city/big_test.dart "$(lines 501)"
change
gate --root "$r" --base base
expect "a city/ test file of 501 lines fails with its count" 1 "FAIL size packages/party_host/test/city/big_test.dart 501"

new_repo night-import
put "$city/rules.dart" "import 'package:party_host/src/night/x.dart';"
change
gate --root "$r" --base base
expect "a city/ file importing night/ fails" 1 "FAIL layers $city/rules.dart"

new_repo adapter-import
put "$city/night_adapter.dart" "import 'package:party_host/src/night/x.dart';"
change
gate --root "$r" --base base
expect "night_adapter.dart importing night/ passes" 0 "RESULT: PASS"

new_repo flutter-import
put "$city/view.dart" "import 'package:flutter/material.dart';"
change
gate --root "$r" --base base
expect "a city/ file importing package:flutter fails" 1 "FAIL layers $city/view.dart"

new_repo args
gate --bogus
expect "an unknown option exits 2" 2 -
gate --root
expect "--root without a value exits 2" 2 -
gate --root "$tmp/none" --base base
expect "a root that is not a git repo exits 2" 2 -

echo "cases $cases failed $fails"
[ "$fails" -eq 0 ] || exit 1
