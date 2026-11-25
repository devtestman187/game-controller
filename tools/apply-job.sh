#!/usr/bin/env bash
# Hand-applies one stopped job's kept work tree: the one way to fix a stop by hand, instead of
# copying files freehand (identity1's i1f fix left arena_character_painter.dart in the tree, and
# other fixes copied more than their allow: list). Documented in docs/flash-digest.md, "Repair a
# stop".
#
#   tools/apply-job.sh <batch dir> <job> [--tree <dir>] [--only <path>]... [--dry] [--force]
#
# <batch dir> holds the briefs (<job>.md) and run.log. The kept work tree is read from
# <batch dir>/flash-<job>.log, the line "the worktree is kept: <path>"; APPLY_LOGS=<dir> reads the
# logs from that folder instead, and --tree names the tree yourself (it wins, and the log is not
# read).
#
# It copies, bytes for bytes (binary files too), into this repository: every file the tree changed,
# added (untracked, not ignored) or deleted under the brief's allow: paths and its report: path. It
# never stages or commits; the paths stay in the working tree for tools/commit-job.sh or a
# named-paths commit. Everything else the tree changed is printed and left alone: generated churn
# (tools/churn.sh) as "SKIPPED churn: <path>", anything else as "SKIPPED outside allow: <path>".
#
# --only <path> copies just that path (repeat the option for more): the cheaper fix when one file
# of a result-4 job is wrong; the files it leaves out are printed as "SKIPPED by --only: <path>". A
# --only path outside the brief's allow: and report: refuses the whole run before anything is
# copied, and so does a target path with uncommitted changes in this repository (the copy would
# lose that work), unless --force. --dry prints the same lists, copies nothing and writes no log
# line.
#
# On success it appends one line to <batch dir>/run.log, as docs/flash-digest.md asks:
# "HAND-FIX <job>: apply-job.sh applied <n> files: <a>, <b>", then prints the paths and the next
# steps (tools/review.sh, the job's tests, commit named paths). A second line, "HAND-FIX-EVENT <job>:
# <n> lines changed, replaced ladder level <l>" (the brief's `ladder:` line, ? when none), is the hand-fix's own event.
# Exit code: 0 applied (or shown, with --dry), 1 refused, 2 bad use. Works in Git Bash on Windows
# and bash on macOS and Linux.
set -u

tool_dir=$(cd "$(dirname "$0")" && pwd) || exit 2
# churn_path is the one list of generated files: a build's PNG or plugin file is skipped by the
# same rule tools/mine.sh and the runner use, never by a second copy of the list.
. "$tool_dir/churn.sh" || exit 2
cd "$tool_dir/.." || exit 2

bad_use() { # bad_use <why>: what the caller got wrong, then exit 2
  echo "apply-job: $1" >&2
  exit 2
}
refuse() { # refuse <why>: nothing is copied or logged, exit 1
  echo "apply-job: refused: $1" >&2
  exit 1
}

batch=""
job=""
tree=""
dry=0
force=0
only=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tree | --only)
      [ $# -ge 2 ] && [ -n "$2" ] || bad_use "$1 needs a value"
      case "$1" in
        --tree) tree=${2%/} ;;
        --only)
          only_path=${2#./}
          only+=("${only_path%/}")
          ;;
      esac
      shift
      ;;
    --dry) dry=1 ;;
    --force) force=1 ;;
    -h | --help)
      sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) bad_use "unknown option $1 (try --help)" ;;
    *)
      if [ -z "$batch" ]; then
        batch=${1%/}
      elif [ -z "$job" ]; then
        job=${1%.md}
      else
        bad_use "one batch folder and one job at a time (try --help)"
      fi
      ;;
  esac
  shift
done

[ -n "$batch" ] && [ -n "$job" ] || bad_use "give the batch folder and the job: tools/apply-job.sh <batch dir> <job>"
[ -d "$batch" ] || bad_use "no such batch folder: $batch"
brief="$batch/$job.md"
[ -f "$brief" ] || bad_use "no brief at $brief"
command -v git > /dev/null 2>&1 || bad_use "git isn't on the PATH"
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || bad_use "not inside a git repository"

field() { # field <name>: the brief's header line value, without a stray CR
  sed -n "s/^$1: *//p" "$brief" | head -n 1 | tr -d '\r'
}
allow=()
while IFS= read -r a; do [ -n "$a" ] && allow+=("$a"); done < <(field allow | sed 's/ *· */\n/g; s|/$||' | sed '/^$/d')
[ ${#allow[@]} -gt 0 ] || bad_use "$brief has no allow: line, so there is no path to apply"
report=$(field report)
report=${report%/}
allowed=("${allow[@]}")
[ -n "$report" ] && allowed+=("$report")

covers() { # covers <path> <path>...: 0 when a listed path is it or a folder holding it
  local path=$1 a
  shift
  for a in "$@"; do
    [ "$path" = "$a" ] && return 0
    case "$path" in "$a"/*) return 0 ;; esac
  done
  return 1
}
join() { # join <separator> <item>...: the items on one line
  local sep=$1 items="" item
  shift
  for item in "$@"; do items+="${items:+$sep}$item"; done
  printf '%s' "$items"
}

for only_path in ${only[@]+"${only[@]}"}; do
  covers "$only_path" "${allowed[@]}" ||
    refuse "--only $only_path is outside $job's allow: and report: paths; nothing was copied"
done

logs=${APPLY_LOGS:-$batch}
logs=${logs%/}
if [ -z "$tree" ]; then
  log="$logs/flash-$job.log"
  [ -f "$log" ] || refuse "no flash log at $log (--tree <kept worktree>, or APPLY_LOGS=<log folder>)"
  tree=$(sed -n 's/.*the worktree is kept: //p' "$log" | tail -n 1 | tr -d '\r')
  [ -n "$tree" ] || refuse "no \"the worktree is kept: <path>\" line in $log (--tree names the tree by hand)"
fi
[ -d "$tree" ] || refuse "the kept worktree isn't there: $tree (the runner removes it after its own apply)"
git -C "$tree" rev-parse --is-inside-work-tree > /dev/null 2>&1 || refuse "not a git worktree: $tree"

# Everything the tree changed, one path per entry: -z so a path's spaces or quotes come through as
# they are. A rename counts as its new path and its old one (the original path follows the new
# one; tools/churn.sh reads it the same way).
entries=()
while IFS= read -r -d '' entry; do entries+=("$entry"); done < <(git -C "$tree" status --porcelain -z -uall 2> /dev/null)
changed_paths=()
changed_kinds=()
i=0
while [ "$i" -lt "${#entries[@]}" ]; do
  entry=${entries[$i]}
  i=$((i + 1))
  case "${entry:0:2}" in
    *R* | *C*)
      changed_paths+=("${entry:3}") changed_kinds+=(copy)
      if [ "$i" -lt "${#entries[@]}" ]; then
        changed_paths+=("${entries[$i]}") changed_kinds+=(delete)
        i=$((i + 1))
      fi
      ;;
    *D*) changed_paths+=("${entry:3}") changed_kinds+=(delete) ;;
    *) changed_paths+=("${entry:3}") changed_kinds+=(copy) ;;
  esac
done
kind_of() { # kind_of <path>: how the tree changed it (copy or delete)
  local at=0
  while [ "$at" -lt "${#changed_paths[@]}" ]; do
    if [ "${changed_paths[$at]}" = "$1" ]; then
      printf '%s' "${changed_kinds[$at]}"
      return 0
    fi
    at=$((at + 1))
  done
  printf 'copy'
}
# Sorted by path, because git status groups untracked files last: unsorted, the printed list and
# the run.log line would read differently from run to run.
sorted=()
while IFS= read -r p; do [ -n "$p" ] && sorted+=("$p"); done < <(printf '%s\n' ${changed_paths[@]+"${changed_paths[@]}"} | LC_ALL=C sort)

# What it applies, and what it names and leaves alone.
targets=()
kinds=()
skipped=()
churned=()
unasked=()
for p in ${sorted[@]+"${sorted[@]}"}; do
  if churn_path "$p"; then
    churned+=("$p")
  elif ! covers "$p" "${allowed[@]}"; then
    skipped+=("$p")
  elif [ ${#only[@]} -gt 0 ] && ! covers "$p" "${only[@]}"; then
    unasked+=("$p")
  else
    targets+=("$p") kinds+=("$(kind_of "$p")")
  fi
done
[ ${#targets[@]} -gt 0 ] || refuse "nothing to apply: $tree changed nothing under $job's allow: or report: paths"

if [ "$force" = 0 ]; then
  dirty=()
  for target in "${targets[@]}"; do
    [ -n "$(git status --porcelain -- "$target" 2> /dev/null)" ] && dirty+=("$target")
  done
  [ ${#dirty[@]} -eq 0 ] ||
    refuse "these paths have uncommitted changes here, and a copy would lose them (--force copies over them): $(join ' ' "${dirty[@]}")"
fi

if [ "$dry" = 1 ]; then
  echo "would apply ${#targets[@]} files:"
else
  echo "applied ${#targets[@]} files:"
fi
i=0
while [ "$i" -lt "${#targets[@]}" ]; do
  if [ "${kinds[$i]}" = delete ]; then
    echo "  ${targets[$i]} (deleted)"
  else
    echo "  ${targets[$i]}"
  fi
  i=$((i + 1))
done
for p in ${skipped[@]+"${skipped[@]}"}; do echo "SKIPPED outside allow: $p"; done
for p in ${churned[@]+"${churned[@]}"}; do echo "SKIPPED churn: $p"; done
for p in ${unasked[@]+"${unasked[@]}"}; do echo "SKIPPED by --only: $p"; done

if [ "$dry" = 1 ]; then
  echo "dry run: nothing copied, run.log unchanged"
  exit 0
fi
i=0 changed=0
while [ "$i" -lt "${#targets[@]}" ]; do
  target=${targets[$i]}
  changed=$((changed + $(diff "$target" "$tree/$target" 2> /dev/null | grep -c "^[<>]"))) # lines changed, for the log
  if [ "${kinds[$i]}" = delete ]; then
    rm -f "$target" || refuse "couldn't delete $target"
  else
    mkdir -p "$(dirname "$target")" && cp -f "$tree/$target" "$target" ||
      refuse "couldn't copy $tree/$target to $target"
  fi
  i=$((i + 1))
done
line="HAND-FIX $job: apply-job.sh applied ${#targets[@]} files: $(join ', ' "${targets[@]}")"
printf '%s\n' "$line" >> "$batch/run.log" || refuse "the files are copied, but $batch/run.log couldn't be written"
lvl=$(sed -n 's/^ladder: *\([0-9][0-9]*\).*/\1/p' "$brief" 2> /dev/null | head -n 1)
printf 'HAND-FIX-EVENT %s: %s lines changed, replaced ladder level %s\n' "$job" "$changed" "${lvl:-?}" >> "$batch/run.log"
echo "$line"
echo "next: run tools/review.sh and the job's tests, then commit these paths only (tools/commit-job.sh $brief)"
exit 0
