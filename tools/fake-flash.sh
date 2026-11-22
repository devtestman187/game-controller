#!/usr/bin/env bash
# Stands in for tools/flash.sh in a rehearsal of the job runner: the same call,
# a short sleep in place of a worker run, a fixed report and one usage row, so
# a whole batch runs end to end with no worker and no API cost. The rehearsal
# that uses it is docs/briefs/m16/process3/REHEARSAL.md.
#
#   tools/fake-flash.sh --brief <file>     # what tools/run-jobs.sh calls
#   tools/fake-flash.sh --preflight        # the runner's preflight: exits 0
#
# Env, all optional:
#   FAKE_FLASH_SLEEP_S   seconds a job run takes, whole or with a fraction (default 2)
#   FAKE_FLASH_TURNS     turns the usage row records (default 10)
#   FAKE_FLASH_RC        the run's exit code (default 0)
#   FAKE_FLASH_NOTE_FILE a file that gets one line per run (default: none)
#   FAKE_FLASH_HANG=1    sleep an hour instead, to test the runner's limits
#   FLASH_USAGE_LOG      the usage log tools/flash.sh reads and writes
#                        (default $HOME/.thumbparty/flash-usage.tsv)
#
# It writes the brief's own paths and nothing else: the `report:` file, one
# line in FAKE_FLASH_NOTE_FILE and one row in FLASH_USAGE_LOG (the folders it
# needs are made). The first `allow:` path is read only to name it in that
# line: its folder gets no file, so the runner's outside-allow audit stays
# quiet, as a real job's would.
# Exit code: FAKE_FLASH_RC, or 2 for bad arguments or a file it can't write.
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u

# What a run does without knobs: a couple of seconds, a sensible turn count,
# success. A rehearsal sets the knobs to make the batch quick.
sleep_default_s=2
turns_default=10
rc_default=0
# A hung run sleeps past any limit a rehearsal sets, so the runner's per-job
# limit or its backstop is what ends it (REHEARSAL.md run 6).
hang_s=3600

bad() { echo "fake-flash: $1" >&2; exit 2; }

whole() { # whole <name> <value>: exits 2 unless the value is digits
  case "$2" in '' | *[!0-9]*) bad "$1 takes a whole number, got '$2'" ;; esac
}

seconds() { # seconds <name> <value>: a plain count of seconds, whole or with a fraction
  case "$2" in '' | .* | *. | *.*.* | *[!0-9.]*) bad "$1 takes seconds, got '$2'" ;; esac
}

pre=0
brief=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brief)
      [ $# -ge 2 ] && [ -n "$2" ] || bad "--brief needs a file"
      [ -f "$2" ] || bad "no brief at $2"
      brief="$2"
      shift
      ;;
    --preflight) pre=1 ;;
    -h | --help)
      sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) bad "unknown argument $1 (try --help)" ;;
  esac
  shift
done

if [ "$pre" = 1 ]; then
  # The runner only wants a 0 here: a stand-in run needs no key and no toolchain.
  echo "fake-flash: preflight ok (stand-in, no worker and no toolchain are run)"
  exit 0
fi
[ -n "$brief" ] || bad "give a brief with --brief (or use --preflight)"

sleep_s="${FAKE_FLASH_SLEEP_S:-$sleep_default_s}"
turns="${FAKE_FLASH_TURNS:-$turns_default}"
code="${FAKE_FLASH_RC:-$rc_default}"
seconds FAKE_FLASH_SLEEP_S "$sleep_s"
whole FAKE_FLASH_TURNS "$turns"
whole FAKE_FLASH_RC "$code"

# The brief's header lines, read as tools/flash.sh and tools/commit-job.sh read them.
field() { sed -n "s/^$1: *//p" "$brief" | head -n 1 | tr -d '\r'; }
report="$(field report)"
[ -n "$report" ] || bad "the brief $brief has no report: line"
allow_first="$(field allow | sed 's/ *· */\n/g' | head -n 1)"
allow_first="${allow_first%/}"
note="${FAKE_FLASH_NOTE_FILE:-}"
usage_log="${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}"

start_s="$(date +%s)"
if [ "${FAKE_FLASH_HANG:-0}" = 1 ]; then
  # A hung run: nothing is written, because the runner should end it first.
  sleep "$hang_s"
  exit "$code"
fi
sleep "$sleep_s"
elapsed_s=$(( $(date +%s) - start_s ))

mkdir -p "$(dirname "$report")" 2> /dev/null || bad "couldn't make the folder for the report $report"
allow_named="${allow_first:-(the brief names no allow: path)}"
note_said="one line in $note"
[ -n "$note" ] || note_said="no note line, because FAKE_FLASH_NOTE_FILE is unset"
{
  echo "## Summary"
  echo
  echo "Stand-in run of tools/fake-flash.sh: no worker ran, so this report is fixed."
  echo "A rehearsal of the runner only needs a report with Summary first and"
  echo "Hand-over last, and a job the runner can commit."
  echo
  echo "- brief: $brief"
  echo "- first allow path: $allow_named"
  echo "- slept: $elapsed_s s"
  echo "- exit code: $code"
  echo
  echo "## Commit message"
  echo
  echo "Rehearsal: the stand-in worker wrote this report"
  echo
  echo "The stand-in for tools/flash.sh wrote a fixed report and one usage row, so a"
  echo "rehearsal of the runner commits a job with no worker and no API cost."
  echo
  echo "## Status row"
  echo
  echo "Rehearsal job done (stand-in report); open: nothing."
  echo
  echo "## Delete"
  echo
  echo "- none"
  echo
  echo "## Hand-over"
  echo
  echo "Nothing was built or tested. The stand-in wrote only this report, $note_said"
  echo "and one row in $usage_log. The first allow path, $allow_named, was not"
  echo "created or changed."
} > "$report" || bad "couldn't write the report $report"

if [ -n "$note" ]; then
  mkdir -p "$(dirname "$note")" 2> /dev/null || bad "couldn't make the folder for $note"
  printf '%s\t%s\tallow=%s\trc=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$brief" "$allow_first" "$code" \
    >> "$note" || bad "couldn't append to $note"
fi

# One usage row in tools/flash_usage.dart's format: time, result, turns,
# seconds, input, cache read, cache write, output, files, task. The task is the
# line tools/flash.sh records, which carries the brief's path: tools/run-jobs.sh
# finds a job's turns by matching that path in the row.
mkdir -p "$(dirname "$usage_log")" 2> /dev/null || bad "couldn't make the folder for $usage_log"
printf '%s\t%s\t%s\t%s\t0\t0\t0\t0\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$code" "$turns" \
  "$elapsed_s" 1 "Your brief is $brief: read it first, then do the job it describes." \
  >> "$usage_log" || bad "couldn't append to $usage_log"

exit "$code"
