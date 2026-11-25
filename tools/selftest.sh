#!/usr/bin/env bash
# Runs the shell tooling's own tests: every <dir>/*-test.sh.
#
#   tools/selftest.sh              # runs tools/tests/*-test.sh
#   tools/selftest.sh <dir>        # runs <dir>/*-test.sh
#   tools/selftest.sh -j <n>       # up to n scripts at once: n a whole number 1-16 (default 1)
#   tools/selftest.sh -h           # this help
#
# Each script runs under timeout(1) so a hung test can't stall the check.
# -j <n> (or SELFTEST_JOBS=<n>; the option wins) runs up to n scripts at once. The
# output keeps the list order: a script's line prints once every script before it
# has finished, so the lines and the RESULT line match a run with -j 1.
# SELFTEST_TIMEOUT: seconds allowed per script (default 120).
# SELFTEST_TIMEOUTS: per-script limits as basename=seconds pairs, comma separated
# (default run-wire-test.sh=240,run-wire2-test.sh=240,run-stops-test.sh=300,check-cache-test.sh=420: their runner cases are the
# slow ones). A script not named there gets SELFTEST_TIMEOUT.
# SELFTEST_LOCK: lock file, from the repository root (default
# .dart_tool/selftest.lock). A second copy on the same lock is refused; a stale
# lock (its pid no longer alive) is replaced.
#
# Output: one PASS|FAIL|TIMEOUT <script> (<n>s) line per script, the failing
# script's FAIL lines indented under it, and a RESULT line last.
# Exit codes: 0 all passed · 1 any failed · 2 any timed out · 3 bad arguments
# or setup (missing folder, no *-test.sh, another copy running).
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u
# The tests must not see the runner's own settings (WORKER, NO_PUSH, CHECK_*, FLASH_WORKER): a combined check run by
# tools/run-jobs.sh passes them down, and they changed the run-wire test (rehearsal1, process6).
unset WORKER NO_PUSH CHECK_FAIL_FAST CHECK_SKIP RUN_CHECK_SKIP FLASH_WORKER

cd "$(dirname "$0")/.." || exit 2

# A plain one-line refusal, ending on the RESULT line the script rules ask for.
bad_input() {
  echo "RESULT: BAD INPUT: $1"
  exit 3
}

dir="tools/tests"
folder=""
folder_given=""
jobs_arg=""
jobs_given=""
nargs=$#
all_args="$*"
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -j)
      [ $# -ge 2 ] || bad_input "-j needs the number of scripts to run at once (1-16)"
      jobs_arg="$2"
      jobs_given=1
      shift
      ;;
    -*) bad_input "unknown option: $1 (try --help)" ;;
    *)
      [ -z "$folder_given" ] || bad_input "one folder at most (got $nargs: $all_args)"
      folder="$1"
      folder_given=1
      ;;
  esac
  shift
done
[ -z "$folder_given" ] || dir="$folder"

jobs="${SELFTEST_JOBS:-1}"
[ -z "$jobs_given" ] || jobs="$jobs_arg"
case "$jobs" in
  '' | *[!0-9]* | ????*) bad_input "scripts at once (-j or SELFTEST_JOBS) must be a whole number 1-16, got '$jobs'" ;;
esac
jobs=$((10#$jobs))
[ "$jobs" -ge 1 ] && [ "$jobs" -le 16 ] || bad_input "scripts at once (-j or SELFTEST_JOBS) must be 1-16, got '$jobs'"

timeout_s="${SELFTEST_TIMEOUT:-120}"
case "$timeout_s" in
  '' | *[!0-9]*) bad_input "SELFTEST_TIMEOUT must be whole seconds, got '$timeout_s'" ;;
esac
[ "$timeout_s" -gt 0 ] || bad_input "SELFTEST_TIMEOUT must be at least 1 second"

# The per-script limits: basename=seconds pairs, comma separated. A script the
# list doesn't name runs under SELFTEST_TIMEOUT.
timeouts="${SELFTEST_TIMEOUTS:-run-wire-test.sh=240,run-wire2-test.sh=240,run-stops-test.sh=300,check-cache-test.sh=420}"
IFS=',' read -ra limits <<< "$timeouts"
for entry in "${limits[@]}"; do
  case "$entry" in
    *=*) ;;
    *) bad_input "SELFTEST_TIMEOUTS entries are name=seconds, got '$entry'" ;;
  esac
  entry_name="${entry%%=*}"
  entry_s="${entry#*=}"
  [ -n "$entry_name" ] || bad_input "SELFTEST_TIMEOUTS entry '$entry' names no script"
  case "$entry_s" in
    '' | *[!0-9]*) bad_input "SELFTEST_TIMEOUTS: $entry_name must be whole seconds, got '$entry_s'" ;;
  esac
  [ "$entry_s" -gt 0 ] || bad_input "SELFTEST_TIMEOUTS: $entry_name must be at least 1 second"
done

# limit_for <script's basename>: its SELFTEST_TIMEOUTS limit, or SELFTEST_TIMEOUT.
limit_for() {
  for entry in "${limits[@]}"; do
    if [ "${entry%%=*}" = "$1" ]; then
      echo "${entry#*=}"
      return 0
    fi
  done
  echo "$timeout_s"
}

command -v timeout > /dev/null 2>&1 || bad_input "timeout isn't on the PATH (it comes with coreutils)"

[ -d "$dir" ] || bad_input "no such folder: $dir"
scripts=()
for f in "$dir"/*-test.sh; do
  [ -f "$f" ] && scripts+=("$f")
done
[ ${#scripts[@]} -gt 0 ] || bad_input "no *-test.sh scripts in $dir"

# One lock per script: two copies on the same lock folder can't run at once.
lock="${SELFTEST_LOCK:-.dart_tool/selftest.lock}"
mkdir -p "$(dirname "$lock")" || bad_input "can't create the folder for the lock: $(dirname "$lock")"
if [ -f "$lock" ]; then
  holder="$(cat "$lock" 2> /dev/null)"
  case "$holder" in
    '' | *[!0-9]*) ;; # no usable pid recorded: stale, replace it below
    *) kill -0 "$holder" 2> /dev/null && bad_input "another selftest.sh is running (pid $holder, lock $lock)" ;;
  esac
fi
printf '%s\n' "$$" > "$lock" || bad_input "can't write the lock: $lock"

tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/thumbparty-selftest-XXXXXX")" || {
  rm -f "$lock"
  bad_input "can't create a temp folder"
}
child=""
# The parallel run's scripts: par_pid[k] is script k's timeout process while it runs
# (unset once reaped), par_rc[k] and par_secs[k] are set when it ends.
par_pid=()
par_began=()
par_rc=()
par_secs=()
par_done=0
cleanup() {
  if [ -n "$child" ]; then
    kill "$child" 2> /dev/null
    wait "$child" 2> /dev/null # reap it before removing its log (Windows keeps the file open)
  fi
  for p in "${par_pid[@]+"${par_pid[@]}"}"; do
    kill "$p" 2> /dev/null
    wait "$p" 2> /dev/null
  done
  rm -rf "$tmp"
  if [ "$(cat "$lock" 2> /dev/null)" = "$$" ]; then
    rm -f "$lock"
  fi
}
trap cleanup EXIT
trap 'trap "" INT TERM; exit 130' INT
trap 'trap "" INT TERM; exit 143' TERM

# start_script <k>: runs scripts[k] in the background under its limit.
start_script() {
  local base
  base="$(basename "${scripts[$1]}")"
  timeout "$(limit_for "$base")" bash "${scripts[$1]}" > "$tmp/$base.log" 2>&1 &
  par_pid[$1]=$!
  par_began[$1]=$(date +%s)
}

# reap_finished <started>: records each started script that has ended since the last call.
reap_finished() {
  local k
  for ((k = 0; k < $1; k++)); do
    [ -n "${par_pid[k]+x}" ] || continue
    kill -0 "${par_pid[k]}" 2> /dev/null && continue
    wait "${par_pid[k]}"
    par_rc[k]=$?
    par_secs[k]=$(($(date +%s) - par_began[k]))
    unset "par_pid[$k]"
    par_done=$((par_done + 1))
  done
}

# show_result <script> <rc> <secs>: prints the script's line (and its FAIL lines), counts it.
show_result() {
  local script="$1" rc="$2" secs="$3" base
  base="$(basename "$script")"
  if [ "$rc" = 0 ]; then
    printf 'PASS  %s (%ss)\n' "$script" "$secs"
    passed=$((passed + 1))
  elif [ "$rc" = 124 ]; then
    printf 'TIMEOUT %s (%ss)\n' "$script" "$secs"
    echo "TIMEOUT: $script exceeded $(limit_for "$base")s"
    timed_out=$((timed_out + 1))
  else
    printf 'FAIL  %s (%ss)\n' "$script" "$secs"
    failed=$((failed + 1))
    if grep -q '^FAIL' "$tmp/$base.log"; then
      grep '^FAIL' "$tmp/$base.log" | sed 's/^/  /'
    else
      echo "  (exit $rc, no FAIL line)"
    fi
  fi
}

# run_parallel: keeps up to $jobs scripts running, and prints each script's result
# once every script before it has finished, so the output is in list order.
run_parallel() {
  local count=${#scripts[@]} started=0 printed=0
  while [ "$printed" -lt "$count" ]; do
    while [ $((started - par_done)) -lt "$jobs" ] && [ "$started" -lt "$count" ]; do
      start_script "$started"
      started=$((started + 1))
    done
    reap_finished "$started"
    while [ "$printed" -lt "$count" ] && [ -n "${par_rc[printed]+x}" ]; do
      show_result "${scripts[$printed]}" "${par_rc[printed]}" "${par_secs[printed]}"
      printed=$((printed + 1))
    done
    sleep 0.1
  done
}

start_all=$(date +%s)
passed=0
failed=0
timed_out=0
if [ "$jobs" -gt 1 ]; then
  run_parallel
else
  # The child runs in the background so the traps above run at once, not after
  # a hung script finishes.
  for script in "${scripts[@]}"; do
    log="$tmp/$(basename "$script").log"
    script_limit="$(limit_for "$(basename "$script")")"
    start=$(date +%s)
    timeout "$script_limit" bash "$script" > "$log" 2>&1 &
    child=$!
    wait "$child"
    rc=$?
    child=""
    secs=$(($(date +%s) - start))
    if [ "$rc" = 0 ]; then
      printf 'PASS  %s (%ss)\n' "$script" "$secs"
      passed=$((passed + 1))
    elif [ "$rc" = 124 ]; then
      printf 'TIMEOUT %s (%ss)\n' "$script" "$secs"
      echo "TIMEOUT: $script exceeded ${script_limit}s"
      timed_out=$((timed_out + 1))
    else
      printf 'FAIL  %s (%ss)\n' "$script" "$secs"
      failed=$((failed + 1))
      if grep -q '^FAIL' "$log"; then
        grep '^FAIL' "$log" | sed 's/^/  /'
      else
        echo "  (exit $rc, no FAIL line)"
      fi
    fi
  done
fi

total=$(($(date +%s) - start_all))
count=${#scripts[@]}
if [ "$timed_out" -gt 0 ]; then
  echo "RESULT: TIMEOUT: $timed_out of $count script(s) exceeded their limit ($passed passed, $failed failed, ${total}s)"
  exit 2
fi
if [ "$failed" -gt 0 ]; then
  echo "RESULT: FAILED: $failed of $count script(s) failed ($passed passed, ${total}s)"
  exit 1
fi
echo "RESULT: ok: $count script(s) passed (${total}s)"
exit 0
