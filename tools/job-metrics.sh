#!/usr/bin/env bash
# One row per worker log of a batch: what each job cost and how it ended, read from the lines
# tools/flash.sh prints into <batch dir>/flash-<job>.log (tools/run-jobs.sh and
# tools/run-review.sh put them there). The batch table is for comparing a batch with another
# (a claude worker against flash); --append is for the runner's run.log.
#
#   tools/job-metrics.sh <batch dir> [--append]
#
# Every <batch dir>/flash-*.log is one worker run: a job's, a job review's, a wave's review or
# the run's review, so `-review` and `wave<N>-review` logs are rows too. One table row per log:
#
#   JOB      the log's name without flash- and .log (i1g2, i1g2-review, wave3-review)
#   WORKER   claude when the model starts with claude-, else flash; a `worker: <name>` line in
#            the batch's run.log (the runner writes one per run, after `start at`) wins over the
#            model, so a batch run on the claude worker is not read as flash
#   MODEL    the model the worker-exit line names
#   TURNS    the usage line's turns
#   IN       input tokens; OUT output tokens; CACHE cache read + cache write as one sum
#   MINUTES  the usage line's seconds / 60, one decimal
#   WALL     the job's start-to-finish minutes, one decimal: from its last `start <job>` or
#            `resume <job>` line in the batch's run.log to the `<job> finished: result` line after
#            it; `-` for a review log and when run.log has no such pair (no run.log, no start line,
#            or no finish line after the start, as for a run started again after its finish)
#   RESULT   the `---- flash: result` code, `no result` when the log has none; when the JSON
#            result log the worker-exit line names is still there, its subtype and
#            terminal_reason follow in brackets
# A field the log does not hold prints `-`: a log with no usage line is a run that never got as
# far as the worker answering.
#
# --append also adds one line per job to <batch dir>/run.log:
#   METRICS <job> worker=<w> model=<m> turns=<t> in=<i> out=<o> cache=<c> min=<n> wall=<n> result=<r>
# with a `-` where the log has no value (result=- where it has no result; wall=- as the WALL
# column). A job that already has a METRICS line in run.log is skipped, so a second --append
# changes nothing.
#
# Exit codes: 0 done (also when nothing was appended); 2 bad use, or no flash-*.log in the
# folder. The table and the append's count line go to stdout.
set -u

bad_use() { # <why>: the one-line refusal the script rules ask for
  echo "job-metrics: $1 (try --help)" >&2
  exit 2
}

dir=""
append=0
for arg in "$@"; do
  case "$arg" in
    -h | --help) sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --append) append=1 ;;
    -*) bad_use "unknown option $arg" ;;
    *)
      [ -z "$dir" ] || bad_use "one batch folder at a time (got $*)"
      dir=$arg
      ;;
  esac
done
[ -n "$dir" ] || bad_use "give the batch folder"
[ -d "$dir" ] || bad_use "not a folder: $dir"
[ "$dir" = / ] || dir=${dir%/}
run_log="$dir/run.log"

# The runner's `worker:` line, if run.log has one: its latest wins, because a restarted run may
# have switched workers. note() writes the runner's date in front of it.
worker_override=""
if [ -f "$run_log" ]; then
  worker_override=$(awk '
    { line = $0; sub(/^[0-9][0-9-]* [0-9][0-9:]* /, "", line) }
    line ~ /^worker: / {
      name = line; sub(/^worker: */, "", name); sub(/ .*$/, "", name)
      if (name != "") found = name
    }
    END { if (found != "") print found }' "$run_log")
fi

# A job's WALL cell: the minutes from its last `start <job>` or `resume <job>` line in run.log to
# the `<job> finished: result` line after it, one decimal, or `-` when there is no such pair. A
# start after the finish cancels the finish. The job name matches exactly. Dates become day
# counts (from 1970, only differences matter), so a run that passes midnight comes out right.
wall_minutes() { # wall_minutes <job>: prints the minutes, or `-`
  LC_ALL=C awk -v job="$1" '
    function days_from(y, m, d,   era, yoe, doy, doe) {
      if (m <= 2) y--
      era = int(y / 400)
      yoe = y - era * 400
      doy = int((153 * ((m + 9) % 12) + 2) / 5) + d - 1
      doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
      return era * 146097 + doe
    }
    $1 ~ /^[0-9]+-[0-9]+-[0-9]+$/ && $2 ~ /^[0-9]+:[0-9]+:[0-9]+$/ {
      split($1, day, "-")
      split($2, clock, ":")
      when = days_from(day[1] + 0, day[2] + 0, day[3] + 0) * 86400 + clock[1] * 3600 + clock[2] * 60 + clock[3]
      if (($3 == "start" || $3 == "resume") && $4 == job) {
        start = when
        started = 1
        finish = ""
      } else if ($3 == job && $4 == "finished:" && started) {
        finish = when
      }
    }
    END {
      if (started && finish != "") printf "%.1f\n", (finish - start) / 60
      else print "-"
    }' "$run_log"
}

# The cells of the log read_log took; reset before each log, `-` where the log has no value.
job="" worker="" model="" turns="" in_tokens="" out_tokens="" cache_tokens="" minutes="" wall=""
result="" result_cell=""

read_log() { # read_log <log>: fills the cells from one worker log, `-` for what it lacks
  local f=$1 line numbers seconds subtype terminal detail json_log
  job=${f##*/}
  job=${job#flash-}
  job=${job%.log}
  model=- turns=- in_tokens=- out_tokens=- cache_tokens=- minutes=-
  result=- result_cell="no result"
  wall=-
  if [ -f "$run_log" ] && [ "${job%-review}" = "$job" ]; then wall=$(wall_minutes "$job"); fi
  line=$(sed -n 's/^---- flash usage: \{0,1\}//p' "$f" | tail -n 1)
  case "$line" in
    '' | 'not available'*) ;; # the worker never answered: no usage line to read
    *)
      # flash_usage.dart prints the numbers in one order: turns, seconds, input, cache read,
      # cache write, output. Six of them, or the line is not one of its own.
      numbers=$(printf '%s\n' "$line" | sed 's/[^0-9]/ /g')
      # Word splitting on purpose: each number is one field.
      set -- $numbers
      if [ $# = 6 ]; then
        turns=$1
        seconds=$2
        in_tokens=$3
        cache_tokens=$(($4 + $5))
        out_tokens=$6
        minutes=$(LC_ALL=C awk -v s="$seconds" 'BEGIN { printf "%.1f", s / 60 }')
      fi
      ;;
  esac
  model=$(sed -n 's/^---- flash: worker exit [^,]*, model \([^,]*\), log .*/\1/p' "$f" | tail -n 1)
  [ -n "$model" ] || model=-
  worker=flash
  case "$model" in claude-*) worker=claude ;; esac
  [ -n "$worker_override" ] && worker=$worker_override
  json_log=$(sed -n 's/^---- flash: worker exit [^,]*, model [^,]*, log \(.*\)$/\1/p' "$f" | tail -n 1)
  line=$(sed -n 's/^---- flash: result //p' "$f" | tail -n 1)
  if [ -n "$line" ]; then
    result=$line
    result_cell=$line
  fi
  detail=""
  if [ -n "$json_log" ] && [ -f "$json_log" ]; then
    subtype=$(sed -n 's/.*"subtype":[[:space:]]*"\([^"]*\)".*/\1/p' "$json_log" | head -n 1)
    terminal=$(sed -n 's/.*"terminal_reason":[[:space:]]*"\([^"]*\)".*/\1/p' "$json_log" | head -n 1)
    [ -n "$subtype" ] && detail="subtype=$subtype"
    [ -n "$terminal" ] && detail="${detail:+$detail, }terminal_reason=$terminal"
  fi
  [ -n "$detail" ] && result_cell="$result_cell ($detail)"
  return 0
}

widths=(0 0 0 0 0 0 0 0 0 0 0)
widen() { # widen <cell>...: each column's width grows to hold its cell
  local i=1 v
  for v in "$@"; do
    if [ ${#v} -gt "${widths[i]}" ]; then widths[i]=${#v}; fi
    i=$((i + 1))
  done
}

row_line() { # row_line <job> <worker> <model> <turns> <in> <out> <cache> <minutes> <wall> <result>
  printf '%-*s %-*s %-*s %*s %*s %*s %*s %*s %*s %s\n' \
    "${widths[1]}" "$1" "${widths[2]}" "$2" "${widths[3]}" "$3" "${widths[4]}" "$4" \
    "${widths[5]}" "$5" "${widths[6]}" "$6" "${widths[7]}" "$7" "${widths[8]}" "$8" \
    "${widths[9]}" "$9" "${10}"
}

print_table() { # print_table: the header, then one line per log in the order the logs came
  local j w m t i o c n wl r
  widen JOB WORKER MODEL TURNS IN OUT CACHE MINUTES WALL RESULT
  row_line JOB WORKER MODEL TURNS IN OUT CACHE MINUTES WALL RESULT
  while IFS=$'\t' read -r j w m t i o c n wl r; do
    row_line "$j" "$w" "$m" "$t" "$i" "$o" "$c" "$n" "$wl" "$r"
  done < <(printf '%s\n' "${rows[@]}")
}

logs=("$dir"/flash-*.log)
[ -f "${logs[0]}" ] || { echo "job-metrics: no flash-*.log in $dir" >&2; exit 2; }

rows=()
metrics=()
for f in "${logs[@]}"; do
  read_log "$f"
  rows+=("$(printf '%s\t' "$job" "$worker" "$model" "$turns" "$in_tokens" "$out_tokens" \
    "$cache_tokens" "$minutes" "$wall")$result_cell")
  widen "$job" "$worker" "$model" "$turns" "$in_tokens" "$out_tokens" "$cache_tokens" "$minutes" "$wall"
  if [ "$append" = 1 ] && ! grep -qF -- "METRICS $job " "$run_log" 2> /dev/null; then
    metrics_line="METRICS $job worker=$worker model=$model turns=$turns in=$in_tokens"
    metrics+=("$metrics_line out=$out_tokens cache=$cache_tokens min=$minutes wall=$wall result=$result")
  fi
done

print_table
if [ "$append" = 1 ]; then
  if [ ${#metrics[@]} -gt 0 ]; then printf '%s\n' "${metrics[@]}" >> "$run_log"; fi
  echo "appended ${#metrics[@]} METRICS line(s) to $run_log"
fi
