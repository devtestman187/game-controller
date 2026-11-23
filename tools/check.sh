#!/usr/bin/env bash
# Runs every automated check in the repo and prints one line per check.
# Full output goes to log files; on a failure, the lines that matter are
# printed too. Documented in docs/dev-tools.md.
#
#   tools/check.sh                 # everything
#   tools/check.sh phone tv        # only some checks (names below)
#   tools/check.sh --list          # list the checks
#   tools/check.sh --verbose ...   # also print every check's full output
#   tools/check.sh --fail-fast ... # stop after a failed format or analyze
#   tools/check.sh -j 4 ...        # the suites four at a time (format and analyze run first)
#
# CHECK_ANALYZE_PKGS="packages/a controller_app" limits the analyze check to those folders
# (tools/flash.sh sets it for a job from the job's own files; the runner runs the whole workspace).
# CHECK_FAIL_FAST=1 (the same as --fail-fast): when format or analyze fails, every check
# after it is printed as SKIPPED and none of them runs; off by default.
# -j N (or -jN, --jobs N, CHECK_JOBS=N): the suites run N at a time, in tools/check-par.sh; format and
# analyze still run first, serially. The lines print in check order after the run; 1 (the default) is serial.
# CHECK_SKIP="tools" (names separated by a space or a comma): each named check prints
# "SKIPPED <name> (CHECK_SKIP)" and does not run; it is not a failure. The runner sets it
# to skip the tools suite when no job changed a file under tools/. An unknown name is bad input.
# CHECK_DART and CHECK_FLUTTER: the commands to run (default dart and flutter; the
# self-test stubs them).
# Checks: format analyze protocol connection metrics kit look arena puzzle host phone tv tools
# Exit code: 0 if every check passed, 1 if any failed, 2 for bad arguments
# or a missing tool. Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

# The commands to run: the self-test stubs these, so a case never needs the toolchain.
dart_cmd="${CHECK_DART:-dart}"
flutter_cmd="${CHECK_FLUTTER:-flutter}"

# Fail-fast: after a failed format or analyze, the checks after it don't run.
fail_fast=0
case "${CHECK_FAIL_FAST:-0}" in
  0) ;;
  1) fail_fast=1 ;;
  *)
    echo "CHECK_FAIL_FAST must be 0 or 1, got '$CHECK_FAIL_FAST'" >&2
    exit 2
    ;;
esac

# name | folder | command | what it covers
checks=(
  "format|.|dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets|code formatting (120 columns, from analysis_options.yaml)"
  "analyze|.|dart analyze --fatal-infos ${CHECK_ANALYZE_PKGS:-}|static analysis of the whole workspace (infos fail, as on CI); CHECK_ANALYZE_PKGS limits it to some folders"
  "protocol|packages/protocol|dart test|messages and codec"
  "connection|packages/connection|dart test|server, client, game host (real sockets on localhost)"
  "metrics|packages/metrics|dart test|analytics counters, sessions, report"
  "kit|packages/game_kit|flutter test|the session loop, modules and hosting settings"
  "look|packages/toy_look|flutter test|the look package: palettes, Look setting, type, theme, shapes, shaders and fallback"
  "arena|packages/test_game|flutter test|the Arena game's rules and view"
  "puzzle|packages/puzzle_game|flutter test|Shape Race rules, view and snapshots"
  "host|packages/party_host|flutter test|the host service, host screens, sound and stats"
  "phone|controller_app|flutter test|the phone app's widget tests"
  "tv|tv_test_app|flutter test|the TV app's widget tests"
  "tools|.|bash tools/selftest.sh -j 4|shell tool self-tests (tools/tests/*-test.sh), four at once"
)

# Runs one check's command, with the toolchain hooks swapped in for the commands
# that name dart or flutter; anything else runs as written.
run_cmd() { # <the check's command>
  case "$1" in
    dart\ *) eval "\"$dart_cmd\" ${1#dart }" ;;
    flutter\ *) eval "\"$flutter_cmd\" ${1#flutter }" ;;
    *) eval "$1" ;;
  esac
}

# selected <name>: 0 when the check was asked for, or when no check name was given.
selected() {
  local w
  [ ${#wanted[@]} = 0 ] && return 0
  for w in "${wanted[@]}"; do [ "$w" = "$1" ] && return 0; done
  return 1
}

# skipped_by_env <name>: 0 when CHECK_SKIP names the check.
skipped_by_env() {
  case " $skip_list " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

# print_result <name> <rc> <secs> <log>: the check's PASS or FAIL line, the lines that matter from a
# failed log, and the whole log with -v. A failure is added to failed. Shared by the serial and parallel runs.
print_result() {
  local name="$1" rc="$2" secs="$3" log="$4" count detail=""
  # "+262: All tests passed!" → 262 tests. Progress lines use \r, so split on it.
  count="$(tr '\r' '\n' < "$log" | grep -oE '\+[0-9]+(: All tests passed| -[0-9]+: Some tests failed)' | tail -1 | grep -oE '^\+[0-9]+' | tr -d '+')"
  [ -n "$count" ] && detail="$count tests, "
  if [ $rc = 0 ]; then
    printf 'PASS  %-11s (%s%ss)\n' "$name" "$detail" "$secs"
  else
    failed+=("$name")
    [ -n "$count" ] && detail="$count passed, "
    printf 'FAIL  %-11s (%sexit %s, %ss)  log: %s\n' "$name" "$detail" "$rc" "$secs" "$log"
    tr '\r' '\n' < "$log" | grep -E "$interesting" | grep -vE '^\s+(dart:|package:)' | awk '!seen[$0]++' | head -40 | sed 's/^/      /'
  fi
  if [ $verbose = 1 ]; then sed 's/^/      | /' "$log"; fi
}

# run_check <name> <folder> <command>: runs one check in turn, or prints SKIPPED after a failed format or analyze.
run_check() {
  local name="$1" dir="$2" cmd="$3" log start rc secs
  if [ -n "$skip_reason" ]; then
    printf 'SKIPPED %s (%s)\n' "$name" "$skip_reason"
    return 0
  fi
  log="$logs/$name.log"
  start=$(date +%s)
  (cd "$root/$dir" && run_cmd "$cmd") > "$log" 2>&1
  rc=$?
  secs=$(($(date +%s) - start))
  print_result "$name" "$rc" "$secs" "$log"
  if [ $rc != 0 ] && [ $fail_fast = 1 ]; then
    case "$name" in
      format | analyze) skip_reason="$name failed" ;;
    esac
  fi
}

verbose=0
wanted=()
jobs="${CHECK_JOBS:-1}" # the suites at once; 1 runs them serially
while [ $# -gt 0 ]; do
  arg="$1"
  shift
  case "$arg" in
    -v | --verbose) verbose=1 ;;
    -f | --fail-fast) fail_fast=1 ;;
    -j | --jobs)
      if [ $# = 0 ]; then
        echo "$arg needs the number of suites to run at once (try --help)" >&2
        exit 2
      fi
      jobs="$1"
      shift
      ;;
    -j*) jobs="${arg#-j}" ;;
    -l | --list)
      for c in "${checks[@]}"; do
        IFS='|' read -r name dir cmd about <<< "$c"
        printf '%-11s %-22s %s\n' "$name" "$dir" "$about"
      done
      exit 0
      ;;
    -h | --help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
    *) wanted+=("$arg") ;;
  esac
done

# The job count: a whole number of at least 1 (from -j, or CHECK_JOBS when no -j is given).
case "$jobs" in
  '' | *[!0-9]* | 0)
    echo "The job count must be a whole number of at least 1, got '$jobs' (-j or CHECK_JOBS)" >&2
    exit 2
    ;;
esac
if [ "$jobs" -gt 1 ]; then
  if [ ! -f "$root/tools/check-par.sh" ]; then
    echo "tools/check-par.sh is missing (it runs the suites for -j $jobs)" >&2
    exit 2
  fi
  . "$root/tools/check-par.sh"
fi

# Every name asked for must exist.
for w in ${wanted[@]+"${wanted[@]}"}; do
  found=0
  for c in "${checks[@]}"; do [ "${c%%|*}" = "$w" ] && found=1; done
  if [ $found = 0 ]; then
    echo "Unknown check: $w (try --list)" >&2
    exit 2
  fi
done

# CHECK_SKIP: the names to skip, with commas read as spaces; every name must exist.
skip_list="${CHECK_SKIP:-}"
skip_list="${skip_list//,/ }"
for s in $skip_list; do
  found=0
  for c in "${checks[@]}"; do [ "${c%%|*}" = "$s" ] && found=1; done
  if [ $found = 0 ]; then
    echo "Unknown check in CHECK_SKIP: $s (try --list)" >&2
    exit 2
  fi
done

for tool in "$dart_cmd" "$flutter_cmd"; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "$tool isn't on the PATH (set CHECK_DART or CHECK_FLUTTER)." >&2
    echo "See docs/building.md (One-time toolchain)." >&2
    exit 2
  fi
done

logs="${TMPDIR:-${TEMP:-/tmp}}/thumbparty-check-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$logs" || exit 2

# The lines worth showing from a failed run: test names that failed, the
# expectation lines, compile and analyzer errors, files that need formatting.
# The FAIL lines of a failed shell suite (tools/selftest.sh prints "FAIL  <script>" and "  FAIL <case>")
# are kept, so the failing script and case show here and in STOP.md.
interesting='\[E\]|Expected:|Actual:|Which:|Error:|error -|warning -|info -|Changed |Some tests failed|Failed to load|Exception|Test failed|^ *FAIL[ :]'

failed=()
skip_reason=""
deferred=() # the suites that check-par.sh runs at once after format and analyze (-j above 1)
start_all=$(date +%s)
for c in "${checks[@]}"; do
  IFS='|' read -r name dir cmd about <<< "$c"
  selected "$name" || continue
  if [ "$jobs" -gt 1 ] && [ "$name" != format ] && [ "$name" != analyze ]; then
    deferred+=("$c")
    continue
  fi
  if skipped_by_env "$name"; then
    printf 'SKIPPED %s (CHECK_SKIP)\n' "$name"
    continue
  fi
  run_check "$name" "$dir" "$cmd"
done
if [ "$jobs" -gt 1 ]; then
  run_parallel_suites
fi

total=$(($(date +%s) - start_all))
if [ ${#failed[@]} = 0 ]; then
  echo "All checks passed (${total}s). Logs: $logs"
  exit 0
fi
echo "${#failed[@]} failed: ${failed[*]} (${total}s). Logs: $logs"
exit 1
