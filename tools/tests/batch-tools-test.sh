#!/usr/bin/env bash
# Tests tools/batch-report.sh (REPORT.md generated from run.log: stop and restart counts, a per-job table with model, ladder,
# turns, failure class and hand fix, the resumed-session mark) and tools/batch-close.sh (the full check line in run.log,
# STOP.md removed, the STATUS.md tip).
#
#   bash tools/tests/batch-tools-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/batch-tools-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0 cases=0
ok() { cases=$((cases + 1)); if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); [ -f "$tmp/out" ] && sed 's/^/    | /' "$tmp/out"; fi; }

repo="$tmp/repo"; b="docs/briefs/m1/demo"
mkdir -p "$repo/tools" "$repo/$b"
cp "$loc/tools/batch-report.sh" "$loc/tools/batch-close.sh" "$repo/tools/"
cat > "$repo/$b/run.log" <<'EOF'
2026-11-24 10:00:00 start at aaaaaaaa on m1
2026-11-24 10:00:05 start a
2026-11-24 10:00:10 start b
2026-11-24 10:02:10 b finished: result 0 (20 turns, 2 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 1/2/3/4
2026-11-24 10:12:10 a finished: result 4 (1 turn, 0 min) model claude-sonnet-5-5, ladder 2, tokens in/read/write/out n/a
2026-11-24 10:12:11 STOPPED: jobs that failed or passed their limit (parked, not committed): a (their logs: x)
RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): a (their logs: x)
HAND-FIX a: apply-job.sh applied 1 files
HAND-FIX-EVENT a: 14 lines changed, replaced ladder level 2
2026-11-24 10:20:00 start at bbbbbbbb on m1
2026-11-24 10:20:01 STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1)
RESULT: STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1)
2026-11-24 10:30:00 start at cccccccc on m1
EOF
printf -- '- 10:13 a class: brief (allow list too small)\n' > "$repo/$b/DRIVER-NOTES.md"
printf 'stop\n' > "$repo/$b/STOP.md"
printf '# Status\n\n**Resume here (demo done, Nov 24; base 1234abcd, final tip see git log (close-out commit after bbbbbbbb)):** things.\n' > "$repo/docs/briefs/m1/STATUS.md"
git -C "$repo" init -q && git -C "$repo" config user.email t@e.x && git -C "$repo" config user.name t && git -C "$repo" config core.autocrlf false
git -C "$repo" add -A && git -C "$repo" commit -q -m base
run() { ( cd "$repo" && "$@" ) > "$tmp/out" 2>&1; }

run bash tools/batch-report.sh "$b"
rep="$repo/$b/REPORT.md"
grep -q 'Runner starts 3 (restarts 2); STOPPED lines 2, of which 1 are pauses; HAND-FIX-EVENT lines 1' "$rep" &&
  grep -q 'Sonnet briefs 1 of 2 (50%), runs 1 Sonnet of 2' "$rep" &&
  grep -q '^| b | claude-haiku-5-5 | 1 | 20 | 2 | 2 | 0 | 1 | - | - |' "$rep" &&
  grep -q '^| a | claude-sonnet-5-5 | 2 | 1 | 0 | 12 | 4 | 1 | brief | 14 line(s), 1 event(s) resumed' "$rep"
ok "batch-report.sh counts starts, STOPPED lines and hand-fix events, and fills the per-job table (resumed session marked)" $?
run bash tools/batch-report.sh "$b"
[ $? = 3 ] || true
( cd "$repo" && bash tools/batch-report.sh "$b" > /dev/null 2>&1 ); [ $? = 3 ]
ok "batch-report.sh refuses to overwrite an existing REPORT.md (exit 3)" $?

run bash tools/batch-close.sh "$b" --line "something failed"
rc=$?; [ "$rc" = 1 ] && [ -e "$repo/$b/STOP.md" ] && ! grep -q '^full check:' "$repo/$b/run.log"
ok "batch-close.sh refuses a line without \"All checks passed\" and changes nothing (exit 1)" $?
run bash tools/batch-close.sh "$b" --line "All checks passed (12s, 3 cached)"
rc=$?
tipv=$(git -C "$repo" rev-parse --short=8 HEAD)
[ "$rc" = 0 ] && [ ! -e "$repo/$b/STOP.md" ] && grep -q "^full check: All checks passed (12s, 3 cached) $(date +%F) $tipv\$" "$repo/$b/run.log" &&
  grep -q "tip $tipv)" "$repo/docs/briefs/m1/STATUS.md" && ! grep -q 'see git log' "$repo/docs/briefs/m1/STATUS.md"
ok "batch-close.sh records the full check line, removes STOP.md and names the tip in STATUS.md" $?
run bash tools/batch-close.sh "$b" --line "All checks passed (1s)" --tip "$tipv"
grep -q "tip $tipv)" "$repo/docs/briefs/m1/STATUS.md" && [ "$(grep -c 'tip ' "$repo/docs/briefs/m1/STATUS.md")" = 1 ]
ok "a second close-out keeps one tip in the STATUS line" $?

if [ "$fails" -gt 0 ]; then echo "RESULT: FAILED: $fails of $cases case(s) failed"; exit 1; fi
echo "RESULT: ok: $cases case(s) passed"
