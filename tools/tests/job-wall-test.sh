#!/usr/bin/env bash
# Tests the WALL column of tools/job-metrics.sh: a job's start-to-finish minutes, read from the
# run.log line `<date> <time> start <job>` (or `resume <job>`) and the `<job> finished: result`
# line after it. The last start or resume counts; a job started again after its finish line has
# no finish and shows `-`; a review log (`-review`, `wave<N>-review`) shows `-`; a job with no
# run.log, no start line or no finish line shows `-`, and a job name must match exactly (jobx
# does not give job a wall time). The batch is built in a temp folder; the times are fixed
# strings, so no real clock is read.
#
#   bash tools/tests/job-wall-test.sh
#
# Prints PASS <case> / FAIL <case> (the tool's output indented under a failure) and exits 1 if
# any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/job-wall-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the tool printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
tool() { # tool <batch dir>: runs the tool on the batch; sets rc, writes $out
  rc=0
  bash tools/job-metrics.sh "$1" > "$out" 2>&1 || rc=$?
}
wall_of() { # wall_of <job>: the WALL cell of that job's row, empty when the table has no such row
  awk -v j="$1" '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == "WALL") c = i }
    $1 == j { print $c }' "$out"
}

# The batch: one worker log for the job, one for its review and one for a wave review.
batch="$tmp/batch"
mkdir -p "$batch"
for j in job i1g2-review wave1-review; do
  printf '%s\n' '---- flash: result 0' > "$batch/flash-$j.log"
done

# The review lines every run.log with lines has: their logs must show `-` whatever the times.
reviews=(
  '2026-11-23 10:00:00 start i1g2-review'
  '2026-11-23 10:07:00 i1g2-review finished: result 0 (3 turns, 1 min)'
  '2026-11-23 10:00:10 start wave1-review'
  '2026-11-23 10:07:10 wave1-review finished: result 0 (3 turns, 1 min)'
)

check() { # check <case> <job's WALL cell> [run.log line...]: a copy of the batch, with that run.log
  local name=$1 want=$2 dir r=1
  shift 2
  dir="$tmp/case$cases"
  cp -r "$batch" "$dir"
  if [ "$#" -gt 0 ]; then printf '%s\n' "$@" "${reviews[@]}" > "$dir/run.log"; fi
  tool "$dir"
  if [ "$rc" = 0 ] && [ "$(wall_of job)" = "$want" ] &&
    [ "$(wall_of i1g2-review)" = - ] && [ "$(wall_of wave1-review)" = - ]; then
    r=0
  fi
  report "$name" "$r"
}

# 1. Started 10:00:00, finished 10:07:30: 450 s, 7.5 minutes.
check "a job started at 10:00:00 and finished at 10:07:30 shows WALL 7.5" 7.5 \
  '2026-11-23 10:00:00 start job' \
  '2026-11-23 10:07:30 job finished: result 0 (20 turns, 7 min)'

# 2. Started 10:00:00, resumed 10:02:00 and again 10:05:00, finished 10:07:30: counts from
#    10:05:00, 150 s, 2.5 minutes.
check "a resumed job counts from its last resume line: 10:05:00 to 10:07:30 is 2.5" 2.5 \
  '2026-11-23 10:00:00 start job' \
  '2026-11-23 10:02:00 resume job' \
  '2026-11-23 10:05:00 resume job' \
  '2026-11-23 10:07:30 job finished: result 0'

# 3. Started 23:50:00 on 11-23, finished 00:05:00 on 11-24: 900 s, 15.0 minutes.
check "a job that runs past midnight counts across the date: 23:50:00 to 00:05:00 is 15.0" 15.0 \
  '2026-11-23 23:50:00 start job' \
  '2026-11-24 00:05:00 job finished: result 0'

# 4. Finished at 10:07:30, started again at 10:10:00 and not finished: no finish after the start.
check "a job started again after its finish line, with no new finish, shows -" - \
  '2026-11-23 10:00:00 start job' \
  '2026-11-23 10:07:30 job finished: result 0' \
  '2026-11-23 10:10:00 start job'

# 5. A finish line with no start line for the job.
check "a job with a finish line and no start line shows -" - \
  '2026-11-23 10:07:30 job finished: result 0'

# 6. A start line with no finish line for the job.
check "a job with a start line and no finish line shows -" - \
  '2026-11-23 10:00:00 start job'

# 7. Lines for jobx are not lines for job.
check "a job's name matches exactly: lines for jobx give job no WALL" - \
  '2026-11-23 10:00:00 start jobx' \
  '2026-11-23 10:07:30 jobx finished: result 0'

# 8. No run.log at all.
check "a batch with no run.log shows - for every job" -

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
