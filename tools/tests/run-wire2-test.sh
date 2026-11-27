#!/usr/bin/env bash
# Tests the runner's wiring (tools/run-jobs.sh) as the f2 brief asks, part 2 of 2 (run-wire-test.sh
# has the stop, churn, lock and dry-run cases): a TERM or an INT in the middle of a job ends the
# run with 143 or 130 and removes only the lock the run wrote; a stop (a job parked: its siblings
# are committed first) waits for a running wave review and commits its report, except a STOP-file
# stop, which kills it at once; and RUN_MAX_MIN stops the run's stuck final review with
# STOPPED: TIMEOUT. (Which wave reviews run at all is run-jobs-split-test.sh's case.)
#
#   bash tools/tests/run-wire2-test.sh
#
# Every case copies one throwaway git repo (built once, by run_wire_template in run-wire-lib.sh)
# into a temp folder, and the tools/ stubs are the same as in run-wire-test.sh. The review cases
# stub `date +%s` with a fake clock that the slow review jumps forward, so RUN_MAX_MIN runs out
# in seconds.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
for v in $(compgen -e | grep -E "^RUN_"); do unset "$v"; done # the caller's RUN_* settings (RUN_PAUSE_AFTER_WAVE leaked, Nov 25)
# The caller's limit and poll settings must not reach the runner: each case sets its own below.
# The runner is started with WORKER=claude MAX_JOBS=n; the stub worker runs as flash, so they must not reach the nested runner (board3c s0).
unset RUN_CHECK_MAX_MIN RUN_REVIEW_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_JOB_FACTOR_PCT \
  RUN_EXPECT_DEFAULT_MIN RUN_TURN_CAP RUN_BASE_CHECK_MAX_MIN BRIEF_CHECK_SKIP BRIEF_CHECK_CMD
unset WORKER MAX_JOBS
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-wire2-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
source "$loc/tools/tests/run-wire-lib.sh"
wire_init
run_wire_template || exit 2

# 10. A TERM in the middle of a job ends the run with 143 (it used to remove the lock and run on),
# and the lock it holds is removed at the exit.
fixture lockterm
FLASH_MODE=slow
start_jobs --no-review
rid=$(lock_pid)
end_runner TERM
touch "$STUB_SLOW_DONE"
sleep 0.3 # the job's stub sees it and leaves, so no stray process outlives the case
if [ "$rc" = 143 ] && [ ! -f "$work/lock" ]; then r=0; else r=1; fi
report "a TERM ends the runner with exit 143 and removes the lock it holds" "$r"

# 11. An INT ends the run with 130 too, and leaves a lock another pid wrote (only its own $$ goes).
fixture lockint
FLASH_MODE=slow
start_jobs --no-review
rid=$(lock_pid)
sleep 30 &
other=$!
printf '%s\n' "$other" > "$work/lock"
end_runner INT
kept=$(cat "$work/lock" 2>/dev/null)
kill "$other" 2>/dev/null
wait "$other" 2>/dev/null
touch "$STUB_SLOW_DONE"
sleep 0.3
if [ "$rc" = 130 ] && [ "$kept" = "$other" ]; then r=0; else r=1; fi
report "an INT ends the runner with exit 130 and removes the lock only when it holds its own pid" "$r"

# 15. A stop (a job parked: its siblings are committed first) waits for the running wave review
# and commits its report. The job's report is seeded, so the runner resumes it and the case costs
# the parked wave only.
fixture waitreview
more_briefs runjob failjob
seed_report runjob
STUB_REVIEW_SLEEP_S=6 STUB_FAIL_BRIEF=failjob.md # still running when the stop comes at ~5 s
run_jobs
if [ "$rc" = 1 ] && logged "STOPPED: jobs that failed or passed their limit (parked, not committed): failjob" &&
  git -C "$repo" cat-file -e "HEAD:$batch/wave1-review-report.md" 2>/dev/null &&
  [ -f "$tmp/waitreview/review-done" ]; then r=0; else r=1; fi
report "a stop waits for the running wave review and commits its report (exit 1)" "$r"

# 16. The STOP file is the one stop that kills a running review at once: no report is kept.
fixture stopreview
more_briefs runjob failjob
seed_report runjob
STUB_REVIEW_SLEEP_S=20 STUB_FAIL_BRIEF=failjob.md STUB_STOP_ON_FAIL=1 # long: a loaded -j 4 run must not finish the review first
run_jobs
if [ "$rc" = 1 ] && logged "STOPPED: stop file" &&
  ! git -C "$repo" cat-file -e "HEAD:$batch/wave1-review-report.md" 2>/dev/null &&
  [ ! -f "$repo/$batch/wave1-review-report.md" ] && [ ! -f "$tmp/stopreview/review-done" ]; then r=0; else r=1; fi
report "a STOP-file stop kills the running wave review at once, with no report committed (exit 1)" "$r"

# 17. RUN_MAX_MIN stops the run's final review: the fake clock jumps while the review sleeps.
fixture reviewtimeout
seed_report runjob
STUB_REVIEW_SLEEP_S=30
printf '%s\n' "$(date +%s)" > "$tmp/reviewtimeout/now"
STUB_NOW="$tmp/reviewtimeout/now" STUB_JUMP_S=3600
RUN_MAX_MIN=1
start_s=$SECONDS
run_jobs
elapsed_s=$((SECONDS - start_s))
if [ "$rc" = 1 ] && logged "STOPPED: TIMEOUT" && [ -f "$tmp/reviewtimeout/review-start" ] &&
  [ ! -f "$repo/$batch/REVIEW.md" ] && [ ! -f "$tmp/reviewtimeout/review-done" ] &&
  [ "$elapsed_s" -lt 25 ]; then r=0; else r=1; fi
report "RUN_MAX_MIN stops the run's stuck final review with STOPPED: TIMEOUT in ${elapsed_s}s (exit 1)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
