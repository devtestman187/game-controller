#!/usr/bin/env bash
# Writes <batch-dir>/STOP.md: why a run stopped, what failed and how to fix it.
# The runner calls this at every stop (tools/run-jobs.sh); it never fails the run.
#
#   tools/run-stop.sh <batch-dir> <work-dir> "<cause text>" [<flash-log>]
#
# <batch-dir> holds run.log; <work-dir> holds run-check.log; <flash-log> is the
# stopped job's log and only its CHANGED FILES OUTSIDE block is quoted.
# STOP.md holds at most STOP_MAX_LINES lines: the cause, its class, a suggested
# repair, the failing test names and error lines from run-check.log (the same
# filter tools/check.sh prints on a failure), the files outside allow from the
# flash log, and the last run.log lines. A missing log is reported as
# "none found", never as an error. The file goes to a temp file and is renamed,
# so a reader never sees half of it; nothing else in the batch folder changes.
#
# The class is one of: churn-outside outside-allow tests-first check-failed
# review-fail size brief-lint preflight stop-file commit-refused job-failed
# timeout other, taken from the cause text the runner passes.
#
# Env knobs, each a whole number of at least 1 (anything else: exit 3):
# STOP_MAX_LINES (40, the file's hard line limit, at least 10) · STOP_LOG_TAIL
# (20, the run.log lines kept, capped so the file fits STOP_MAX_LINES) ·
# STOP_ERROR_LINES (8, the most error lines) · STOP_OUTSIDE_LINES (5, the most
# outside files) · STOP_COL (300, the most columns one quoted line keeps, since
# a whole run.log line can be long).
# Exit codes: 0 STOP.md is written, whatever it says · 3 bad arguments or an
# unwritable batch folder. Works in Git Bash on Windows and bash on macOS/Linux.
set -u

STOP_MAX_LINES=${STOP_MAX_LINES:-40}
STOP_LOG_TAIL=${STOP_LOG_TAIL:-20}
STOP_ERROR_LINES=${STOP_ERROR_LINES:-8}
STOP_OUTSIDE_LINES=${STOP_OUTSIDE_LINES:-5}
STOP_COL=${STOP_COL:-300}
# The lines worth quoting from a failed check: the pattern tools/check.sh uses.
# The FAIL lines name a failed shell suite's script and case (tools/check.sh keeps them too).
INTERESTING='\[E\]|Expected:|Actual:|Which:|Error:|error -|warning -|info -|Changed |Some tests failed|Failed to load|Exception|Test failed|^ *FAIL[ :]'

bad_input() { echo "RESULT: BAD INPUT: $1"; exit 3; }

whole() { # whole <knob> <value>: a whole number, or bad input naming the knob
  case "$2" in '' | *[!0-9]*) bad_input "$1 takes a whole number, got '$2'" ;; esac
}

usage() { sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; }

classify() { # classify <cause>: one word from the class list in the header
  case "$1" in
    *"brief lint:"*) echo brief-lint ;;
    *tests-first:*) echo tests-first ;;
    *"checks failed"*) echo check-failed ;;
    *"review.sh found a FAIL"*) echo review-fail ;;
    *"must be split"*) echo size ;;
    *preflight*) echo preflight ;;
    *"stop file"*) echo stop-file ;;
    *"commit of "*" refused"*) echo commit-refused ;;
    *"jobs that failed"* | *"need applying by hand"*) echo job-failed ;;
    *TIMEOUT* | *"time limit"*) echo timeout ;;
    *churn*) echo churn-outside ;;
    *outside*allow* | *"CHANGED FILES OUTSIDE"* | *"result 4"*) echo outside-allow ;;
    *) echo other ;;
  esac
}

repair_for() { # repair_for <class>: the suggested repair, naming the digest or a command
  case "$1" in
    churn-outside) echo "generated churn is not ours: leave it; add a path the runner keeps hitting to tools/churn.sh, never to allow: (docs/flash-digest.md \"Repair a stop\")." ;;
    outside-allow) echo "apply the patch from the allowed paths or hand-apply from the kept worktree, run tools/review.sh and the job's tests, append \"HAND-FIX <job>: ...\" to run.log, restart (docs/flash-digest.md \"Repair a stop\")." ;;
    tests-first) echo "fix the test so it fails on the old code (never the gate), or add \"tests-first: exempt <reason>\" to the brief for a pure refactor (docs/flash-digest.md \"Repair a stop\")." ;;
    check-failed) echo "run tools/check.sh <suite> for the failing name above, fix the one cause, append \"HAND-FIX <job>: ...\" to run.log and restart (docs/flash-digest.md \"Repair a stop\")." ;;
    review-fail) echo "run bash tools/review.sh, fix the FAIL lines it prints in the code (never a rule), then restart (docs/flash-digest.md \"Repair a stop\")." ;;
    size) echo "split the lib file named in the cause to under 380 lines (docs/coding-guidelines.md G3), append \"HAND-FIX <job>: ...\" to run.log, restart." ;;
    brief-lint) echo "make the brief's report: line exactly one bare path (no second report: line, no words after the path), then restart (tools/run-jobs.sh --dry-run prints LINT FAIL)." ;;
    preflight) echo "run tools/check.sh format analyze by hand: the worker cannot, so no job would run tests; see run-preflight.log in the work folder, then restart." ;;
    stop-file) echo "a person or Claude asked for this stop: delete <batch>/STOP (the runner does at the next start), fix the cause, then restart." ;;
    commit-refused) echo "read run-commit.log in the work folder, commit the job's named paths by hand, append \"HAND-FIX <job>: ...\" to run.log and restart (docs/flash-digest.md \"Repair a stop\")." ;;
    job-failed) echo "open the job's flash-<job>.log, apply its result by hand, append \"HAND-FIX <job>: ...\" to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md \"Repair a stop\")." ;;
    timeout) echo "the run passed RUN_MAX_MIN: read the last run.log job, stop the runner if it is stuck, then restart (docs/flash-digest.md \"Repair a stop\")." ;;
    *) echo "read the cause and the lines below, fix the one cause, append \"HAND-FIX <job>: ...\" to run.log, then restart (docs/flash-digest.md \"Repair a stop\")." ;;
  esac
}

interesting_lines() { # interesting_lines <run-check.log>: failing names and error lines, de-duplicated
  tr '\r' '\n' < "$1" | grep -E "$INTERESTING" | grep -vE '^\s+(dart:|package:)' | awk '!seen[$0]++'
}

outside_paths() { # outside_paths <flash-log>: the files in a CHANGED FILES OUTSIDE block
  awk '/CHANGED FILES OUTSIDE/{on=1;next} /^---- flash:/{on=0} on&&/^  /{print $1}' "$1"
}

short() { # short <line>: one quoted line, cut to STOP_COL columns
  if [ "${#1}" -gt "$STOP_COL" ]; then printf '%s...' "${1:0:$STOP_COL}"; else printf '%s' "$1"; fi
}

add_lines() { # add_lines <max> <item>...: appends items to out, "  (+N more)" last when cut
  local max=$1; shift
  local total=$# show=$# i
  [ "$total" -gt "$max" ] && show=$((max - 1))
  for ((i = 0; i < show; i++)); do out+=("  $(short "$1")"); shift; done
  [ "$total" -gt "$max" ] && out+=("  (+$((total - show)) more)")
}

# ---- arguments ----
case "${1:-}" in
  -h | --help) usage; exit 0 ;;
esac
[ $# -ge 3 ] && [ $# -le 4 ] || bad_input "usage: tools/run-stop.sh <batch-dir> <work-dir> \"<cause>\" [<flash-log>]"
B=${1%/} WORK=${2%/} raw_cause=$3 flash=${4:-}
[ -d "$B" ] || bad_input "no batch folder: ${1}"
[ -w "$B" ] || bad_input "the batch folder is not writable: ${1}"
[ -z "$WORK" ] && WORK=.

# ---- env knobs: a bad one is bad input, never a broken or over-long file ----
whole STOP_MAX_LINES "$STOP_MAX_LINES"
whole STOP_LOG_TAIL "$STOP_LOG_TAIL"
whole STOP_ERROR_LINES "$STOP_ERROR_LINES"
whole STOP_OUTSIDE_LINES "$STOP_OUTSIDE_LINES"
whole STOP_COL "$STOP_COL"
[ "$STOP_MAX_LINES" -ge 10 ] || bad_input "STOP_MAX_LINES takes at least 10 lines, got $STOP_MAX_LINES"
[ "$STOP_LOG_TAIL" -ge 1 ] || bad_input "STOP_LOG_TAIL takes at least 1 line, got $STOP_LOG_TAIL"
[ "$STOP_ERROR_LINES" -ge 1 ] || bad_input "STOP_ERROR_LINES takes at least 1, got $STOP_ERROR_LINES"
[ "$STOP_OUTSIDE_LINES" -ge 1 ] || bad_input "STOP_OUTSIDE_LINES takes at least 1, got $STOP_OUTSIDE_LINES"
[ "$STOP_COL" -ge 1 ] || bad_input "STOP_COL takes at least 1 column, got $STOP_COL"
# The head line, the three section lines and one line each for errors and files
# leave the tail this much room; a bigger knob is capped rather than obeyed.
tail_cap=$((STOP_MAX_LINES - 9))
if [ "$STOP_LOG_TAIL" -gt "$tail_cap" ]; then
  STOP_LOG_TAIL=$tail_cap
  echo "NOTE: STOP_LOG_TAIL is capped at $STOP_LOG_TAIL lines so STOP.md fits $STOP_MAX_LINES"
fi

# ---- input files (a missing one is "none found", not an error) ----
checklog="$WORK/run-check.log"; [ -f "$checklog" ] || checklog=""
runlog="$B/run.log"; [ -f "$runlog" ] || runlog=""
[ -n "$flash" ] && [ -f "$flash" ] || flash=""

# The cause may hold quotes, spaces and newlines; STOP.md shows it as one line.
cause=$(printf '%s' "$raw_cause" | tr '\n\r\t' '   ' | tr -s ' ' | sed 's/^ //; s/ $//')
cl=$(classify "$cause")

errs=() outs=() logs=()
[ -n "$checklog" ] && mapfile -t errs < <(interesting_lines "$checklog")
[ -n "$flash" ] && mapfile -t outs < <(outside_paths "$flash")
[ -n "$runlog" ] && mapfile -t logs < <(tr -d '\r' < "$runlog" | tail -n "$STOP_LOG_TAIL")

# ---- the report: 4 head lines, 3 section lines, the caps from the env knobs ----
# The tail cap above keeps room at 2 or more, and two lines each for errors and
# files are the least those sections need, so the file stays within the limit.
room=$((STOP_MAX_LINES - 7 - STOP_LOG_TAIL))
errmax=$((room - 1)); [ "$errmax" -gt "$STOP_ERROR_LINES" ] && errmax=$STOP_ERROR_LINES
outmax=$((room - errmax)); [ "$outmax" -gt "$STOP_OUTSIDE_LINES" ] && outmax=$STOP_OUTSIDE_LINES

out=("STOP $(date '+%F %T') $B" "cause: $(short "${cause:-(empty)}")" "class: $cl" "repair: $(repair_for "$cl")")
out+=("failing tests and errors (run-check.log):")
if [ ${#errs[@]} -gt 0 ]; then add_lines "$errmax" "${errs[@]}"; else out+=("  none found"); fi
out+=("files outside allow (flash log):")
if [ ${#outs[@]} -gt 0 ]; then add_lines "$outmax" "${outs[@]}"; else out+=("  none found"); fi
out+=("run.log (last $STOP_LOG_TAIL lines):")
if [ ${#logs[@]} -gt 0 ]; then add_lines "$STOP_LOG_TAIL" "${logs[@]}"; else out+=("  none found"); fi

# ---- atomic write: a temp file in the same folder, then rename ----
tmp=$(mktemp "$B/.STOP.md.XXXXXX" 2>/dev/null) || bad_input "cannot write in the batch folder: $B"
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "${out[@]}" > "$tmp" 2>/dev/null || bad_input "cannot write in the batch folder: $B"
mv -f "$tmp" "$B/STOP.md" 2>/dev/null || bad_input "cannot replace $B/STOP.md"
echo "RESULT: ok: STOP.md written (${#out[@]} lines): $B/STOP.md"
