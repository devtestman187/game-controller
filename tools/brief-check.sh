#!/usr/bin/env bash
# Pre-run check of a batch's briefs: the defects that stopped identity1 wave 1 (two jobs of one
# wave sharing a file, a new file no job allows, a changes: item used outside every allow:) are
# reported before any job of the batch starts.
#
#   tools/brief-check.sh <briefs-dir>   # check the jobs <briefs-dir>/waves.txt still has to run
#   tools/brief-check.sh -h | --help    # this help
#
# <briefs-dir>/waves.txt: one wave per line, the wave's job names whitespace separated, `#`
# comments. A job listed in <briefs-dir>/done.txt (`<job> <sha> ...`, which tools/run-jobs.sh
# writes after the job's commit) or in dropped.txt is skipped, as it never runs.
#
# One line per finding, `FAIL <rule> <job>: <what>` or `WARN <rule> <job>: <what>`:
#   wave       two jobs of one wave allow: the same path, or one of them a folder holding the
#              other's path: their commits would fight over the file
#   new-file   a do: line creates NEW <path> (a path with a folder and an extension) that the
#              job's own allow: does not cover: the job could not commit the file it makes
#   changes    a changes: item is used in a .dart file under a lib/ or test/ folder that no job
#              of its wave or an earlier wave allows, so the wave's combined check cannot pass.
#              The items are types, enum values, constants, strings and keys, separated by ' · ';
#              for a new sealed subtype or enum value the brief names a sibling whose uses are
#              the switches and lists. A hit in a file the job itself creates is ignored. A file
#              that only a later wave's job allows is a FAIL too: that wave runs after this one.
#   allow-size (WARN) an allow: with over 20 entries or over 3 packages (packages/<x>,
#              controller_app, tools, docs): split the job
#
# Env: BRIEF_CHECK_ROOT  the repo root to search (default .)
#      BRIEF_CHECK_REF   a git ref searched with git grep instead of the working tree, so the
#                        replay reads an old commit; the printed paths carry no ref prefix
# Output: the FAIL and WARN lines, then the result: `RESULT: ok: <n> job(s), <w> WARN` (exit 0;
# a WARN is allowed) or `RESULT: FAILED: <f> FAIL, <w> WARN (<n> job(s) checked)` (exit 1).
# A FAIL is final here: the runner's gate around it lets BRIEF_CHECK_SKIP=<reason> override one.
# Exit codes: 0 ok · 1 a FAIL · 2 bad use.
set -u

cd "$(dirname "$0")/.." || exit 2

# The two thresholds of an allow: line (owner, Nov 22): over either one is a WARN, not a FAIL,
# because a big allow: still commits; it only widens the job's review and its commit.
MAX_ALLOW_ENTRIES=20
MAX_ALLOW_PACKAGES=3

bad_use() { # bad_use <why>: the one-line refusal of bad use, then exit 2
  echo "brief-check: $1" >&2
  echo "RESULT: BAD INPUT: $1"
  exit 2
}

case ${1:-} in
  -h | --help)
    sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac
[ $# -eq 1 ] || bad_use "usage: tools/brief-check.sh <briefs-dir>"
B=${1%/}
[ -f "$B/waves.txt" ] || bad_use "no $B/waves.txt: a batch is a folder of briefs with a waves.txt"
root=${BRIEF_CHECK_ROOT:-.}
ref=${BRIEF_CHECK_REF:-}
[ -d "$root" ] || bad_use "BRIEF_CHECK_ROOT is not a folder: $root"
if [ -n "$ref" ] && ! git -C "$root" rev-parse --verify -q "$ref^{commit}" > /dev/null; then
  bad_use "BRIEF_CHECK_REF is not a git ref under $root: $ref"
fi

tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/brief-check-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

field() { # field <brief> <name>: the brief's one-line <name>: value (a missing line: nothing)
  sed -n "s/^$2: *//p" "$1" | head -n 1 | tr -d '\r'
}

allow_of() { # allow_of <brief>: the allow: entries, one per line, a trailing / dropped
  field "$1" allow | sed 's/ *· */\n/g' |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's|/$||' | awk 'NF'
}

changes_of() { # changes_of <brief>: the changes: items, one per line, the note in ( ) dropped
  field "$1" changes | sed 's/ *· */\n/g' | sed 's/ *(.*$//' | tr -d '`' |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | awk 'NF'
}

new_of() { # new_of <brief>: the paths its do: lines create with NEW, one per line
  sed -n 's/^[0-9][0-9]* //p' "$1" | awk '
    {
      started = 0
      for (i = 1; i <= NF; i++) {
        w = $i
        if (!started) {
          if (w == "NEW") started = 1
          continue
        }
        if (w == "file") continue
        gsub(/^[[:punct:]]+/, "", w)
        gsub(/[[:punct:]]+$/, "", w)
        if (w ~ /\// && w ~ /\.[A-Za-z0-9]+$/) print w
        if ($i ~ /:$/) break
      }
    }'
}

skipped() { # skipped <job>: the job is in done.txt (its commit is made) or dropped.txt
  [ -f "$B/done.txt" ] && grep -q "^$1 " "$B/done.txt" && return 0
  [ -f "$B/dropped.txt" ] && grep -qxF -- "$1" "$B/dropped.txt" && return 0
  return 1
}

jobs=() # the jobs still to run, in the order waves.txt names them
job_wave=() # parallel to jobs: the job's wave number
wave_jobs=() # by wave number: that wave's job names
waves=() # the wave numbers that hold a job
w=0
while IFS= read -r line; do
  line=${line%%#*}
  line=${line%$'\r'} # a waves.txt saved on Windows keeps a CR on each line
  case $line in *[![:space:]]*) ;; *) continue ;; esac
  w=$((w + 1))
  for j in $line; do
    [ -f "$B/$j.md" ] || continue # a missing brief is the runner's own dry run to report
    skipped "$j" && continue
    jobs+=("$j")
    job_wave+=("$w")
    if [ -z "${wave_jobs[$w]:-}" ]; then
      wave_jobs[$w]=$j
      waves+=("$w")
    else
      wave_jobs[$w]="${wave_jobs[$w]} $j"
    fi
    allow_of "$B/$j.md" > "$tmp/$j.allow"
    changes_of "$B/$j.md" > "$tmp/$j.changes"
    new_of "$B/$j.md" > "$tmp/$j.new"
  done
done < "$B/waves.txt"

fails=0
warns=0
fail() { echo "FAIL $*"; fails=$((fails + 1)); }
warn() { echo "WARN $*"; warns=$((warns + 1)); }

covers() { # covers <path> <allow: entry>: 0 when the entry is the path or a folder holding it
  [ "$1" = "$2" ] && return 0
  case $1 in "$2"/*) return 0 ;; esac
  return 1
}

allow_covers() { # allow_covers <job> <path>: 0 when one of the job's allow: entries covers it
  local a
  while IFS= read -r a; do
    covers "$2" "$a" && return 0
  done < "$tmp/$1.allow"
  return 1
}

made_by() { # made_by <job> <path>: 0 when the job's own do: lines create that path or its folder
  local c
  while IFS= read -r c; do
    covers "$2" "$c" && return 0
  done < "$tmp/$1.new"
  return 1
}

first_allow() { # first_allow <path>: the earliest wave's job whose allow: covers it, "job wave"
  local i j best="" bw=0
  for i in "${!jobs[@]}"; do
    j=${jobs[$i]}
    allow_covers "$j" "$1" || continue
    if [ -z "$best" ] || [ "${job_wave[$i]}" -lt "$bw" ]; then
      best=$j
      bw=${job_wave[$i]}
    fi
  done
  [ -z "$best" ] || printf '%s %s\n' "$best" "$bw"
  return 0
}

search_item() { # search_item <text>: the lib/ and test/ .dart files under root that use it
  local item=$1
  if [ -n "$ref" ]; then
    (cd "$root" && git grep -l -w -F -e "$item" "$ref" -- '*.dart' 2> /dev/null) |
      sed 's/^[^:]*://' | grep -E '(^|/)(lib|test)/'
  else
    (cd "$root" && grep -rlwF -e "$item" --include='*.dart' --exclude-dir=.dart_tool \
      --exclude-dir=.git --exclude-dir=build . 2> /dev/null) |
      sed 's|^\./||' | grep -E '(^|/)(lib|test)/'
  fi | LC_ALL=C sort -u
}

check_pair() { # check_pair <jobA> <jobB>: FAIL for every allow: path the two of one wave share
  local a=$1 b=$2 pa pb
  mapfile -t la < "$tmp/$a.allow"
  mapfile -t lb < "$tmp/$b.allow"
  for pa in ${la[@]+"${la[@]}"}; do
    for pb in ${lb[@]+"${lb[@]}"}; do
      if [ "$pa" = "$pb" ]; then
        fail "wave $b: $a and $b both allow $pa"
      elif covers "$pb" "$pa"; then
        fail "wave $b: $a allows folder $pa, which holds $b's $pb"
      elif covers "$pa" "$pb"; then
        fail "wave $b: $b allows folder $pb, which holds $a's $pa"
      fi
    done
  done
  return 0
}

check_waves() { # check_waves: no two jobs of one wave may allow the same path
  local n i k
  local -a wave
  for w in ${waves[@]+"${waves[@]}"}; do
    mapfile -t wave < <(printf '%s\n' ${wave_jobs[$w]})
    n=${#wave[@]}
    for ((i = 0; i < n; i++)); do
      for ((k = i + 1; k < n; k++)); do
        check_pair "${wave[$i]}" "${wave[$k]}"
      done
    done
  done
  return 0
}

check_allow_size() { # check_allow_size <job>: WARN for an allow: over either threshold
  local j=$1 n=0 pkgs=0 seen=" " a pkg
  local -a list
  mapfile -t list < "$tmp/$j.allow"
  n=${#list[@]}
  [ "$n" -gt 0 ] || return 0
  for a in "${list[@]}"; do
    case $a in
      packages/?*/*) pkg=${a#packages/}; pkg=packages/${pkg%%/*} ;;
      packages/?*) pkg=$a ;;
      */*) pkg=${a%%/*} ;;
      *) pkg="" ;;
    esac
    [ -n "$pkg" ] || continue
    case $seen in *" $pkg "*) ;; *)
      seen="$seen$pkg "
      pkgs=$((pkgs + 1))
      ;;
    esac
  done
  [ "$n" -gt "$MAX_ALLOW_ENTRIES" ] &&
    warn "allow-size $j: $n allow: entries (over $MAX_ALLOW_ENTRIES); split the job"
  [ "$pkgs" -gt "$MAX_ALLOW_PACKAGES" ] &&
    warn "allow-size $j: $pkgs packages in its allow: (over $MAX_ALLOW_PACKAGES); split it by package"
  return 0
}

check_new_files() { # check_new_files <job>: every NEW path its do: lines make is in its allow:
  local j=$1 c
  local -a made
  mapfile -t made < "$tmp/$j.new"
  for c in ${made[@]+"${made[@]}"}; do
    allow_covers "$j" "$c" ||
      fail "new-file $j: its do: line creates $c, which its allow: does not cover"
  done
  return 0
}

check_changes() { # check_changes <job> <wave>: FAIL for a hit outside an earlier or same wave allow
  local j=$1 w=$2 item hit found a aw
  local -a items
  mapfile -t items < "$tmp/$j.changes"
  for item in ${items[@]+"${items[@]}"}; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      made_by "$j" "$hit" && continue
      found=$(first_allow "$hit")
      if [ -z "$found" ]; then
        fail "changes $j: $item is used in $hit, which no job of wave $w or earlier allows"
        continue
      fi
      a=${found% *}
      aw=${found##* }
      [ "$aw" -le "$w" ] ||
        fail "changes $j: $item is used in $hit, which only $a of wave $aw allows, after wave $w"
    done < <(search_item "$item")
  done
  return 0
}

check_waves
for i in "${!jobs[@]}"; do
  j=${jobs[$i]}
  check_allow_size "$j"
  check_new_files "$j"
  check_changes "$j" "${job_wave[$i]}"
done

n=${#jobs[@]}
if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails FAIL, $warns WARN ($n job(s) checked)"
  exit 1
fi
echo "RESULT: ok: $n job(s), $warns WARN"
exit 0
