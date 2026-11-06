#!/usr/bin/env bash
# The mechanical checks from docs/coding-guidelines.md, over the .dart files
# that changed (or over every file) and the lines it adds. Prints one line per
# finding: FAIL <check> <file>:<line> <detail> or NOTE ..., then the totals.
# It finds the mechanical things first; it doesn't replace the review (it
# can't judge a design, a name or a test's worth). Documented in dev-tools.md.
#
#   tools/review.sh                  # uncommitted changes (one job's diff)
#   tools/review.sh --base origin/main  # the whole branch
#   tools/review.sh --all            # every file, every line
#   tools/review.sh --help
#
# Checks: size func platform layers leftover catch types timing clock number
# Exit code: 0 no FAIL, 1 any FAIL, 2 bad arguments or a missing git.
set -u

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

base=""
all=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --all) all=1 ;;
    --base)
      [ $# -ge 2 ] || { echo "--base needs a ref (try --help)" >&2; exit 2; }
      base="$2"
      shift
      ;;
    --base=*) base="${1#--base=}" ;;
    *)
      echo "Unknown option: $1 (try --help)" >&2
      exit 2
      ;;
  esac
  shift
done

command -v git > /dev/null 2>&1 || { echo "git isn't on the PATH." >&2; exit 2; }
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "Not inside a git repository." >&2; exit 2; }
[ -n "$base" ] || base=HEAD
git rev-parse --verify --quiet "$base^{commit}" > /dev/null || { echo "Unknown base: $base" >&2; exit 2; }

tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$tmp"' EXIT

# The .dart files under the code folders, without builds and generated files.
in_scope() {
  case "$1" in *.dart) ;; *) return 1 ;; esac
  case "$1" in
    controller_app/* | tv_test_app/* | packages/* | assets/*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    build/* | */build/* | .dart_tool/* | */.dart_tool/*) return 1 ;;
    *.g.dart | *generated_plugin_registrant*) return 1 ;;
  esac
  return 0
}

changed=()
if [ $all = 1 ]; then
  while IFS= read -r f; do changed+=("$f"); done < <(git ls-files 2> /dev/null)
else
  while IFS= read -r f; do changed+=("$f"); done < <(git diff --name-only "$base" 2> /dev/null)
fi
while IFS= read -r f; do changed+=("$f"); done < <(git ls-files --others --exclude-standard 2> /dev/null)

files=()
while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] && in_scope "$f" && files+=("$f")
done < <(printf '%s\n' ${changed[@]+"${changed[@]}"} | LC_ALL=C sort -u)

fails=0
notes=0
finding() { # level check file line detail
  if [ "$1" = FAIL ]; then fails=$((fails + 1)); else notes=$((notes + 1)); fi
  printf '%s %-8s %s:%s %s\n' "$1" "$2" "$3" "$4" "$5"
}

# The package a file belongs to: the name: of its nearest pubspec.yaml.
package_of() {
  local dir
  dir=$(dirname "$1")
  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/pubspec.yaml" ]; then
      sed -n 's/^name:[[:space:]]*//p' "$dir/pubspec.yaml" | head -1 | tr -d "\"'"
      return
    fi
    dir=$(dirname "$dir")
  done
}

for f in ${files[@]+"${files[@]}"}; do
  lines=$(awk 'END { print NR }' "$f")

  # a size
  case "$f" in
    */lib/*)
      if [ "$lines" -gt 400 ]; then
        finding FAIL size "$f" 1 "$lines lines (lib limit 400)"
      elif [ "$lines" -gt 300 ]; then
        finding NOTE size "$f" 1 "$lines lines (lib limit 400, aim 300)"
      fi
      ;;
    */test/*) [ "$lines" -gt 500 ] && finding FAIL size "$f" 1 "$lines lines (test limit 500)" ;;
  esac

  # b func: members (indent 0 or 2, ending in "{") and their length. lib only.
  if [ "${f#*/lib/}" != "$f" ]; then
    mapfile -t hits < <(
      awk '
        BEGIN { start = 0 }
        function spaces(k,   s, i) { s = ""; for (i = 0; i < k; i++) s = s " "; return s }
        function isDecl(s) {
          return s ~ /^((abstract|base|final|sealed|interface)[ \t]+)*(class|mixin|enum|extension)([ \t<{]|$)/
        }
        function short(s) {
          sub(/[ \t]*\{[ \t]*$/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s)
          if (length(s) > 60) s = substr(s, 1, 57) "..."
          return s
        }
        {
          sub(/\r$/, "")
          match($0, /^ */); ind = RLENGTH
          if (start > 0) {
            if ($0 == spaces(ind0) "}" || $0 == spaces(ind0) "};") {
              len = FNR - start + 1
              if (len > 60) printf "FAIL|func|%d|%d lines (>60): %s\n", start, len, short(sig)
              else if (len > 40 && sig !~ /(^|[ \t])build\(/) printf "NOTE|func|%d|%d lines (>40): %s\n", start, len, short(sig)
              start = 0
            }
            next
          }
          # "({" and ", {" open a named-parameter list, not a body.
          if ((ind == 0 || ind == 2) && $0 ~ /\{[ \t]*$/ && $0 !~ /(\(|,[ \t]*)\{[ \t]*$/ && !isDecl($0)) {
            start = FNR; ind0 = ind; sig = $0
          }
        }
      ' "$f"
    )
    for h in ${hits[@]+"${hits[@]}"}; do
      IFS='|' read -r level check at detail <<< "$h"
      finding "$level" "$check" "$f" "$at" "$detail"
    done
  fi

  # c platform: the platform is read in an adapter only.
  case "$f" in
    packages/*/lib/*)
      mapfile -t hits < <(grep -nF 'Platform.is' "$f")
      for h in ${hits[@]+"${hits[@]}"}; do
        finding FAIL platform "$f" "${h%%:*}" "Platform.is in a package"
      done
      ;;
  esac

  # d layers: no import points up or sideways.
  own=$(package_of "$f")
  mapfile -t hits < <(grep -nE '^[[:space:]]*import[[:space:]]' "$f")
  for h in ${hits[@]+"${hits[@]}"}; do
    at="${h%%:*}"
    spec="${h#*:}"
    case "$spec" in *package:*) ;; *) continue ;; esac
    rest="${spec#*package:}"
    pkg="${rest%%/*}"
    rest="${rest#*/}"
    rest="${rest%%\'*}"
    rest="${rest%%\"*}"
    msg=""
    case "$f" in
      packages/*)
        case "$pkg" in controller | tvtest) msg="a package imports the app ($pkg)" ;; esac
        ;;
    esac
    case "$f" in
      packages/protocol/* | packages/connection/* | packages/metrics/*)
        [ "$pkg" = flutter ] && msg="flutter in a pure Dart package"
        ;;
      packages/puzzle_game/*)
        case "$pkg" in
          party_host) msg="a game imports party_host" ;;
          test_game) msg="a game imports the other game (test_game)" ;;
        esac
        ;;
      packages/test_game/*)
        case "$pkg" in
          party_host) msg="a game imports party_host" ;;
          puzzle_game) msg="a game imports the other game (puzzle_game)" ;;
        esac
        ;;
    esac
    if [ -z "$msg" ] && [ "${rest#src/}" != "$rest" ] && [ "$pkg" != "$own" ]; then
      msg="imports package:$pkg/src/ from outside $pkg"
    fi
    [ -n "$msg" ] && finding FAIL layers "$f" "$at" "$msg"
  done

  # e-j: the lines this change adds (every line with --all).
  added_all=0
  if [ $all = 1 ] || ! git ls-files --error-unmatch -- "$f" > /dev/null 2>&1; then
    added_all=1
  else
    git diff -U0 "$base" -- "$f" > "$tmp/diff" 2> /dev/null
    awk '
      /^@@/ {
        h = ""
        for (i = 1; i <= NF; i++) if ($i ~ /^\+[0-9]/) h = $i
        sub(/^\+/, "", h)
        split(h, p, ",")
        count = (p[2] == "" ? 1 : p[2] + 0)
        for (n = p[1] + 0; n < p[1] + count; n++) print n
      }
    ' "$tmp/diff" | LC_ALL=C sort -un > "$tmp/added"
  fi
  mapfile -t hits < <(
    awk -v file="$f" -v all="$added_all" -v af="$tmp/added" '
      BEGIN { if (all != "1") while ((getline n < af) > 0) added[n + 0] = 1 }
      function say(level, check, at, detail) { print level "|" check "|" at "|" detail }
      function strip(s,   out, i, c, q, esc) {
        out = ""; q = ""; esc = 0
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (q != "") {
            if (esc) esc = 0
            else if (c == "\\") esc = 1
            else if (c == q) q = ""
          } else if (c == "\"" || c == "\047") q = c
          else if (c == "/" && substr(s, i + 1, 1) == "/") break
          else out = out c
        }
        return out
      }
      function numbers(s,   pos, rest, start, len, num, before, pre, after, token) {
        if (s ~ /^[ \t]*(import|export|part|library)[ \t]/) return
        if (s ~ /^[ \t]*(static[ \t]+)?(const|final)[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=/) return
        pos = 0
        while (1) {
          rest = substr(s, pos + 1)
          if (!match(rest, /[0-9]+(\.[0-9]+)?/)) return
          start = pos + RSTART; len = RLENGTH; num = substr(rest, RSTART, RLENGTH)
          pos = start + len - 1
          before = (start > 1) ? substr(s, start - 1, 1) : ""
          after = substr(s, start + len, 1)
          if (before ~ /[A-Za-z0-9_.]/ || after ~ /[A-Za-z0-9_.]/) continue
          token = num
          if (before == "-") {
            pre = (start > 2) ? substr(s, start - 2, 1) : ""
            if (pre == "" || pre ~ /[^A-Za-z0-9_.)\]]/) token = "-" num
          }
          if (token ~ /^(-1|0|1|2|0\.0|1\.0|0\.5)$/) continue
          say("NOTE", "number", FNR, "numeric literal " token)
          return
        }
      }
      {
        sub(/\r$/, "")
        if (pending) {
          if ($0 ~ /^[ \t]*\}[ \t]*$/) say("FAIL", "catch", pending, "empty catch body")
          pending = 0
        }
        if (all != "1" && !(FNR in added)) next
        lib = (file ~ /\/lib\//)
        if ($0 ~ /TODO|FIXME|XXX/) say("FAIL", "leftover", FNR, "TODO/FIXME/XXX")
        if (lib && $0 ~ /(^|[^A-Za-z0-9_])print\(/) say("FAIL", "leftover", FNR, "print(")
        if (lib && $0 ~ /debugPrint\(/) say("FAIL", "leftover", FNR, "debugPrint(")
        if ($0 ~ /\/\/ *ignore(_for_file)?:/) say("FAIL", "leftover", FNR, "// ignore comment")
        if ($0 ~ /catch/ && $0 ~ /\{[ \t]*\}[ \t]*;?[ \t]*$/) say("FAIL", "catch", FNR, "empty catch body")
        else if ($0 ~ /catch/ && $0 ~ /\{[ \t]*$/) pending = FNR
        if (lib && $0 ~ /(^|[^A-Za-z0-9_])dynamic([^A-Za-z0-9_]|$)/) say("FAIL", "types", FNR, "dynamic")
        if (lib && $0 ~ /Future\.delayed\(/) say("NOTE", "timing", FNR, "Future.delayed(")
        if (lib && $0 ~ /sleep\(/) say("NOTE", "timing", FNR, "sleep(")
        if (file ~ /^packages\/(puzzle_game|test_game)\/lib\//) {
          if ($0 ~ /DateTime\.now\(/) say("FAIL", "clock", FNR, "DateTime.now()")
          if ($0 ~ /Random\([ \t]*\)/) say("FAIL", "clock", FNR, "Random() without a seed")
        }
        if (lib) numbers(strip($0))
      }
    ' "$f"
  )
  for h in ${hits[@]+"${hits[@]}"}; do
    IFS='|' read -r level check at detail <<< "$h"
    finding "$level" "$check" "$f" "$at" "$detail"
  done
done

echo "review: $fails fail, $notes note"
[ "$fails" = 0 ] && exit 0
exit 1
