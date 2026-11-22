#!/usr/bin/env bash
# Tests tools/run-stop.sh against docs/briefs/m16/process2/script-rules.md and
# the p2-stop brief: one case per class, the failing names and log tail, the
# outside files, missing logs, huge logs, bad arguments and env knobs (non-numeric,
# below the minimum, capped), a path with spaces, a cause with quotes and
# newlines, and nothing else in the folder changed.
#
#   bash tools/tests/run-stop-test.sh
#
# Every case builds its batch and work folders in a temp folder, so no case
# sees another's files. Prints PASS <case> / FAIL <case> and exits 1 if any
# case failed. Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/../.." || exit 2
stop="$(pwd)/tools/run-stop.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-stop-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what run-stop.sh printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
run_stop() { # <args...>: runs run-stop.sh, storing rc and out
  rc=0
  bash "$stop" "$@" > "$out" 2>&1 || rc=$?
}
batch="" work=""
fixture() { # fixture <name>: fresh batch and work folders; sets batch and work
  batch="$tmp/$1/batch"; work="$tmp/$1/work"
  rm -rf "${tmp:?}/$1"; mkdir -p "$batch" "$work"
}
log_with() { # log_with <n>: n run.log lines, then the line LAST-LINE
  seq 1 "$1" | sed 's/^/2026-11-21 00:00:00 log line /' > "$batch/run.log"
  echo "2026-11-21 00:00:00 LAST-LINE" >> "$batch/run.log"
}
check_fail() { # check_fail: a run-check.log with one failing test
  printf '00:03 +5 -1: test/score_row_test.dart: scores the rows [E]\n' > "$work/run-check.log"
  printf '  Expected: 3\n    Actual: 4\n' >> "$work/run-check.log"
  echo '    package:flutter/src/foundation/assertions.dart:1: Error: inside' >> "$work/run-check.log"
  echo '00:03 +5 -1: Some tests failed.' >> "$work/run-check.log"
}
flash_outside() { # flash_outside <flash-log> <path>...: a flash log with a CHANGED FILES OUTSIDE block
  local f=$1 p; shift
  { echo "---- flash: CHANGED FILES OUTSIDE --allow (tools/run-stop.sh):"
    for p in "$@"; do echo "  $p"; done
    echo "---- flash: result 4"; } > "$f"
}
has() { grep -qF "$1" "$batch/STOP.md"; } # has <text>: STOP.md holds it

# One case per class: the cause text the runner passes picks the class.
class_case() { # class_case <class> <cause text>
  fixture "class-$1"
  log_with 3
  run_stop "$batch" "$work" "$2"
  if [ "$rc" = 0 ] && grep -qxF "class: $1" "$batch/STOP.md" && has "repair: "; then r=0; else r=1; fi
  report "class $1: the cause text picks its class, with a repair (exit 0)" "$r"
}

class_case churn-outside "the job changed generated churn outside its allow: docs/design/a.png"
class_case outside-allow "the job changed files outside its allow: lib/a.dart; nothing of this wave is committed"
class_case tests-first "tests-first: packages/party_host/test/score_row_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed"
class_case check-failed "checks failed twice on the combined tree after s6a s8p wtv (see .dart_tool/run-jobs/docs_briefs_m16_phonehost2/run-check.log); nothing of this wave is committed"
class_case review-fail "tools/review.sh found a FAIL after s2 (see .dart_tool/run-jobs/x/run-review.log); nothing of this wave is committed"
class_case size "a touched lib file is over 380 lines and must be split: packages/party_host/lib/host_screen.dart; nothing of this wave is committed"
class_case brief-lint "brief lint: s3: report: line must be exactly one bare path (got: two words)"
class_case preflight "preflight failed: the worker cannot run flutter or tools/check.sh in its sandbox, so no job would run tests (see .dart_tool/run-jobs/x/run-preflight.log); nothing was started"
class_case stop-file "stop file"
class_case commit-refused "commit of s4 refused (see .dart_tool/run-jobs/x/run-commit.log)"
class_case job-failed "jobs that failed or need applying by hand: s6b2:4 (their logs: docs/briefs/m16/phonehost2/flash-<job>.log)"
class_case timeout "TIMEOUT: the run passed RUN_MAX_MIN (360 min); see run.log"
class_case other "a cause no class names"

# Every repair names the digest section or a command to run.
bad=()
for c in churn-outside outside-allow tests-first check-failed review-fail size brief-lint preflight stop-file \
  commit-refused job-failed timeout other; do
  repair=$(grep -h '^repair: ' "$tmp/class-$c/batch/STOP.md" | cut -c9-)
  case "$repair" in
    *"docs/flash-digest.md"* | *"docs/coding-guidelines.md"* | *"tools/"* | *"<batch>/STOP"*) ;;
    *) bad+=("$c") ;;
  esac
done
if [ ${#bad[@]} = 0 ]; then r=0; else r=1; fi
report "every class's repair names the digest section or a command" "$r"

# The failing test, its error lines and the newest run.log line are kept.
fixture detail
log_with 40
check_fail
run_stop "$batch" "$work" "checks failed twice on the combined tree after s6"
n=$(wc -l < "$batch/STOP.md")
if [ "$rc" = 0 ] && [ "$n" -le 40 ] && has "test/score_row_test.dart" && has "Expected: 3" && has "LAST-LINE" &&
  has "failing tests and errors (run-check.log):" && ! has "assertions.dart"; then r=0; else r=1; fi
report "a check stop names the failing test, its error lines and the newest log line ($n lines)" "$r"

# The run.log tail is at most the last 20 lines of 41: line 22 is the oldest kept.
if grep -q 'log line 22$' "$batch/STOP.md" && ! grep -q 'log line 21$' "$batch/STOP.md"; then r=0; else r=1; fi
report "only the last 20 run.log lines are kept (the oldest kept is line 22 of 41)" "$r"

# Huge logs stay inside 40 lines, and the newest run.log line survives the cut.
fixture huge
log_with 500
for i in $(seq 1 500); do echo "00:0$((i % 10)) +0 -1: test/t$i\_test.dart: case $i [E]"; done > "$work/run-check.log"
flash_outside "$work/flash.log" $(seq 1 500 | sed 's|^|docs/design/p|; s|$|.png|')
run_stop "$batch" "$work" "checks failed twice on the combined tree after s6" "$work/flash.log"
n=$(wc -l < "$batch/STOP.md")
if [ "$rc" = 0 ] && [ "$n" -le 40 ] && has "LAST-LINE" && has "more)" && has "files outside allow (flash log):"; then r=0; else r=1; fi
report "huge logs still give at most 40 lines, the newest line and a (+N more) marker ($n lines)" "$r"

# A flash log with outside files: the paths are quoted, up to the outside cap.
fixture flash
log_with 3
flash_outside "$work/flash.log" "docs/design/a.png" "lib/b.dart"
run_stop "$batch" "$work" "files outside its allow: lib/b.dart" "$work/flash.log"
if [ "$rc" = 0 ] && has "lib/b.dart" && has "files outside allow (flash log):"; then r=0; else r=1; fi
report "the files outside allow are quoted from the flash log" "$r"

# Missing logs: three "none found" lines, never an error.
fixture missing
run_stop "$batch" "$work" "something odd happened" "$work/no-such-flash.log"
n=$(grep -c 'none found' "$batch/STOP.md")
if [ "$rc" = 0 ] && [ "$n" = 3 ]; then r=0; else r=1; fi
report "missing run.log, run-check.log and flash log say none found three times (exit 0)" "$r"

# Bad arguments: exit 3, a plain message, and the RESULT line last.
bad_case() { # bad_case <case> <args...>
  local name=$1; shift
  run_stop "$@"
  if [ "$rc" = 3 ] && tail -n 1 "$out" | grep -q '^RESULT: BAD INPUT: '; then r=0; else r=1; fi
  report "$name" "$r"
}
bad_case "no arguments is bad input (exit 3)"
bad_case "one argument is bad input (exit 3)" "$tmp"
fixture args
bad_case "a missing batch folder is bad input (exit 3)" "$tmp/no-such-batch" "$work" "cause"
echo x > "$tmp/a-file"
bad_case "a batch path that is a file is bad input (exit 3)" "$tmp/a-file" "$work" "cause"

# An env knob takes a whole number: a bad one is bad input (exit 3, RESULT last,
# no STOP.md), never an abort inside $(( )) with no line saying why.
knob_case() { # knob_case <slug> <case text> <VAR=value> <message fragment>
  fixture "knob-$1"
  log_with 3
  rc=0
  env "$3" bash "$stop" "$batch" "$work" "checks failed twice on the combined tree" > "$out" 2>&1 || rc=$?
  if [ "$rc" = 3 ] && tail -n 1 "$out" | grep -qF "RESULT: BAD INPUT: $4" && [ ! -f "$batch/STOP.md" ]; then r=0; else r=1; fi
  report "$2" "$r"
}
knob_case max-abc "a non-numeric STOP_MAX_LINES is bad input (exit 3)" \
  STOP_MAX_LINES=abc "STOP_MAX_LINES takes a whole number"
knob_case tail-abc "a non-numeric STOP_LOG_TAIL is bad input (exit 3)" \
  STOP_LOG_TAIL=abc "STOP_LOG_TAIL takes a whole number"
knob_case errs-abc "a non-numeric STOP_ERROR_LINES is bad input (exit 3)" \
  STOP_ERROR_LINES=many "STOP_ERROR_LINES takes a whole number"
knob_case outside-abc "a non-numeric STOP_OUTSIDE_LINES is bad input (exit 3)" \
  STOP_OUTSIDE_LINES=2x "STOP_OUTSIDE_LINES takes a whole number"
knob_case col-abc "a non-numeric STOP_COL is bad input (exit 3)" \
  STOP_COL=wide "STOP_COL takes a whole number"
knob_case max-nine "STOP_MAX_LINES below 10 is bad input (exit 3)" \
  STOP_MAX_LINES=9 "STOP_MAX_LINES takes at least 10 lines"
knob_case tail-zero "STOP_LOG_TAIL=0 is bad input (exit 3)" \
  STOP_LOG_TAIL=0 "STOP_LOG_TAIL takes at least 1 line"

# A tail bigger than the limit allows is capped: 40 - 9 leaves 31, so of 61
# run.log lines the oldest kept is line 31 and the file is exactly 40 lines.
fixture tail-large
log_with 60
rc=0
STOP_LOG_TAIL=60 bash "$stop" "$batch" "$work" "checks failed twice on the combined tree" > "$out" 2>&1 || rc=$?
n=$(wc -l < "$batch/STOP.md")
if [ "$rc" = 0 ] && [ "$n" -eq 40 ] && grep -qF 'NOTE: STOP_LOG_TAIL is capped at 31 lines' "$out" &&
  has "LAST-LINE" && grep -q 'log line 31$' "$batch/STOP.md" && ! grep -q 'log line 30$' "$batch/STOP.md"; then r=0; else r=1; fi
report "STOP_LOG_TAIL=60 is capped at 31 lines and STOP.md stays 40 lines ($n lines)" "$r"

# The smallest limit still writes a whole file: 10 - 9 leaves a one-line tail.
fixture max-smallest
log_with 30
rc=0
STOP_MAX_LINES=10 bash "$stop" "$batch" "$work" "checks failed twice on the combined tree" > "$out" 2>&1 || rc=$?
n=$(wc -l < "$batch/STOP.md")
if [ "$rc" = 0 ] && [ "$n" -eq 10 ] && has "class: check-failed" && has "LAST-LINE"; then r=0; else r=1; fi
report "STOP_MAX_LINES=10 keeps the head and one log line, exactly 10 lines ($n lines)" "$r"

# A batch folder path with spaces works.
fixture "spaces one"
batch="$tmp/spaces one/batch two"; work="$tmp/spaces one/work three"
mkdir -p "$batch" "$work"
log_with 3
check_fail
run_stop "$batch" "$work" "checks failed twice on the combined tree"
if [ "$rc" = 0 ] && [ -f "$batch/STOP.md" ] && has "test/score_row_test.dart"; then r=0; else r=1; fi
report "a batch folder and work folder with spaces work" "$r"

# A cause with quotes, an apostrophe and a newline stays one cause line.
fixture cause
run_stop "$batch" "$work" $'He said "x" and it\'s y\nsecond line'
lines=$(grep -c '^cause:' "$batch/STOP.md")
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && has 'He said "x" and it' && has "second line"; then r=0; else r=1; fi
report "quotes and a newline in the cause stay on one cause line" "$r"

# An empty cause is class other, still written.
fixture empty
run_stop "$batch" "$work" ""
if [ "$rc" = 0 ] && has "class: other" && has "cause: (empty)"; then r=0; else r=1; fi
report "an empty cause is class other (exit 0)" "$r"

# Nothing else in the folder changes and no temp file stays, over two runs.
fixture clean
log_with 3
before=$(ls -a "$batch" | sort)
run_stop "$batch" "$work" "checks failed twice on the combined tree"
run_stop "$batch" "$work" "checks failed twice on the combined tree"
after=$(ls -a "$batch" | sort)
added=$(comm -13 <(echo "$before") <(echo "$after"))
if [ "$rc" = 0 ] && [ "$added" = "STOP.md" ] && ! ls "$batch"/.STOP.md.* > /dev/null 2>&1; then r=0; else r=1; fi
report "only STOP.md is added to the folder (no temp file left after two runs)" "$r"

# An old STOP.md is replaced, not appended to.
fixture replace
echo old > "$batch/STOP.md"
run_stop "$batch" "$work" "checks failed twice on the combined tree"
if [ "$rc" = 0 ] && ! grep -qx old "$batch/STOP.md" && has "class: check-failed"; then r=0; else r=1; fi
report "an old STOP.md is replaced" "$r"

# A run-check.log with Windows line endings still gives its test name.
fixture crlf
printf '00:03 +5 -1: test/score_row_test.dart: scores the rows [E]\r\n  Expected: 3\r\n' > "$work/run-check.log"
run_stop "$batch" "$work" "checks failed twice on the combined tree"
if [ "$rc" = 0 ] && has "test/score_row_test.dart" && has "Expected: 3"; then r=0; else r=1; fi
report "a run-check.log with CRLF line endings is read" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
