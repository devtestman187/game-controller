#!/usr/bin/env bash
# Tests tools/debug-leftovers.sh in a throwaway git repo: an added BISECT marker, a debug marker comment
# and a print( / debugPrint( in a test file FAIL (exit 1, file:line named); print in lib code, a clean
# change, an old (unchanged) leftover and an untracked new test file with a marker are judged right.
#   bash tools/tests/debug-leftovers-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tool="$(pwd)/tools/debug-leftovers.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/debug-leftovers-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0
out="$tmp/out.txt"
mkdir -p "$tmp/repo/tools" "$tmp/repo/pkg/lib" "$tmp/repo/pkg/test"
cp "$tool" "$tmp/repo/tools/"
cd "$tmp/repo" || exit 2
git init -q . && git config user.email t@t && git config user.name t
printf 'void a() {}\n// old BISECT line\n' > pkg/lib/a.dart
printf 'void main() {}\n' > pkg/test/a_test.dart
git add -A && git commit -qm base
run() { rc=0; bash tools/debug-leftovers.sh "$@" > "$out" 2>&1 || rc=$?; }
want() { # want <case> <rc> [text]
  if [ "$rc" = "$2" ] && { [ -z "${3:-}" ] || grep -qF -- "$3" "$out"; }; then echo "PASS $1"; else echo "FAIL $1 (rc $rc)"; sed 's/^/    | /' "$out"; fails=$((fails + 1)); fi
}
run; want clean-tree-with-old-leftover 0 'no debug leftovers'
printf 'void main() {\n  print("x");\n}\n' > pkg/test/a_test.dart
run; want print-in-test 1 'pkg/test/a_test.dart:2'
printf 'void main() {\n  debugPrint("x");\n}\n' > pkg/test/a_test.dart
run; want debugPrint-in-test 1 'debugPrint'
git checkout -q pkg/test/a_test.dart
printf 'void a() { print("ok in lib"); }\n// old BISECT line\n' > pkg/lib/a.dart
run; want print-in-lib-ok 0
printf 'void a() {\n  return; // DEBUG skip\n}\n// old BISECT line\n' > pkg/lib/a.dart
run; want debug-marker-comment 1 'pkg/lib/a.dart:2'
printf 'void a() {}\n// old BISECT line\nconst x = 1; // BISECT 2\n' > pkg/lib/a.dart
run; want bisect-added 1 'BISECT 2'
git checkout -q pkg/lib/a.dart
printf 'void main() { // bisect\n}\n' > pkg/test/new_test.dart
run; want untracked-new-test 1 'pkg/test/new_test.dart:1'
rm pkg/test/new_test.dart
printf 'void a() {}\n// old BISECT line\nvoid b() {}\n' > pkg/lib/a.dart
git commit -qam b
run --range HEAD~1..HEAD; want range-clean 0
printf 'void c() {}\nvoid main() { print(1); }\n' > pkg/test/b_test.dart
git add pkg/test/b_test.dart && git commit -qm c
run --range HEAD~1..HEAD; want range-print 1 'pkg/test/b_test.dart:2'
bash tools/debug-leftovers.sh --bogus > "$out" 2>&1; rc=$?; want bad-arg 2
[ "$fails" = 0 ] || exit 1
