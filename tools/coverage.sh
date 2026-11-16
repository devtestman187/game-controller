#!/usr/bin/env bash
# Measures line coverage for every package, with every file in its lib/ counted.
#
#   tools/coverage.sh                     # regenerate the coverage tests, run all
#   tools/coverage.sh protocol kit        # only these packages
#   tools/coverage.sh --no-gen protocol   # keep the generated tests as they are
#   tools/coverage.sh --list              # list the packages
#
# The numbers are exact because tools/coverage_imports.dart first writes one
# test per package that imports every file in its lib/: a file nothing imports
# is otherwise missing from coverage/lcov.info instead of counting as 0%
# (M14 bugs15). `flutter test --coverage` is used everywhere, also for the pure
# Dart packages, which it runs in this workspace. The table comes from
# tools/coverage_summary.dart, also written to coverage/summary.txt at the
# repository root.
#
# Exit code: 0 if every package's tests passed, 1 if any failed (the table is
# printed either way), 2 for bad arguments or a missing tool. Works in Git
# Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

# folder | what it covers
packages=(
  "packages/protocol|messages and codec"
  "packages/connection|server, client, game host (real sockets on localhost)"
  "packages/metrics|analytics counters, sessions, report"
  "packages/game_kit|the session loop, modules and hosting settings"
  "packages/toy_look|the look package: palettes, type, theme, shapes, shaders and fallback"
  "packages/test_game|the Arena game's rules and view"
  "packages/puzzle_game|Shape Race rules, view and snapshots"
  "packages/party_host|the host service, host screens, sound and stats"
  "controller_app|the phone app's widget tests"
  "tv_test_app|the TV app's widget tests"
)

generate=1
wanted=()
for arg in "$@"; do
  case "$arg" in
    --no-gen) generate=0 ;;
    -l | --list)
      for c in "${packages[@]}"; do
        IFS='|' read -r folder about <<< "$c"
        printf '%-22s %s\n' "$folder" "$about"
      done
      exit 0
      ;;
    -h | --help)
      sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
    *) wanted+=("$arg") ;;
  esac
done

# Every name asked for must be a folder above or its last part, so both
# `packages/protocol` and `protocol` work.
selected=()
for w in ${wanted[@]+"${wanted[@]}"}; do
  found=""
  for c in "${packages[@]}"; do
    folder="${c%%|*}"
    if [ "$w" = "$folder" ] || [ "$w" = "${folder##*/}" ]; then found="$folder"; fi
  done
  if [ -z "$found" ]; then
    echo "Unknown package: $w (try --list)" >&2
    exit 2
  fi
  selected+=("$found")
done

for tool in dart flutter; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "$tool isn't on the PATH. See docs/building.md (One-time toolchain)." >&2
    exit 2
  fi
done

logs="${TMPDIR:-${TEMP:-/tmp}}/thumbparty-coverage-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$logs" || exit 2

if [ $generate = 1 ]; then
  dart run tools/coverage_imports.dart || exit 1
  echo
fi

# The lines worth showing from a failed run, as in tools/check.sh.
interesting='\[E\]|Expected:|Actual:|Which:|Error:|error -|warning -|info -|Changed |Some tests failed|Failed to load|Exception|Test failed'

failed=()
for c in "${packages[@]}"; do
  IFS='|' read -r folder about <<< "$c"
  if [ ${#selected[@]} -gt 0 ]; then
    skip=1
    for w in "${selected[@]}"; do [ "$w" = "$folder" ] && skip=0; done
    [ $skip = 1 ] && continue
  fi
  log="$logs/${folder//\//-}.log"
  rm -rf "$folder/coverage"
  start=$(date +%s)
  (cd "$root/$folder" && flutter test --coverage) > "$log" 2>&1
  rc=$?
  secs=$(($(date +%s) - start))
  # "+262: All tests passed!" → 262 tests. Progress lines use \r, so split on it.
  count="$(tr '\r' '\n' < "$log" | grep -oE '\+[0-9]+(: All tests passed| -[0-9]+: Some tests failed)' | tail -1 | grep -oE '^\+[0-9]+' | tr -d '+')"
  detail=""
  [ -n "$count" ] && detail="$count tests, "
  if [ $rc = 0 ]; then
    printf 'PASS  %-22s (%s%ss)\n' "$folder" "$detail" "$secs"
  else
    failed+=("$folder")
    [ -n "$count" ] && detail="$count passed, "
    printf 'FAIL  %-22s (%sexit %s, %ss)  log: %s\n' "$folder" "$detail" "$rc" "$secs" "$log"
    tr '\r' '\n' < "$log" | grep -E "$interesting" | grep -vE '^\s+(dart:|package:)' | awk '!seen[$0]++' | head -40 | sed 's/^/      /'
  fi
done

echo
dart run tools/coverage_summary.dart || exit 1
echo "Coverage logs: $logs"
if [ ${#failed[@]} = 0 ]; then
  exit 0
fi
echo "${#failed[@]} failed: ${failed[*]}" >&2
exit 1
