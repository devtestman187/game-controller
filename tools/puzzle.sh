#!/usr/bin/env bash
# The Shape Race puzzle kit (m13 s20): make, check and render one puzzle.
#
#   tools/puzzle.sh new <id> --level easy|medium [--name "Name"]
#   tools/puzzle.sh check [id]     # the rule book over every puzzle, or one
#   tools/puzzle.sh render <id>    # writes docs/design/puzzles/<id>.png
#
# The guide is docs/puzzles.md. Works in Git Bash on Windows and bash on
# macOS/Linux.
set -u

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"
puzzles="$root/packages/puzzle_game/puzzles"

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

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
    exec dart "$root/tools/puzzle_new.dart" new "$@"
    ;;
  check)
    id="${1:-}"
    if [ $# -gt 1 ]; then
      usage
      exit 2
    fi
    if [ -n "$id" ] && [ ! -f "$puzzles/$id.json" ]; then
      echo "No puzzle at packages/puzzle_game/puzzles/$id.json (see the list in index.json)." >&2
      exit 2
    fi
    cd "$root/packages/puzzle_game" || exit 2
    if [ -n "$id" ]; then
      exec flutter test --dart-define="puzzleId=$id" test/puzzle_check_test.dart test/puzzle_schema_test.dart
    else
      exec flutter test test/puzzle_check_test.dart test/puzzle_schema_test.dart
    fi
    ;;
  render)
    id="${1:-}"
    if [ $# -ne 1 ]; then
      usage
      exit 2
    fi
    if [ ! -f "$puzzles/$id.json" ]; then
      echo "No puzzle at packages/puzzle_game/puzzles/$id.json (see the list in index.json)." >&2
      exit 2
    fi
    cd "$root/packages/puzzle_game" || exit 2
    exec flutter test --dart-define="puzzleId=$id" test/puzzle_render_test.dart
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
