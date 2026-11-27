#!/usr/bin/env bash
# m17 board3m g3n: the merge gate for the board line. It lists the files the branch changes against the base and
# fails a path outside the board's folders, a lib or sim file over its line limit, or a city/ file that reaches into
# night/ (only night_adapter.dart may) or into Flutter. Prints one FAIL line per finding, then RESULT.
#
#   bash tools/board-gate.sh [--root <dir>] [--base <ref>]
#   exit 0 = PASS, 1 = FAIL, 2 = bad use
set -u
root=$(cd "$(dirname "$0")/.." && pwd) || exit 2
# default_base: the milestone branch the board line merges into; --base overrides it for other branches.
default_base=m17
base=$default_base
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || { echo "usage: --root needs a directory" >&2; exit 2; }; root=$2; shift 2 ;;
    --base) [ $# -ge 2 ] || { echo "usage: --base needs a ref" >&2; exit 2; }; base=$2; shift 2 ;;
    *) echo "usage: bash tools/board-gate.sh [--root <dir>] [--base <ref>]" >&2; exit 2 ;;
  esac
done
git -C "$root" rev-parse --git-dir > /dev/null 2>&1 || { echo "not a git repo: $root" >&2; exit 2; }
mb=$(git -C "$root" merge-base "$base" HEAD 2> /dev/null) || { echo "no merge base with $base" >&2; exit 2; }
files=$(git -C "$root" diff --name-only "$mb..HEAD") || exit 2
# lib_limit_lines: the line limit for city/ and sim lib files (guidelines: about 300, hard limit 400; 380 leaves room).
# test_limit_lines: the line limit for test files (guidelines: tests 500).
lib_limit_lines=380
test_limit_lines=500
city=packages/party_host/lib/src/city
adapter=$city/night_adapter.dart
re_night='^[[:space:]]*(import|export)[[:space:]].*/night/'
re_flutter="^[[:space:]]*(import|export)[[:space:]].*package:flutter[/'\"]"
fails=0

# allowed <path>: true when the board line may change this path.
allowed() {
  case "$1" in
    packages/party_host/lib/src/city/* | packages/party_host/test/city/* | tools/sim/* | tools/tests/*) return 0 ;;
    tools/board-gate.sh | docs/*) return 0 ;;
  esac
  return 1
}
# limit_of <path>: the line limit for a .dart file the gate counts; prints nothing for any other file.
limit_of() {
  case "$1" in
    packages/party_host/test/city/*.dart | tools/sim/*_test.dart) echo "$test_limit_lines" ;;
    packages/party_host/lib/src/city/*.dart | tools/sim/*.dart) echo "$lib_limit_lines" ;;
  esac
}

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if ! allowed "$f"; then
    echo "FAIL paths $f"
    fails=$((fails + 1))
  fi
  # The gate checks what is committed: sizes and layers come from HEAD, so a deleted path has nothing to check.
  git -C "$root" cat-file -e "HEAD:$f" 2> /dev/null || continue
  limit=$(limit_of "$f")
  if [ -n "$limit" ]; then
    n=$(git -C "$root" show "HEAD:$f" | awk 'END { print NR }')
    if [ "$n" -gt "$limit" ]; then
      echo "FAIL size $f $n"
      fails=$((fails + 1))
    fi
  fi
  case "$f" in
    $city/*.dart)
      if git -C "$root" show "HEAD:$f" | grep -Eq "$re_flutter"; then
        echo "FAIL layers $f package:flutter import"
        fails=$((fails + 1))
      fi
      if [ "$f" != "$adapter" ] && git -C "$root" show "HEAD:$f" | grep -Eq "$re_night"; then
        echo "FAIL layers $f night/ import"
        fails=$((fails + 1))
      fi
      ;;
  esac
done <<< "$files"

if [ "$fails" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
fi
echo "RESULT: FAIL $fails"
exit 1
