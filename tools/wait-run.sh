#!/usr/bin/env bash
# Waits for a batch run (tools/run-jobs.sh) without polling by hand: blocks for
# a while, prints the run.log lines that are new since the last call, and exits
# as soon as the run logs DONE or STOPPED.
#
#   tools/wait-run.sh <briefs-dir> [--max <s>]
#
# One call blocks at most WAIT_MAX_S seconds (default 170, capped at 170: the
# agent shell moves a call still running at 180 s into the background), so a
# driver calls it in a loop until it exits 0 or 1.
#
# Exit codes; the last line is always `RESULT: ...`:
#   0 DONE      a DONE line after the run's last `start at` line
#   1 STOPPED   a `STOPPED: <why>` line there (read the lines above and the logs)
#   2 STALLED   run.log, the batch's flash-*.log files and the run's work folder
#               unchanged for WAIT_STALL_MIN minutes, or OVERRUN: a job with no
#               `finished` line yet runs past 1.5 x its expected minutes (once per
#               job: a later call says so and waits the window instead)
#   3 BAD INPUT no folder, no run.log, a bad option, or another waiter on the
#               same folder
#   4 running   the window ended with the run still going; the result names the
#               job, its minutes so far and its expected minutes: call again; after
#               the last job it says `checking: the combined check for <n> min`,
#               during the run's review `reviewing: the run's review for <n> min`,
#               and before the first job `preflight (no job started yet)`
#
# A job starts at its `start <job>` line, or at its `resume <job> (applied by hand,
# not committed yet)` line when the runner found its report already in the folder;
# it ends at its `finished: result` or `committed <job>:` line, whichever comes last.
# The runner's `start the run's review` note is not a job: it shows as `reviewing`
# and never OVERRUNs (the review has RUN_REVIEW_MAX_MIN, not a job's estimate).
#
# A job's expected minutes: an `expected-min:` line in its brief, else the
# median of that job's last WAIT_RECENT_ROWS flash-usage rows (FLASH_USAGE_LOG),
# else WAIT_EXPECT_DEFAULT_MIN.
#
# Env knobs: WAIT_MAX_S (window, cap 170), WAIT_POLL_S (5 s), WAIT_STALL_MIN
# (20), WAIT_EXPECT_DEFAULT_MIN (15), WAIT_RECENT_ROWS (30), FLASH_USAGE_LOG
# (~/.thumbparty/flash-usage.tsv), RUN_WORK (the runner's work folder, named as
# tools/run-jobs.sh names it: .dart_tool/run-jobs/<briefs-dir, / as _>),
# WAIT_LOGS (the folder the runner was given as --logs, when the flash-*.log
# files are not in the briefs folder), WAIT_STATE_DIR (.dart_tool/wait-run: the
# lock, position, marker and overrun files; a test points it at a temp folder).
# The four counts are whole numbers of at least 1; anything else is BAD INPUT
# (exit 3).
#
# The position file holds the byte offset already printed, so a repeat call
# prints only new lines; a new `start at` line moves it back to that line, so a
# fresh run is printed from its own first line (which names the commit). A
# garbage or too-large position is reset the same way. A last line whose
# newline has not been written yet comes out in two pieces; run.log lines are
# written whole, so this does not happen. No git command runs: run.log, the
# briefs and the usage log are the only inputs.
set -u
cd "$(dirname "$0")/.." || exit 3

WAIT_CAP_S=170
WAIT_MAX_S=${WAIT_MAX_S:-$WAIT_CAP_S}
WAIT_POLL_S=${WAIT_POLL_S:-5}
WAIT_STALL_MIN=${WAIT_STALL_MIN:-20}
WAIT_EXPECT_DEFAULT_MIN=${WAIT_EXPECT_DEFAULT_MIN:-15}
WAIT_RECENT_ROWS=${WAIT_RECENT_ROWS:-30}
USAGE_LOG=${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}

bad() { # bad <sentence>: the one line saying why, exit 3
  printf 'RESULT: BAD INPUT: %s\n' "$1"
  exit 3
}
result() { # result <exit code> <RESULT sentence>
  printf 'RESULT: %s\n' "$2"
  exit "$1"
}
epoch() { # epoch <YYYY-MM-DD HH:MM:SS>: seconds since 1970; fails when unreadable
  case "${1:-}" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]*) ;;
    *) return 1 ;;
  esac
  date -d "${1:0:19}" +%s 2> /dev/null
}
cleanup() { # remove the lock (ours only) and the marker; a TERM lands here at once
  [ -n "${nap_pid:-}" ] && kill "$nap_pid" 2> /dev/null
  [ "${have_lock:-0}" = 1 ] && [ "$(cat "$LOCK" 2> /dev/null)" = $$ ] && rm -f "$LOCK"
  [ "${have_marker:-0}" = 1 ] && rm -f "$MARKER"
  return 0
}
take_lock() { # one waiter per briefs folder; a stale lock (dead pid) is replaced
  local pid
  if [ -f "$LOCK" ]; then
    pid=$(cat "$LOCK" 2> /dev/null)
    case "$pid" in
      '' | *[!0-9]*) rm -f "$LOCK" ;; # a crashed waiter left garbage
      *) kill -0 "$pid" 2> /dev/null && bad "another waiter (pid $pid) is on $B; let it finish or remove $LOCK" ;;
    esac
  fi
  printf '%s\n' "$$" > "$LOCK" || bad "cannot write the lock $LOCK"
  have_lock=1
}
run_start_line() { # the line number of the run's last `start at` line, 0 when none
  local n
  n=$(grep -n ' start at ' "$LOG" | tail -n 1 | cut -d: -f1)
  printf '%s\n' "${n:-0}"
}
offset_after() { # offset_after <line>: bytes of the file up to and including it
  [ "$1" -gt 0 ] || { printf '0\n'; return; }
  head -n "$1" "$LOG" | wc -c | tr -d ' '
}
first_line_off() { # where a new run starts printing: its own `start at` line, which says the commit
  if [ "$start_ln" -gt 1 ]; then offset_after $((start_ln - 1)); else offset_after 0; fi
}
read_pos() { # the offset already printed; a garbage value (or none) means 0
  local p
  p=$(cat "$POS" 2> /dev/null)
  case "$p" in '' | *[!0-9]*) p=0 ;; esac
  POS_V=$((p))
}
print_new() { # print the bytes added since the last call, then move the position
  local size chunk
  size=$(wc -c < "$LOG" | tr -d ' ')
  if [ "$POS_V" -lt "$run_start_off" ] || [ "$POS_V" -gt "$size" ]; then
    POS_V=$run_start_off # a new run, or a position that cannot be right: print this run again
  fi
  if [ "$size" -gt "$POS_V" ]; then
    chunk=$(tail -c "+$((POS_V + 1))" "$LOG" | head -c "$((size - POS_V))")
    [ -n "$chunk" ] && printf '%s\n' "$chunk"
    POS_V=$size
  fi
  printf '%s\n' "$POS_V" > "$POS"
}
run_ended() { # 0 and END_KIND/END_TEXT when this run logged DONE or STOPPED
  local line
  line=$(tail -n "+$((start_ln + 1))" "$LOG" | grep -E ' (DONE|STOPPED): ' | tail -n 1)
  [ -n "$line" ] || return 1
  case "$line" in
    *' DONE: '*) END_KIND=DONE; END_TEXT=${line#* DONE: } ;;
    *) END_KIND=STOPPED; END_TEXT=${line#* STOPPED: } ;;
  esac
}
unfinished_jobs() { # `start time<TAB>job` for each job with no finished or committed line yet, earliest first
  tail -n "+$((start_ln + 1))" "$LOG" | awk '
    {
      ts = substr($0, 1, 19) # the runner prefixes every line with its time
      rest = $0
      sub(/^[0-9-]+ [0-9:]+ /, "", rest)
    }
    rest ~ /^start / {
      job = rest
      sub(/^start /, "", job)
      # The `start at <sha>` line is the run itself, and the runner note that begins the run
      # review (tools/run-review.sh) is not a job: neither is named or overrun here.
      if (job !~ /^at / && job !~ /^the run.s review$/ && !(job in started)) started[job] = ts
    }
    rest ~ /^resume / { # a report left in the folder: the runner applies the job by hand
      job = rest
      sub(/^resume /, "", job)
      sub(/ \(applied by hand.*/, "", job)
      if (job != "" && !(job in started)) started[job] = ts
    }
    rest ~ / finished: result / {
      job = rest
      sub(/ finished: result .*/, "", job)
      if (job in started) delete started[job]
    }
    rest ~ /^committed [^ ]+: / { # a resumed job has no finished line; its commit ends it
      job = rest
      sub(/^committed /, "", job)
      sub(/: .*/, "", job)
      if (job in started) delete started[job]
    }
    END { for (job in started) printf "%s\t%s\n", started[job], job }
  ' | sort
}
minutes_since() { # minutes_since <YYYY-MM-DD HH:MM:SS>: whole minutes from it to now, 0 when unreadable
  local from
  from=$(epoch "$1")
  [ -n "$from" ] || { printf '0\n'; return; }
  printf '%s\n' $((($(date +%s) - from) / 60))
}
last_job_ts() { # the time of this run's last `<job> finished: result` or `committed <job>:` line, empty when none
  tail -n "+$((start_ln + 1))" "$LOG" |
    grep -E '^[0-9-]+ [0-9:]+ ([^ ]+ finished: result |committed [^ ]+: )' |
    tail -n 1 | cut -c1-19
}
review_ts() { # the time of this run's last `start the run's review` note, empty when it has none
  tail -n "+$((start_ln + 1))" "$LOG" |
    grep -E '^[0-9-]+ [0-9:]+ start the run.s review$' |
    tail -n 1 | cut -c1-19
}
seen_reset() { # a new run (a later `start at` line) forgets the overruns the last one reported
  [ "$(head -n 1 "$SEEN" 2> /dev/null)" = "run $start_ln" ] && return 0
  printf 'run %s\n' "$start_ln" > "$SEEN" 2> /dev/null
}
seen_has() { # seen_has <job>: 0 when a call of this run already reported that job's overrun
  [ "$(head -n 1 "$SEEN" 2> /dev/null)" = "run $start_ln" ] || return 1
  grep -qxF -- "$1" "$SEEN" 2> /dev/null
}
seen_add() { printf '%s\n' "$1" >> "$SEEN"; }
expected_min() { # expected_min <job>: minutes from its brief, else the usage median, else the default
  local brief="$B/$1.md" v
  if [ -f "$brief" ]; then
    v=$(sed -n 's/^expected-min:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$brief" | head -n 1)
    [ -n "$v" ] && { printf '%s\n' "$v"; return; }
  fi
  # The brief path comes in through the environment: awk's -v would eat the backslashes of a Windows path.
  v=$(WAIT_BRIEF="$brief" awk -F'\t' 'index($10, ENVIRON["WAIT_BRIEF"]) && $4 + 0 > 0 { print $4 / 60 }' \
    "$USAGE_LOG" 2> /dev/null |
    tail -n "$WAIT_RECENT_ROWS" | sort -n |
    awk '{ a[NR] = $1 } END { if (!NR) exit; m = (NR % 2 ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2); printf "%d\n", int(m + 0.5) }')
  [ -n "$v" ] && { printf '%s\n' "$v"; return; }
  printf '%s\n' "$WAIT_EXPECT_DEFAULT_MIN"
}
overrun() { # exit 2 the first time a job still running passed 1.5 x its expected minutes
  local ts job from mins now elapsed
  now=$(date +%s)
  while IFS=$'\t' read -r ts job; do
    [ -n "${job:-}" ] || continue
    from=$(epoch "$ts")
    [ -n "$from" ] || continue
    mins=$(expected_min "$job")
    elapsed=$((now - from))
    if [ "$elapsed" -gt $((mins * 90)) ] && ! seen_has "$job"; then
      seen_add "$job" # the driver saw it; the next call keeps waiting and says so
      result 2 "OVERRUN: $job has run $((elapsed / 60)) min, expected ~$mins (1.5 x is $((mins * 90 / 60)) min)"
    fi
  done < <(unfinished_jobs)
}
stalled() { # 0 when run.log, the flash logs and the work folder stood still too long
  local now
  [ -n "$run_started_s" ] || return 1
  now=$(date +%s)
  [ $((now - run_started_s)) -ge $((WAIT_STALL_MIN * 60)) ] || return 1
  touch -d "@$((now - WAIT_STALL_MIN * 60))" "$MARKER" 2> /dev/null || return 1
  have_marker=1
  [ -z "$(find "${watched[@]}" -newer "$MARKER" -print -quit 2> /dev/null)" ]
}
running_text() { # the exit-4 sentence: the running job, the check after the last job, or the run before its first job
  local ts job
  IFS=$'\t' read -r ts job < <(unfinished_jobs | head -n 1) || true
  if [ -n "${job:-}" ]; then
    printf '%s for %d min (expected ~%s)' "$job" "$(minutes_since "$ts")" "$(expected_min "$job")"
    seen_has "$job" && printf ', overrun already reported'
    return 0
  fi
  ts=$(review_ts) # the run's own review runs after every job and is not a job: no OVERRUN
  if [ -n "$ts" ]; then
    printf "reviewing: the run's review for %d min" "$(minutes_since "$ts")"
    return 0
  fi
  ts=$(last_job_ts) # no job is running: the combined check runs after the last job's line
  if [ -n "$ts" ]; then
    printf 'checking: the combined check for %d min' "$(minutes_since "$ts")"
    return 0
  fi
  ts=$(grep -E ' start at ' "$LOG" | tail -n 1 | cut -c1-19) # the run itself, from its start at line
  printf 'preflight (no job started yet) for %d min (expected ~%s)' "$(minutes_since "$ts")" \
    "$(expected_min 'preflight (no job started yet)')"
}
nap() { # nap <seconds>: a sleep that a TERM interrupts at once
  sleep "$1" &
  nap_pid=$!
  wait "$nap_pid" 2> /dev/null
  nap_pid=""
}

B=""
max=""
while [ $# -gt 0 ]; do
  case "$1" in
    --max) [ $# -ge 2 ] || bad "--max needs a number of seconds"; max=$2; shift 2 ;;
    -h | --help) awk 'NR > 1 && /^set -u/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    -*) bad "unknown option $1 (try --help)" ;;
    *) [ -z "$B" ] || bad "one briefs folder at a time (got $B and ${1%/})"; B=${1%/}; shift ;;
  esac
done
[ -n "$B" ] || bad "usage: tools/wait-run.sh <briefs-dir> [--max <s>]"
[ -d "$B" ] || bad "no such folder: $B"
LOG="$B/run.log"
[ -f "$LOG" ] || bad "no run.log in $B (the runner writes it; is a run going?)"
case "$WAIT_MAX_S" in '' | *[!0-9]*) bad "the window takes whole seconds (WAIT_MAX_S=$WAIT_MAX_S)" ;; esac
case "$WAIT_STALL_MIN" in
  '' | *[!0-9]*) bad "the stall window takes whole minutes (WAIT_STALL_MIN=$WAIT_STALL_MIN)" ;;
esac
case "$WAIT_POLL_S" in '' | *[!0-9]*) bad "the poll takes whole seconds (WAIT_POLL_S=$WAIT_POLL_S)" ;; esac
case "$WAIT_RECENT_ROWS" in
  '' | *[!0-9]*) bad "the usage rows take a whole number (WAIT_RECENT_ROWS=$WAIT_RECENT_ROWS)" ;;
esac
if [ -n "$max" ]; then
  case "$max" in *[!0-9]*) bad "--max takes whole seconds, not $max" ;; esac
  WAIT_MAX_S=$max
fi
[ "$WAIT_MAX_S" -ge 1 ] || bad "the wait window takes at least 1 second"
[ "$WAIT_STALL_MIN" -ge 1 ] || bad "the stall window takes at least 1 minute"
[ "$WAIT_POLL_S" -ge 1 ] || bad "the poll takes at least 1 second"
[ "$WAIT_RECENT_ROWS" -ge 1 ] || bad "the usage rows take at least 1"
if [ "$WAIT_MAX_S" -gt "$WAIT_CAP_S" ]; then
  echo "NOTE: the wait window is capped at ${WAIT_CAP_S} s"
  WAIT_MAX_S=$WAIT_CAP_S
fi

state=${WAIT_STATE_DIR:-.dart_tool/wait-run}
mkdir -p "$state" || bad "cannot make the state folder $state"
name=$(printf '%s' "$B" | tr -c 'A-Za-z0-9._-' '_') # a path can hold / \ : and spaces; a file name may not
LOCK="$state/$name.lock"
POS="$state/$name.pos"
MARKER="$state/$name.marker"
SEEN="$state/$name.overrun"
WORK=${RUN_WORK:-.dart_tool/run-jobs/${B//\//_}}
watched=("$LOG")
for f in "$B"/flash-*.log; do [ -f "$f" ] && watched+=("$f"); done
if [ -n "${WAIT_LOGS:-}" ]; then
  for f in "$WAIT_LOGS"/flash-*.log; do [ -f "$f" ] && watched+=("$f"); done
fi
[ -d "$WORK" ] && watched+=("$WORK")
have_lock=0
have_marker=0
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
take_lock

start_ln=$(run_start_line)
run_start_off=$(first_line_off)
run_started_s=$(epoch "$(grep -E ' start at ' "$LOG" | tail -n 1 | cut -c1-19)")
seen_reset
read_pos
deadline=$(($(date +%s) + WAIT_MAX_S))
printf 'WAIT: %s, window %s s, poll %s s\n' "$B" "$WAIT_MAX_S" "$WAIT_POLL_S"

while :; do
  start_ln=$(run_start_line)
  run_start_off=$(first_line_off)
  run_started_s=$(epoch "$(grep -E ' start at ' "$LOG" | tail -n 1 | cut -c1-19)")
  seen_reset # a restart while we wait (a new start at line) is a new run
  print_new
  if run_ended; then
    [ "$END_KIND" = DONE ] && result 0 "ok: DONE: $END_TEXT"
    result 1 "STOPPED: $END_TEXT"
  fi
  if stalled; then
    result 2 "STALLED: run.log, the flash logs and $WORK stood still for $WAIT_STALL_MIN min and no job finished"
  fi
  overrun
  now=$(date +%s)
  [ "$now" -ge "$deadline" ] && result 4 "running: $(running_text)"
  left=$((deadline - now))
  nap $((left < WAIT_POLL_S ? left : WAIT_POLL_S))
done
