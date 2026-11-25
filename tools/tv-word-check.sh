#!/usr/bin/env bash
# Guard for owner decision 7 (APP-START.md): user-visible text in the controller app and its
# packages says "screen" for the display device, not "TV". Scans the Dart files in
# controller_app/lib and packages/*/lib for the whole word TV (case sensitive), skips comment
# lines, and takes out the allowed names (Thumb Party TV, Android TV, Google TV) before it looks.
# tv_test_app is not scanned: its own screens name the platform it runs on (owner scope, driver Nov 25).
#
#   tools/tv-word-check.sh           # the repo this script is in
#   tools/tv-word-check.sh <root>    # another tree with the same folders (the self-test uses one)
#
# Prints each hit as file:line: text, with the file relative to the root.
# Exit codes: 0 no hits · 1 hits · 2 no controller_app/lib folder under the root.
set -u

# The names that stay: they name the app or the platform, not the display device.
allowed_names=("Thumb Party TV" "Android TV" "Google TV")

# Allowed spellings that are not user text, as file|exact trimmed line|reason. The
# case-sensitive TV scan never matches them; they are listed so a later change to the scan
# doesn't flag a switch key, an identifier value or a log tag.
allowed_lines=(
  "packages/party_host/lib/src/text/phone_text.dart|'tv' => kindTv,|switch key, not text"
  "packages/party_host/lib/src/host_identity.dart|static const tv = 'tv';|identifier value"
  "packages/party_host/lib/src/keep_awake.dart|ref.read(logProvider).add('tv', line);|log tag"
)

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
  allowed=""
  for entry in "${allowed_lines[@]}"; do
    [ "${entry%|*}" = "$file|$trimmed" ] && allowed=1
  done
  [ -z "$allowed" ] || continue
  printf '%s:%s: %s\n' "$file" "$line_no" "$trimmed"
  hits=$((hits + 1))
done < <(grep -rnw --include='*.dart' TV "${dirs[@]}")

[ "$hits" -eq 0 ]
