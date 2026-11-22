#!/usr/bin/env bash
# The unattended job runner for flash-worker (low-usage mode). It runs a folder
# of briefs in waves, checks and commits each job, has a second cheap worker
# review each job and then the whole run, and stops only when a person or
# Claude is truly needed. The framework is described in docs/flash-framework.md.
#
#   tools/run-jobs.sh <briefs-dir> [--logs <dir>] [--no-review] [--dry-run]
#   tools/run-jobs.sh <briefs-dir> --drop <job>   (never run <job>; appends to dropped.txt)
#   touch <briefs-dir>/STOP   (stops a running runner between steps; never kill it)
#
# <briefs-dir>/waves.txt: one wave per line, job names (brief files without
# .md) separated by spaces; `#` starts a comment. Jobs of one wave run at the
# same time (at most 3) and must share no files.
#
# For each wave:
#   1. start the jobs (tools/flash.sh --brief); a job listed in <briefs-dir>/done.txt
#      (`<job> <sha>`, written after its commit; older batches without a done.txt: a
#      committed report) or in dropped.txt is skipped, so the runner is safe to start again;
#   2. a job that stopped with result 4 (files outside its allow: list): known
#      generated churn (CHURN_OUTSIDE, from tools/churn.sh: library and m13 PNGs,
#      site/shots, run-base, tv plugin files, stray run-*.patch, a test-written
#      *-results.json) is dropped, one log line per job, so such a job is applied
#      and never a stop; always-fine files (SAFE_OUTSIDE: analysis_options,
#      .gitignore, .gitattributes, pubspec.lock) are applied; any other file stops;
#   3. new test files are run against the old code: one that passes there was
#      not written test-first and STOPS the run, unless the job's brief has a
#      line `tests-first: exempt <reason>` (pure refactors, docs) and the test
#      lies under one of its allow: paths;
#   4. tools/check.sh on the combined tree (a failing suite, but never format or
#      analyze, is tried once more with the packages fetched), then
#      tools/review.sh: any FAIL, or a touched lib file over SIZE_STOP lines, stops the run;
#   5. each job is committed and pushed (tools/commit-job.sh --push);
#   6. a reviewer job per committed job writes <job>-review-report.md. Reviews run
#      in the background while the next wave works (at most 3 flash jobs in all,
#      the review chain counting as one); their report files are committed at the
#      next serial point (after the next wave commit), staging only those files.
#      A plan with a single wave skips this review: the run review covers it.
# At the end one more worker job reads everything since the run's first commit
# and writes <briefs-dir>/REVIEW.md; it runs in the background under the same 5 s
# check_stop poll as a job, so RUN_MAX_MIN stops a stuck review. Claude reads its
# Summary and writes one fix brief. Progress and stops: <briefs-dir>/run.log (a
# STOPPED line with no later `start at` line needs attention).
# Working files (run-base, run-check.log, run-review.log, run-commit.log, patches,
# markers) live in .dart_tool/run-jobs/<briefs-dir name> (gitignored), never in the
# briefs dir; RUN_WORK overrides. run-base is set once, at the batch's first start
# (also logged in run.log as `run-base <sha>`, so a fresh clone can recover it).
# run.log IS committed (force-added) at every serial point, at a stop and at the
# end, so STOPPED, HAND-FIX and final-check lines survive. A job committed by hand
# after a stop is marked by a `HAND-FIX <job>: <what>` line in run.log (or a file
# <briefs-dir>/<job>-handfixed, or a `Hand-fixed:` line in the commit message);
# on a restart the runner logs a WARN and runs that job's tests-first proof and
# worker review instead of skipping it. Review jobs drop generated churn too.
# The patch taken from a result-4 job's kept folder holds only the brief's allow:
# and report: paths plus the always-fine files (a folder cut from a dirty tree
# also carries stray edits, which made `git apply` fail on a fix job).
# Before the first wave a preflight (tools/flash.sh --preflight, a tiny real worker call) must show the
# worker can run flutter and tools/check.sh; PREFLIGHT_SKIP=1 skips it. A failed suite is tried
# once more; PathNotFoundException (temp-folder race) retries at once, format and analyze never do.
# Before every wave the base check (tools/run-base.sh: format and analyze of the last commit) must pass; RUN_BASE_CHECK_SKIP=1 skips it.
# Before the preflight every brief's report: line is linted: it must be exactly one bare path
# (no second report: line, no words after the path), or the run stops before wave 1.
# STOP file: <briefs-dir>/STOP is checked before each wave, job start, review and commit; when
# present the runner kills its child processes at once, logs `STOPPED: stop file` and exits 1;
# the file is removed at the next start. Every other stop waits for a running wave review and
# commits its report before killing, so no review is lost. Never revert a job's commits
# without `--drop <job>` first.
# Every stop writes <briefs-dir>/STOP.md through tools/run-stop.sh (why, the failing lines, the
# last run.log lines, a suggested repair) and commits it; the next start removes and commits it.
# One runner per batch: the work folder's lock holds its pid, so a second runner on the same
# batch exits 2 with `RESULT: refused, a run is active (pid N)`; a lock whose pid is gone is
# replaced. Time limits (tools/run-limits.sh): RUN_MAX_MIN minutes is the run's (an explicit value,
# else the computed backstop: the undone jobs' estimates +25%, logged at the start), and past it
# `STOPPED: TIMEOUT`. A job's is its `expected-min:` x1.5: `job <j> passed its limit (<n> min,
# estimate <m>)`. A job over RUN_TURN_CAP turns (120; a brief line `turns: <n>` raises it) stops
# the run after it, before its checks. Every run ends with `RESULT: DONE: <n> jobs, <m> min` or
# `RESULT: STOPPED: <cause>`, printed and in run.log. FLASH_CMD (default tools/flash.sh) runs the
# preflight and every job, so a stand-in worker can drive a run.
# NO_PUSH=1 in the environment commits without pushing.
# Its step and review helpers live next to it in tools/run-steps.sh and
# tools/run-review.sh, sourced after the cd to the repo root below.
# Exit code: 0 done, 1 stopped, 2 bad use.
set -u
unset CHECK_ANALYZE_PKGS # the runner always analyzes the whole workspace (flash.sh scopes the workers' own analyze)
dir=$(cd "$(dirname "$0")" && pwd) || exit 2
cd "$dir/.." || exit 2
. "$dir/churn.sh" || exit 2
. "$dir/run-steps.sh" || exit 2
. "$dir/run-review.sh" || exit 2
# The per-step limits and the backstop. A folder holding only the runner's files, as the fixture
# copies in tools/tests do, has no run-limits.sh: no limit of its own, as before they existed.
[ -f "$dir/run-limits.sh" ] && . "$dir/run-limits.sh"
[ -f "$dir/run-base.sh" ] && . "$dir/run-base.sh" # the base check; an older fixture has no such file
# Files outside a job's allow: list that are applied and committed (always fine).
SAFE_OUTSIDE='^(([^/]+/)*analysis_options\.yaml|\.gitignore|\.gitattributes|([^/]+/)*pubspec\.lock)$'
# Known generated churn outside the list: dropped (never copied), logged per job. The one
# list is tools/churn.sh's, sourced above: CHURN_REGEX and CHURN_PATHS (the unchurn below).
CHURN_OUTSIDE=$CHURN_REGEX
unchurn() { git checkout -- "${CHURN_PATHS[@]}" 2>/dev/null; }
SIZE_STOP=380
RUN_TURN_CAP=${RUN_TURN_CAP:-120} # the most turns one job may take; a brief line `turns: <n>` raises it for that job
# A brief's report: line must be exactly one bare path (spaces, quotes and backticks are refused).
REPORT_BARE='^[^[:space:]`"'\'']+$'

B="" LOGS="" review=1 dry=0 drop=""
while [ $# -gt 0 ]; do
  case "$1" in
    --logs) LOGS=${2:?}; shift 2 ;;
    --no-review) review=0; shift ;;
    --dry-run) dry=1; shift ;;
    --drop) drop=${2:?}; shift 2 ;;
    -h|--help) sed -n '2,81p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
    *) B=${1%/}; shift ;;
  esac
done
if [ -n "$drop" ] && [ -n "$B" ] && [ -d "$B" ]; then
  echo "$drop" >> "$B/dropped.txt"; echo "dropped $drop: $B/dropped.txt (commit it)"; exit 0
fi
[ -n "$B" ] && [ -f "$B/waves.txt" ] || { echo "Usage: tools/run-jobs.sh <briefs-dir> (it needs <briefs-dir>/waves.txt)" >&2; exit 2; }
LOGS=${LOGS:-$B}
WORK=${RUN_WORK:-.dart_tool/run-jobs/${B//\//_}}
mkdir -p "$WORK"
RUN_MAX_MIN=${RUN_MAX_MIN:-} # empty: the computed backstop, set at the start below
case $RUN_MAX_MIN in *[!0-9]*) echo "RUN_MAX_MIN takes whole minutes; using the backstop" >&2; RUN_MAX_MIN="" ;; esac
RUN_START_S=$(date +%s) # the run's time limit counts from here (time_check)
mapfile -t WAVES < <(sed 's/#.*//' "$B/waves.txt" | awk 'NF')

note() { echo "$(date '+%F %T') $*" | tee -a "$B/run.log"; }
result() { echo "RESULT: $*" | tee -a "$B/run.log"; } # the last line of every run, printed and in run.log
kill_tree() { local c; for c in $(ps -ef 2>/dev/null | awk -v p="$1" '$3==p{print $2}'); do kill_tree "$c"; done; kill "$1" 2>/dev/null; }
check_stop() { # the time limit first, then the STOP file: either one stops the run
  time_check
  [ -f "$B/STOP" ] || return 0
  stop "stop file"
}
handfixed() { # handfixed <job>: was its commit made by hand after a stop?
  [ -f "$B/$1-handfixed" ] && return 0
  # only the job named right after "HAND-FIX " counts, never a free-text mention of it
  grep -qE "(^|[^A-Za-z0-9_-])HAND-FIX $1:" "$B/run.log" 2>/dev/null && return 0
  git log -1 --format=%B -- "$B/$1-report.md" | grep -qi '^Hand-fixed:'
}
is_done() { # is_done <job>: in done.txt; no done.txt (older batch): report committed at HEAD
  if [ -f "$B/done.txt" ]; then
    grep -q "^$1 " "$B/done.txt" && return 0
    handfixed "$1" && committed "$B/$1-report.md"; return
  fi
  committed "$B/$1-report.md"
}
is_dropped() { grep -qxF "$1" "$B/dropped.txt" 2>/dev/null; }
stop() { # stop <cause> [flash-log]: STOP.md first, then the children; the STOP file kills at once
  local cause=$1 log=${2:-} p
  note "STOPPED: $cause"
  write_stop "$cause" "$log"
  # A wave review running in the background holds another job's work: let it finish and flush
  # its report before the kill, or that report is lost. The STOP file is the one cause that
  # kills at once, because a person asking for the run to end wants it gone now.
  case $cause in "stop file") ;; *) flush_reviews wait ;; esac
  for p in $(jobs -p); do kill_tree "$p"; done
  wait 2>/dev/null; flush_reviews
  result "STOPPED: $cause"
  save_stop "runner: log and STOP.md at a stop"
  exit 1
}
finding() { echo "- $*" >> "$B/run-findings.md"; note "finding: $*"; }
usage() { # usage <brief path>: the job's turns and minutes, from the flash usage log
  awk -F'	' -v b="$1" 'index($10, b){t=$3; m=$4/60} END{if(t) printf "%d turns, %.0f min", t, m}' "${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}" 2>/dev/null
}
# turn_cap <job>: the job's turns, from the usage row `usage` reads, against RUN_TURN_CAP or its
# brief's `turns: <n>` line; more turns than the cap stops the run. No usage row (a stand-in
# worker): nothing to count.
turn_cap() {
  local t cap
  t=$(usage "$B/$1.md" | sed -n 's/^\([0-9][0-9]*\) turns.*/\1/p')
  [ -n "$t" ] || return 0
  cap=$(sed -n 's/^turns:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$B/$1.md" | head -n 1)
  case $cap in '' | 0) cap=$RUN_TURN_CAP ;; esac
  [ "$t" -le "$cap" ] || stop "job $1 used $t turns, over its cap of $cap"
}
# The wave's wait: one poll for every job it started, so a job's own limit is checked while
# any job of the wave runs. The per-job loop this replaced waited the jobs one after another
# and only tested the one it was waiting on, so a later job passed its limit unseen (p3e ran
# 48 min against 30 while p3d's job was waited out).
job_limit_over() { # job_limit_over <index into started>: 0 when that job passed its own limit
  local i=$1
  [ "${limits[$i]}" -gt 0 ] || return 1
  [ $(($(date +%s) - ${since[$i]})) -ge "${limits[$i]}" ]
}
limit_stop() { # limit_stop <index>: the job's limit stop, naming it and its estimate
  local i=$1 j
  j=${started[$i]}
  stop "job $j passed its limit ($((${limits[$i]} / ${RUN_LIMIT_UNIT_S:-60})) min, estimate $(run_expected_min "$B/$j.md"))"
}
finished_job() { # finished_job <index>: wait its exit, log it, cap it, then sort it into ok or failed
  local i=$1 j rc
  j=${started[$i]}
  wait "${pids[$i]}"; rc=$?
  note "$j finished: result $rc ($(usage "$B/$j.md"))"
  turn_cap "$j" # before the checks: a job over its turn cap is a stop of its own
  if [ $rc -eq 4 ] && apply_safe "$j" "$LOGS/flash-$j.log"; then
    [ -n "$DROPPED" ] && note "$j: dropped generated churn outside its list: $DROPPED"
    [ -n "$APPLIED" ] && note "$j: applied always-fine files outside its list: $APPLIED"
    extra+=($APPLIED); rc=0
  fi
  if [ $rc -eq 0 ] && [ -f "$B/$j-report.md" ]; then ok+=("$j"); else failed+=("$j:$rc"); fi
}
committed() { git cat-file -e "HEAD:$1" 2>/dev/null; }
save() { # save <message> <path>...: commit and push just these paths
  local msg=$1; shift
  git reset -q; git add -A -f -- "$@" 2>/dev/null
  git diff --cached --quiet && return 0
  git commit -q -m "$msg" && { [ -n "${NO_PUSH:-}" ] || git push -q origin "HEAD:refs/heads/$(git rev-parse --abbrev-ref HEAD)"; }
}
report_bad() { # report_bad <job>: why the brief's report: line is not one bare path (nothing when it is)
  local n v
  n=$(grep -c '^report:' "$B/$1.md")
  [ "$n" -eq 0 ] && { echo "no report: line"; return; }
  [ "$n" -gt 1 ] && { echo "two report: lines"; return; }
  v=$(sed -n 's/^report: *//p' "$B/$1.md" | tr -d '\r')
  [[ $v =~ $REPORT_BARE ]] || echo "${v:-nothing after report:}"
}
brief_lint() { # brief_lint: every job still to run has exactly one bare report: path; a dry run prints LINT FAIL lines
  local wave j why bad=0
  for wave in "${WAVES[@]}"; do
    for j in $wave; do
      if is_dropped "$j" || is_done "$j"; then continue; fi
      [ -f "$B/$j.md" ] || continue # the wave loop's own message covers a missing brief
      why=$(report_bad "$j"); [ -n "$why" ] || continue
      bad=1
      if [ $dry -eq 1 ]; then echo "LINT FAIL $j: report: line must be exactly one bare path (got: $why)"
      else note "STOPPED: brief lint: $j: report: line must be exactly one bare path (got: $why)"; fi
    done
  done
  return $bad
}

if [ $dry -eq 1 ]; then
  n=0
  for wave in "${WAVES[@]}"; do
    n=$((n + 1)); echo "wave $n:"
    for j in $wave; do
      [ -f "$B/$j.md" ] || { echo "  $j: MISSING $B/$j.md"; continue; }
      if is_dropped "$j"; then echo "  $j: skip (dropped)"; elif is_done "$j"; then echo "  $j: skip (committed)"; else echo "  $j: run"; fi
    done
  done
  brief_lint
  echo "then: the run's review -> $B/REVIEW.md"; exit 0
fi

# The review state that the helpers in tools/run-review.sh write and read.
RV_NAMES=()   # the jobs (and their commit ranges) the next wave review covers
RV_RANGES=()
PENDING=()    # jobs whose review was started and whose report is not committed yet
REVPIDS=()    # the background review chains' pids
DROPPED="" APPLIED="" # set by apply_safe (tools/run-steps.sh): churn dropped, always-fine files applied

handfix_recheck() { # handfix_recheck <job>: the proof and review a hand commit skipped; once per job
  local j=$1 c
  [ -f "$WORK/rechecked-$j" ] && return 0
  grep -q "^$j .* proof\$" "$B/done.txt" 2>/dev/null && return 0 # also survives a fresh clone
  c=$(git log -1 --format=%H -- "$B/$j-report.md")
  note "WARN: $j was committed by hand ($(git rev-parse --short "$c")); a plain restart would skip its tests-first proof and worker review, so both run now"
  TF_COMMIT=$c tests_first "$j"
  # its worker review joins the wave's review (one per wave, not one per hand-fixed job)
  if [ $review -eq 1 ] && ! committed "$B/$j-review-report.md"; then RV_NAMES+=("$j"); RV_RANGES+=("$c^..$c"); fi
  : > "$WORK/rechecked-$j"
  # the marker in done.txt: a restart (or a fresh clone) does not repeat the proof and the review
  echo "$j $c proof" >> "$B/done.txt"; save "runner: proof and review of hand-fixed $j done" "$B/done.txt"
  note "hand-fixed $j: tests-first proof and worker review done (marked in done.txt)"
}

# The run's own limit: an explicit RUN_MAX_MIN wins, else the computed backstop of the jobs still
# to do. A folder without run-limits.sh keeps the fixed 360, and no job left keeps one job's time.
if [ -z "$RUN_MAX_MIN" ] && declare -F run_backstop_min > /dev/null; then
  RUN_MAX_MIN=$(run_backstop_min "$B/waves.txt")
  [ "$RUN_MAX_MIN" -ge "$RUN_EXPECT_DEFAULT_MIN" ] || RUN_MAX_MIN=$RUN_EXPECT_DEFAULT_MIN
  note "RUN_MAX_MIN=$RUN_MAX_MIN min (computed backstop of the jobs still to do)"
fi
[ -n "$RUN_MAX_MIN" ] || RUN_MAX_MIN=360

lock_take # after the dry run, which changes nothing: a second runner on this batch exits 2 here
branch=$(git rev-parse --abbrev-ref HEAD)
note "start at $(git rev-parse --short HEAD) on $branch"
[ -f "$B/STOP" ] && { rm -f "$B/STOP"; note "removed the old stop file"; }
clear_last_stop
if [ ! -s "$WORK/run-base" ]; then # once, at the batch's first start; recovered from run.log on a fresh clone
  sed -n 's/.* run-base \([0-9a-f]\{7,40\}\)$//p' "$B/run.log" 2>/dev/null | head -n 1 > "$WORK/run-base"
  [ -s "$WORK/run-base" ] || { [ -s "$B/run-base" ] && cp "$B/run-base" "$WORK/run-base" || git rev-parse HEAD > "$WORK/run-base"; }
  note "run-base $(cat "$WORK/run-base")"
fi
[ -f .dart_tool/package_config.json ] || { note "fetching packages (new folder)"; flutter pub get > "$WORK/run-pub.log" 2>&1; }
for r in "$B"/*-review-report.md; do # reports of an earlier run that stopped before it could commit them
  [ -f "$r" ] && ! committed "$r" && { save "review report left by an earlier run: $(basename "$r")" "$r"; note "committed the left-over $(basename "$r")"; }
done

# Brief lint: the runner commits the report: path whole, so it must be exactly one bare path.
brief_lint || lint_stop

# Preflight: a worker that cannot run flutter and tools/check.sh would run blind (bugs10 job 1),
# so one tiny real worker call proves it before any job starts. PREFLIGHT_SKIP=1 skips it.
if [ -z "${PREFLIGHT_SKIP:-}" ]; then
  if ${FLASH_CMD:-tools/flash.sh} --preflight > "$WORK/run-preflight.log" 2>&1; then note "preflight ok: the worker ran flutter --version and tools/check.sh --list"
  else stop "preflight failed: the worker cannot run flutter or tools/check.sh in its sandbox, so no job would run tests (see $WORK/run-preflight.log); nothing was started"; fi
fi

wn=0
for wave in "${WAVES[@]}"; do
  wn=$((wn + 1))
  check_stop
  if [ -n "${RUN_BASE_CHECK_SKIP:-}" ]; then note "base check skipped (RUN_BASE_CHECK_SKIP)"
  elif declare -F run_base_check > /dev/null; then
    run_base_check "$WORK/run-base-check.log" ||
      stop "the base $RUN_BASE_WHY (log $WORK/run-base-check.log); no job of wave $wn was started" \
        "$WORK/run-base-check.log"
  fi
  [ "$(wc -w <<< "$wave")" -le 3 ] || stop "a wave has more than 3 jobs: $wave"
  started=() pids=() since=() resumed=()
  for j in $wave; do
    check_stop
    is_dropped "$j" && { note "skip $j (dropped)"; continue; }
    [ -f "$B/$j.md" ] || stop "no brief $B/$j.md"
    committed "$B/$j.md" || stop "the brief $B/$j.md is not committed (job folders are cut from the last commit)"
    if is_done "$j"; then
      if committed "$B/$j-report.md" && handfixed "$j"; then handfix_recheck "$j"; fi
      note "skip $j (already done)"; continue
    fi
    if [ -f "$B/$j-report.md" ]; then note "resume $j (applied by hand, not committed yet)"; resumed+=("$j"); continue; fi
    slot_wait
    [ ${#started[@]} -gt 0 ] && { sleep 25; check_stop; }
    note "start $j"
    since+=("$(date +%s)") # the job's limit counts from here
    ${FLASH_CMD:-tools/flash.sh} --brief "$B/$j.md" > "$LOGS/flash-$j.log" 2>&1 &
    pids+=($!) started+=("$j")
  done
  if [ ${#started[@]} -eq 0 ] && [ ${#resumed[@]} -eq 0 ]; then
    # nothing ran; a hand-fixed job rechecked above still gets its worker review (one for the wave)
    wave_review "$wn"
    if [ -n "$WREV" ]; then
      save "runner: log and review brief for hand-fixed jobs of wave $wn" "$B/run.log" "$B/done.txt" "$B/$WREV-review.md"
      check_stop; start_reviews "$WREV"
    fi
    continue
  fi
  ok=("${resumed[@]}") failed=() extra=()
  limits=() # each started job's own limit in seconds; 0 (no run-limits.sh): STOP file only
  for i in "${!started[@]}"; do
    limits[$i]=0
    declare -F run_job_limit_s > /dev/null && limits[$i]=$(run_job_limit_s "$B/${started[$i]}.md")
  done
  pending=("${!pids[@]}")
  while [ ${#pending[@]} -gt 0 ]; do # one poll: every job's limit, the STOP file, then exits
    check_stop
    for i in "${pending[@]}"; do job_limit_over "$i" && limit_stop "$i"; done
    rest=()
    for i in "${pending[@]}"; do
      if kill -0 "${pids[$i]}" 2>/dev/null; then rest+=("$i"); else finished_job "$i"; fi
    done
    pending=("${rest[@]}")
    [ ${#pending[@]} -gt 0 ] && sleep "${RUN_POLL_S:-5}"
  done
  if [ ${#ok[@]} -gt 0 ]; then
    unchurn
    dart_fix "${ok[@]}"
    tests_first "${ok[@]}"
    checks "${ok[*]}"
    for j in "${ok[@]}"; do ci_patch "$j"; done
    reviewed=()
    wave_from=$(git rev-parse HEAD)
    for j in "${ok[@]}"; do
      head -n 40 "$B/$j-report.md" | grep -q '^## Summary' || finding "$j's report has no Summary block in its first 40 lines"
      check_stop
      tools/commit-job.sh "$B/$j.md" $([ -n "${NO_PUSH:-}" ] || echo --push) >> "$WORK/run-commit.log" 2>&1 || stop "commit of $j refused (see $WORK/run-commit.log)"
      note "committed $j: $(git log --oneline -1)"
      echo "$j $(git rev-parse HEAD)" >> "$B/done.txt"
    done
    # one worker review per wave, over all the jobs committed in it (and any hand-fixed job rechecked in it)
    RV_NAMES+=("${ok[@]}"); RV_RANGES+=("$wave_from..$(git rev-parse HEAD)")
    wave_review "$wn"; [ -n "$WREV" ] && reviewed+=("$WREV")
    [ ${#extra[@]} -gt 0 ] && save "files outside the jobs' lists, applied by the runner (always-fine list): ${ok[*]}" "${extra[@]}"
    paths=("$B/run.log" "$B/done.txt"); [ -f "$B/run-findings.md" ] && paths+=("$B/run-findings.md")
    for j in "${reviewed[@]}"; do paths+=("$B/$j-review.md"); done
    save "runner: log and review briefs after ${ok[*]}" "${paths[@]}"
    flush_reviews
    check_stop
    [ ${#reviewed[@]} -gt 0 ] && start_reviews "${reviewed[@]}"
  fi
  if [ ${#failed[@]} -gt 0 ]; then # the first failed job's log goes into STOP.md, quoted by its outside block
    stop "jobs that failed or need applying by hand: ${failed[*]} (their logs: $LOGS/flash-<job>.log)" \
      "$LOGS/flash-${failed[0]%%:*}.log"
  fi
done

flush_reviews wait
check_stop
[ $review -eq 1 ] && ! committed "$B/REVIEW.md" && final_review
note "DONE: every job is committed. Claude reads the Summary of $B/REVIEW.md, verifies its findings and writes one fix brief"
result "DONE: $(printf '%s\n' "${WAVES[@]}" | wc -w) jobs, $(( ($(date +%s) - RUN_START_S) / 60 )) min"
paths=("$B/run.log"); [ -f "$B/run-findings.md" ] && paths+=("$B/run-findings.md")
save "runner: log at the end of the run" "${paths[@]}"
