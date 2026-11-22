#!/usr/bin/env bash
# Sourced by tools/run-jobs.sh, after it has cd'd to the repo root:
#   . "$dir/run-wave.sh"   (dir: the folder holding run-jobs.sh)
# The wait on one wave's jobs: one poll for every job the wave started, so each job's own limit
# is checked while any job of the wave runs. A job that passes its limit or fails stops alone: it
# is parked (logged, its process tree killed) and its siblings run on. At the wave's end the
# runner checks and commits the finished jobs, then stops naming the parked ones; they are not in
# done.txt, so a restart runs them again. The STOP file, RUN_MAX_MIN and a failed combined check
# still stop everything (tools/run-jobs.sh's check_stop and checks).
# A job over RUN_TURN_CAP turns whose own run ended with result 0 and a report is accepted with a
# WARN (its own checks passed; flash.sh's --max-turns stays the hard stop); over the cap with any
# other result it is parked.
# Not run on its own; it reads the runner's globals (B, LOGS, started, pids, since, limits,
# RUN_TURN_CAP, RUN_LIMIT_UNIT_S, RUN_POLL_S) and its note, stop, check_stop, kill_tree, usage,
# run_expected_min and apply_safe helpers, and writes its ok, extra and parked arrays.

job_limit_over() { # job_limit_over <index into started>: 0 when that job passed its own limit
  local i=$1
  [ "${limits[$i]}" -gt 0 ] || return 1
  [ $(($(date +%s) - ${since[$i]})) -ge "${limits[$i]}" ]
}

park() { # park <job>: the job stops alone; its siblings run on and the wave's end stops naming it
  parked+=("$1")
}

limit_stop() { # limit_stop <index>: park the job, naming its limit and its estimate; its siblings run on
  local i=$1 j
  j=${started[$i]}
  note "job $j passed its limit ($((${limits[$i]} / ${RUN_LIMIT_UNIT_S:-60})) min," \
    "estimate $(run_expected_min "$B/$j.md")) (parked, siblings continue)"
  kill_tree "${pids[$i]}"
  park "$j"
}

turn_cap() { # turn_cap <job> <rc>: the job's turns, from the usage row `usage` reads, against
  # RUN_TURN_CAP or its brief's `turns: <n>` line. Over the cap with result 0 and the job's report:
  # a WARN and 0 (accepted); over the cap with any other result: a park line and 1. No usage row
  # (a stand-in worker): nothing to count.
  local j=$1 rc=$2 t cap
  t=$(usage "$B/$j.md" | sed -n 's/^\([0-9][0-9]*\) turns.*/\1/p')
  [ -n "$t" ] || return 0
  cap=$(sed -n 's/^turns:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$B/$j.md" | head -n 1)
  case $cap in '' | 0) cap=$RUN_TURN_CAP ;; esac
  [ "$t" -gt "$cap" ] || return 0
  if [ "$rc" -eq 0 ] && [ -f "$B/$j-report.md" ]; then
    note "WARN: job $j used $t turns, over its cap of $cap (its own checks passed; accepted)"
    return 0
  fi
  note "job $j used $t turns, over its cap of $cap (parked, siblings continue)"
  return 1
}

finished_job() { # finished_job <index>: wait its exit, log it, cap it, then sort it into ok or parked
  local i=$1 j rc
  j=${started[$i]}
  wait "${pids[$i]}"; rc=$?
  note "$j finished: result $rc ($(usage "$B/$j.md"))"
  turn_cap "$j" "$rc" || { park "$j"; return; }
  if [ $rc -eq 4 ] && apply_safe "$j" "$LOGS/flash-$j.log"; then
    [ -n "$DROPPED" ] && note "$j: dropped generated churn outside its list: $DROPPED"
    [ -n "$APPLIED" ] && note "$j: applied always-fine files outside its list: $APPLIED"
    extra+=($APPLIED); rc=0
  fi
  if [ $rc -eq 0 ] && [ -f "$B/$j-report.md" ]; then ok+=("$j")
  else note "job $j parked (result $rc); its siblings continue"; park "$j"; fi
}

wave_wait() { # wave_wait: the poll on every started job: each job's limit, the STOP file, then its exit
  local pending=("${!pids[@]}") i rest
  while [ ${#pending[@]} -gt 0 ]; do
    check_stop
    rest=()
    for i in "${pending[@]}"; do
      if job_limit_over "$i"; then limit_stop "$i"; else rest+=("$i"); fi # a parked job is not waited for
    done
    pending=("${rest[@]}")
    rest=()
    for i in "${pending[@]}"; do
      if kill -0 "${pids[$i]}" 2>/dev/null; then rest+=("$i"); else finished_job "$i"; fi
    done
    pending=("${rest[@]}")
    [ ${#pending[@]} -gt 0 ] && sleep "${RUN_POLL_S:-5}"
  done
}
