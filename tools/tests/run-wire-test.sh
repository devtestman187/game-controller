#!/usr/bin/env bash
# Tests the runner's wiring (tools/run-jobs.sh) as the p2-wire and f2 briefs ask: every stop
# (a failed check, the STOP file, the brief lint) writes <batch>/STOP.md through
# tools/run-stop.sh and commits it, the next start removes it and commits the removal;
# a failing tools/run-stop.sh never changes the runner's exit and its finding is committed
# with the log; a result-4 job whose only outside files are generated churn is applied,
# never a stop, and its own paths are copied from the kept worktree when the patch is empty
# or does not apply; one runner per batch (a second is refused, a stale lock is replaced, a
# signal ends the run with 130/143 and removes only the lock the run wrote); RUN_MAX_MIN=0
# runs out with STOPPED: TIMEOUT; and the dry run prints its plan, takes no lock and leaves
# no STOP.md.
# f2: a stop waits for a running wave review and commits its report, except a STOP-file
# stop, which kills it at once; RUN_MAX_MIN stops the run's stuck final review with
# STOPPED: TIMEOUT. (Which wave reviews run at all is run-jobs-split-test.sh's case.)
#
#   bash tools/tests/run-wire-test.sh
#
# Every case builds a throwaway git repo in a temp folder: the four runner files are
# copies, and tools/flash.sh, check.sh, review.sh, commit-job.sh and run-stop.sh are stubs
# driven by FLASH_MODE and the STUB_* variables, so no worker, test suite or check runs.
# The briefs folder sits inside the repo, because the runner asks git about its paths.
# The last case also stubs `date +%s` (a fake clock that the slow review jumps forward),
# so RUN_MAX_MIN runs out in seconds.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-wire-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the runner printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
repo=""
batch="docs/briefs/fix" # relative: the runner's paths must be repo paths for git
work=""
mkdir -p "$tmp/bin" "$tmp/datebin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/flutter"
cp "$tmp/bin/flutter" "$tmp/bin/dart"
# A fake clock for the one case that needs time to run out: `date +%s` reads STUB_NOW. It is
# on PATH only while STUB_NOW is set (a date call of its own is slow in Git Bash).
real_date=$(command -v date)
cat > "$tmp/datebin/date" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "+%s" ] && [ -f "\${STUB_NOW:-}" ]; then cat "\$STUB_NOW"; exit 0; fi
exec "$real_date" "\$@"
EOF
chmod +x "$tmp/bin/flutter" "$tmp/bin/dart" "$tmp/datebin/date"

FLASH_MODE=plain STUB_CHECK_FAIL=0 STUB_STOP_FAIL=0 PREFLIGHT_SKIP=1 RUN_MAX_MIN=360
STUB_REVIEW_SLEEP_S="" STUB_FAIL_BRIEF="" STUB_STOP_ON_FAIL=0 STUB_JUMP_S="" STUB_NOW=""
export FLASH_MODE STUB_CHECK_FAIL STUB_STOP_FAIL PREFLIGHT_SKIP RUN_MAX_MIN
export STUB_REVIEW_SLEEP_S STUB_FAIL_BRIEF STUB_STOP_ON_FAIL STUB_JUMP_S STUB_NOW

# The five stubs. They lean on the STUB_* variables fixture exports.
stubs() {
  cat > "$repo/tools/flash.sh" <<'EOF'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then
  [ "${FLASH_MODE:-}" = preflight ] && touch "$STUB_BATCH/STOP"
  echo "preflight ok (stub)"
  exit 0
fi
brief=${2:-}
write_report() { mkdir -p "$(dirname "$1")"; printf '## Summary\n\nstub report\n' > "$1"; }
review_report() { # review_report: the report a review brief asks for
  case "$(basename "$brief")" in
    run-review.md) echo "$STUB_BATCH/REVIEW.md" ;;
    *) echo "${brief%.md}-report.md" ;;
  esac
}
if [ "${FLASH_MODE:-plain}" = churn ]; then # a kept worktree whose only outside files are generated churn
  git worktree add --detach -q "$STUB_TREE" HEAD || exit 3
  printf 'changed\n' >> "$STUB_TREE/src/app.dart"
  write_report "$STUB_TREE/$STUB_REPORT"
  echo "---- flash: CHANGED FILES OUTSIDE --allow (stub):"
  echo "  site/shots/join.png"
  echo "  $STUB_RESULTS"
  echo "---- flash: the worktree is kept: $STUB_TREE"
  echo "---- flash: result 4"
  exit 4
fi
if [ "${FLASH_MODE:-plain}" = churnfail ]; then # churn only outside, a change of its own, and a patch the repo's own edit makes fail
  git worktree add --detach -q "$STUB_TREE" HEAD || exit 3
  printf 'changed\n' > "$STUB_TREE/src/app.dart"
  mkdir -p "$STUB_TREE/site/shots" && printf 'shot\n' > "$STUB_TREE/site/shots/join.png"
  write_report "$STUB_TREE/$STUB_REPORT"
  echo "---- flash: CHANGED FILES OUTSIDE --allow (stub):"
  echo "  site/shots/join.png"
  echo "---- flash: the worktree is kept: $STUB_TREE"
  echo "---- flash: result 4"
  exit 4
fi
if [ "${FLASH_MODE:-plain}" = churnempty ]; then # churn only outside, no change of its own (the patch is empty), the report in the repo
  git worktree add --detach -q "$STUB_TREE" HEAD || exit 3
  mkdir -p "$STUB_TREE/site/shots" && printf 'shot\n' > "$STUB_TREE/site/shots/join.png"
  write_report "$STUB_REPORT"
  echo "---- flash: CHANGED FILES OUTSIDE --allow (stub):"
  echo "  site/shots/join.png"
  echo "---- flash: the worktree is kept: $STUB_TREE"
  echo "---- flash: result 4"
  exit 4
fi
if [ "${FLASH_MODE:-plain}" = slow ]; then # a job that runs until the case touches $STUB_SLOW_DONE, so the case can signal the runner
  for _ in $(seq 300); do
    [ -f "${STUB_SLOW_DONE:-}" ] && break
    sleep 0.2
  done
  exit 0
fi
if [ -n "${STUB_REVIEW_SLEEP_S:-}" ] && [[ $brief == *-review.md ]]; then # a slow review: mark, sleep, report
  touch "$STUB_REVIEW_START"
  [ -n "${STUB_JUMP_S:-}" ] && echo "$(($(cat "$STUB_NOW") + STUB_JUMP_S))" > "$STUB_NOW"
  sleep "$STUB_REVIEW_SLEEP_S"
  write_report "$(review_report)"; touch "$STUB_REVIEW_DONE"
  exit 0
fi
if [ -n "${STUB_FAIL_BRIEF:-}" ] && [ "$(basename "$brief")" = "$STUB_FAIL_BRIEF" ]; then
  if [ "${STUB_STOP_ON_FAIL:-}" = 1 ]; then # raise the STOP file and stay alive until the runner sees it
    touch "$STUB_BATCH/STOP"
    sleep 30
  fi
  exit 1
fi
case "$brief" in *-review.md) write_report "$(review_report)" ;; *) write_report "$STUB_REPORT" ;; esac
exit 0
EOF
  cat > "$repo/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
if [ "${STUB_CHECK_FAIL:-}" = 1 ]; then
  echo '00:01 +1 -1: test/app_test.dart: works [E]'
  echo '00:01 +1 -1: Some tests failed.'
  exit 1
fi
echo "check ok (stub)"
EOF
  cat > "$repo/tools/review.sh" <<'EOF'
#!/usr/bin/env bash
echo "RESULT: ok: nothing to report (stub)"
EOF
  cat > "$repo/tools/commit-job.sh" <<'EOF'
#!/usr/bin/env bash
git add -A && git commit -q -m "job: $(basename "$1" .md)" && echo "Committed: stub"
EOF
  cat > "$repo/tools/run-stop.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${3:-}" >> "$STUB_STOP_CALLS"
[ "${STUB_STOP_FAIL:-}" = 1 ] && { echo "RESULT: BAD INPUT: stub failure"; exit 3; }
printf 'STOP (stub)\ncause: %s\n' "${3:-}" > "${1%/}/STOP.md"
echo "RESULT: ok: STOP.md written (stub)"
EOF
  chmod +x "$repo"/tools/*.sh
}

fixture() { # fixture <case> [badreport]: a fresh repo, batch and work folder, and the default knobs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"
  FLASH_MODE=plain STUB_CHECK_FAIL=0 STUB_STOP_FAIL=0 PREFLIGHT_SKIP=1 RUN_MAX_MIN=360
  STUB_REVIEW_SLEEP_S="" STUB_FAIL_BRIEF="" STUB_STOP_ON_FAIL=0 STUB_JUMP_S="" STUB_NOW=""
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool" "$work"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" "$loc/tools/churn.sh" "$repo/tools/"
  stubs
  printf 'base\n' > "$repo/src/app.dart"
  printf '{}\n' > "$repo/.dart_tool/package_config.json"
  printf 'allow: src/app.dart · %s/runjob-report.md\n' "$batch" > "$repo/$batch/runjob.md"
  if [ "${2:-}" = badreport ]; then
    printf 'report: %s/runjob-report.md extra\n' "$batch" >> "$repo/$batch/runjob.md"
  else
    printf 'report: %s/runjob-report.md\n' "$batch" >> "$repo/$batch/runjob.md"
  fi
  printf 'runjob\n' > "$repo/$batch/waves.txt"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name t
  git -C "$repo" add -A
  git -C "$repo" commit -q -m base || exit 2
  STUB_MARK="$base/flash-ran" STUB_BATCH="$batch" STUB_REPORT="$batch/runjob-report.md"
  STUB_TREE="$base/tree" STUB_RESULTS="$batch/runjob-results.json" STUB_STOP_CALLS="$base/stop-calls"
  STUB_SLOW_DONE="$base/slow-done"
  STUB_REVIEW_START="$base/review-start" STUB_REVIEW_DONE="$base/review-done"
  export STUB_MARK STUB_BATCH STUB_REPORT STUB_TREE STUB_RESULTS STUB_STOP_CALLS STUB_SLOW_DONE
  export STUB_REVIEW_START STUB_REVIEW_DONE
}

run_jobs() { # run_jobs [args]: the runner from the repo root, stubs first on PATH; sets rc and out
  local path="$tmp/bin:$PATH"
  rc=0
  [ -n "${STUB_NOW:-}" ] && path="$tmp/datebin:$path" # only the fake-clock case stubs date
  ( cd "$repo" && PATH="$path" NO_PUSH=1 RUN_WORK="$work" \
    timeout -k 5 60 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
}
start_jobs() { # start_jobs [args]: the runner in the background (a case signals it); sets runner_pid
  set -m # job control: without it a background bash starts with INT ignored, and its trap never runs
  ( cd "$repo" && PATH="$tmp/bin:$PATH" NO_PUSH=1 RUN_WORK="$work" bash tools/run-jobs.sh "$batch" "$@" ) \
    > "$out" 2>&1 &
  runner_pid=$!
  set +m
}
lock_pid() { # lock_pid: the pid in the runner's lock once it is taken, or nothing after 10 s
  local i
  for i in $(seq 100); do
    [ -s "$work/lock" ] && { cat "$work/lock"; return 0; }
    sleep 0.1
  done
  return 1
}
end_runner() { # end_runner <INT|TERM>: signal the runner ($rid, else its shell), collect its exit in rc;
  # one still alive after 15 s is killed, so a runner that ignores the signal fails the case, not the script
  local i
  kill -"$1" "${rid:-$runner_pid}" 2>/dev/null
  for i in $(seq 150); do
    kill -0 "${rid:-$runner_pid}" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "${rid:-$runner_pid}" 2>/dev/null && kill -KILL "${rid:-$runner_pid}" 2>/dev/null
  wait "$runner_pid"
  rc=$?
  echo "end_runner $1: runner $rc, lock $(cat "$work/lock" 2>/dev/null)" >> "$out"
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
more_briefs() { # more_briefs <job>...: a brief per job, one wave per job, committed
  local j
  for j in "$@"; do
    printf 'allow: src/app.dart · %s/%s-report.md\nreport: %s/%s-report.md\n' "$batch" "$j" "$batch" "$j" > "$repo/$batch/$j.md"
  done
  printf '%s\n' "$@" > "$repo/$batch/waves.txt"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "more briefs"
}
seed_report() { # seed_report <job>: its report is on disk, so the runner resumes it (no job run, no 5 s poll)
  printf '## Summary\n\nstub report\n' > "$repo/$batch/$1-report.md"
}
stopmd() { [ -f "$repo/$batch/STOP.md" ] && grep -qF "$1" "$repo/$batch/STOP.md"; } # stopmd <text>
stop_committed() { git -C "$repo" cat-file -e "HEAD:$batch/STOP.md" 2>/dev/null; }

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

# 11. A stop (a failed job) waits for the running wave review and commits its report. The
# job's report is seeded, so the runner resumes it and the case costs the failing wave only.
fixture waitreview
more_briefs runjob failjob
seed_report runjob
STUB_REVIEW_SLEEP_S=6 STUB_FAIL_BRIEF=failjob.md # still running when the stop comes at ~5 s
run_jobs
if [ "$rc" = 1 ] && logged "STOPPED: jobs that failed" &&
  git -C "$repo" cat-file -e "HEAD:$batch/wave1-review-report.md" 2>/dev/null &&
  [ -f "$tmp/waitreview/review-done" ]; then r=0; else r=1; fi
report "a stop waits for the running wave review and commits its report (exit 1)" "$r"

# 12. The STOP file is the one stop that kills a running review at once: no report is kept.
fixture stopreview
more_briefs runjob failjob
seed_report runjob
STUB_REVIEW_SLEEP_S=6 STUB_FAIL_BRIEF=failjob.md STUB_STOP_ON_FAIL=1
run_jobs
if [ "$rc" = 1 ] && logged "STOPPED: stop file" &&
  ! git -C "$repo" cat-file -e "HEAD:$batch/wave1-review-report.md" 2>/dev/null &&
  [ ! -f "$repo/$batch/wave1-review-report.md" ] && [ ! -f "$tmp/stopreview/review-done" ]; then r=0; else r=1; fi
report "a STOP-file stop kills the running wave review at once, with no report committed (exit 1)" "$r"

# 13. RUN_MAX_MIN stops the run's final review: the fake clock jumps while the review sleeps.
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
