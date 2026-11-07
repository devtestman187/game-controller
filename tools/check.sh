#!/usr/bin/env bash
# Runs every automated check in the repo and prints one line per check.
# Full output goes to log files; on a failure, the lines that matter are
# printed too. Documented in docs/dev-tools.md.
#
#   tools/check.sh                 # everything
#   tools/check.sh phone tv        # only some checks (names below)
#   tools/check.sh --list          # list the checks
#   tools/check.sh --verbose ...   # also print every check's full output
#
# Checks: format analyze protocol connection metrics kit arena puzzle host phone tv
# Exit code: 0 if every check passed, 1 if any failed, 2 for bad arguments
# or a missing tool. Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

# name | folder | command | what it covers
checks=(
  "format|.|dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets|code formatting (120 columns, from analysis_options.yaml)"
  "analyze|.|dart analyze --fatal-infos|static analysis of the whole workspace (infos fail, as on CI)"
  "protocol|packages/protocol|dart test|messages and codec"
  "connection|packages/connection|dart test|server, client, game host (real sockets on localhost)"
  "metrics|packages/metrics|dart test|analytics counters, sessions, report"
  "kit|packages/game_kit|flutter test|the session loop, modules and hosting settings"
  "arena|packages/test_game|flutter test|the Arena game's rules and view"
  "puzzle|packages/puzzle_game|flutter test|Shape Race rules, view and snapshots"
  "host|packages/party_host|flutter test|the host service, host screens, sound and stats"
  "phone|controller_app|flutter test|the phone app's widget tests"
  "tv|tv_test_app|flutter test|the TV app's widget tests"
)

verbose=0
wanted=()
for arg in "$@"; do
  case "$arg" in
    -v | --verbose) verbose=1 ;;
    -l | --list)
      for c in "${checks[@]}"; do
        IFS='|' read -r name dir cmd about <<< "$c"
        printf '%-11s %-22s %s\n' "$name" "$dir" "$about"
      done
      exit 0
      ;;
    -h | --help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
    *) wanted+=("$arg") ;;
  esac
done

# Every name asked for must exist.
for w in ${wanted[@]+"${wanted[@]}"}; do
  found=0
  for c in "${checks[@]}"; do [ "${c%%|*}" = "$w" ] && found=1; done
  if [ $found = 0 ]; then
    echo "Unknown check: $w (try --list)" >&2
    exit 2
  fi
done

for tool in dart flutter; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "$tool isn't on the PATH. See docs/building.md (One-time toolchain)." >&2
    exit 2
  fi
done

logs="${TMPDIR:-${TEMP:-/tmp}}/thumbparty-check-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$logs" || exit 2

# The lines worth showing from a failed run: test names that failed, the
# expectation lines, compile and analyzer errors, files that need formatting.
interesting='\[E\]|Expected:|Actual:|Which:|Error:|error -|warning -|info -|Changed |Some tests failed|Failed to load|Exception|Test failed'

failed=()
start_all=$(date +%s)
for c in "${checks[@]}"; do
  IFS='|' read -r name dir cmd about <<< "$c"
  if [ ${#wanted[@]} -gt 0 ]; then
    skip=1
    for w in "${wanted[@]}"; do [ "$w" = "$name" ] && skip=0; done
    [ $skip = 1 ] && continue
  fi
  log="$logs/$name.log"
  start=$(date +%s)
  (cd "$root/$dir" && eval "$cmd") > "$log" 2>&1
  rc=$?
  secs=$(($(date +%s) - start))
  # "+262: All tests passed!" → 262 tests. Progress lines use \r, so split on it.
  count="$(tr '\r' '\n' < "$log" | grep -oE '\+[0-9]+(: All tests passed| -[0-9]+: Some tests failed)' | tail -1 | grep -oE '^\+[0-9]+' | tr -d '+')"
  detail=""
  [ -n "$count" ] && detail="$count tests, "
  if [ $rc = 0 ]; then
    printf 'PASS  %-11s (%s%ss)\n' "$name" "$detail" "$secs"
  else
    failed+=("$name")
    [ -n "$count" ] && detail="$count passed, "
    printf 'FAIL  %-11s (%sexit %s, %ss)  log: %s\n' "$name" "$detail" "$rc" "$secs" "$log"
    tr '\r' '\n' < "$log" | grep -E "$interesting" | grep -vE '^\s+(dart:|package:)' | awk '!seen[$0]++' | head -40 | sed 's/^/      /'
  fi
  [ $verbose = 1 ] && sed 's/^/      | /' "$log"
done

total=$(($(date +%s) - start_all))
if [ ${#failed[@]} = 0 ]; then
  echo "All checks passed (${total}s). Logs: $logs"
  exit 0
fi
echo "${#failed[@]} failed: ${failed[*]} (${total}s). Logs: $logs"
exit 1
