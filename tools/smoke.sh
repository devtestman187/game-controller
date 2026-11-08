#!/usr/bin/env bash
# Checks the apps against each other with real clients, over the real network
# stack: the development TV app (tools/tv-dev.sh), a simulated controller
# (packages/connection/bin/sim_controller.dart) and, with --emulator, the
# phone app on the Android emulator. Each step is proved by a line in the
# client's own output or a tool's exit code, and by the TV app's own log too
# when that log is live; the PASS line says which proofs it used. A log that
# ends in the flutter tool's crash report counts as silent, since the tool
# died and the app's later lines never reach it (Nov 7, docs/dev-tools.md).
# Documented in docs/dev-tools.md.
#
#   tools/smoke.sh              # the TV app and the simulated controller
#   tools/smoke.sh --emulator   # also the phone app on the emulator
#   tools/smoke.sh --keep       # leave what it started running
#   tools/smoke.sh --self-test  # check what it makes of a crashed log, then stop
#   tools/smoke.sh --help
#
# It starts the development TV app only when no copy is running, reads its
# port and pairing code, and prints one line per step: PASS <step> (<proof>,
# <s>s), or FAIL <step> and the end of the log it was reading. Logs and the
# phone's screenshot go to a new folder under the temp folder, printed at the
# end.
# Needs Git Bash on Windows (tools/tv-dev.sh is Windows only) and Flutter.
# SMOKE_WAIT_SECS (default 20) is how long a step waits for its line.
# Exit code: 0 smoke passed, 1 a step failed, 2 bad use or a missing tool.
set -u

cd "$(dirname "$0")/.." || exit 2

use_emulator=0
keep=0
wants_self_test=0
for arg in "$@"; do
  case "$arg" in
    --emulator) use_emulator=1 ;;
    --keep) keep=1 ;;
    --self-test) wants_self_test=1 ;;
    -h | --help)
      sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

for tool in dart flutter; do
  command -v "$tool" > /dev/null 2>&1 || {
    echo "$tool isn't on the PATH (docs/building.md)" >&2
    exit 2
  }
done
[ -f tools/tv-dev.sh ] || { echo "tools/tv-dev.sh is missing" >&2; exit 2; }
if [ "$use_emulator" = 1 ] && [ ! -f tools/emulator.sh ]; then
  echo "tools/emulator.sh is missing" >&2
  exit 2
fi

# How long a step waits for its line, and how often it looks (twice a second).
wait_secs="${SMOKE_WAIT_SECS:-20}"
poll_secs=0.5
case "$wait_secs" in
  '' | *[!0-9]*)
    echo "SMOKE_WAIT_SECS is a number of seconds, not '$wait_secs'" >&2
    exit 2
    ;;
esac
# The simulated controller runs this long: enough for the streamed input and
# for one metrics batch, which it sends every 10 s.
sim_seconds=12
# The second run only has to get in with the saved pairing, so it is short.
reconnect_seconds=5
# Its name, so its lines can't be taken for the TV app's own built-in
# simulated controllers, which use the default "Simulated controller".
sim_name="Smoke controller"
# From inside the emulator, this PC is 10.0.2.2 (docs/dev-tools.md).
emulator_pc=10.0.2.2
# The phone app's package, for asking the device whether it is installed.
app_package=com.thumbparty.app
# The flutter tool's crash report and how many of the log's last non-blank
# lines are looked at for it. When they hold it, the tool died after the app
# started, so the app's lines stop there and the log proves nothing (Nov 7;
# docs/dev-tools.md).
tool_crash_line='A crash report has been written to'

out="${TMPDIR:-${TEMP:-/tmp}}/thumbparty-smoke-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out" || exit 2
# The pairing the simulated controller saves: this run's folder, so it never
# sits next to the sources, and gone when the run ends.
token_file="$out/sim-token.json"

tv_port=""
tv_code=""
tv_log=""
started_tv=0
sim_pid=""
sim2_pid=""
sim_view_pid=""

# Everything this run started goes away here, unless it may stay (--keep).
# The development TV app is stopped through tv-dev.sh, which stops only this
# repository's debug build; no other process is touched.
cleanup() {
  trap - EXIT
  for pid in "$sim_pid" "$sim2_pid" "$sim_view_pid"; do
    if [ -n "$pid" ]; then
      kill "$pid" 2> /dev/null
      wait "$pid" 2> /dev/null
    fi
  done
  rm -f "$token_file"
  if [ "$started_tv" = 1 ]; then
    if [ "$keep" = 1 ]; then
      echo "Left the development TV app running (--keep)."
    elif tools/tv-dev.sh stop > "$out/tv-stop.log" 2>&1; then
      echo "Stopped the development TV app."
    else
      echo "Couldn't stop the development TV app: tools/tv-dev.sh stop (see $out/tv-stop.log)"
    fi
  fi
}
trap cleanup EXIT

# A path as bash can open it (tv-dev.sh prints the Windows one).
to_bash_path() {
  if command -v cygpath > /dev/null 2>&1; then cygpath -u "$1"; else echo "$1"; fi
}

# The lines in a log file, 0 when there isn't one yet.
lines_in() {
  if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi
}

# Waits for a line matching the pattern $3 in the log file $1, among the
# lines after line $2: a step counts the lines before it starts, so a line
# from an earlier run doesn't count. Returns 1 after the wait timeout ($4,
# default wait_secs).
wait_line() {
  local file="$1" from="$2" pattern="$3" secs="${4:-$wait_secs}" i
  for ((i = 0; i < secs * 2; i++)); do
    if tail -n "+$((from + 1))" "$file" 2> /dev/null | grep -aqE -- "$pattern"; then return 0; fi
    sleep "$poll_secs"
  done
  return 1
}

t0=0
step_secs() { echo $(($(date +%s) - t0)); }

# A passed step: the proofs it used (sim, sim+tv, tv, tool) and how long it
# took. A step this run can't prove says so with skip instead.
ok() { printf 'PASS  %-13s (%s, %ss)\n' "$1" "${2:-}" "$(step_secs)"; }

skip() { printf 'SKIP  %-13s (%s)\n' "$1" "$2"; }

# A failed step: the end of the log it was reading, then the way out.
bad() { # step [the log the step was reading]
  printf 'FAIL  %-13s (%ss)\n' "$1" "$(step_secs)"
  if [ $# -ge 2 ]; then
    echo "  The last 10 lines of $2:"
    tail -10 "$2" 2> /dev/null | sed 's/^/  | /'
  else
    echo "  The last 10 lines of the TV app's log ($tv_log):"
    tail -10 "$tv_log" 2> /dev/null | sed 's/^/  | /'
  fi
  echo "Smoke failed: $1. Logs: $out"
  exit 1
}

# Whether the TV app's log is live: it has a host line after the last
# "Listening" line and no flutter tool crash report after it. A sandbox (and
# this PC outside it) can lose the app's lines after it starts while the app
# keeps running (docs/dev-tools.md); then the simulated controller's own
# output is the only proof there is.
tv_is_live() {
  local listening
  [ -f "$tv_log" ] || return 1
  listening="$(grep -an 'Listening on port' "$tv_log" 2> /dev/null | tail -1 | cut -d: -f1)"
  [ -n "$listening" ] || return 1
  # The crash report can come anywhere after the app's start, and its links
  # and blank lines can follow it (Nov 7: 9 lines from the end): once the
  # tool that writes the log is gone, nothing after it is live.
  if tail -n "+$((listening + 1))" "$tv_log" 2> /dev/null | grep -aqF -- "$tool_crash_line"; then
    return 1
  fi
  tail -n "+$((listening + 1))" "$tv_log" 2> /dev/null | grep -aq '\[host\]'
}

# The two log shapes the TV app's log took on Nov 7, checked against
# tv_is_live: one ending in a normal app line (live) and one ending in the
# flutter tool's crash report after the app's lines (silent). Nothing else
# runs for --self-test. 0 when both are read right, 1 when one isn't.
self_test() {
  local live="$out/self-test-live.log" crashed="$out/self-test-crashed.log" rc=0
  printf '%s\n' '[host] Listening on port 45780 (pairing code 5416)' \
    '[host] Smoke controller (sim 0.11.0, supports metrics) says hello from 127.0.0.1' > "$live"
  printf '%s\n' '[host] Listening on port 45780 (pairing code 5416)' \
    '[host] Smoke controller (sim 0.11.0, supports metrics) says hello from 127.0.0.1' \
    'A crash report has been written to C:\Users\...\flutter_01.log' > "$crashed"
  # The Nov 7 evening shape: the report's link and blank lines after it.
  printf '%s
' 'To report your crash to the Flutter team, first read the guide to filing a bug.'     'https://flutter.dev/to/report-bugs' '' 'Create a new GitHub issue by pasting this link into your browser.'     'https://github.com/flutter/flutter/issues/new?title=tool_crash' '' >> "$crashed"
  tv_log="$crashed"
  if tv_is_live; then
    echo "FAIL self-test: a log ending in the flutter tool's crash report was read as live" >&2
    rc=1
  else
    echo "PASS self-test: a log ending in the flutter tool's crash report is silent"
  fi
  tv_log="$live"
  if tv_is_live; then
    echo "PASS self-test: a log ending in an app line is live"
  else
    echo "FAIL self-test: a log ending in an app line was read as silent" >&2
    rc=1
  fi
  rm -f "$live" "$crashed"
  rmdir "$out" 2> /dev/null # it holds nothing else: a self-test starts no app
  return $rc
}

if [ "$wants_self_test" = 1 ]; then
  self_test
  exit $?
fi

# The TV app's second proof for a step: 0 when its line ($2) came after the
# mark this run set before the client started, 1 when the log isn't live, and
# a failed step when the log is live but has no line for it.
tv_line() { # step pattern
  tv_is_live || return 1
  wait_line "$tv_log" "$mark" "$2" && return 0
  echo "  The TV app's log is live, but no line for this step came:"
  tail -n "+$((mark + 1))" "$tv_log" 2> /dev/null | tr -d '\r' | grep -aF -- "$sim_name" | sed 's/^/  | /'
  bad "$1"
}

# One step, proved by a line of the simulated controller's own output ($3, in
# the log $2) and by the TV app's matching line ($4) when its log is live. $5
# is the wait in seconds (default wait_secs).
sim_step() { # step log pattern [tv pattern] [secs]
  local step="$1" log="$2" pattern="$3" tv_pattern="${4:-}" secs="${5:-$wait_secs}" proof=sim
  t0=$(date +%s)
  wait_line "$log" 0 "$pattern" "$secs" || bad "$step" "$log"
  if [ -n "$tv_pattern" ] && tv_line "$step" "$tv_pattern"; then proof=sim+tv; fi
  ok "$step" "$proof"
}

# The port, pairing code and log file of the running development TV app, from
# tv-dev.sh status, in tv_port, tv_code and tv_log. Returns 1 until it has
# all three (it hasn't started yet, or the app is still starting).
read_status() {
  local text port code file
  text="$(tools/tv-dev.sh status 2> /dev/null | tr -d '\r')" || return 1
  port="$(printf '%s\n' "$text" | sed -n 's/^Port: *\([0-9][0-9]*\).*/\1/p')"
  code="$(printf '%s\n' "$text" | sed -n 's/^Code: *\([0-9][0-9]*\).*/\1/p')"
  file="$(printf '%s\n' "$text" | sed -n 's/^Log: *//p')"
  [ -n "$port" ] && [ -n "$code" ] && [ -n "$file" ] || return 1
  tv_port="$port"
  tv_code="$code"
  tv_log="$(to_bash_path "$file")"
}

# Starts the development TV app when none is running, and leaves a copy that
# was already there alone. Its output goes to a file: tv-dev.sh warns that
# piping start into another command never ends (the app keeps the pipe open).
start_tv() {
  local i
  if read_status; then
    echo "Using the development TV app already running."
    return 0
  fi
  # A failed start can leave the app running (the flutter tool crashed, the
  # app didn't), so it's ours to stop either way.
  # Two tries: in some shells the flutter tool crashes at start (it can't make
  # a temp folder), and when that happens before it prints the port, the
  # start fails although the app runs; the second try usually gets through.
  local ok=0 try
  for try in 1 2; do
    tools/tv-dev.sh start "$@" > "$out/tv-start.log" 2>&1 && ok=1
    grep -q '^Already running' "$out/tv-start.log" || started_tv=1
    [ "$ok" = 1 ] && break
    tools/tv-dev.sh stop > /dev/null 2>&1
  done
  [ "$ok" = 1 ] || return 1
  for ((i = 0; i < wait_secs * 2; i++)); do
    if read_status; then return 0; fi
    sleep "$poll_secs"
  done
  return 1
}

# Waits until the development TV app has stopped, for the frames step's
# restart. Returns 1 if it is still there after the wait.
wait_tv_stopped() {
  local i
  for ((i = 0; i < wait_secs * 2; i++)); do
    tools/tv-dev.sh status > /dev/null 2>&1 || return 0
    sleep "$poll_secs"
  done
  return 1
}

t0=$(date +%s)
if start_tv; then ok tv-app tool; else bad tv-app "$out/tv-start.log"; fi
echo "TV app on port $tv_port, pairing code $tv_code (log: $tv_log)"

# The steps below: the simulated controller pairs, streams input for
# sim_seconds, sends a metrics batch and quits; a second, short run then
# connects with the pairing the first one saved. Every step is proved by the
# simulated controller's own line, and by the TV app's matching line too when
# its log is live.
# The first run's whole length plus the usual wait, since its first
# `dart run` also compiles the package.
sim_wait=$((sim_seconds + wait_secs))

mark="$(lines_in "$tv_log")"
(cd packages/connection && exec dart run connection:sim_controller \
  --host 127.0.0.1 --port "$tv_port" --code "$tv_code" --name "$sim_name" \
  --stream --metrics --seconds "$sim_seconds" --token-file "$token_file") > "$out/sim.log" 2>&1 &
sim_pid=$!

sim_log="$out/sim.log"
# The host's welcome is its answer to the hello, so it proves the hello landed.
sim_step hello "$sim_log" 'Welcome from ' "$sim_name \(sim[^)]*\) says hello from"
sim_step paired "$sim_log" 'Paired with ' "$sim_name connected \(pairing code\), player [0-9]+"
sim_step player "$sim_log" 'The TV made this phone player [0-9]+' "$sim_name connected \(pairing code\), player [0-9]+"
# The host answers pings and takes input and metrics batches without a line of
# its own, so these three steps are the simulated controller's word alone.
sim_step ping "$sim_log" 'ping [0-9]+ ms'
sim_step input "$sim_log" 'Summary: .*[1-9][0-9]* input states sent, 0 drops' '' "$sim_wait"
sim_step metrics "$sim_log" 'metrics batch [1-9]' '' "$sim_wait"
sim_step disconnect "$sim_log" 'Disconnecting' "$sim_name disconnected"

# The second connect: the same controller id and the host's token, saved by
# the run above, so the host lets it in without the code. The first run is
# gone by now (it has said its summary and disconnected): the host keeps one
# connection per controller, and both runs share the id.
wait "$sim_pid" 2> /dev/null
sim_pid=""

mark="$(lines_in "$tv_log")"
(cd packages/connection && exec dart run connection:sim_controller \
  --host 127.0.0.1 --port "$tv_port" --name "$sim_name" \
  --seconds "$reconnect_seconds" --token-file "$token_file") > "$out/sim2.log" 2>&1 &
sim2_pid=$!

sim_log="$out/sim2.log"
t0=$(date +%s)
wait_line "$sim_log" 0 '^CONNECTED' "$sim_wait" || bad reconnect "$sim_log"
if grep -q 'Sending pairing code' "$sim_log"; then
  echo "  The second run sent the pairing code, so it didn't use the saved pairing:"
  grep 'Sending pairing code' "$sim_log" | sed 's/^/  | /'
  bad reconnect "$sim_log"
fi
proof=sim
if tv_line reconnect "$sim_name connected \(saved pairing\), player [0-9]+"; then proof=sim+tv; fi
ok reconnect "$proof"

# adb, for asking the device whether the phone app is installed: where
# tools/emulator.sh looks for it.
find_adb() {
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -z "$sdk" ]; then
    case "$(uname -s)" in
      MINGW* | MSYS* | CYGWIN*) sdk="${LOCALAPPDATA:-}/Android/Sdk" ;;
      Darwin) sdk="$HOME/Library/Android/sdk" ;;
      *) sdk="$HOME/Android/Sdk" ;;
    esac
  fi
  sdk="${sdk//\\//}"
  if [ -x "$sdk/platform-tools/adb.exe" ]; then echo "$sdk/platform-tools/adb.exe"; return 0; fi
  if [ -x "$sdk/platform-tools/adb" ]; then echo "$sdk/platform-tools/adb"; return 0; fi
  command -v adb
}

# Whether the phone app is on the device: `pm path` prints a path when it is.
phone_has_app() { "$adb" shell pm path "$app_package" 2> /dev/null | tr -d '\r' | grep -q '^package:'; }

if [ "$use_emulator" = 1 ]; then
  t0=$(date +%s)
  if tools/emulator.sh start > "$out/emulator.log" 2>&1; then ok emulator tool; else bad emulator "$out/emulator.log"; fi

  adb="$(find_adb)" || { echo "adb isn't on the PATH and no Android SDK folder has it" >&2; exit 2; }

  # The phone's steps need the app on the device: install it when it's missing.
  if ! phone_has_app; then
    t0=$(date +%s)
    echo "The phone app isn't installed: tools/emulator.sh install"
    if tools/emulator.sh install > "$out/phone-install.log" 2>&1; then
      ok phone-install tool
    else
      bad phone-install "$out/phone-install.log"
    fi
  fi

  t0=$(date +%s)
  if tools/emulator.sh launch > "$out/phone-launch.log" 2>&1; then
    ok phone-app tool
  else
    bad phone-app "$out/phone-launch.log"
  fi

  # connect waits until the phone shows the player badge: its exit code is
  # the phone's proof that it paired.
  mark="$(lines_in "$tv_log")"
  t0=$(date +%s)
  if tools/emulator.sh connect "$emulator_pc:$tv_port" "$tv_code" > "$out/phone-connect.log" 2>&1; then
    ok phone-paired tool
  else
    bad phone-paired "$out/phone-connect.log"
  fi

  # The TV app's log is the only place the phone's hello shows, so this step
  # is skipped when that log is silent.
  t0=$(date +%s)
  if tv_is_live; then
    if wait_line "$tv_log" "$mark" '\((android|ios) [^)]*\) says hello from'; then
      ok phone-hello tv
    else
      bad phone-hello
    fi
  else
    skip phone-hello "the TV app's log is silent, so there is no hello line to read"
  fi

  t0=$(date +%s)
  if tools/emulator.sh shot "$out/phone.png" > "$out/phone-shot.log" 2>&1; then
    ok phone-shot tool
  else
    bad phone-shot "$out/phone-shot.log"
  fi

  # Launched again, which clears its data: the phone doesn't rejoin a TV later.
  t0=$(date +%s)
  if tools/emulator.sh launch > "$out/phone-reset.log" 2>&1; then
    ok phone-reset tool
  else
    bad phone-reset "$out/phone-reset.log"
  fi
fi

# The frames step (M12 §6): the measuring tools end to end. It restarts the
# TV app in the arena, so a copy this run didn't start is left alone (a
# restart also ends every pairing and truncates the TV app's log). The
# simulated controller views the game the way a phone does, streams input, and
# prints the medians it measured when its seconds run out: that line is the
# proof, since the TV app has nothing to say about its own frames.
if [ "$started_tv" = 0 ]; then
  skip frames "the TV app was already running, and the step needs one started in the arena"
else
  t0=$(date +%s)
  tools/tv-dev.sh stop > "$out/tv-stop.log" 2>&1
  wait_tv_stopped || bad frames "$out/tv-stop.log"
  start_tv --game arena || bad frames "$out/tv-start.log"
  echo "TV app in the arena on port $tv_port, pairing code $tv_code"
  mark="$(lines_in "$tv_log")"
  (cd packages/connection && exec dart run connection:sim_controller \
    --host 127.0.0.1 --port "$tv_port" --code "$tv_code" --name "$sim_name" \
    --view --stream --seconds "$sim_seconds") > "$out/sim-view.log" 2>&1 &
  sim_view_pid=$!
  sim_log="$out/sim-view.log"
  sim_step frames "$sim_log" 'Touch to frame: [0-9]+ ms median' '' "$sim_wait"
  wait "$sim_view_pid" 2> /dev/null
  sim_view_pid=""
  grep -aE '^(Touch to frame|Frame jitter|Frames): ' "$sim_log" 2> /dev/null | sed 's/^/  /'
fi

echo "Smoke passed. Logs: $out"
