# Sourced by tools/run-jobs.sh (when present, after run-wave.sh), never run on its own. tune4 (Nov 25).
# It reads the runner's globals (B, LOGS, WORK, RUN_LIMIT_UNIT_S) and its note helper.
#
# phase <name>: M2. One `phase: <name> (<prev> took <n>s)` line in run.log at each step change (preflight, worker,
# tests-first, check, review, apply), so a long pause between two lines can be put on a phase: the time of the
# line is the phase start, `took` closes the one before. Idle time and the driver's own time then show in the gaps.
#
# job_idle_over <index into started>: T2, the hung-job guard. 0 when the job has shown no sign of life for
# RUN_JOB_IDLE_MIN minutes (default 10; a minute is RUN_LIMIT_UNIT_S seconds, 60 by default): no file of its job
# worktree (the flash log names it: `job worktree <path>`) and no flash log of the batch has changed since the
# last sign. Not a wall limit: a job that keeps writing files is never hung, however long it runs. The check
# itself runs at most every RUN_IDLE_POLL_S seconds (default 30), the file scan is one `find -newer`.

PHASE_NAME="" PHASE_AT=0
phase() { # phase <name>
  local now prev=""
  now=$(date +%s)
  [ -n "$PHASE_NAME" ] && prev=" ($PHASE_NAME took $((now - PHASE_AT))s)"
  PHASE_NAME=$1 PHASE_AT=$now
  note "phase: $1$prev"
}

declare -A IDLE_LAST IDLE_POLLED # by job name: a job of the next wave starts with a fresh clock
job_idle_over() { # job_idle_over <index>
  local i=$1 j now unit idle ref wt f
  j=${started[$i]}
  kill -0 "${pids[$i]}" 2> /dev/null || return 1 # a job that already ended is the exit check's, not hung
  now=$(date +%s)
  unit=${RUN_LIMIT_UNIT_S:-60}
  idle=$(( ${RUN_JOB_IDLE_MIN:-10} * unit ))
  ref="$WORK/idle-$j.ref"
  if [ -z "${IDLE_LAST[$j]:-}" ]; then IDLE_LAST[$j]=$now IDLE_POLLED[$j]=$now; : > "$ref"; return 1; fi
  [ $((now - ${IDLE_POLLED[$j]})) -ge "${RUN_IDLE_POLL_S:-30}" ] || return 1
  IDLE_POLLED[$j]=$now
  wt=$(sed -n 's/^---- flash: job worktree //p' "$LOGS/flash-$j.log" 2> /dev/null | tail -n 1 | tr -d '\r')
  f=$(find "$LOGS/flash-$j.log" ${wt:+"$wt"} -newer "$ref" -type f -print -quit 2> /dev/null)
  if [ -n "$f" ]; then IDLE_LAST[$j]=$now; : > "$ref"; return 1; fi
  [ $((now - ${IDLE_LAST[$j]})) -ge "$idle" ]
}

idle_stop() { # idle_stop <index>: log "hung", kill the job's tree, park it; its siblings run on
  local i=$1 j
  j=${started[$i]}
  note "job $j hung: no file of its worktree or log changed for ${RUN_JOB_IDLE_MIN:-10} min (RUN_JOB_IDLE_MIN) (parked, siblings continue)"
  kill_tree "${pids[$i]}"
  park "$j"
}
