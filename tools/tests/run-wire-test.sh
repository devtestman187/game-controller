#!/usr/bin/env bash
# Tests the runner's wiring (tools/run-jobs.sh) as the p2-wire and f2 briefs ask, part 1 of 2
# (run-wire2-test.sh has the signal, lock-holder and review-wait cases). Every stop (a failed
# check, the STOP file, the brief lint) writes <batch>/STOP.md through tools/run-stop.sh and
# commits it, the next start removes it and commits the removal; a failing tools/run-stop.sh never
# changes the runner's exit and its finding is committed with the log; a result-4 job whose only
# outside files are generated churn is applied, never a stop, and its own paths are copied from
# the kept worktree when the patch is empty or does not apply; a second runner on a batch is
# refused and a stale lock is replaced; RUN_MAX_MIN=0 runs out with STOPPED: TIMEOUT; and the
# dry run prints its plan, takes no lock and leaves no STOP.md.
#
#   bash tools/tests/run-wire-test.sh
#
# Every case copies one throwaway git repo (built once, by run_wire_template in run-wire-lib.sh)
# into a temp folder: the five runner files are copies, and tools/flash.sh, check.sh, review.sh,
# commit-job.sh and run-stop.sh are stubs driven by FLASH_MODE and the STUB_* variables, so no
# worker, test suite or check runs. The briefs folder sits inside the repo, because the runner
# asks git about its paths.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
# The caller's limit and poll settings must not reach the runner: each case sets its own below.
unset RUN_CHECK_MAX_MIN RUN_REVIEW_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_JOB_FACTOR_PCT \
  RUN_EXPECT_DEFAULT_MIN RUN_TURN_CAP RUN_BASE_CHECK_MAX_MIN BRIEF_CHECK_SKIP BRIEF_CHECK_CMD
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-wire-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
source "$loc/tools/tests/run-wire-lib.sh"
wire_init
run_wire_template || exit 2

# 1. A failed check: STOP.md, committed, and the run stops after trying the check twice.
fixture checkfail
STUB_CHECK_FAIL=1
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: checks failed twice on the combined tree after runjob" &&
  stopmd "checks failed twice" && stop_committed; then r=0; else r=1; fi
report "a failed check writes STOP.md with the cause and commits it (exit 1)" "$r"

# 2. The STOP file, made by the preflight stub: STOP.md names it and is committed.
fixture stopfile
FLASH_MODE=preflight PREFLIGHT_SKIP=""
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: stop file" && stopmd "stop file" && stop_committed; then r=0; else r=1; fi
report "the STOP file writes STOP.md with its cause and commits it (exit 1)" "$r"

# 3. The brief lint, before wave 1: STOP.md too.
fixture lint badreport
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: brief lint" && stopmd "report: line" && stop_committed; then r=0; else r=1; fi
report "the brief lint writes STOP.md with its cause and commits it (exit 1)" "$r"

# 4. A failing run-stop.sh (at the lint stop): the runner still exits 1, says so, and commits the
# findings and the log (the finding is the only record that no STOP.md was written).
fixture stopfail badreport
STUB_STOP_FAIL=1
run_jobs --no-review
if [ "$rc" = 1 ] && [ ! -f "$repo/$batch/STOP.md" ] && logged "STOPPED: brief lint" &&
  grep -qF "STOP.md was not written" "$repo/$batch/run-findings.md" 2>/dev/null &&
  git -C "$repo" cat-file -e "HEAD:$batch/run-findings.md" 2>/dev/null &&
  git -C "$repo" cat-file -e "HEAD:$batch/run.log" 2>/dev/null; then r=0; else r=1; fi
report "a failing run-stop.sh leaves the exit at 1, says so in the committed findings and commits the log" "$r"

# 5. Result 4 with only generated churn outside: applied (the churn dropped), never a stop.
fixture churn
FLASH_MODE=churn
run_jobs --no-review
if [ "$rc" = 0 ] &&
  logged "runjob: dropped generated churn outside its list: site/shots/join.png docs/briefs/fix/runjob-results.json" &&
  logged "committed runjob" && ! logged "STOPPED" && [ ! -f "$repo/$batch/STOP.md" ] &&
  git -C "$repo" grep -q changed HEAD -- src/app.dart &&
  git -C "$repo" cat-file -e "HEAD:$batch/runjob-report.md" 2>/dev/null; then r=0; else r=1; fi
report "result 4 with only generated churn (site/shots, the test's *-results.json) is applied (exit 0)" "$r"

# 6. Result 4 with only churn outside and a patch that does not apply (the repo's own edit of an
# allowed file conflicts with the job's): the job's own paths are copied from the kept worktree.
fixture churnfail
FLASH_MODE=churnfail
printf 'local\n' > "$repo/src/app.dart"
run_jobs --no-review
if [ "$rc" = 0 ] &&
  logged "runjob: the patch was empty or did not apply" &&
  logged "copied its own paths from the kept worktree: src/app.dart docs/briefs/fix/runjob-report.md" &&
  logged "runjob: dropped generated churn outside its list: site/shots/join.png" &&
  logged "committed runjob" && ! logged "STOPPED" &&
  git -C "$repo" grep -q changed HEAD -- src/app.dart &&
  git -C "$repo" cat-file -e "HEAD:$batch/runjob-report.md" 2>/dev/null &&
  [ ! -e "$repo/site/shots/join.png" ]; then r=0; else r=1; fi
report "result 4 with only churn outside and a patch that does not apply copies the job's own paths (exit 0)" "$r"

# 7. The same with an empty patch (the kept worktree has no change of its own): copied too, no stop.
fixture churnempty
FLASH_MODE=churnempty
run_jobs --no-review
if [ "$rc" = 0 ] && logged "runjob: the patch was empty or did not apply" &&
  logged "runjob: dropped generated churn outside its list: site/shots/join.png" &&
  logged "committed runjob" && ! logged "STOPPED" &&
  git -C "$repo" cat-file -e "HEAD:$batch/runjob-report.md" 2>/dev/null &&
  [ ! -e "$repo/site/shots/join.png" ]; then r=0; else r=1; fi
report "result 4 with only churn outside and an empty patch copies the job's own paths (exit 0)" "$r"

# 8. A live lock: a second runner on the same batch is refused with exit 2.
fixture lockrefused
sleep 30 &
sleeper=$!
printf '%s\n' "$sleeper" > "$work/lock"
run_jobs --no-review
live=$(tail -n 1 "$out")
kill "$sleeper" 2>/dev/null
wait "$sleeper" 2>/dev/null
if [ "$rc" = 2 ] && [ "$live" = "RESULT: refused, a run is active (pid $sleeper)" ] &&
  [ ! -f "$repo/docs/briefs/fix/run.log" ]; then r=0; else r=1; fi
report "a second runner on the same batch exits 2 with the RESULT: refused line" "$r"

# 9. A stale lock (its pid is gone) is replaced, and the run goes on to its own stop.
fixture stalelock
printf '2147483\n' > "$work/lock"
RUN_MAX_MIN=0
run_jobs --no-review
if [ "$rc" = 1 ] && logged "replaced a stale lock (pid 2147483 is gone)" && logged "STOPPED: TIMEOUT" &&
  [ ! -f "$work/lock" ]; then r=0; else r=1; fi
report "a stale lock is replaced and the trap removes the lock on exit (exit 1)" "$r"

# 12. RUN_MAX_MIN=0: the first step past the limit stops with TIMEOUT and writes STOP.md.
fixture timeout
RUN_MAX_MIN=0
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: TIMEOUT" && stopmd "RUN_MAX_MIN=0" && stop_committed; then r=0; else r=1; fi
report "RUN_MAX_MIN=0 stops with TIMEOUT and STOP.md (exit 1)" "$r"

# 13. The next start removes the last stop's committed STOP.md and commits the removal.
fixture removal
printf 'old stop\n' > "$repo/$batch/STOP.md"
git -C "$repo" add -f "$batch/STOP.md"
git -C "$repo" commit -q -m "the last stop's STOP.md"
RUN_MAX_MIN=0 # the run stops at once, so this start leaves a STOP.md of its own
run_jobs --no-review
if [ "$rc" = 1 ] && logged "removed the last stop's STOP.md" && stopmd "RUN_MAX_MIN=0" &&
  git -C "$repo" log --format=%s -- "$batch/STOP.md" | grep -q "removal of the last stop"; then r=0; else r=1; fi
report "the next start removes the last stop's STOP.md and commits the removal (exit 1)" "$r"

# 14. The dry run: the same plan as before, no lock, no STOP.md, no job started.
fixture dryrun
RUN_MAX_MIN=0 # a dry run has no time limit either
expected="$tmp/expected.txt"
{
  echo "wave 1:"
  echo "  runjob: run"
  echo "then: the run's review -> $batch/REVIEW.md"
} > "$expected"
run_jobs --dry-run
if [ "$rc" = 0 ] && diff -u "$expected" "$out" > "$tmp/diff.txt" && [ ! -f "$work/lock" ] &&
  [ ! -f "$repo/$batch/STOP.md" ] && [ ! -f "$STUB_MARK" ]; then r=0; else r=1; fi
report "the dry run prints its plan and takes no lock, writes no STOP.md, starts no job (exit 0)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
