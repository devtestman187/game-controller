#!/usr/bin/env bash
# Tests tools/brief-check-rules.sh through tools/brief-check.sh: a do: line that shrinks layout
# (FittedBox, scale-down, smaller font) FAILs unless the brief names a 48 dp touch-target test or
# carries `touch-target: exempt <reason>`; model: must be haiku or sonnet and sonnet needs turns:.
#   bash tools/tests/brief-check-rules-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/brief-check-rules-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0
out="$tmp/out.txt"
batch="$tmp/batch"
case_() { # case_ <name> <rc wanted> <text wanted or ""> <brief lines...>
  local name=$1 want=$2 text=$3 rc=0
  shift 3
  rm -rf "$batch"; mkdir -p "$batch"; echo j > "$batch/waves.txt"
  printf '%s\n' "job: j" "allow: a/b.dart" "$@" > "$batch/j.md"
  BRIEF_CHECK_ROOT="$tmp" BRIEF_CHECK_REF= bash tools/brief-check.sh "$batch" > "$out" 2>&1 || rc=$?
  if [ "$rc" = "$want" ] && { [ -z "$text" ] || grep -qF -- "$text" "$out"; }; then echo "PASS $name"; else echo "FAIL $name (rc $rc)"; sed 's/^/    | /' "$out"; fails=$((fails + 1)); fi
}
case_ shrink-fails 1 'FAIL shrink j' '1 Wrap the title in a FittedBox so it scales down'
case_ shrink-smaller-font 1 'FAIL shrink j' '1 Use a smaller font size on narrow phones'
case_ shrink-with-48dp-test 0 '' '1 Wrap the title in a FittedBox' '2 Tests: the 48 dp touch-target test of every button'
case_ shrink-exempt 0 '' 'touch-target: exempt no tappable child' '1 Shrink the banner'
case_ no-shrink 0 '' '1 Add a field'
case_ model-sonnet-no-turns 1 'FAIL model j' 'model: sonnet' '1 Add a field'
case_ model-sonnet-turns 0 '' 'model: sonnet' 'turns: 50' '1 Add a field'
case_ model-haiku 0 '' 'model: haiku' '1 Add a field'
case_ model-unknown 1 'must be haiku or sonnet' 'model: opus' 'turns: 50' '1 Add a field'
[ "$fails" = 0 ] || exit 1
