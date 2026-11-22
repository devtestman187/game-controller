#!/usr/bin/env bash
# The per-step time limits of one run, and where they come from. Sourced, no side effects:
#   . tools/run-limits.sh                          # sets the RUN_* values below, adds no work
#   . tools/run-limits.sh && run_expected_min x.md # a job's estimate, its limit, the backstop
# tools/run-jobs.sh and its helpers (tools/run-steps.sh, tools/run-review.sh) source it after
# the cd to the repo root. Every limit counts in RUN_LIMIT_UNIT_S-second "minutes", so a test
# sets RUN_LIMIT_UNIT_S=1 and a 12 min limit runs out in 12 s.
#
# Four helpers, each printing one whole number of minutes on stdout (the one that prints
# seconds says so), whatever RUN_LIMIT_UNIT_S is:
#   run_expected_min <brief>     a job's minutes: the higher of its brief's `expected-min:` line
#                                and its usage median (below), else RUN_EXPECT_DEFAULT_MIN;
#                                a job whose brief is named f<job> is at least RUN_FIX_FLOOR_MIN
#   run_usage_median_min <brief> the median of its last RUN_RECENT_ROWS usage rows, or nothing
#                                when it has none and when that median is under a minute (so
#                                short runs say nothing about a whole job)
#   run_job_limit_s <brief>      the seconds it may run: its expected minutes x RUN_JOB_FACTOR_PCT
#   run_backstop_min <waves.txt> the whole run's minutes: the estimates of the jobs in waves.txt
#                                that are in neither done.txt nor dropped.txt, +25% (rounded up),
#                                and at least RUN_BACKSTOP_FLOOR_MIN while a job is left;
#                                0 when there is no waves.txt (the runner refuses such a batch)
#
# Env knobs, each a whole number (anything else keeps the default):
#   RUN_JOB_FACTOR_PCT 150      a job's limit over its estimate (owner, Nov 22)
#   RUN_FIX_FLOOR_MIN 25        the least a fix job is estimated at (owner, Nov 22)
#   RUN_BACKSTOP_FLOOR_MIN 45   the least a run with a job left is allowed (owner, Nov 22)
#   RUN_CHECK_MAX_MIN 20        the combined check (tools/check.sh) and its one retry
#   RUN_REVIEW_MAX_MIN 10       one worker review (a wave's or the run's)
#   RUN_EXPECT_DEFAULT_MIN 20   a job with no expected-min: line and no usable usage rows
#   RUN_POLL_S 5                how often a step waiting in the background looks again
#   RUN_LIMIT_UNIT_S 60         seconds in one limit "minute" (a test sets 1)
#   RUN_RECENT_ROWS 30          the job's last usage rows the median is taken from
#   FLASH_USAGE_LOG (~/.thumbparty/flash-usage.tsv)  the rows that median is taken from
# RUN_CHECK_MAX_MIN, RUN_REVIEW_MAX_MIN and RUN_POLL_S are only named here: the steps that
# wait (tools/run-steps.sh's check_once, tools/run-review.sh's run_review) read them.

# The owner's backstop (Nov 22): the whole run gets the estimates of the jobs still to do +25%.
RUN_BACKSTOP_PCT=125

run_number() { # run_number <value> <default>: <value> when it is a whole number, else <default>
  case ${1:-} in
    '' | *[!0-9]*) printf '%s\n' "$2" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

RUN_JOB_FACTOR_PCT=$(run_number "${RUN_JOB_FACTOR_PCT:-}" 150)
RUN_FIX_FLOOR_MIN=$(run_number "${RUN_FIX_FLOOR_MIN:-}" 25)
RUN_BACKSTOP_FLOOR_MIN=$(run_number "${RUN_BACKSTOP_FLOOR_MIN:-}" 45)
RUN_CHECK_MAX_MIN=$(run_number "${RUN_CHECK_MAX_MIN:-}" 20)
RUN_REVIEW_MAX_MIN=$(run_number "${RUN_REVIEW_MAX_MIN:-}" 10)
RUN_EXPECT_DEFAULT_MIN=$(run_number "${RUN_EXPECT_DEFAULT_MIN:-}" 20)
RUN_POLL_S=$(run_number "${RUN_POLL_S:-}" 5)
RUN_LIMIT_UNIT_S=$(run_number "${RUN_LIMIT_UNIT_S:-}" 60)
RUN_RECENT_ROWS=$(run_number "${RUN_RECENT_ROWS:-}" 30)
FLASH_USAGE_LOG=${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}

run_is_fix_job() { # run_is_fix_job <brief>: true when its name is f<job>, as fix jobs are named
  local base=${1:-}
  base=${base##*/}
  base=${base%.md}
  [[ $base =~ ^f[0-9]+$ ]]
}

run_usage_median_min() { # run_usage_median_min <brief>: its usage median in minutes (see the header)
  # The brief path goes in through the environment: awk's -v would eat a Windows path's
  # backslashes (tools/wait-run.sh makes the same call).
  RUN_BRIEF=${1:-} awk -F'\t' 'index($10, ENVIRON["RUN_BRIEF"]) && $4 + 0 > 0 { print $4 / 60 }' \
    "$FLASH_USAGE_LOG" 2> /dev/null |
    tail -n "$RUN_RECENT_ROWS" | sort -n |
    awk '{ a[NR] = $1 } END {
      if (!NR) exit
      m = (NR % 2 ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2)
      if (m < 1) exit # short runs say nothing about a whole job
      printf "%d\n", int(m + 0.5)
    }'
}

run_expected_min() { # run_expected_min <brief>: a job's expected minutes (see the header)
  local brief=${1:-} line=0 med=""
  if [ -f "$brief" ]; then
    line=$(sed -n 's/^expected-min:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$brief" | head -n 1 | tr -d '\r')
  fi
  case $line in '' | *[!0-9]*) line=0 ;; esac # no line, or one allowing no time at all
  # The owner's rule (Nov 22): the estimate is a floor, so the slower of the two wins; brief
  # estimates kept coming in low (p3f 15 hit 22, f1 30 hit 45).
  med=$(run_usage_median_min "$brief")
  [ -n "$med" ] && [ "$med" -gt "$line" ] && line=$med
  [ "$line" -gt 0 ] || line=$RUN_EXPECT_DEFAULT_MIN
  if run_is_fix_job "$brief" && [ "$line" -lt "$RUN_FIX_FLOOR_MIN" ]; then
    line=$RUN_FIX_FLOOR_MIN # a fix job's brief is written in a hurry; its floor is the owner's
  fi
  printf '%s\n' "$line"
}

run_job_limit_s() { # run_job_limit_s <brief>: the seconds the job may run (see the header)
  local s
  s=$(( $(run_expected_min "${1:-}") * RUN_JOB_FACTOR_PCT * RUN_LIMIT_UNIT_S / 100 ))
  [ "$s" -gt 0 ] || s=1 # a limit of 0 s would stop every job at once
  printf '%s\n' "$s"
}

run_backstop_min() { # run_backstop_min <waves.txt>: the whole run's minutes (see the header)
  local waves=${1:-} folder j total=0 minute
  [ -f "$waves" ] || { printf '0\n'; return 0; }
  folder=$(dirname "$waves")
  for j in $(sed 's/#.*//' "$waves" | awk 'NF'); do
    [ -f "$folder/done.txt" ] && grep -q "^$j " "$folder/done.txt" && continue
    [ -f "$folder/dropped.txt" ] && grep -qxF "$j" "$folder/dropped.txt" && continue
    total=$((total + $(run_expected_min "$folder/$j.md")))
  done
  # Rounded up: a run that needs 62.5 min must be allowed its whole 63rd minute.
  minute=$(((total * RUN_BACKSTOP_PCT + 99) / 100))
  # The owner's floor (Nov 22): one 15-min job would give 19 min, and a run's commit, review
  # and check need more than that even when the job itself is quick. A run with no job left
  # has nothing to wait for, so it keeps its 0.
  if [ "$total" -gt 0 ] && [ "$minute" -lt "$RUN_BACKSTOP_FLOOR_MIN" ]; then
    minute=$RUN_BACKSTOP_FLOOR_MIN
  fi
  printf '%s\n' "$minute"
}
