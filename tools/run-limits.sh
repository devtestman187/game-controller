#!/usr/bin/env bash
# The per-step time limits of one run, and where they come from. Sourced, no side effects:
#   . tools/run-limits.sh                          # sets the RUN_* values below, adds no work
#   . tools/run-limits.sh && run_expected_min x.md # a job's estimate, its limit, the backstop
# tools/run-jobs.sh and its helpers (tools/run-steps.sh, tools/run-review.sh) source it after
# the cd to the repo root. Every limit counts in RUN_LIMIT_UNIT_S-second "minutes", so a test
# sets RUN_LIMIT_UNIT_S=1 and a 12 min limit runs out in 12 s.
#
# Three helpers, each printing one whole number on stdout:
#   run_expected_min <brief>     a job's minutes: its brief's `expected-min:` line, else the
#                                median of its last RUN_RECENT_ROWS usage rows, else the default
#   run_job_limit_s <brief>      the seconds it may run: its expected minutes x RUN_JOB_FACTOR_PCT
#   run_backstop_min <waves.txt> the whole run's minutes: the estimates of the jobs in waves.txt
#                                that are in neither done.txt nor dropped.txt, +25% (rounded up);
#                                0 when there is no waves.txt (the runner refuses such a batch)
#
# Env knobs, each a whole number (anything else keeps the default):
#   RUN_JOB_FACTOR_PCT 150      a job's limit over its estimate (owner, Nov 22)
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
RUN_CHECK_MAX_MIN=$(run_number "${RUN_CHECK_MAX_MIN:-}" 20)
RUN_REVIEW_MAX_MIN=$(run_number "${RUN_REVIEW_MAX_MIN:-}" 10)
RUN_EXPECT_DEFAULT_MIN=$(run_number "${RUN_EXPECT_DEFAULT_MIN:-}" 20)
RUN_POLL_S=$(run_number "${RUN_POLL_S:-}" 5)
RUN_LIMIT_UNIT_S=$(run_number "${RUN_LIMIT_UNIT_S:-}" 60)
RUN_RECENT_ROWS=$(run_number "${RUN_RECENT_ROWS:-}" 30)
FLASH_USAGE_LOG=${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}

run_expected_min() { # run_expected_min <brief>: a job's expected minutes (see the header)
  local brief=${1:-} v=""
  if [ -f "$brief" ]; then
    v=$(sed -n 's/^expected-min:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$brief" | head -n 1 | tr -d '\r')
  fi
  case $v in
    '' | 0) ;; # no line, or a line that would allow no time at all: look at the usage rows
    *) printf '%s\n' "$v"; return 0 ;;
  esac
  # The brief path goes in through the environment: awk's -v would eat a Windows path's
  # backslashes (tools/wait-run.sh makes the same call).
  v=$(RUN_BRIEF=$brief awk -F'\t' 'index($10, ENVIRON["RUN_BRIEF"]) && $4 + 0 > 0 { print $4 / 60 }' \
    "$FLASH_USAGE_LOG" 2> /dev/null |
    tail -n "$RUN_RECENT_ROWS" | sort -n |
    awk '{ a[NR] = $1 } END { if (!NR) exit; m = (NR % 2 ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2); printf "%d\n", int(m + 0.5) }')
  case $v in '' | 0) v=$RUN_EXPECT_DEFAULT_MIN ;; esac # a median under a minute is no limit
  printf '%s\n' "$v"
}

run_job_limit_s() { # run_job_limit_s <brief>: the seconds the job may run (see the header)
  local s
  s=$(( $(run_expected_min "${1:-}") * RUN_JOB_FACTOR_PCT * RUN_LIMIT_UNIT_S / 100 ))
  [ "$s" -gt 0 ] || s=1 # a limit of 0 s would stop every job at once
  printf '%s\n' "$s"
}

run_backstop_min() { # run_backstop_min <waves.txt>: the whole run's minutes (see the header)
  local waves=${1:-} folder j total=0
  [ -f "$waves" ] || { printf '0\n'; return 0; }
  folder=$(dirname "$waves")
  for j in $(sed 's/#.*//' "$waves" | awk 'NF'); do
    [ -f "$folder/done.txt" ] && grep -q "^$j " "$folder/done.txt" && continue
    [ -f "$folder/dropped.txt" ] && grep -qxF "$j" "$folder/dropped.txt" && continue
    total=$((total + $(run_expected_min "$folder/$j.md")))
  done
  # Rounded up: a run that needs 62.5 min must be allowed its whole 63rd minute.
  printf '%s\n' $(((total * RUN_BACKSTOP_PCT + 99) / 100))
}
