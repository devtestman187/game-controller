#!/usr/bin/env bash
# Tests tools/wait-run.sh against docs/briefs/m16/process2/script-rules.md and
# the job M16 process2 wait.
#
#   bash tools/tests/wait-run-test.sh
#
# Every case builds a fake briefs folder (a run.log, sometimes a brief and a
# flash-usage log) in a temp folder and runs wait-run.sh on it. WAIT_STATE_DIR
# points inside the temp folder, so no case touches .dart_tool/wait-run and the
# cases cannot see each other's position or lock files.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
wait_sh="$(pwd)/tools/wait-run.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/wait-run-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# report <case> <0 passed | 1 failed>: on a failure, the FAIL line names the exit
# code and the last line printed (tools/selftest.sh shows only FAIL lines), and
# the whole output follows for someone running this file directly.
report() {
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    pass "$1"
  else
    fails=$((fails + 1))
    echo "FAIL $1 (rc=$rc, last: $(tail -n 1 "$out"))"
    sed 's/^/    | /' "$out"
  fi
}

out="$tmp/out.txt"
usage="$tmp/no-usage.tsv" # most cases have no history
state="$tmp/state"
envs=(WAIT_STATE_DIR="$state" FLASH_USAGE_LOG="$usage")
rc=0
run() { # <briefs-dir> [args...]: runs wait-run.sh, storing its exit code and output
  rc=0
  env "${envs[@]}" bash "$wait_sh" "$@" > "$out" 2>&1 || rc=$?
}
last() { tail -n 1 "$out"; }
now() { date '+%F %T'; }
ago() { date -d "-$1 minutes" '+%F %T'; }
batch() { mkdir -p "$tmp/$1" && printf '%s\n' "$tmp/$1"; }
reset_envs() { envs=(WAIT_STATE_DIR="$state" FLASH_USAGE_LOG="$usage"); }

run "$tmp/no-such-folder"
if [ "$rc" = 3 ] && last | grep -qF 'RESULT: BAD INPUT: no such folder'; then r=0; else r=1; fi
report "a missing folder is bad input (exit 3)" "$r"

d=$(batch no-log)
run "$d"
if [ "$rc" = 3 ] && last | grep -qF 'RESULT: BAD INPUT: no run.log in'; then r=0; else r=1; fi
report "a folder with no run.log is bad input (exit 3)" "$r"

d=$(batch bad-max)
printf '%s\n' "$(now) start at abc1234 on m16" > "$d/run.log"
run "$d" --max abc
if [ "$rc" = 3 ] && last | grep -qF 'RESULT: BAD INPUT: --max takes whole seconds'; then r=0; else r=1; fi
report "a non-numeric --max is bad input (exit 3)" "$r"

d=$(batch done)
{
  echo "$(ago 30) start at c60ea5a7 on m16"
  echo "$(ago 30) run-base c60ea5a7a6f5a02f4d7b3f901347e7392ba49c4d"
  echo "$(ago 29) start a"
  echo "$(ago 26) a finished: result 0 (20 turns, 3 min)"
  echo "$(now) DONE: every job is committed. Claude reads the Summary"
} > "$d/run.log"
run "$d"
if [ "$rc" = 0 ] && grep -qF 'a finished: result 0' "$out" &&
  grep -qF 'start at c60ea5a7' "$out" &&
  last | grep -qF 'RESULT: ok: DONE: every job is committed. Claude reads the Summary'; then r=0; else r=1; fi
report "a DONE line ends the wait at once (exit 0) and prints the whole run" "$r"

d=$(batch stopped)
{
  echo "$(ago 20) start at abc1234 on m16"
  echo "$(ago 20) start b"
  echo "$(now) STOPPED: checks failed twice on the combined tree after b (see run-check.log)"
} > "$d/run.log"
run "$d"
if [ "$rc" = 1 ] && last | grep -qF 'RESULT: STOPPED: checks failed twice on the combined tree after b'; then r=0; else r=1; fi
report "a STOPPED line ends the wait (exit 1) with the runner's reason" "$r"

d=$(batch running)
{
  echo "$(now) start at abc1234 on m16"
  echo "$(now) start c"
} > "$d/run.log"
t0=$(date +%s)
run "$d" --max 6
secs=$(($(date +%s) - t0))
if [ "$rc" = 4 ] && [ "$secs" -ge 5 ] && [ "$secs" -lt 20 ] &&
  last | grep -qE '^RESULT: running: c for 0 min \(expected ~15\)$'; then r=0; else r=1; fi
report "--max 6 ends a still-running wait with exit 4 (${secs}s): the job, its minutes, expected ~15" "$r"

d=$(batch stalled)
{
  echo "$(ago 40) start at abc1234 on m16"
  echo "$(ago 40) start d"
} > "$d/run.log"
touch -d '40 minutes ago' "$d/run.log"
envs+=(WAIT_STALL_MIN=1)
t0=$(date +%s)
run "$d" --max 20
secs=$(($(date +%s) - t0))
reset_envs
if [ "$rc" = 2 ] && [ "$secs" -lt 5 ] && last | grep -qF 'RESULT: STALLED: run.log, the flash logs'; then r=0; else r=1; fi
report "a run.log 40 min old with no DONE is STALLED (exit 2, ${secs}s, no wait)" "$r"

d=$(batch elsewhere)
printf 'expected-min: 100\n' > "$d/f.md"
{
  echo "$(ago 40) start at abc1234 on m16"
  echo "$(ago 40) start f"
} > "$d/run.log"
touch -d '40 minutes ago' "$d/run.log"
mkdir -p "$tmp/logs"
echo "worker output" > "$tmp/logs/flash-f.log"
envs+=(WAIT_STALL_MIN=1 WAIT_LOGS="$tmp/logs")
run "$d" --max 2
reset_envs
if [ "$rc" = 4 ] && last | grep -qF 'RESULT: running: f for 40 min'; then r=0; else r=1; fi
report "WAIT_LOGS watches the flash log of a runner started with --logs (no false STALLED)" "$r"

d=$(batch overrun)
printf 'expected-min: 2\n' > "$d/e.md"
{
  echo "$(ago 10) start at abc1234 on m16"
  echo "$(ago 10) start e"
} > "$d/run.log"
run "$d" --max 20
if [ "$rc" = 2 ] && last | grep -qF 'RESULT: OVERRUN: e has run 10 min, expected ~2 (1.5 x is 3 min)'; then r=0; else r=1; fi
report "a brief's expected-min: 2 makes a 10 min job OVERRUN (exit 2)" "$r"

usage2="$tmp/usage.tsv"
d=$(batch overrun-usage)
{
  echo "$(ago 10) start at abc1234 on m16"
  echo "$(ago 10) start g"
} > "$d/run.log"
for s in 60 120 180; do
  printf '2026-11-20T10:00:00\t0\t20\t%s\t1\t2\t3\t4\t5\t%s\n' "$s" "$d/g.md" >> "$usage2"
done
envs=(WAIT_STATE_DIR="$state" FLASH_USAGE_LOG="$usage2")
run "$d" --max 20
reset_envs
if [ "$rc" = 2 ] && last | grep -qF 'RESULT: OVERRUN: g has run 10 min, expected ~2'; then r=0; else r=1; fi
report "the usage log's median (1, 2, 3 min) is the expected time when the brief has none" "$r"

d=$(batch repeat)
{
  echo "$(now) start at abc1234 on m16"
  echo "$(now) start r"
  echo "$(now) r finished: result 0 (30 turns, 4 min)"
} > "$d/run.log"
run "$d" --max 2
first_rc=$rc
first_has=0
grep -qF 'r finished: result 0' "$out" && first_has=1
echo "$(now) DONE: all done" >> "$d/run.log"
run "$d"
r=0
[ "$first_rc" = 4 ] || r=1   # the first call saw a run still going
[ "$first_has" = 1 ] || r=1  # and printed its lines
[ "$rc" = 0 ] || r=1         # the second call saw the DONE
grep -qF 'DONE: all done' "$out" || r=1
grep -qF 'r finished' "$out" && r=1 # but not the lines the first call printed
grep -qF 'start r' "$out" && r=1
report "a second call prints only the lines added since the first" "$r"

d=$(batch old-done)
{
  echo "$(ago 30) DONE: an older run of this folder"
  echo "$(ago 20) start at def5678 on m16"
  echo "$(ago 20) start s"
} > "$d/run.log"
run "$d" --max 2
if [ "$rc" = 4 ] && ! grep -qF 'an older run' "$out"; then r=0; else r=1; fi
report "a DONE before the last start at does not end the wait" "$r"

d=$(batch "dir with spaces")
{
  echo "$(now) start at abc1234 on m16"
  echo "$(now) DONE: every job is committed"
} > "$d/run.log"
run "$d"
if [ "$rc" = 0 ] && last | grep -qF 'RESULT: ok: DONE: every job is committed'; then r=0; else r=1; fi
report "a briefs folder whose path has spaces works" "$r"

d=$(batch locked)
{
  echo "$(now) start at abc1234 on m16"
  echo "$(now) start x"
} > "$d/run.log"
env "${envs[@]}" timeout 3 bash "$wait_sh" "$d" --max 20 > "$tmp/background.txt" 2>&1 &
for _ in $(seq 50); do [ -n "$(ls "$state"/*.lock 2> /dev/null)" ] && break; sleep 0.1; done
run "$d" --max 3
if [ "$rc" = 3 ] && grep -qF 'another waiter' "$out" && last | grep -qF 'RESULT: BAD INPUT:'; then r=0; else r=1; fi
report "a second waiter on the same folder is refused (exit 3)" "$r"
wait
left=$(ls "$state"/*.lock "$state"/*.marker 2> /dev/null | tr '\n' ' ')
if [ -z "$left" ]; then r=0; else r=1; fi
report "an interrupted waiter (TERM from timeout) leaves no lock and no marker${left:+ [left: $left]}" "$r"

d=$(batch garbage)
stateg="$tmp/state-garbage"
{
  echo "$(now) start at abc1234 on m16"
  echo "$(now) start q"
  echo "$(now) DONE: fine"
} > "$d/run.log"
envs=(WAIT_STATE_DIR="$stateg" FLASH_USAGE_LOG="$usage")
run "$d"
first_rc=$rc
pos_file=$(ls "$stateg"/*.pos 2> /dev/null | head -n 1)
printf 'not a number\n' > "$pos_file"
run "$d"
reset_envs
if [ "$first_rc" = 0 ] && [ "$rc" = 0 ] && grep -qF 'start at abc1234' "$out"; then r=0; else r=1; fi
report "a garbage position file is reset and the call still works" "$r"

d=$(batch capped)
{
  echo "$(now) start at abc1234 on m16"
  echo "$(now) DONE: every job is committed"
} > "$d/run.log"
run "$d" --max 999
if [ "$rc" = 0 ] && grep -qF 'NOTE: the wait window is capped at 170 s' "$out"; then r=0; else r=1; fi
report "--max 999 is capped at 170 s (the shell backgrounds a call at 180 s)" "$r"

d=$(batch live)
{
  echo "$(now) start at abc1234 on m16"
  echo "$(now) start w"
} > "$d/run.log"
env "${envs[@]}" bash "$wait_sh" "$d" --max 6 > "$out" 2>&1 &
bgpid=$!
sleep 1
echo "$(now) a line written while the waiter waits" >> "$d/run.log"
wait "$bgpid"
rc=$?
if [ "$rc" = 4 ] && grep -qF 'a line written while the waiter waits' "$out" &&
  last | grep -qF 'RESULT: running: w for'; then r=0; else r=1; fi
report "a line appended during the wait is printed by that same call" "$r"

run -h
if [ "$rc" = 0 ] && grep -qF 'tools/wait-run.sh <briefs-dir> [--max <s>]' "$out" &&
  grep -qF 'Exit codes' "$out"; then r=0; else r=1; fi
report "-h prints the usage, exit codes and knobs (exit 0)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
