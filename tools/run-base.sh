#!/usr/bin/env bash
# The base check: before each wave the runner proves the base still compiles, because the jobs of
# one wave are cut from the same last commit and every job's `check:` suites compile against the
# whole workspace (identity1 wave 1b: i1b's own check could never pass on a base without i1a2's
# compile fix, and the job ran 60 min). Sourced, no side effects of its own:
#   . tools/run-base.sh && run_base_check <log>   # 0 when the base passes, else RUN_BASE_WHY says why
# run_base_check runs ${RUN_BASE_CHECK_CMD:-bash tools/check.sh --fail-fast format analyze} (the
# base is the repository's last commit, which is what the wave's job folders are cut from) with its
# output in <log>, for at most RUN_BASE_CHECK_MAX_MIN "minutes" of RUN_LIMIT_UNIT_S seconds
# (tools/run-limits.sh; 5 min by default). It returns non-zero on a failure or on that limit, which
# kills the check's whole process tree, and leaves one line for the runner's stop message in
# RUN_BASE_WHY: "does not compile: <the log's first failing line>" or
# "check passed its limit (RUN_BASE_CHECK_MAX_MIN=<n> min)". tools/run-jobs.sh sources it next to
# tools/run-limits.sh and calls it before every wave; RUN_BASE_CHECK_SKIP=1 is the caller's skip.

# The default, validated as tools/run-limits.sh validates its own knobs (that file may be missing
# in a folder that holds only the runner's files).
RUN_BASE_CHECK_MAX_MIN=${RUN_BASE_CHECK_MAX_MIN:-5}
case $RUN_BASE_CHECK_MAX_MIN in '' | *[!0-9]*) RUN_BASE_CHECK_MAX_MIN=5 ;; esac

run_base_why() { # run_base_why <log>: the log's first failing line, else its first line
  local line
  line=$(grep -m 1 -E '^FAIL|error:|Error:|error - ' "${1:-}" 2> /dev/null)
  [ -n "$line" ] || line=$(grep -m 1 '[^[:space:]]' "${1:-}" 2> /dev/null)
  printf '%s\n' "${line:-no output}"
}

run_base_check() { # run_base_check <log>: the base's format and analyze (see the header)
  local log=${1:?} limit_s start pid rc
  RUN_BASE_WHY=""
  limit_s=$((RUN_BASE_CHECK_MAX_MIN * ${RUN_LIMIT_UNIT_S:-60}))
  [ "$limit_s" -gt 0 ] || limit_s=1 # a 0 s limit would refuse every base at once
  ${RUN_BASE_CHECK_CMD:-bash tools/check.sh --fail-fast format analyze} > "$log" 2>&1 &
  pid=$!
  start=$(date +%s)
  while kill -0 "$pid" 2> /dev/null; do
    if [ $(($(date +%s) - start)) -ge "$limit_s" ]; then
      # The runner's tree kill when it is there (it defines kill_tree before its first wave).
      if declare -F kill_tree > /dev/null; then kill_tree "$pid"; else kill "$pid" 2> /dev/null; fi
      wait "$pid" 2> /dev/null
      RUN_BASE_WHY="check passed its limit (RUN_BASE_CHECK_MAX_MIN=$RUN_BASE_CHECK_MAX_MIN min)"
      return 3
    fi
    sleep "${RUN_POLL_S:-5}"
  done
  wait "$pid"
  rc=$?
  [ "$rc" -eq 0 ] && return 0
  RUN_BASE_WHY="does not compile: $(run_base_why "$log")"
  return 1
}
