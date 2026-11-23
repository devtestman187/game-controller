#!/usr/bin/env bash
# Tests tools/job-metrics.sh, the batch's table of what each worker log cost: one row per
# flash-*.log with its job, worker, model, turns, in / out / cache tokens, minutes, wall and result;
# the worker is claude when the model starts with claude-, else flash, and a date-prefixed
# `worker: <name>` line in run.log wins; cache is read + write summed; minutes are seconds / 60
# to one decimal; a log with no usage line prints `-` and `no result`; the JSON log the
# worker-exit line names adds its subtype to the result column; --append writes one METRICS line
# per job to run.log (a `-` per missing value, result=- for no result) and a second run appends
# nothing; no argument and a folder with no logs are bad use, exit 2.
#
#   bash tools/tests/job-metrics-test.sh
#
# The fixture batch is built in a temp folder: four logs (a claude-model one whose JSON result
# log is kept, a deepseek one, one with a worker-exit line and no usage line, and an empty one),
# and the cases that need a run.log copy the batch and add one, with the runner's date prefix.
# Prints PASS <case> / FAIL <case> (the tool's output indented under a failure) and exits 1 if
# any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/job-metrics-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the tool printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
tool() { # tool [args]: runs the tool with those arguments on the batch; sets rc, writes $out
  rc=0
  bash tools/job-metrics.sh "$@" > "$out" 2>&1 || rc=$?
}
squeeze() { tr -s ' ' < "$out"; } # the table with runs of spaces as one
row() { squeeze | grep -qxF -- "$1"; } # row <line>: the squeezed table has exactly that line
rows() { squeeze | grep -c '^\(cli\|deep\|nousage\|empty\) ' || true; } # the table's data rows
mlines() { # mlines <run.log>: how many METRICS lines it holds (0 when it has none)
  if [ -f "$1" ]; then grep -c '^METRICS ' "$1" || true; else echo 0; fi
}

# The fixture batch. The claude-model log's JSON result log is kept, so its subtype shows; the
# other two worker-exit lines name logs that are gone, as in a real batch.
batch="$tmp/batch"
mkdir -p "$batch"
printf '{"type":"result","subtype":"success"}\n' > "$tmp/cli-result.json"
printf '%s\n' \
  '---- flash usage: 40 turns, 1234 s, input 1200 + cache read 50000 + cache write 7000, output 3400 tokens' \
  "---- flash: worker exit 0, model claude-haiku-5-5, log $tmp/cli-result.json" \
  '---- flash: result 0' > "$batch/flash-cli.log"
printf '%s\n' \
  '---- flash usage: 161 turns, 1386 s, input 5000 + cache read 9000 + cache write 1000, output 20000 tokens' \
  "---- flash: worker exit 1, model deepseek-v4-flash, log $tmp/gone.json" \
  '---- flash: result 4' > "$batch/flash-deep.log"
printf '%s\n' \
  "---- flash: worker exit 0, model deepseek-v4-flash, log $tmp/gone-too.json" > "$batch/flash-nousage.log"
: > "$batch/flash-empty.log"

# 1. The header names the ten columns and every flash-*.log gets one row.
tool "$batch"
if [ "$rc" = 0 ] && row 'JOB WORKER MODEL TURNS IN OUT CACHE MINUTES WALL RESULT' && [ "$(rows)" = 4 ]; then
  r=0
else
  r=1
fi
report "the table's header names the ten columns and one row per flash-*.log" "$r"

# 2. A claude-model log: worker claude, its model, its numbers, 1234 s as 20.6 min, no run.log so
#    no WALL (`-`), its result code with the JSON log's subtype (50000 + 7000 = 57000 cache tokens).
tool "$batch"
if [ "$rc" = 0 ] && row 'cli claude claude-haiku-5-5 40 1200 3400 57000 20.6 - 0 (subtype=success)'; then
  r=0
else
  r=1
fi
report "a claude-model log's row names the claude worker, its usage and the result's subtype" "$r"

# 3. A deepseek log: worker flash, cache read + write summed (9000 + 1000 = 10000), 1386 s as
#    23.1 min, and the gone JSON log adds nothing to the result.
if [ "$rc" = 0 ] && row 'deep flash deepseek-v4-flash 161 5000 20000 10000 23.1 - 4'; then
  r=0
else
  r=1
fi
report "a deepseek log's row names the flash worker and sums cache read + write" "$r"

# 4. A log that never reached the worker's answer: every number is `-` and there is no result.
if [ "$rc" = 0 ] && row 'nousage flash deepseek-v4-flash - - - - - - no result'; then
  r=0
else
  r=1
fi
report "a log with no usage line prints - for its numbers and no result" "$r"

# 5. An empty log: model too, and the model-less worker falls back to flash.
if [ "$rc" = 0 ] && row 'empty flash - - - - - - - no result'; then
  r=0
else
  r=1
fi
report "an empty log prints - for every field and falls back to the flash worker" "$r"

# 6. The runner's `worker:` line in run.log wins over the model: the deepseek log's row says
#    claude, and so does the claude-model one.
cp -r "$batch" "$tmp/withworker"
printf '%s\n' '2026-11-22 16:39:40 start at 37e32bdc on m16' '2026-11-22 16:39:41 worker: claude' \
  > "$tmp/withworker/run.log"
tool "$tmp/withworker"
if [ "$rc" = 0 ] && row 'deep claude deepseek-v4-flash 161 5000 20000 10000 23.1 - 4' &&
  row 'cli claude claude-haiku-5-5 40 1200 3400 57000 20.6 - 0 (subtype=success)'; then
  r=0
else
  r=1
fi
report "a worker: line in run.log wins over the model's name" "$r"

# 7. --append keeps run.log's existing lines and adds one METRICS line per job, a `-` where the
#    log has no value.
cp -r "$batch" "$tmp/append"
printf '%s\n' '2026-11-22 16:39:40 start at 37e32bdc on m16' > "$tmp/append/run.log"
tool "$tmp/append" --append
if [ "$rc" = 0 ] && [ "$(mlines "$tmp/append/run.log")" = 4 ] &&
  grep -qxF 'METRICS cli worker=claude model=claude-haiku-5-5 turns=40 in=1200 out=3400 cache=57000 min=20.6 wall=- result=0' "$tmp/append/run.log" &&
  grep -qxF 'METRICS deep worker=flash model=deepseek-v4-flash turns=161 in=5000 out=20000 cache=10000 min=23.1 wall=- result=4' "$tmp/append/run.log" &&
  grep -qxF 'METRICS empty worker=flash model=- turns=- in=- out=- cache=- min=- wall=- result=-' "$tmp/append/run.log" &&
  grep -qxF '2026-11-22 16:39:40 start at 37e32bdc on m16' "$tmp/append/run.log" &&
  grep -qF 'appended 4 METRICS line(s)' "$out"; then
  r=0
else
  r=1
fi
report "--append adds one METRICS line per job and keeps run.log's lines" "$r"

# 8. A second --append changes nothing: the same four METRICS lines, nothing appended.
before=$(grep '^METRICS ' "$tmp/append/run.log" | md5sum)
tool "$tmp/append" --append
after=$(grep '^METRICS ' "$tmp/append/run.log" | md5sum)
if [ "$rc" = 0 ] && [ "$(mlines "$tmp/append/run.log")" = 4 ] && [ "$before" = "$after" ] &&
  grep -qF 'appended 0 METRICS line(s)' "$out"; then
  r=0
else
  r=1
fi
report "a second --append appends nothing" "$r"

# 9. No batch folder: bad use, exit 2, no table.
tool
if [ "$rc" = 2 ] && ! grep -q '^JOB ' "$out"; then
  r=0
else
  r=1
fi
report "no argument is bad use, exit 2" "$r"

# 10. A folder with no flash-*.log: exit 2 and the folder is named.
mkdir -p "$tmp/nologs"
tool "$tmp/nologs"
if [ "$rc" = 2 ] && grep -qF 'no flash-*.log in' "$out"; then
  r=0
else
  r=1
fi
report "a folder with no flash-*.log is bad use, exit 2" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
