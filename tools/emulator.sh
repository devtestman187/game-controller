#!/usr/bin/env bash
# Drives the phone app on an Android emulator (or a phone on adb) for checks:
# start the emulator, install with cleared data, connect to a TV app, list
# what's on screen, tap by name or position, take screenshots.
# Documented in docs/dev-tools.md.
#
#   tools/emulator.sh start [avd]          # boot (default AVD: m7_android12) and wait
#   tools/emulator.sh install [apk]        # clear data, install (builds the debug APK if missing), clear again
#   tools/emulator.sh install --build      # the same, rebuilding the debug APK first
#   tools/emulator.sh launch               # clear data and open the app on the Connect screen
#   tools/emulator.sh connect 10.0.2.2:45780 1234   # type the TV's address and code, wait until connected
#   tools/emulator.sh ui                   # the labelled things on screen, with their centres
#   tools/emulator.sh tap-name "Connect"   # tap the first thing with that label
#   tools/emulator.sh tap 1882 870         # tap at screen pixels (as in the screenshot)
#   tools/emulator.sh hold 828 596 2300    # touch and hold for 2300 ms
#   tools/emulator.sh text "hello"; tools/emulator.sh key enter|back|<keycode>
#   tools/emulator.sh shot out.png         # screenshot (pixels match tap coordinates)
#   tools/emulator.sh capture-size on|off # render at 810x1800 @315 (same dp, 44% fewer pixels)
#   tools/emulator.sh stop                 # shut the emulator down
#
# The app reconnects to the last TV it paired with, which may be someone's
# real TV app. So launch and install always clear its data first.
# From the emulator, the PC is 10.0.2.2. With several devices attached, set
# ANDROID_SERIAL. Exit code: 0 ok, 1 failed or timed out, 2 bad use.
set -u
export MSYS_NO_PATHCONV=1 # Git Bash: leave /sdcard/... paths alone

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"
app=com.thumbparty.app

# Phone render size for captures: the emulator window is about 878x427 on the host,
# so filling 1080x2400 is wasted. 810x1800 at density 315 keeps the same dp layout
# (411x914 dp) with 44% fewer pixels to draw. Reset after every take, pass or fail.
capture_size=810x1800
capture_density=315

die() { echo "emulator: $1" >&2; exit "${2:-2}"; }
winpath() { if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

# The Android SDK: ANDROID_HOME, ANDROID_SDK_ROOT, or the usual place per OS.
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$sdk" ]; then
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) sdk="${LOCALAPPDATA:-}/Android/Sdk" ;;
    Darwin) sdk="$HOME/Library/Android/sdk" ;;
    *) sdk="$HOME/Android/Sdk" ;;
  esac
fi
sdk="${sdk//\\//}"
ext=""
[ -f "$sdk/platform-tools/adb.exe" ] && ext=".exe"
adb="$sdk/platform-tools/adb$ext"
emulator="$sdk/emulator/emulator$ext"
[ -f "$adb" ] || adb="$(command -v adb || true)" # else adb from the PATH
[ -n "$adb" ] || die "adb not found: set ANDROID_HOME to the Android SDK (docs/building.md)"

a() { "$adb" "$@"; }
device_ready() { [ "$(a shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = "1" ]; }

# Every labelled node on screen: "label|class|x|y" (centre in screen pixels).
nodes() {
  a shell uiautomator dump /sdcard/thumbparty-ui.xml > /dev/null 2>&1 || return 1
  a exec-out cat /sdcard/thumbparty-ui.xml | sed 's/></>\n</g' |
    sed -nE 's/.*text="([^"]*)".*class="([^"]*)".*content-desc="([^"]*)".*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1|\3|\2|\4|\5|\6|\7/p' |
    awk -F'|' '{ label = ($2 != "" ? $2 : $1); cls = $3; sub(/.*\./, "", cls);
                 if (label != "" || cls == "EditText") printf "%s|%s|%d|%d\n", label, cls, ($4 + $6) / 2, ($5 + $7) / 2 }'
}

# The centre "x y" of the first node whose label matches $1 (or of the
# $2-th EditText when $1 is "EditText").
find_node() {
  if [ "$1" = EditText ]; then
    nodes | awk -F'|' -v n="${2:-1}" '$2 == "EditText" { if (++i == n) { print $3, $4; exit } }'
  else
    nodes | awk -F'|' -v want="$1" 'index($1, want) == 1 { print $3, $4; exit }'
  fi
}

wait_for() { # label, seconds
  for _ in $(seq 1 "$2"); do
    [ -n "$(find_node "$1")" ] && return 0
    sleep 1
  done
  return 1
}

clear_data() { a shell pm clear "$app" > /dev/null 2>&1 || true; }

case "${1:-}" in
  start)
    avd="${2:-m7_android12}"
    if a get-state > /dev/null 2>&1 && device_ready; then
      echo "A device is already running: $(a get-serialno | tr -d '\r')"
      exit 0
    fi
    [ -f "$emulator" ] || die "emulator not found in $sdk/emulator (sdkmanager emulator)"
    (nohup "$emulator" -avd "$avd" -gpu host -no-snapshot-save -no-audio < /dev/null > /dev/null 2>&1 &)
    echo "Starting $avd..."
    a wait-for-device
    for _ in $(seq 1 180); do
      if device_ready; then
        echo "Booted: $(a get-serialno | tr -d '\r') ($(a shell wm size | tr -d '\r' | sed 's/.*: //'))"
        exit 0
      fi
      sleep 2
    done
    die "didn't finish booting in 6 minutes" 1
    ;;
  stop)
    # Never leave the render override behind, even if a take failed.
    a shell wm size reset > /dev/null 2>&1 || true
    a shell wm density reset > /dev/null 2>&1 || true
    a emu kill
    ;;
  capture-size)
    case "${2:-on}" in
      on)
        a shell wm size "$capture_size" || die "wm size failed" 1
        a shell wm density "$capture_density" || die "wm density failed" 1
        echo "capture size $capture_size at density $capture_density"
        ;;
      off)
        a shell wm size reset || die "wm size reset failed" 1
        a shell wm density reset || die "wm density reset failed" 1
        echo "capture size reset"
        ;;
      *) die "usage: capture-size [on|off]" ;;
    esac
    ;;
  install)
    build=0
    if [ "${2:-}" = --build ]; then
      build=1
      shift
    fi
    apk="${2:-$root/controller_app/build/app/outputs/flutter-apk/app-debug.apk}"
    if [ -z "${2:-}" ] && { [ $build = 1 ] || [ ! -f "$apk" ]; }; then
      echo "Building the debug APK..."
      (cd "$root/controller_app" && flutter build apk --debug) || die "build failed" 1
    fi
    [ -f "$apk" ] || die "no APK at $apk"
    clear_data
    a install -r "$(winpath "$apk")" | tr -d '\r' | tail -1
    clear_data
    echo "Installed, with no saved TV."
    ;;
  launch)
    clear_data
    a shell monkey -p "$app" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
    echo "Opened with cleared data. Waiting for the Connect screen..."
    wait_for "Connect to a TV" 60 && echo "Ready." || die "the Connect screen didn't show (try: tools/emulator.sh shot x.png)" 1
    ;;
  connect)
    address="${2:-}"
    code="${3:-}"
    [ -n "$address" ] && [ -n "$code" ] || die "usage: connect <host:port> <code>"
    xy="$(find_node EditText 1)"
    [ -n "$xy" ] || die "no address box on screen: run 'tools/emulator.sh launch' first" 1
    a shell input tap $xy
    sleep 1
    a shell input text "$address"
    a shell input keyevent 66
    echo "Connecting to $address..."
    if wait_for "Enter the code" 20; then
      sleep 1
      a shell input text "$code"
      a shell input keyevent 66
    fi
    # Connected: the controller screen's player badge (P1, P2...) shows.
    for _ in $(seq 1 30); do
      badge="$(nodes | awk -F'|' '$1 ~ /^You are player [0-9]+/ || $1 ~ /^P[0-9]+$/ { print $1; exit }')"
      if [ -n "$badge" ]; then
        echo "Connected ($badge)."
        exit 0
      fi
      sleep 1
    done
    die "not connected after 30 s (wrong code? see: tools/emulator.sh ui)" 1
    ;;
  ui)
    nodes | awk -F'|' '{ printf "%-40s %-16s %5d %5d\n", substr($1, 1, 40), $2, $3, $4 }' ||
      die "couldn't read the screen" 1
    ;;
  tap-name)
    [ -n "${2:-}" ] || die "usage: tap-name <label>"
    xy="$(find_node "$2")"
    [ -n "$xy" ] || die "nothing labelled '$2' on screen (see: tools/emulator.sh ui)" 1
    a shell input tap $xy
    echo "tapped '$2' at $xy"
    ;;
  tap) [ $# -ge 3 ] || die "usage: tap <x> <y>"; a shell input tap "$2" "$3" ;;
  hold) [ $# -ge 4 ] || die "usage: hold <x> <y> <ms>"; a shell input swipe "$2" "$3" "$2" "$3" "$4" ;;
  text) [ -n "${2:-}" ] || die "usage: text <text>"; a shell input text "$2" ;;
  key)
    case "${2:-}" in
      enter) code=66 ;; back) code=4 ;; home) code=3 ;; "") die "usage: key enter|back|home|<keycode>" ;; *) code="$2" ;;
    esac
    a shell input keyevent "$code"
    ;;
  shot)
    [ -n "${2:-}" ] || die "usage: shot <file.png>"
    a exec-out screencap -p > "$2" || die "screenshot failed" 1
    echo "saved $2"
    ;;
  *)
    sed -n '2,24p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
    [ -z "${1:-}" ] && exit 0 || exit 2
    ;;
esac