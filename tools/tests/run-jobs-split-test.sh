#!/usr/bin/env bash
# Tests that the split of tools/run-jobs.sh (its step and review helpers now in
# tools/run-steps.sh and tools/run-review.sh) changed no behaviour: in a temp git
# repo copy of the tools, --dry-run on a fixture batch (a done job, a dropped job,
# a job to run, a missing brief and a bad report: line) prints the text the old
# file printed; --help, an unknown option, a missing waves.txt and a batch path
# with spaces behave as before; every moved function is defined once; the sizes
# hold; no job starts.
#
#   bash tools/tests/run-jobs-split-test.sh
#
# tools/flash.sh is a stub that would leave a marker, so a dry run that started a
# job would show it. Prints PASS <case> / FAIL <case> and exits 1 on any FAIL.
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-jobs-split-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the runner printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
# The temp repo's path holds a space; the tools are the three files of the split.
repo="$tmp/repo one"
batch="$repo/docs/briefs/fix"
spaced="$repo/docs/briefs/fix batch"
work="$tmp/work one"
mkdir -p "$repo/tools" "$batch" "$spaced" "$work"
cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" "$repo/tools/"
cat > "$repo/tools/flash.sh" <<EOF
#!/usr/bin/env bash
echo flash >> "$tmp/flash-ran"
EOF
printf 'report: docs/briefs/fix/donejob-report.md\n' > "$batch/donejob.md"
printf 'report: docs/briefs/fix/dropjob-report.md\n' > "$batch/dropjob.md"
printf 'report: docs/briefs/fix/runjob-report.md\n' > "$batch/runjob.md"
printf 'report: docs/briefs/fix/bad.md extra\n' > "$batch/badjob.md"
printf '# one wave of five jobs\n\ndonejob dropjob runjob missingjob badjob\n' > "$batch/waves.txt"
printf 'report: docs/briefs/fix batch/runjob-report.md\n' > "$spaced/runjob.md"
printf 'runjob\n' > "$spaced/waves.txt"
printf 'report: docs/briefs/fix/donejob-report.md\n' > "$batch/donejob-report.md"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name t
git -C "$repo" add -A
git -C "$repo" commit -q -m base || exit 2
printf 'donejob %s\n' "$(git -C "$repo" rev-parse HEAD)" > "$batch/done.txt"
printf 'dropjob\n' > "$batch/dropped.txt"

run_jobs() { # run_jobs [args...]: runs the copy from the repo root, storing rc and out
  rc=0
  ( cd "$repo" && RUN_WORK="$work" bash tools/run-jobs.sh "$@" ) > "$out" 2>&1 || rc=$?
}

# The text the old, unsplit tools/run-jobs.sh printed for this batch (the dry-run
# of the split keeps it word for word).
expected="$tmp/expected.txt"
{
  echo "wave 1:"
  echo "  donejob: skip (committed)"
  echo "  dropjob: skip (dropped)"
  echo "  runjob: run"
  echo "  missingjob: MISSING $batch/missingjob.md"
  echo "  badjob: run"
  echo "LINT FAIL badjob: report: line must be exactly one bare path (got: docs/briefs/fix/bad.md extra)"
  echo "then: the run's review -> $batch/REVIEW.md"
} > "$expected"

run_jobs "$batch" --dry-run
if [ "$rc" = 0 ] && diff -u "$expected" "$out" > "$tmp/diff.txt"; then r=0; else r=1; fi
cases=$((cases + 1))
if [ "$r" = 0 ]; then pass "the dry run prints exactly what the old runner printed (done, dropped, run, missing brief, bad report line) (exit 0)"
else fail "the dry run prints exactly what the old runner printed (done, dropped, run, missing brief, bad report line) (exit 0)"; sed 's/^/    | /' "$tmp/diff.txt"; fi

run_jobs --help
if [ "$rc" = 0 ] && grep -q 'tools/run-jobs.sh <briefs-dir>' "$out" &&
  [ "$(tail -n 1 "$out")" = "Exit code: 0 done, 1 stopped, 2 bad use." ]; then r=0; else r=1; fi
report "--help prints the whole header, usage line to exit codes (exit 0)" "$r"

run_jobs --bogus
if [ "$rc" = 2 ] && grep -qx 'Unknown option: --bogus (try --help)' "$out"; then r=0; else r=1; fi
report "an unknown option exits 2 with its message" "$r"

mkdir -p "$tmp/no-waves"
run_jobs "$tmp/no-waves" --dry-run
if [ "$rc" = 2 ] && grep -q 'it needs <briefs-dir>/waves.txt' "$out"; then r=0; else r=1; fi
report "a batch folder without waves.txt exits 2 with the usage line" "$r"

run_jobs "$spaced" --dry-run
if [ "$rc" = 0 ] && grep -qx '  runjob: run' "$out" &&
  grep -qxF "then: the run's review -> $spaced/REVIEW.md" "$out"; then r=0; else r=1; fi
report "a batch folder path with spaces works (dry run)" "$r"

if [ -e "$tmp/flash-ran" ]; then r=1; else r=0; fi
report "no job started: the flash stub left no marker" "$r"

# One version of every moved function: a definition of each name in exactly one file.
dups=()
for f in apply_safe outside_files tests_first checks dart_fix ci_patch review_brief wave_review \
  review_salvage start_reviews flush_reviews slot_wait; do
  n=$(cat "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" | grep -cE "^$f\(\) \{")
  [ "$n" = 1 ] || dups+=("$f=$n")
done
echo "not defined once: ${dups[*]:-none}" > "$out"
if [ ${#dups[@]} = 0 ]; then r=0; else r=1; fi
report "every moved function is defined exactly once across the three files" "$r"

# The sizes the split promises: the runner at or under 330 lines, each helper under 250.
runner_lines=$(wc -l < "$loc/tools/run-jobs.sh")
steps_lines=$(wc -l < "$loc/tools/run-steps.sh")
review_lines=$(wc -l < "$loc/tools/run-review.sh")
echo "runner=$runner_lines steps=$steps_lines review=$review_lines" > "$out"
if [ "$runner_lines" -le 330 ] && [ "$steps_lines" -lt 250 ] && [ "$review_lines" -lt 250 ]; then r=0; else r=1; fi
report "the sizes hold (runner $runner_lines <= 330, steps $steps_lines and review $review_lines < 250)" "$r"

rc=0
{ bash -n "$loc/tools/run-jobs.sh" && bash -n "$loc/tools/run-steps.sh" && bash -n "$loc/tools/run-review.sh"; } > "$out" 2>&1 || rc=$?
if [ "$rc" = 0 ]; then r=0; else r=1; fi
report "bash -n accepts the runner and both sourced files" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
