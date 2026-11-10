#!/usr/bin/env bash
# The level kit (M14 k1a): make, check and render one level, a puzzle or a map.
#
#   tools/level.sh new puzzle <id> --level easy|medium [--name "Name"]
#   tools/level.sh check [id]      # every kind's rule book, or one level's
#   tools/level.sh render <id>     # writes docs/design/puzzles/<id>.png
#   tools/level.sh --self-test     # print the commands a run would use
#
# Maps come with the Arena's map kit (M14 k1b). The guide is docs/levels.md.
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

# kind | files folder | package | test define | check tests | render test
# A kind joins this table when its game reads level files: maps in M14 k1b.
kinds=(
  "puzzle|packages/puzzle_game/puzzles|packages/puzzle_game|puzzleId|test/puzzle_check_test.dart test/puzzle_schema_test.dart|test/puzzle_render_test.dart"
)

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

# Why there is no level $1: one line per kind, each with its own folder.
no_level() {
  local row kind folder package define check_tests render_test
  for row in "${kinds[@]}"; do
    IFS='|' read -r kind folder package define check_tests render_test <<< "$row"
    echo "No level at $folder/$1.json (see the list in index.json)." >&2
  done
}

self_test() {
  local row bad=0
  for row in "${kinds[@]}"; do
    IFS='|' read -r kind folder package define check_tests render_test <<< "$row"
    if [ -z "$kind" ] || [ -z "$folder" ] || [ -z "$package" ] || [ -z "$define" ] || [ -z "$check_tests" ] || [ -z "$render_test" ]; then
      echo "self-test: a kind row is missing a field: $row" >&2
      bad=1
    elif [ ! -f "$root/$folder/index.json" ]; then
      echo "self-test: $kind: no index at $folder/index.json" >&2
      bad=1
    else
      echo "new $kind: dart tools/level_new.dart new $kind <id> --level easy|medium [--name \"Name\"]"
      echo "check ($kind): cd $package && flutter test $check_tests"
      echo "check <id> ($kind): cd $package && flutter test --dart-define=$define=<id> $check_tests"
      echo "render <id> ($kind): cd $package && flutter test --dart-define=$define=<id> $render_test"
    fi
  done
  [ $bad = 0 ] || exit 1
  echo "self-test: ok"
}

if [ "${1:-}" = --self-test ]; then
  self_test
  exit 0
fi

for tool in dart flutter; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "$tool isn't on the PATH. See docs/building.md (One-time toolchain)." >&2
    exit 2
  fi
done

command="${1:-}"
[ $# -gt 0 ] && shift

case "$command" in
  new)
    if [ $# = 0 ]; then
      usage
      exit 2
    fi
    exec dart "$root/tools/level_new.dart" new "$@"
    ;;
  check)
    id="${1:-}"
    if [ $# -gt 1 ]; then
      usage
      exit 2
    fi
    if [ -z "$id" ]; then
      # No id: every kind's library, in table order.
      status=0
      for row in "${kinds[@]}"; do
        IFS='|' read -r kind folder package define check_tests render_test <<< "$row"
        (cd "$root/$package" && flutter test $check_tests) || status=1
      done
      exit $status
    fi
    matches=()
    for row in "${kinds[@]}"; do
      IFS='|' read -r kind folder package define check_tests render_test <<< "$row"
      [ -f "$root/$folder/$id.json" ] && matches+=("$row")
    done
    if [ ${#matches[@]} = 0 ]; then
      no_level "$id"
      exit 2
    fi
    if [ ${#matches[@]} -gt 1 ]; then
      IFS='|' read -r kind folder package define check_tests render_test <<< "${matches[0]}"
      for row in "${matches[@]:1}"; do
        IFS='|' read -r other_kind other_folder other_package other_define other_checks other_render <<< "$row"
        echo "\"$id\" is both a $kind ($folder/$id.json) and a $other_kind ($other_folder/$id.json): ids are unique across kinds, so give one of them another id." >&2
      done
      exit 2
    fi
    IFS='|' read -r kind folder package define check_tests render_test <<< "${matches[0]}"
    (cd "$root/$package" && flutter test --dart-define="$define=$id" $check_tests)
    exit $?
    ;;
  render)
    id="${1:-}"
    if [ $# -ne 1 ]; then
      usage
      exit 2
    fi
    for row in "${kinds[@]}"; do
      IFS='|' read -r kind folder package define check_tests render_test <<< "$row"
      if [ -f "$root/$folder/$id.json" ]; then
        (cd "$root/$package" && flutter test --dart-define="$define=$id" $render_test)
        exit $?
      fi
    done
    no_level "$id"
    exit 2
    ;;
  -h | --help | help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac
