#!/usr/bin/env bash
# Tests tools/tag-to-version.sh: a release tag maps to the app version (m16.4 -> 0.16.4,
# m16 -> 0.16.0, v1.0 -> 1.0.0, v2 -> 2.0.0); any other tag, or a wrong number of arguments,
# exits 2 with a message on stderr and nothing on stdout.
#
#   bash tools/tests/tag-to-version-test.sh
#
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2

fails=0

ok() { # ok <tag> <version>: exit 0 and that version on stdout
  local out code
  out="$(bash tools/tag-to-version.sh "$1" 2> /dev/null)"
  code=$?
  if [ $code = 0 ] && [ "$out" = "$2" ]; then
    echo "PASS $1 -> $2"
  else
    echo "FAIL $1 -> $2 (exit $code, stdout '$out')"
    fails=$((fails + 1))
  fi
}

bad() { # bad <label> <args...>: exit 2, a message on stderr, nothing on stdout
  local label="$1" out err code
  shift
  out="$(bash tools/tag-to-version.sh "$@" 2> /dev/null)"
  code=$?
  err="$(bash tools/tag-to-version.sh "$@" 2>&1 > /dev/null)"
  if [ $code = 2 ] && [ -z "$out" ] && [ -n "$err" ]; then
    echo "PASS exits 2 for $label"
  else
    echo "FAIL exits 2 for $label (exit $code, stdout '$out', stderr '$err')"
    fails=$((fails + 1))
  fi
}

ok m16.4 0.16.4
ok m13.4 0.13.4
ok m16 0.16.0
ok v1.0 1.0.0
ok v2 2.0.0
bad "an empty tag" ""
bad "no argument"
bad "a bare m" m
bad "three numbers" m1.2.3
bad "a bare v" v
bad "v with three numbers" v1.2.3
bad "main" main
bad "a version without the m" 16.4
bad "an x in the number" m16.x
bad "a plus sign" m+16.4
bad "an extra argument" m16.4 extra

if [ $fails = 0 ]; then
  echo "All tag-to-version cases passed."
  exit 0
fi
echo "$fails tag-to-version case(s) failed."
exit 1
