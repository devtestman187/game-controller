#!/usr/bin/env bash
# Runs the shell tooling's own tests: every <dir>/*-test.sh, one at a time.
#
#   tools/selftest.sh              # runs tools/tests/*-test.sh
#   tools/selftest.sh <dir>        # runs <dir>/*-test.sh
#   tools/selftest.sh -h           # this help
#
# Each script runs under timeout(1) so a hung test can't stall the check.
# SELFTEST_TIMEOUT: seconds allowed per script (default 120).
# SELFTEST_TIMEOUTS: per-script limits as basename=seconds pairs, comma separated
# (default run-wire-test.sh=240: its runner cases are the slow ones). A script
# not named there gets SELFTEST_TIMEOUT.
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

cd "$(dirname "$0")/.." || exit 2

# A plain one-line refusal, ending on the RESULT line the script rules ask for.
bad_input() {
  echo "RESULT: BAD INPUT: $1"
  exit 3
}

dir="tools/tests"
[ $# -le 1 ] || bad_input "one folder at most (got $#: $*)"
case "${1:-}" in
  -h | --help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  -*) bad_input "unknown option: $1 (try --help)" ;;
  "") ;;
  *) dir="$1" ;;
esac

timeout_s="${SELFTEST_TIMEOUT:-120}"
case "$timeout_s" in
  '' | *[!0-9]*) bad_input "SELFTEST_TIMEOUT must be whole seconds, got '$timeout_s'" ;;
esac
[ "$timeout_s" -gt 0 ] || bad_input "SELFTEST_TIMEOUT must be at least 1 second"

# The per-script limits: basename=seconds pairs, comma separated. A script the
# list doesn't name runs under SELFTEST_TIMEOUT.
timeouts="${SELFTEST_TIMEOUTS:-run-wire-test.sh=240}"
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
cleanup() {
  if [ -n "$child" ]; then
    kill "$child" 2> /dev/null
    wait "$child" 2> /dev/null # reap it before removing its log (Windows keeps the file open)
  fi
  rm -rf "$tmp"
  if [ "$(cat "$lock" 2> /dev/null)" = "$$" ]; then
    rm -f "$lock"
  fi
}
trap cleanup EXIT
trap 'trap "" INT TERM; exit 130' INT
trap 'trap "" INT TERM; exit 143' TERM

start_all=$(date +%s)
passed=0
failed=0
timed_out=0
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
