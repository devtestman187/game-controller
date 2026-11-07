#!/usr/bin/env bash
# Starts, checks and stops a development copy of the TV app on Windows
# (flutter run -d windows), without touching a release copy someone is using.
# Documented in docs/dev-tools.md.
#
#   tools/tv-dev.sh start     # build and start; prints the port and pairing code
#                             # (always passes --dart-define=SHARE_VIEW=true, so
#                             # phones joined to it show the games it hosts, M12)
#   tools/tv-dev.sh start --hz 20|30|60 --game arena|shape_race
#                             # start straight into a game, for measuring runs (M12)
#   tools/tv-dev.sh status    # running? port, pairing code, log file
#   tools/tv-dev.sh stop      # stops only this repository's debug build
#   tools/tv-dev.sh log       # the last 40 log lines
#   tools/tv-dev.sh window shot out.png   # anything after "window" goes to tools/tv-window.ps1
#
# The app listens on 45780 if it's free, otherwise on another port (a
# release copy already running keeps 45780); phones connect to the port
# printed here. Exit code: 0 ok, 1 not running or didn't start, 2 bad use.
# Needs Git Bash on Windows, Flutter, and Windows PowerShell.
set -u

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"
state="${TMPDIR:-${TEMP:-/tmp}}/thumbparty-dev"
log="$state/tv.log"
mkdir -p "$state" || exit 2

winpath() { if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
usage() { sed -n '2,/^set -u/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; }
ps_run() { powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$1" | tr -d '\r'; }
exe="$(winpath "$root/tv_test_app/build/windows/x64/runner/Debug/ThumbPartyTV.exe")"

# The process ID of this repository's debug build, or nothing.
running_pid() {
  ps_run "Get-Process ThumbPartyTV -ErrorAction SilentlyContinue | Where-Object { \$_.Path -ieq '$exe' } | Select-Object -First 1 -ExpandProperty Id"
}

# "port code" from the newest "Listening on port N (pairing code C)" line.
port_and_code() {
  [ -f "$log" ] || return 1
  tr -d '\r' < "$log" | grep -aoE 'Listening on port [0-9]+ \(pairing code [0-9]+\)' | tail -1 |
    sed -E 's/Listening on port ([0-9]+) \(pairing code ([0-9]+)\)/\1 \2/'
}

status() {
  local pid pc
  pid="$(running_pid)"
  if [ -z "$pid" ]; then
    echo "Not running."
    return 1
  fi
  pc="$(port_and_code)"
  echo "Running: process $pid"
  if [ -n "$pc" ]; then
    echo "Port:    ${pc% *}   (a phone or the Android emulator connects to <this PC's IP>:${pc% *}, the emulator uses 10.0.2.2:${pc% *})"
    echo "Code:    ${pc#* }"
  fi
  echo "Log:     $(winpath "$log")"
}

case "${1:-}" in
  start)
    shift
    # A dev TV always shares its game with the phones that join it (m12-joined-view §0.1).
    defines=(--dart-define=SHARE_VIEW=true)
    while [ $# -gt 0 ]; do
      case "$1" in
        --hz | --game)
          [ $# -ge 2 ] || { echo "$1 needs a value." >&2; usage >&2; exit 2; }
          if [ "$1" = --hz ]; then
            case "$2" in
              20 | 30 | 60) defines+=("--dart-define=FRAME_RATE_HZ=$2") ;;
              *) echo "--hz is 20, 30 or 60, not $2." >&2; usage >&2; exit 2 ;;
            esac
          else
            case "$2" in
              arena | shape_race) defines+=("--dart-define=START_GAME=$2") ;;
              *) echo "--game is arena or shape_race, not $2." >&2; usage >&2; exit 2 ;;
            esac
          fi
          shift 2
          ;;
        *) echo "Unknown start option $1." >&2; usage >&2; exit 2 ;;
      esac
    done
    if [ -n "$(running_pid)" ]; then
      echo "Already running."
      [ ${#defines[@]} -gt 0 ] && echo "The start options apply to a new start: tools/tv-dev.sh stop first."
      status
      exit 0
    fi
    command -v flutter > /dev/null 2>&1 || { echo "flutter isn't on the PATH (docs/building.md)" >&2; exit 2; }
    : > "$log"
    # Detached, so it keeps running after this shell closes. stdin from
    # /dev/null: flutter run would otherwise wait for keys (r, R, q).
    (cd "$root/tv_test_app" && nohup flutter run -d windows "${defines[@]}" < /dev/null >> "$log" 2>&1 &)
    echo "Building and starting (the first build takes a few minutes)..."
    for _ in $(seq 1 600); do
      if [ -n "$(port_and_code)" ]; then
        status
        exit 0
      fi
      if grep -aqE 'Error: |BUILD FAILED|Exception:|Lost connection to device' "$log" 2> /dev/null; then
        echo "It didn't start. The end of the log:"
        tail -20 "$log"
        exit 1
      fi
      sleep 1
    done
    echo "Not listening after 10 minutes. Log: $(winpath "$log")"
    exit 1
    ;;
  status) status; exit $? ;;
  stop)
    pid="$(running_pid)"
    if [ -z "$pid" ]; then
      echo "Not running."
      exit 0
    fi
    ps_run "Stop-Process -Id $pid -Confirm:\$false"
    echo "Stopped process $pid (flutter run ends by itself)."
    ;;
  log) [ -f "$log" ] && tail -40 "$log" || echo "No log yet." ;;
  window)
    shift
    # A Git Bash path for the screenshot (/tmp/x.png, /c/...) becomes a Windows one.
    if [ "${1:-}" = shot ] && [ -n "${2:-}" ] && [ "${2:0:1}" = / ]; then
      set -- shot "$(winpath "$2")" "${@:3}"
    fi
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(winpath "$root/tools/tv-window.ps1")" "$@" | tr -d '\r'
    exit "${PIPESTATUS[0]}"
    ;;
  *)
    usage
    [ -z "${1:-}" ] && exit 0 || exit 2
    ;;
esac
