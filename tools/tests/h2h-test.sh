#!/usr/bin/env bash
# Tests tools/h2h.sh (m165 t2): the winner's kept tree is applied through apply-job.sh (allow: files and report), the loser's
# diff is saved as loser-<job>.patch (new file included, generated churn left out), both worktrees are removed and pruned,
# run.log gets an H2H line; --dry changes nothing; a missing tree and bad use refuse without touching anything.
#   bash tools/tests/h2h-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/h2h-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0 cases=0
out="$tmp/out.txt"
report() { cases=$((cases + 1)); if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); sed 's/^/    | /' "$out"; fi; }
repo=$tmp/repo batch=$tmp/batch ws=$tmp/ws wl=$tmp/wl
mkdir -p "$repo/tools" "$repo/lib" "$repo/reports" "$batch"
cp tools/apply-job.sh tools/churn.sh tools/h2h.sh "$repo/tools/"
printf 'a1\n' > "$repo/lib/a.dart"
git -C "$repo" init -q
git -C "$repo" -c user.email=t@example.com -c user.name=t add -A
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m base
for j in xs xh; do printf 'job: %s\nallow: lib/a.dart · lib/new.dart\nreport: reports/%s.md\n' "$j" "$j" > "$batch/$j.md"; done
git -C "$repo" worktree add -q --detach "$ws" HEAD
git -C "$repo" worktree add -q --detach "$wl" HEAD
printf 'win\n' > "$ws/lib/a.dart"; printf 'new\n' > "$ws/lib/new.dart"; mkdir -p "$ws/reports"; printf "rep
" > "$ws/reports/xs.md"
printf 'lose\n' > "$wl/lib/a.dart"; printf 'newl\n' > "$wl/lib/new.dart"; mkdir -p "$wl/site/shots"; printf 'p\n' > "$wl/site/shots/x.png"
printf -- '---- flash: apply: no (head-to-head arm): changes NOT applied here; the worktree is kept: %s\n' "$ws" > "$batch/flash-xs.log"
printf -- '---- flash: apply: no (head-to-head arm): changes NOT applied here; the worktree is kept: %s\n' "$wl" > "$batch/flash-xh.log"
: > "$batch/run.log"
run() { rc=0; bash "$repo/tools/h2h.sh" "$@" > "$out" 2>&1 || rc=$?; }

run "$batch" xs xh --dry
if [ "$rc" = 0 ] && [ "$(cat "$repo/lib/a.dart")" = a1 ] && [ -d "$ws" ] && [ -d "$wl" ] && [ ! -e "$batch/loser-xh.patch" ]; then r=0; else r=1; fi
report "--dry names the trees and changes nothing" "$r"

run "$batch" xs xs
if [ "$rc" = 2 ]; then r=0; else r=1; fi
report "the same job as winner and loser is bad use (exit $rc)" "$r"

run "$batch" xs xh
if [ "$rc" = 0 ] && [ "$(cat "$repo/lib/a.dart")" = win ] && [ "$(cat "$repo/lib/new.dart")" = new ] && [ -f "$repo/reports/xs.md" ] &&
  [ ! -e "$ws" ] && [ ! -e "$wl" ] && ! git -C "$repo" worktree list | grep -q 'ws\|wl' &&
  grep -q '^H2H xs won over xh' "$batch/run.log" && grep -q '^HAND-FIX xs:' "$batch/run.log"; then r=0; else r=1; fi
report "the winner is applied, both worktrees removed and pruned, run.log has the H2H line" "$r"
if grep -q '^+lose' "$batch/loser-xh.patch" && grep -q '^+newl' "$batch/loser-xh.patch" && ! grep -q 'shots' "$batch/loser-xh.patch"; then r=0; else r=1; fi
report "the loser's patch holds its edit and its new file, not the generated churn" "$r"

run "$batch" xs xh
if [ "$rc" = 1 ]; then r=0; else r=1; fi
report "a second run refuses: the kept trees are gone (exit $rc)" "$r"
[ "$fails" = 0 ] || exit 1
echo "RESULT: ok: $cases case(s) passed"
