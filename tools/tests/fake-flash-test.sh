#!/usr/bin/env bash
# Tests tools/fake-flash.sh, the stand-in worker a rehearsal of the job runner
# uses: a brief run's report (Summary first, Hand-over last), the note line and
# the usage row tools/run-jobs.sh reads, the defaults, FAKE_FLASH_RC, the
# preflight, a hung run, bad arguments and folders with spaces.
#
#   bash tools/tests/fake-flash-test.sh
#
# Every case builds its own brief and folders in a temp folder, so no case sees
# another's files. The sleeps are 1 s (or 2 s for the defaults and the hang), so
# the whole run takes about 5 s. Prints PASS <case> / FAIL <case> and exits 1
# if any case failed. Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/../.." || exit 2
fake="$(pwd)/tools/fake-flash.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/fake-flash-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the run printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
dir=""
brief=""
knobs=()
# The usage log's field separator: a real tab, which some awks don't read from '\t'.
tab="$(printf '\t')"
run_fake() { # run_fake [args...]: runs the stand-in with the case's knobs
  rc=0
  env ${knobs[@]+"${knobs[@]}"} bash "$fake" "$@" > "$out" 2>&1 || rc=$?
}
knob() { # knob <name> <value>: one more env setting for the next run
  knobs+=("$1=$2")
}
fixture() { # fixture <name>: a brief whose allow: has two paths, a report folder to make, and a log folder
  dir="$tmp/$1"
  mkdir -p "$dir/work" "$dir/logs"
  brief="$dir/brief.md"
  printf 'job: rehearsal %s\nallow: %s/work/note.txt · %s/work/second.txt\ncheck: none\nreport: %s/docs/report.md\n' \
    "$1" "$dir" "$dir" "$dir" > "$brief"
  knobs=(FLASH_USAGE_LOG="$dir/logs/usage.tsv" FAKE_FLASH_NOTE_FILE="$dir/logs/notes.txt")
}
seconds_since() { # seconds_since <epoch>: whole seconds from then to now
  echo $(( $(date +%s) - $1 ))
}

# One run's report: Summary on its first line, Hand-over as the last heading,
# and the first allow: path named (that is what the brief is read for).
fixture report
knob FAKE_FLASH_SLEEP_S 1
knob FAKE_FLASH_TURNS 7
start="$(date +%s)"
run_fake --brief "$brief"
elapsed="$(seconds_since "$start")"
last_heading="$(grep '^## ' "$dir/docs/report.md" 2> /dev/null | tail -n 1)"
r=1
if [ "$rc" = 0 ] && [ "$elapsed" -ge 1 ] &&
  head -n 1 "$dir/docs/report.md" 2> /dev/null | grep -qx '## Summary' &&
  [ "$last_heading" = "## Hand-over" ] &&
  grep -q '^## Commit message$' "$dir/docs/report.md" &&
  grep -qF "$dir/work/note.txt" "$dir/docs/report.md"; then r=0; fi
report "a brief run sleeps 1 s and writes a report with Summary first, Hand-over last and the first allow path (${elapsed} s)" \
  "$r"

# The run writes the report, one note line and the usage row, and nothing in
# the allow: folder (the first path is only named, the second not at all).
lines="$(wc -l < "$dir/logs/notes.txt" 2> /dev/null)"
[ -n "$lines" ] || lines=0
r=1
if [ "$(ls -A "$dir/work")" = "" ] && [ "$(ls -A "$dir/docs")" = "report.md" ] &&
  [ "$(ls -A "$dir/logs" | sort | tr '\n' ' ')" = "notes.txt usage.tsv " ] && [ "$lines" = 1 ] &&
  grep -qF "$brief" "$dir/logs/notes.txt" && grep -qF "allow=$dir/work/note.txt" "$dir/logs/notes.txt" &&
  ! grep -q "second.txt" "$dir/logs/notes.txt" && grep -q "rc=0" "$dir/logs/notes.txt"; then r=0; fi
report "the run writes only the report, one note line and the usage row; the allow folder stays empty" "$r"

# The usage row is in tools/run-jobs.sh's format: ten fields, the result, the
# asked turns, one file, and a task field that holds the brief's path (run-jobs
# finds a job's turns by matching that path in the row).
row() { # row <field number>: that field of the first usage row
  awk -F'\t' -v n="$1" '{ print $n }' "$dir/logs/usage.tsv"
}
rows="$(wc -l < "$dir/logs/usage.tsv")"
fields="$(awk -F'\t' 'END { print NF }' "$dir/logs/usage.tsv")"
task_seen="$(row 10)"
r=1
if [ "$rows" = 1 ] && [ "$fields" = 10 ] && [ "$(row 3)" = 7 ] && [ "$(row 2)" = 0 ] &&
  [ "$(row 9)" = 1 ] && [ "$task_seen" = "Your brief is $brief: read it first, then do the job it describes." ]; then
  r=0
fi
report "the usage log gets one ten-field row with 7 turns, a 0, one file and the brief's path in the task field" \
  "$r"

# Without knobs: a 2 s run, 10 turns, exit 0.
fixture defaults
start="$(date +%s)"
run_fake --brief "$brief"
elapsed="$(seconds_since "$start")"
turns_seen="$(awk -F'\t' '{ print $3 }' "$dir/logs/usage.tsv" 2> /dev/null)"
if [ "$rc" = 0 ] && [ "$elapsed" -ge 2 ] && [ "$turns_seen" = 10 ]; then r=0; else r=1; fi
report "the defaults are a 2 s run, 10 turns and exit 0 (${elapsed} s, $turns_seen turns)" "$r"

# FAKE_FLASH_RC is the exit code, and a failed run still leaves its report and row.
fixture rc
knob FAKE_FLASH_SLEEP_S 0
knob FAKE_FLASH_RC 4
run_fake --brief "$brief"
r=1
if [ "$rc" = 4 ] && grep -q 'exit code: 4' "$dir/docs/report.md" 2> /dev/null &&
  [ "$(awk -F'\t' '{ print $2 }' "$dir/logs/usage.tsv" 2> /dev/null)" = 4 ]; then r=0; fi
report "FAKE_FLASH_RC=4 is the exit code, and the report and the usage row still say 4" "$r"

# The preflight the runner calls first: exit 0 and no file at all.
fixture preflight
run_fake --preflight
r=1
if [ "$rc" = 0 ] && [ -z "$(ls -A "$dir/docs" 2> /dev/null)" ] && [ -z "$(ls -A "$dir/logs")" ] &&
  [ -z "$(ls -A "$dir/work")" ] && grep -q 'preflight ok' "$out"; then r=0; fi
report "--preflight exits 0 and writes no report, note line or usage row" "$r"

# A hung run outlasts the runner's patience: timeout ends it and nothing is written.
fixture hang
knob FAKE_FLASH_HANG 1
rc=0
env ${knobs[@]+"${knobs[@]}"} timeout 2 bash "$fake" --brief "$brief" > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 124 ] && [ ! -e "$dir/docs/report.md" ] && [ -z "$(ls -A "$dir/logs")" ]; then r=0; fi
report "FAKE_FLASH_HANG=1 outlasts a 2 s timeout (exit $rc) and writes nothing" "$r"

# Bad arguments: exit 2 and a fake-flash: line saying what was wrong.
bad_case() { # bad_case <case> <args...>
  local name=$1
  shift
  run_fake "$@"
  if [ "$rc" = 2 ] && grep -q '^fake-flash: ' "$out"; then r=0; else r=1; fi
  report "$name" "$r"
}
fixture args
bad_case "an unknown argument is bad input (exit 2)" --nonsense
bad_case "--brief with no value is bad input (exit 2)" --brief
bad_case "a missing brief file is bad input (exit 2)" --brief "$tmp/no-such-brief.md"
no_report="$dir/plain.md"
printf 'job: no report\nallow: %s/work/note.txt\n' "$dir" > "$no_report"
bad_case "a brief with no report: line is bad input (exit 2)" --brief "$no_report"
knob FAKE_FLASH_SLEEP_S 1.2.3
run_fake --brief "$brief"
r=1
if [ "$rc" = 2 ] && grep -q 'FAKE_FLASH_SLEEP_S takes seconds' "$out"; then r=0; fi
report "FAKE_FLASH_SLEEP_S=1.2.3 is bad input (exit 2)" "$r"
fixture turns
knob FAKE_FLASH_TURNS ten
run_fake --brief "$brief"
r=1
if [ "$rc" = 2 ] && grep -q 'FAKE_FLASH_TURNS takes a whole number' "$out"; then r=0; fi
report "FAKE_FLASH_TURNS=ten is bad input (exit 2)" "$r"

# A brief, its report and its folders with spaces work.
dir="$tmp/spaces one/job two"
mkdir -p "$dir/work" "$dir/logs"
brief="$dir/my brief.md"
printf 'job: spaces\nallow: %s/work/note.txt\nreport: %s/docs/my report.md\n' "$dir" "$dir" > "$brief"
knobs=(FLASH_USAGE_LOG="$dir/logs/usage.tsv" FAKE_FLASH_NOTE_FILE="$dir/logs/notes.txt" FAKE_FLASH_SLEEP_S=0)
run_fake --brief "$brief"
r=1
if [ "$rc" = 0 ] && head -n 1 "$dir/docs/my report.md" 2> /dev/null | grep -qx '## Summary' &&
  grep -qF "$dir/work/note.txt" "$dir/logs/notes.txt" &&
  [ "$(row 10)" = "Your brief is $brief: read it first, then do the job it describes." ]; then r=0; fi
report "a brief and folders with spaces work, and the row still names the brief" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
