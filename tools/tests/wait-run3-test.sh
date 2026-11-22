#!/usr/bin/env bash
# Tests the three process3 p3a fixes of tools/wait-run.sh against the log lines
# tools/run-jobs.sh writes:
#   1. OVERRUN is reported once per job; the next call says so and waits the window;
#   2. after the last job's finished/committed line the result says
#      `checking: the combined check for <n> min`, not "preflight (no job started yet)";
#   3. a `resume <job> (applied by hand, ...)` line counts as that job's start, up
#      to its `committed <job>:` line.
#
#   bash tools/tests/wait-run3-test.sh
#
# Every case builds a fake briefs folder (a run.log, sometimes a brief) in a temp
# folder and runs wait-run.sh on it with a 2 s window and a 1 s poll, so the whole
# script runs in about 15 s. WAIT_STATE_DIR points inside the temp folder and the
# calls of one case share it: the overrun record must survive between them.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
wait_sh="$(pwd)/tools/wait-run.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/wait-run3-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }

# report <case> <0 passed | 1 failed>: on a failure, the FAIL line names the exit
# code and the last line printed (tools/selftest.sh shows only FAIL lines), and
# the whole output follows for someone running this file directly.
report() {
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    pass "$1"
  else
    fails=$((fails + 1))
    echo "FAIL $1 (rc=$rc, last: $(last))"
    sed 's/^/    | /' "$out"
  fi
}

out="$tmp/out.txt"
state="$tmp/state"
usage="$tmp/no-usage.tsv" # no case here needs a usage history
envs=(WAIT_STATE_DIR="$state" FLASH_USAGE_LOG="$usage" WAIT_MAX_S=2 WAIT_POLL_S=1)
rc=0
run() { # <briefs-dir>: runs wait-run.sh, storing its exit code and output
  rc=0
  env "${envs[@]}" bash "$wait_sh" "$@" > "$out" 2>&1 || rc=$?
}
last() { tail -n 1 "$out"; }
ago() { date -d "-$1 minutes" '+%F %T'; }
batch() { mkdir -p "$tmp/$1" && printf '%s\n' "$tmp/$1"; }

# 1. OVERRUN once per job: the call that finds it exits 2, the next call says the
# overrun was already reported and waits its full 2 s window instead of exiting 2.
d=$(batch overrun-once)
printf 'expected-min: 2\n' > "$d/e.md"
{
  echo "$(ago 10) start at abc1234 on m16"
  echo "$(ago 10) start e"
} > "$d/run.log"
run "$d"
first_rc=$rc
first_last=$(last)
t0=$(date +%s)
run "$d"
took=$(($(date +%s) - t0))
r=0
[ "$first_rc" = 2 ] || r=1
[ "$first_last" = 'RESULT: OVERRUN: e has run 10 min, expected ~2 (1.5 x is 3 min)' ] || r=1
[ "$rc" = 4 ] || r=1
[ "$(last)" = 'RESULT: running: e for 10 min (expected ~2), overrun already reported' ] || r=1
[ "$took" -ge 2 ] && [ "$took" -lt 10 ] || r=1
report "OVERRUN is reported once (exit 2), then the next call says so and waits the window (${took}s, exit 4)" "$r"

# A new run (a later `start at` line, the job started again) forgets that record.
{
  echo "$(ago 10) start at def5678 on m16"
  echo "$(ago 10) start e"
} >> "$d/run.log"
run "$d"
if [ "$rc" = 2 ] && [ "$(last)" = 'RESULT: OVERRUN: e has run 10 min, expected ~2 (1.5 x is 3 min)' ]; then r=0; else r=1; fi
report "a new run reports the same job's OVERRUN again (exit 2)" "$r"

# 2. After the last job's commit line and before DONE, the run is checking.
d=$(batch checking)
{
  echo "$(ago 30) start at abc1234 on m16"
  echo "$(ago 30) start a"
  echo "$(ago 28) a finished: result 0 (20 turns, 3 min)"
  echo "$(ago 26) committed a: 1234567 a example job"
} > "$d/run.log"
run "$d"
if [ "$rc" = 4 ] && [ "$(last)" = 'RESULT: running: checking: the combined check for 26 min' ]; then r=0; else r=1; fi
report "after the last job's commit line the result says the combined check for 26 min (exit 4)" "$r"

# 3. A resume line is the job's start; its commit line is its end.
d=$(batch resume)
printf 'expected-min: 9\n' > "$d/r.md"
{
  echo "$(ago 12) start at abc1234 on m16"
  echo "$(ago 12) resume r (applied by hand, not committed yet)"
} > "$d/run.log"
run "$d"
first_rc=$rc
first_last=$(last)
echo "$(ago 1) committed r: 89abcde r example job" >> "$d/run.log"
run "$d"
r=0
[ "$first_rc" = 4 ] || r=1
[ "$first_last" = 'RESULT: running: r for 12 min (expected ~9)' ] || r=1
[ "$rc" = 4 ] || r=1
[ "$(last)" = 'RESULT: running: checking: the combined check for 1 min' ] || r=1
report "a resume line shows its job running for 12 min (expected ~9), then its commit line turns to checking" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
