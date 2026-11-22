#!/usr/bin/env bash
# The dependency probe: every `probe:` stub patch of a batch (a tiny patch that adds the new class,
# enum value or constant a job's brief plans) is applied in a throwaway worktree; `pub get` then
# `analyze` run over the whole workspace there; and each file the analyze then fails on must be in
# the allow: of a job that runs BEFORE the probe job. The case it exists for: identity1 i1a's two
# new messages broke two switches in files no job allowed, so the job's check could never pass. A
# file allowed only by a job of the SAME wave is a FAIL too (the contract belongs in an earlier
# wave, or the two jobs merge), and so is one allowed only by a later wave's job.
#
#   tools/probe-deps.sh <batch dir>     # every job of the batch whose brief has a probe: line
#   tools/probe-deps.sh --help
#
# A job's id is its brief's file name without .md (waves.txt lists the same ids), and its wave is
# the line of <batch dir>/waves.txt that holds it; a batch without waves.txt is bad use, because a
# same-wave dependence can't be seen then. The probe: path is read from the repo root first, then
# from the batch folder. The worktree is a detached checkout of ${PROBE_BASE:-HEAD} in a temp
# folder, removed on every exit (the EXIT trap, so also at a timeout and on Ctrl-C). A batch with
# no probe: line says so and exits 0.
#
# Env knobs (anything else is bad use):
#   PROBE_MAX_MIN    10   one probe job's minutes for pub get, analyze and review together
#   RUN_LIMIT_UNIT_S 60   seconds in one limit "minute" (a test sets 1, so 1 min runs out in 1 s)
#   PROBE_POLL_S     1    seconds between two looks at the command; may be a fraction (0.1)
# The commands, each run inside the worktree: PROBE_PUB_CMD (flutter pub get), PROBE_ANALYZE_CMD
# (dart analyze --fatal-infos) and PROBE_REVIEW_CMD (bash tools/review.sh), the last skipped when
# PROBE_REVIEW=0. review.sh runs after `git add -N .`, so its diff holds the patch's new files.
#
# Output: one FAIL line per error file outside an earlier job's allow (a review.sh layers FAIL in a
# file the probe job allows is a WARN line instead), then a PROBE <job>: <n> error files line per
# probe job, then the RESULT line last. The patch's own files are exempt from the FAIL rule but do
# count in <n>. Exit codes: 0 no FAIL, 1 a FAIL, 2 bad use, 3 timed out or setup failed: a probe
# that could not run is never a pass.
set -u

cd "$(dirname "$0")/.." || exit 2
root=$(pwd)

bad_input() { # bad_input <why>: the RESULT line the tool rules ask for, then exit 2
  echo "RESULT: BAD INPUT: $1"
  exit 2
}

setup_failed() { # setup_failed <why>: a probe that could not run is never a pass (exit 3)
  echo "RESULT: SETUP FAILED: $1"
  exit 3
}

case ${1:-} in
  -h | --help)
    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac
[ $# -ge 1 ] || bad_input "give the batch folder: tools/probe-deps.sh <batch dir>"
[ $# -le 1 ] || bad_input "one batch folder at most (got $#: $*)"
batch=${1%/}
[ -d "$batch" ] || bad_input "no such batch folder: $batch"
waves="$batch/waves.txt"
[ -f "$waves" ] || bad_input "no $waves: without it a job's wave is unknown, and a same-wave dependence can't be seen"
command -v git > /dev/null 2>&1 || setup_failed "git isn't on the PATH"
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || setup_failed "not inside a git repository: $root"

# The knobs, each refused rather than quietly replaced: a limit nobody can read is worse than none.
PROBE_DEFAULT_MAX_MIN=10
PROBE_DEFAULT_POLL_S=1
PROBE_DEFAULT_UNIT_S=60
PROBE_MAX_MIN=${PROBE_MAX_MIN:-$PROBE_DEFAULT_MAX_MIN}
case $PROBE_MAX_MIN in *[!0-9]* | 0) bad_input "PROBE_MAX_MIN must be a whole number above 0, got '$PROBE_MAX_MIN'" ;; esac
PROBE_POLL_S=${PROBE_POLL_S:-$PROBE_DEFAULT_POLL_S}
case $PROBE_POLL_S in
  *[!0-9.]* | *.*.*) bad_input "PROBE_POLL_S must be seconds like 1 or 0.1, got '$PROBE_POLL_S'" ;;
esac
# A sleep of 0 would spin the loop: the value has to hold a digit other than 0.
[ -n "${PROBE_POLL_S//[0.]/}" ] || bad_input "PROBE_POLL_S must be more than 0 seconds, got '$PROBE_POLL_S'"
limit_unit_s=${RUN_LIMIT_UNIT_S:-$PROBE_DEFAULT_UNIT_S}
case $limit_unit_s in *[!0-9]* | 0) bad_input "RUN_LIMIT_UNIT_S must be a whole number above 0, got '$limit_unit_s'" ;; esac
limit_s=$((PROBE_MAX_MIN * limit_unit_s))

tmp=$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/probe-deps-XXXXXX") || setup_failed "can't create a temp folder"
trees=()
child=""
wt=""
total_files=0
: > "$tmp/fails"
: > "$tmp/warns"
: > "$tmp/probes"
: > "$tmp/patched"

kill_tree() { # kill_tree <pid>: the process and its children (the runner's tree kill)
  local c
  for c in $(ps -ef 2> /dev/null | awk -v p="$1" '$3 == p { print $2 }'); do kill_tree "$c"; done
  kill "$1" 2> /dev/null
}

cleanup() { # cleanup: the running probe, its worktrees and the temp folder, on every exit
  local t orphan=0
  if [ -n "$child" ]; then
    kill_tree "$child"
    wait "$child" 2> /dev/null # reap it before the folder goes (Windows keeps the files open)
    child=""
  fi
  for t in ${trees[@]+"${trees[@]}"}; do
    git worktree remove --force "$t" > /dev/null 2>&1 || orphan=1
    [ -d "$t" ] && rm -rf "$t" # a file in use: the folder goes now, the record at the prune
  done
  # Only a removal that failed leaves a record behind, and the prune is what clears it.
  [ "$orphan" = 0 ] || git worktree prune > /dev/null 2>&1
  rm -rf "$tmp"
}
trap cleanup EXIT
trap 'trap "" INT TERM; exit 130' INT
trap 'trap "" INT TERM; exit 143' TERM

first_line() { # first_line <log>: its first non-blank line, else "no output"
  local l
  l=$(grep -m 1 '[^[:space:]]' "${1:-}" 2> /dev/null)
  printf '%s\n' "${l:-no output}"
}

field() { # field <brief> <name>: that header line's value, without a stray CR
  sed -n "s/^$2: *//p" "$1" | head -n 1 | tr -d '\r'
}

allow_of() { # allow_of <brief>: its allow: entries, one per line, a folder's trailing / trimmed
  field "$1" allow | sed 's/ *· */\n/g; s|/$||' | sed '/^$/d'
}

in_allow() { # in_allow <file> <brief>: 0 when the brief's allow: names the file or a folder of it
  local f=$1 a
  while IFS= read -r a; do
    [ "$f" = "$a" ] && return 0
    case $f in "$a"/*) return 0 ;; esac
  done < <(allow_of "$2")
  return 1
}

wave_of() { # wave_of <job>: its 1-based wave number in waves.txt, else nothing
  tr -d '\r' < "$waves" |
    PROBE_WAVE_JOB=$1 awk '$0 !~ /^[[:space:]]*(#|$)/ { n++; for (i = 1; i <= NF; i++) if ($i == ENVIRON["PROBE_WAVE_JOB"]) { print n; exit } }'
}

normalize() { # normalize: each path on the way in, as a repo-relative path with forward slashes
  sed 's|\\|/|g; s|^\./||' | tr -d '\r'
}

patch_files() { # patch_files <patch>: the paths the patch adds or changes, one per line
  sed -n 's/^+++ b\///p; s/^--- a\///p' "${1:-}" 2> /dev/null | grep -v '^/dev/null$' | normalize | sort -u
}

error_files() { # error_files <analyze log>: the files its error lines name, one per line, unique
  grep -E '^[[:space:]]*error' "${1:-}" 2> /dev/null |
    awk 'match($0, /[^[:space:]]+\.dart:[0-9]+:[0-9]+/) { print substr($0, RSTART, RLENGTH) }' |
    sed 's/:[0-9][0-9]*:[0-9][0-9]*$//' | normalize | sort -u
}

names() { # names <space-separated jobs>: "a", or "a and b"
  local out="" j
  for j in $1; do
    case $out in '') out=$j ;; *) out="$out and $j" ;; esac
  done
  printf '%s' "$out"
}

run_limited() { # run_limited <command line> <deadline> <log>: the command in $wt, killed at the deadline # returns 124 at the deadline (dart analyze itself exits 3 on errors)
  [ "$(date +%s)" -lt "$2" ] || return 124
  ( cd "$wt" && exec $1 ) > "$3" 2>&1 &
  child=$!
  while kill -0 "$child" 2> /dev/null; do
    if [ "$(date +%s)" -ge "$2" ]; then
      kill_tree "$child"
      wait "$child" 2> /dev/null
      child=""
      return 124
    fi
    sleep "$PROBE_POLL_S"
  done
  wait "$child"
  local rc=$?
  child=""
  return "$rc"
}

timeout_at() { # timeout_at <job> <step>: the RESULT line; the trap removes the worktree
  echo "RESULT: TIMEOUT: $1 passed PROBE_MAX_MIN=$PROBE_MAX_MIN min ($limit_s s) at $2; its worktree was removed"
  exit 3
}

absolute() { # absolute <path>: the path as git apply reads it, from any folder (the worktree's too)
  case $1 in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$root/${1#./}" ;; esac
}

resolve_patch() { # resolve_patch <brief>: the probe: path, from the repo root first, then the batch folder
  local p
  p=$(field "$1" probe)
  if [ -f "$p" ]; then absolute "$p"; return 0; fi
  if [ -f "$batch/$p" ]; then absolute "$batch/$p"; return 0; fi
  return 1
}

new_tree() { # new_tree <job>: a detached worktree at $tmp/<job>, which the trap removes
  wt="$tmp/$1"
  if ! git -c core.autocrlf=false worktree add -q --detach "$wt" "${PROBE_BASE:-HEAD}" > "$tmp/setup.log" 2>&1; then
    setup_failed "$1: git worktree add ${PROBE_BASE:-HEAD} failed: $(first_line "$tmp/setup.log")"
  fi
  trees+=("$wt")
}

apply_patch() { # apply_patch <brief> <patch>: the patch inside the worktree, or exit 3
  if ! git -C "$wt" -c core.autocrlf=false apply "$2" > "$tmp/patch.log" 2>&1; then
    setup_failed "$(basename "$1" .md): $(field "$1" probe) doesn't apply at ${PROBE_BASE:-HEAD}: $(first_line "$tmp/patch.log")"
  fi
}

dep_lines() { # dep_lines <file>: the jobs whose allow: names it, one per line
  local b
  for b in ${briefs[@]+"${briefs[@]}"}; do
    in_allow "$1" "$b" && basename "$b" .md
  done
  return 0
}

check_file() { # check_file <job> <wave> <file>: one FAIL line when no earlier job's allow: holds it
  local job=$1 pw=$2 f=$3 j w own=0 earlier=0 same="" later="" unlisted=""
  grep -qxF -- "$f" "$tmp/patched" && return 0 # the patch's own files are exempt
  for j in $(dep_lines "$f"); do
    if [ "$j" = "$job" ]; then
      own=1
      continue
    fi
    w=$(wave_of "$j")
    if [ -z "$w" ]; then
      unlisted="$unlisted $j"
    elif [ "$w" = "$pw" ]; then
      same="$same $j"
    elif [ "$w" -lt "$pw" ]; then
      earlier=$((earlier + 1))
    else
      later="$later $j"
    fi
  done
  [ "$own" = 1 ] && return 0
  [ "$earlier" = 0 ] || return 0
  if [ -n "$same" ]; then
    printf 'FAIL deps %s: %s is only in the allow of %s, a job of the same wave %s (move the contract to an earlier wave, or merge the jobs)\n' \
      "$job" "$f" "$(names "$same")" "$pw" >> "$tmp/fails"
  elif [ -n "$later" ]; then
    printf 'FAIL deps %s: %s is only in the allow of %s, a later wave (the stub breaks it before that job runs)\n' \
      "$job" "$f" "$(names "$later")" >> "$tmp/fails"
  elif [ -n "$unlisted" ]; then
    printf 'FAIL deps %s: %s is only in the allow of %s, which waves.txt does not list\n' \
      "$job" "$f" "$(names "$unlisted")" >> "$tmp/fails"
  else
    printf "FAIL deps %s: %s is in no job's allow\n" "$job" "$f" >> "$tmp/fails"
  fi
}

review_warns() { # review_warns <brief> <review log>: a layers FAIL in a file the job allows is a WARN
  local brief=$1 line rest f
  while IFS= read -r line; do
    rest=${line#FAIL layers }
    rest=${rest#"${rest%%[![:space:]]*}"} # review.sh pads its columns
    f=${rest%% *}
    f=${f%:*}
    in_allow "$f" "$brief" || continue
    printf 'WARN layers %s: %s\n' "$(basename "$brief" .md)" "$rest" >> "$tmp/warns"
  done < <(grep '^FAIL layers ' "${2:-}" 2> /dev/null)
}

probe_cmds() { # probe_cmds <brief> <wave> <patch>: pub get, analyze and review in $wt (see the header)
  local job patch log rc deadline files f n
  job=$(basename "$1" .md)
  patch=$3
  deadline=$(($(date +%s) + limit_s))
  log="$tmp/$job-pub.log"
  run_limited "${PROBE_PUB_CMD:-flutter pub get}" "$deadline" "$log"
  rc=$?
  [ "$rc" = 124 ] && timeout_at "$job" "${PROBE_PUB_CMD:-flutter pub get}"
  [ "$rc" = 0 ] || setup_failed "$job: ${PROBE_PUB_CMD:-flutter pub get} failed: $(first_line "$log")"
  log="$tmp/$job-analyze.log"
  run_limited "${PROBE_ANALYZE_CMD:-dart analyze --fatal-infos}" "$deadline" "$log"
  rc=$?
  [ "$rc" = 124 ] && timeout_at "$job" "${PROBE_ANALYZE_CMD:-dart analyze --fatal-infos}"
  patch_files "$patch" > "$tmp/patched"
  files=$(error_files "$log")
  n=$(printf '%s\n' "$files" | grep -c .)
  if [ "$rc" != 0 ] && [ "$n" = 0 ]; then
    printf 'FAIL deps %s: analyze exited %s and named no error file, so no file can be cleared: %s\n' \
      "$job" "$rc" "$(first_line "$log")" >> "$tmp/fails"
  fi
  for f in $files; do
    check_file "$job" "$2" "$f"
  done
  total_files=$((total_files + n))
  printf 'PROBE %s: %s error files\n' "$job" "$n" >> "$tmp/probes"
  if [ "${PROBE_REVIEW:-1}" != 0 ]; then
    git -C "$wt" add -N . > /dev/null 2>&1
    log="$tmp/$job-review.log"
    run_limited "${PROBE_REVIEW_CMD:-bash tools/review.sh}" "$deadline" "$log"
    [ "$?" = 124 ] && timeout_at "$job" "${PROBE_REVIEW_CMD:-bash tools/review.sh}"
    review_warns "$1" "$log"
  fi
}

probe_one() { # probe_one <brief>: one job's probe (see the header)
  local brief=$1 job wave patch
  job=$(basename "$brief" .md)
  wave=$(wave_of "$job")
  [ -n "$wave" ] || bad_input "$waves doesn't list $job, so its wave is unknown and no dependence can be seen"
  patch=$(resolve_patch "$brief") ||
    setup_failed "$job: the probe: patch $(field "$brief" probe) is neither in the repo root nor in $batch"
  new_tree "$job"
  apply_patch "$brief" "$patch"
  probe_cmds "$brief" "$wave" "$patch"
}

briefs=()
probes=()
for f in "$batch"/*.md; do
  [ -f "$f" ] || continue
  case $(basename "$f") in *-report.md) continue ;; esac
  grep -q '^job:' "$f" 2> /dev/null || continue
  briefs+=("$f")
  [ -z "$(field "$f" probe)" ] || probes+=("$f")
done
if [ ${#probes[@]} = 0 ]; then
  echo "no probe: line in $batch: its jobs carry no stub patch, so nothing is probed"
  echo "RESULT: ok: no probe: line in the batch"
  exit 0
fi

for b in ${probes[@]+"${probes[@]}"}; do
  probe_one "$b"
done

cat "$tmp/fails" "$tmp/warns" "$tmp/probes"
fails_n=$(grep -c . "$tmp/fails")
warns_n=$(grep -c . "$tmp/warns")
if [ "$fails_n" -gt 0 ]; then
  echo "RESULT: FAILED: $fails_n error file(s) of ${#probes[@]} probe job(s) outside an earlier job's allow"
  exit 1
fi
echo "RESULT: ok: ${#probes[@]} probe job(s), every error file in an earlier job's allow ($total_files error file(s), $warns_n WARN)"
exit 0
