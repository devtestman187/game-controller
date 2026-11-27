#!/usr/bin/env bash
# Checks what the change list touches, in one call: `dart format` on the changed
# .dart files, `dart analyze` once per touched package (nearest pubspec.yaml), one
# `flutter test`/`dart test` per package, and tools/churn.sh's generated churn
# reverted last, so a test run never leaves it behind. "Check what I touched":
# it cds to the repository root, so run it from anywhere.
#
#   tools/mine.sh          # the whole check on `git status`'s change list
#   tools/mine.sh -h       # this help
#
# Quiet when it is green: analyzer errors, failing tests (the test's name and the
# first 8 lines under it), `NO TESTS <package>`, `OK <n> tests <package>` for a
# package whose tests passed, and a RESULT line last. Tests run: the touched
# *_test.dart files that still exist plus the tests under the package's test/
# folder that name a touched lib file's basename (git grep -l), each once. A test
# this misses still runs in the runner's combined check, which stays the
# authority on the whole tree.
#
# DART, FLUTTER: the commands to run (default dart, flutter; the self-test stubs
# them). MINE_TIMEOUT: seconds the whole run may take (default 900).
#
# Exit codes: 0 ok · 1 a check failed · 2 MINE_TIMEOUT ran out or a command
# stalled · 3 bad input or setup (not a git worktree, missing dart/flutter,
# another copy running). The last line is
# `RESULT: <ok|FAILED|TIMEOUT|BAD INPUT>: <one sentence>`.
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u

bad_input() { # <why>: the plain one-line refusal the script rules ask for
  echo "RESULT: BAD INPUT: $1"
  exit 3
}

here="$(cd "$(dirname "$0")" && pwd)" || bad_input "can't find the script's folder ($0)"
cd "$here/.." || bad_input "can't cd to the repository root from $here"
root="$(pwd)"

case "${1:-}" in
  -h | --help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  '') ;;
  *) bad_input "no arguments (got '$*'; try --help)" ;;
esac

timeout_s="${MINE_TIMEOUT:-900}"
case "$timeout_s" in
  '' | *[!0-9]*) bad_input "MINE_TIMEOUT must be whole seconds, got '$timeout_s'" ;;
esac
[ "$timeout_s" -gt 0 ] || bad_input "MINE_TIMEOUT must be at least 1 second"
dart_cmd="${DART:-dart}"
flutter_cmd="${FLUTTER:-flutter}"
command -v timeout > /dev/null 2>&1 || bad_input "timeout isn't on the PATH (it comes with coreutils)"
command -v git > /dev/null 2>&1 || bad_input "git isn't on the PATH"
command -v "$dart_cmd" > /dev/null 2>&1 || bad_input "can't find the dart command '$dart_cmd' (set DART)"
command -v "$flutter_cmd" > /dev/null 2>&1 || bad_input "can't find the flutter command '$flutter_cmd' (set FLUTTER)"
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || bad_input "not a git worktree: $root"
[ -f "$here/churn.sh" ] || bad_input "tools/churn.sh is missing (it lists the generated churn)"
. "$here/churn.sh"

# One lock per change list: a second copy is refused, a stale one (its pid gone) replaced.
lock=".dart_tool/mine.lock"
mkdir -p "$(dirname "$lock")" || bad_input "can't create the folder for the lock: $(dirname "$lock")"
if [ -f "$lock" ]; then
  holder="$(cat "$lock" 2> /dev/null)"
  case "$holder" in
    '' | *[!0-9]*) ;; # no usable pid recorded: stale, replace it below
    *) kill -0 "$holder" 2> /dev/null && bad_input "another mine.sh is running (pid $holder, lock $lock)" ;;
  esac
fi
printf '%s\n' "$$" > "$lock" || bad_input "can't write the lock: $lock"

child=""
tmp=""
cleanup() { # at every exit, an interrupt included: the child, the logs, the lock
  if [ -n "$child" ]; then
    kill "$child" 2> /dev/null
    wait "$child" 2> /dev/null # reap it before removing the log it held open (Windows)
  fi
  [ -n "$tmp" ] && rm -rf "$tmp"
  if [ "$(cat "$lock" 2> /dev/null)" = "$$" ]; then
    rm -f "$lock"
  fi
}
trap cleanup EXIT
trap 'trap "" INT TERM; exit 130' INT
trap 'trap "" INT TERM; exit 143' TERM
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/thumbparty-mine-XXXXXX")" || bad_input "can't create a temp folder"
deadline=$(($(date +%s) + timeout_s))
churn_snapshot "$tmp/churn-snapshot" # churn already dirty now may be a person's edit: not reverted at the end

timeout_exit() { # <what>: the run's time is gone; revert the churn and stop
  churn_revert
  echo "TIMEOUT: $1 exceeded ${timeout_s}s"
  echo "RESULT: TIMEOUT: $1 exceeded ${timeout_s}s"
  exit 2
}

run() { # <what> <log> <dir> <command...>: run it there, in the background, under the time left
  local what="$1" log="$2" dir="$3" left rc
  shift 3
  left=$((deadline - $(date +%s)))
  [ "$left" -lt 1 ] && timeout_exit "$what"
  (cd "$dir" && exec timeout "$left" "$@") > "$log" 2>&1 &
  child=$!
  wait "$child"
  rc=$?
  child=""
  [ "$rc" = 124 ] && timeout_exit "$what"
  return "$rc"
}

has_item() { # <value> <items...>: is the value among them?
  local value="$1" item
  shift
  for item in "$@"; do [ "$item" = "$value" ] && return 0; done
  return 1
}

show_lines() { # <log> <grep pattern> <count>: the matching lines (or the first ones), indented
  local shown
  shown="$(tr '\r' '\n' < "$1" | grep -E "$2" | head -n "$3")"
  if [ -z "$shown" ]; then shown="$(tr '\r' '\n' < "$1" | grep -vE '^[[:space:]]*$' | head -n "$3")"; fi
  [ -n "$shown" ] && printf '%s\n' "$shown" | sed 's/^/  /'
  return 0
}

print_test_failures() { # <log>: each failing test's name and the first 8 lines under it
  local shown rc
  shown="$(tr '\r' '\n' < "$1" | awk '
    /\[E\]$/ {
      name = $0; sub(/ \[E\]$/, "", name)
      if (match(name, /[0-9]+:[0-9]+ \+[0-9]+ -[0-9]+: /)) name = substr(name, RSTART + RLENGTH)
      printf "  FAILED %s\n", name
      left = 8; found = 1; next
    }
    left > 0 {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[0-9]+:[0-9]+ /) { left = 0; next }
      printf "    %s\n", $0
      left--
    }
    END { exit(found ? 0 : 1) }
  ')"
  rc=$?
  [ "$rc" = 0 ] && printf '%s\n' "$shown" && return 0
  show_lines "$1" 'Error|error|Exception|Failed to load' 8
}

test_count() { # <log>: the test count the runner's last summary line reports, empty if none
  tr '\r' '\n' < "$1" | grep -oE '\+[0-9]+(: All tests passed| -[0-9]+: Some tests failed)' | tail -n 1 \
    | grep -oE '^\+[0-9]+' | tr -d '+'
}

changed=() # every path git status reports; a rename counts as its new path
old_paths=() # the old paths of renames: a test naming one still runs
dart_touched=() # changed or removed .dart paths
dart_files=() # the changed .dart files that still exist: what dart format gets
packages=() # each touched package once: what dart analyze gets
tests=() # the test files of the package being handled (paths from the root)

read_changes() { # fills changed and old_paths from git status
  local entries=() entry i=0
  # --untracked-files=all lists each new file, not its folder: a folder entry would hide its .dart files
  while IFS= read -r -d '' entry; do entries+=("$entry"); done < <(git status --porcelain -z --untracked-files=all)
  while [ "$i" -lt "${#entries[@]}" ]; do
    entry="${entries[$i]}"
    i=$((i + 1))
    case "${entry:0:2}" in
      *R* | *C*) # the rename's old path follows; a test naming it still runs
        [ -n "${entries[$i]:-}" ] && old_paths+=("${entries[$i]}")
        i=$((i + 1))
        ;;
    esac
    changed+=("${entry:3}")
  done
}

package_of() { # <path>: the nearest folder with a pubspec.yaml ("" for the root), empty when none
  local dir
  dir="$(dirname -- "$1")"
  while :; do
    if [ -f "$dir/pubspec.yaml" ]; then
      [ "$dir" = "." ] && dir=""
      printf '%s' "$dir"
      return 0
    fi
    [ "$dir" = "." ] && return 0
    case "$dir" in
      */*) dir="${dir%/*}" ;;
      *) dir="." ;;
    esac
  done
}

collect() { # fills dart_touched, dart_files and packages from the change list
  local path package
  for path in ${changed[@]+"${changed[@]}"} ${old_paths[@]+"${old_paths[@]}"}; do
    case "$path" in
      pubspec.yaml | */pubspec.yaml) ;;
      *.dart) dart_touched+=("$path"); [ -f "$path" ] && dart_files+=("$path") ;;
      */) # a folder git lists as one entry (a nested repository): its files are not seen, so fail
        echo "FAILED untracked folder $path: its files are not listed, so they cannot be checked"
        failed=$((failed + 1))
        continue
        ;;
      *) continue ;;
    esac
    package="$(package_of "$path")"
    has_item "$package" ${packages[@]+"${packages[@]}"} || packages+=("$package")
  done
}

format_dart() { # dart format on the changed .dart files that exist
  [ "${#dart_files[@]}" -gt 0 ] || return 0
  run "dart format" "$tmp/format.log" "$root" "$dart_cmd" format "${dart_files[@]}" && return 0
  failed=$((failed + 1))
  echo "FAILED dart format"
  show_lines "$tmp/format.log" '.' 8
}

analyze_packages() { # dart analyze once per touched package
  local package dir
  for package in ${packages[@]+"${packages[@]}"}; do
    dir="${package:-.}"
    run "dart analyze $dir" "$tmp/analyze.log" "$root" "$dart_cmd" analyze --fatal-infos "$dir" && continue
    failed=$((failed + 1))
    echo "FAILED dart analyze $dir"
    show_lines "$tmp/analyze.log" '(error|warning|info) - ' 8
  done
}

fill_tests() { # <package>: its touched tests plus the tests naming a touched lib file, once each
  local package="$1" path base hit
  tests=()
  for path in ${changed[@]+"${changed[@]}"}; do
    case "$path" in *_test.dart) ;; *) continue ;; esac
    [ -f "$path" ] || continue
    [ "$(package_of "$path")" = "$package" ] || continue
    has_item "$path" ${tests[@]+"${tests[@]}"} || tests+=("$path")
  done
  for path in ${dart_touched[@]+"${dart_touched[@]}"}; do
    [ "$(package_of "$path")" = "$package" ] || continue
    case "$path" in lib/* | */lib/*) ;; *) continue ;; esac
    base="$(basename -- "$path")"
    while IFS= read -r hit; do
      case "$hit" in *_test.dart) ;; *) continue ;; esac
      [ -f "$hit" ] || continue
      has_item "$hit" ${tests[@]+"${tests[@]}"} || tests+=("$hit")
    done < <(git grep -lF -e "$base" -- "${package:+$package/}test" 2> /dev/null)
  done
}

test_command() { # <package>: dart for a plain Dart package, flutter for a Flutter one
  if grep -qE '^[[:space:]]+(flutter|flutter_test):' "${1:+$1/}pubspec.yaml" 2> /dev/null; then
    printf '%s' "$flutter_cmd"
  else
    printf '%s' "$dart_cmd"
  fi
}

run_tests() { # one dart test/flutter test per touched package
  local package dir rel=() count path
  for package in ${packages[@]+"${packages[@]}"}; do
    fill_tests "$package"
    dir="${package:-.}"
    if [ "${#tests[@]}" = 0 ]; then
      echo "NO TESTS $dir"
      continue
    fi
    rel=()
    for path in ${tests[@]+"${tests[@]}"}; do rel+=("${path#"${package:+$package/}"}"); done
    if run "tests $dir" "$tmp/test.log" "$root/$dir" "$(test_command "$package")" test "${rel[@]}"; then
      tested=$((tested + 1))
      count="$(test_count "$tmp/test.log")"
      echo "OK ${count:+$count }tests $dir"
    else
      failed=$((failed + 1))
      echo "FAILED tests $dir"
      print_test_failures "$tmp/test.log"
    fi
  done
}

failed=0
tested=0
read_changes
collect
if [ "${#changed[@]}" = 0 ]; then
  echo "no changes: nothing to format, analyze or test"
else
  format_dart
  analyze_packages
  run_tests
fi
churn_revert
if [ "$failed" -gt 0 ]; then
  echo "RESULT: FAILED: $failed check(s) failed (${#packages[@]} package(s), ${#dart_files[@]} file(s) formatted)"
  exit 1
fi
echo "RESULT: ok: ${#dart_files[@]} file(s) formatted, ${#packages[@]} package(s) analyzed, $tested package(s) tested"
exit 0
