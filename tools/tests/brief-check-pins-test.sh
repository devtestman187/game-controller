#!/usr/bin/env bash
# tune4 T3: the `pins` WARN of tools/brief-check.sh (tools/brief-check-pins.sh): a job whose allow: holds a lib file that
# defines a widget, while a test file names that widget and no job of the wave or an earlier wave allows the test,
# WARNs (exit 0). Allowing the test in the job, or in an earlier wave's job, silences it; a later wave's job does not.
#
#   bash tools/tests/brief-check-pins-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/brief-check-pins-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0 cases=0 out="$tmp/out.txt" rc=0 batch="$tmp/batch"
report() { cases=$((cases + 1)); if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); sed 's/^/    | /' "$out"; fi; }
mkdir -p "$tmp/packages/x/lib" "$tmp/packages/x/test"
printf 'class HomeCard extends StatelessWidget {}\nclass _Private extends State<HomeCard> {}\n' > "$tmp/packages/x/lib/home.dart"
printf 'void main() { find.byType(HomeCard); }\n' > "$tmp/packages/x/test/home_test.dart"
brief() { { echo "job: $1"; echo "allow: $2"; echo "changes: SomethingElse"; } > "$batch/$1.md"; }
check() { rc=0; BRIEF_CHECK_ROOT="$tmp" BRIEF_CHECK_REF= bash tools/brief-check.sh "$batch" > "$out" 2>&1 || rc=$?; }
fresh() { rm -rf "$batch"; mkdir -p "$batch"; printf '%s\n' "$@" > "$batch/waves.txt"; }

fresh a; brief a "packages/x/lib/home.dart"; check
if [ "$rc" = 0 ] && grep -q "^WARN pins a: packages/x/test/home_test.dart names the widget HomeCard" "$out"; then r=0; else r=1; fi
report "a job allowing the widget file but not the test that names it gets a pins WARN (exit $rc)" "$r"
fresh a; brief a "packages/x/lib/home.dart · packages/x/test/home_test.dart"; check
if [ "$rc" = 0 ] && ! grep -q "WARN pins" "$out"; then r=0; else r=1; fi
report "allowing the test in the same job gives no pins WARN" "$r"
fresh "a" "b"; brief a "packages/x/lib/home.dart"; brief b "packages/x/test/home_test.dart"; check
if [ "$rc" = 1 ] || grep -q "WARN pins a:" "$out"; then r=0; else r=1; fi
report "the test allowed only by a LATER wave's job still WARNs (or the wave rule fails it)" "$r"
fresh "b" "a"; brief a "packages/x/lib/home.dart"; brief b "packages/x/test/home_test.dart"; check
if ! grep -q "WARN pins a:" "$out"; then r=0; else r=1; fi
report "the test allowed by an EARLIER wave's job gives no pins WARN" "$r"
if [ "$fails" -gt 0 ]; then echo "RESULT: FAILED: $fails of $cases case(s) failed"; exit 1; fi
echo "RESULT: ok: $cases case(s) passed"
