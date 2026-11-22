#!/usr/bin/env bash
# The brief gate, sourced by tools/run-jobs.sh through its gate_step seam when it is present:
#   . "$dir/run-gate.sh"   (dir: the folder holding run-jobs.sh)
# Before wave 1 the batch's briefs are checked against tools/brief-check.sh (p4a): its FAILs are
# the defects that used to stop a wave halfway (two jobs of one wave sharing a file, a new file no
# job allows, a changes: item no job allows). gate_step captures this file's output, so the dry run
# prints brief-check's whole output and exits 1 on a FAIL, while the start refuses with one line
# (`brief-check failed: <first FAIL line>`), which becomes the stop's cause. A rehearsal knows its
# overlaps: BRIEF_CHECK_SKIP=<reason> turns that refusal into a logged WARN, never a stop, and is
# the only override, because the stop itself is what saves the wave.
# Not run on its own: it reads the runner's B (the briefs folder) and its note helper.
# Env: BRIEF_CHECK_CMD  the command that checks the batch, replacing `bash tools/brief-check.sh`
#                       (split on spaces; the batch folder is appended as its last argument); a
#                       folder with neither it nor tools/brief-check.sh skips the gate.
#      BRIEF_CHECK_SKIP a reason (a rehearsal): a start's FAIL becomes `WARN brief-check skipped`
# Returns 0 to go on, 1 with the reason on stdout (the dry run's text, the start's stop cause).

brief_check_first() { # brief_check_first <output>: its first FAIL line, else its last non-empty line
  printf '%s\n' "$1" | awk '
    /^FAIL/ { print; found = 1; exit }
    { if (NF) last = $0 }
    END { if (!found && last != "") print last }'
}

brief_gate() { # brief_gate <dry|start>: 0 to go on; 1 with the reason printed (dry: whole output)
  local mode=${1:-} cmd out rc=0 why
  case $mode in
    dry | start) ;;
    *) echo "brief gate: unknown mode '$mode' (dry or start)"; return 1 ;;
  esac
  if [ -z "${BRIEF_CHECK_CMD:-}" ] && [ ! -f tools/brief-check.sh ]; then return 0; fi
  cmd=${BRIEF_CHECK_CMD:-bash tools/brief-check.sh}
  out=$($cmd "$B" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] && return 0
  if [ "$mode" = dry ]; then # the reader of the plan sees every FAIL, not only the first
    [ -z "$out" ] || printf '%s\n' "$out"
    return 1
  fi
  why=$(brief_check_first "$out")
  case $rc in
    1) # a FAIL: final, unless a rehearsal says why it is expected
      if [ -n "${BRIEF_CHECK_SKIP:-}" ]; then
        note "WARN brief-check skipped: $BRIEF_CHECK_SKIP"
        return 0
      fi
      echo "brief-check failed: $why"
      ;;
    *) echo "brief-check could not run (exit $rc): $why" ;; # bad use or a crash: never skipped
  esac
  return 1
}
