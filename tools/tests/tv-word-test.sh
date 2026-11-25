#!/usr/bin/env bash
# Tests tools/tv-word-check.sh (owner decision 7, APP-START.md): a bare whole word TV in
# user-visible Dart text is a hit and is named; the allowed names, comment lines and the
# allowed non-text spellings pass; a missing folder is exit 2. The last case runs the
# check on the real repo, where it must pass: that is the guard.
#
#   bash tools/tests/tv-word-test.sh
#
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
real="$(pwd)"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/tvword-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
check="$real/tools/tv-word-check.sh"

fails=0
cases=0
n=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# expect <case> <want> <got>: passes when the output (or exit code) is exactly <want>.
expect() {
  cases=$((cases + 1))
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1"
    printf '    want: [%s]\n    got:  [%s]\n' "$2" "$3"
  fi
}

# verdict <case> <want exit> <want output> <relative file> <dart line>: writes the line into
# a new tree at that file, runs the check on the tree, and compares the exit code and output.
verdict() {
  local tree out rc
  n=$((n + 1))
  tree="$tmp/tree-$n"
  mkdir -p "$tree/controller_app/lib" "$tree/$(dirname "$4")" || exit 2
  printf '%s\n' "$5" > "$tree/$4"
  out="$(bash "$check" "$tree" 2>&1)"
  rc=$?
  expect "$1: exit" "$2" "$rc"
  expect "$1: output" "$3" "$out"
}

screen=controller_app/lib/screen.dart
phone=packages/party_host/lib/src/text/phone_text.dart

verdict "a bare TV in a label is a hit and is named" 1 \
  "controller_app/lib/screen.dart:1: title: 'Connect to a TV'," "$screen" "  title: 'Connect to a TV',"
verdict "a TV's possessive is a hit" 1 \
  "controller_app/lib/screen.dart:1: body: \"the TV's game events\"," "$screen" "  body: \"the TV's game events\","
verdict "the allowed name Thumb Party TV passes" 0 "" "$screen" "  title: 'Thumb Party TV',"
verdict "the allowed name Android TV passes" 0 "" "$screen" "  hostName: 'Android TV',"
verdict "the allowed name Google TV passes" 0 "" "$screen" "  label: 'Google TV',"
verdict "an allowed name does not hide a bare TV in the same line" 1 \
  "controller_app/lib/screen.dart:1: body: 'Thumb Party TV and the TV'," "$screen" \
  "  body: 'Thumb Party TV and the TV',"
verdict "a // comment is skipped" 0 "" "$screen" "  // the TV keeps its own game"
verdict "a /// doc comment is skipped" 0 "" "$screen" "/// Sent to the TV and shown in Diagnostics."
verdict "an indented // comment with a CR line end is skipped" 0 "" "$screen" "    // Back to the TV client"$'\r'
verdict "the allowed switch key 'tv' => kindTv passes" 0 "" "$phone" "    'tv' => kindTv,"
verdict "the allowed identifier static const tv = 'tv' passes" 0 "" \
  "packages/party_host/lib/src/host_identity.dart" "  static const tv = 'tv';"
out="$(bash "$check" "$tmp/empty" 2>&1)"
rc=$?
expect "a root with no controller_app/lib is exit 2" 2 "$rc"

# The real repo: no hit, exit 0. The guard.
out="$(bash "$check" "$real" 2>&1)"
rc=$?
expect "the real repo: exit" 0 "$rc"
expect "the real repo: no hit lines" "" "$out"

echo "RESULT: $((cases - fails))/$cases cases passed"
[ "$fails" -eq 0 ]
