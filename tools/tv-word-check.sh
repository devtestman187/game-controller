#!/usr/bin/env bash
# Guard for owner decision 7 (APP-START.md): user-visible text in the controller app and its
# packages says "screen" for the display device, not "TV". Scans the Dart files in
# controller_app/lib and packages/*/lib for the whole word TV (case sensitive), skips comment
# lines, and takes out the allowed names (Thumb Party TV, Android TV, Google TV) before it looks.
# tv_test_app is not scanned: its own screens name the platform it runs on (owner decision 7, APP-START.md, 2026-11-25).
#
#   tools/tv-word-check.sh           # the repo this script is in
#   tools/tv-word-check.sh <root>    # another tree with the same folders (the self-test uses one)
#
# Prints each hit as file:line: text, with the file relative to the root.
# Exit codes: 0 no hits · 1 hits · 2 no controller_app/lib folder under the root.
set -u

# The names that stay: they name the app or the platform, not the display device.
allowed_names=("Thumb Party TV" "Android TV" "Google TV")

# The lowercase spellings (the 'tv' switch key, the tv identifier value, the 'tv' log tag) never match the
# case-sensitive scan, so no list is needed for them.

root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" 2> /dev/null || {
  echo "no such folder: $root"
  exit 2
}
[ -d controller_app/lib ] || {
  echo "no controller_app/lib under $root"
  exit 2
}
dirs=(controller_app/lib)
for d in packages/*/lib; do
  [ -d "$d" ] && dirs+=("$d")
done

hits=0
# Each row is file:line:text. The paths are relative, so they hold no drive colon.
while IFS= read -r row; do
  file="${row%%:*}"
  rest="${row#*:}"
  line_no="${rest%%:*}"
  text="${rest#*:}"
  trimmed="${text#"${text%%[![:space:]]*}"}"
  trimmed="${trimmed%$'\r'}"
  case "$trimmed" in
    //*) continue ;;
  esac
  rest_text="$trimmed"
  for name in "${allowed_names[@]}"; do
    rest_text="${rest_text//"$name"/}"
  done
  grep -qw TV <<< "$rest_text" || continue
  printf '%s:%s: %s\n' "$file" "$line_no" "$trimmed"
  hits=$((hits + 1))
done < <(grep -rnw --include='*.dart' TV "${dirs[@]}")

[ "$hits" -eq 0 ]
