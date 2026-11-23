#!/usr/bin/env bash
# Tests the brief gate (tools/run-gate.sh, sourced by tools/run-jobs.sh through its gate_step
# seam): a dry run on a batch whose two jobs of one wave allow the same file prints
# tools/brief-check.sh's whole output and exits 1; a start stops with
# `brief gate: brief-check failed: <first FAIL line>` before any job starts;
# BRIEF_CHECK_SKIP=<reason> turns that stop into a logged WARN and the jobs are committed; a clean
# batch starts; a repo without run-gate.sh runs the same batch as before. A stand-in
# BRIEF_CHECK_CMD shows the dry run's whole output against a start's one line.
# The last case is the environment leak: every limit setting a caller exports must be cleared by
# the wire tests' own unset, or their cases run with the caller's numbers.
#
#   bash tools/tests/run-gate-test.sh
#
# Every case builds a throwaway git repo in a temp folder: the runner's files are copies (with
# tools/brief-check.sh, and tools/run-gate.sh where the case wants it), tools/check.sh, review.sh,
# commit-job.sh and run-stop.sh are stubs, and FLASH_CMD points at a stub worker that writes the
# brief's report and ends with STUB_RC, so no worker, test suite or check runs. Each kind of repo
# is built once and copied per case. A 25 s sleep stub shortens the runner's wait between a wave's
# starts to 0.1 s. The wire tests are minutes long (run-wire-test.sh has a 240 s allowance in
# tools/selftest.sh), so this script never runs them: the tools suite runs each once with a clean
# environment, and the leak case checks the unsets that keep a caller's numbers out of their cases.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
# The caller's limit and poll settings must not reach the runner: each case sets its own below.
unset RUN_CHECK_MAX_MIN RUN_REVIEW_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_JOB_FACTOR_PCT \
  RUN_EXPECT_DEFAULT_MIN RUN_TURN_CAP RUN_BASE_CHECK_MAX_MIN BRIEF_CHECK_SKIP BRIEF_CHECK_CMD
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-gate-test-XXXXXX")" || exit 2
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
batch="docs/briefs/fix" # relative: the runner's paths must be repo paths for git
repo=""
work=""
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/flutter"
cp "$tmp/bin/flutter" "$tmp/bin/dart"
real_sleep=$(command -v sleep)
# The runner's one 25 s wait between the starts of a wave's jobs: 0.1 s keeps the order of the
# starts (the cases only read the lines, not the timing), and every other sleep is the caller's own.
cat > "$tmp/bin/sleep" <<EOF
#!/usr/bin/env bash
case "\${1:-}" in 25) exec "$real_sleep" 0.1 ;; *) exec "$real_sleep" "\$@" ;; esac
EOF
chmod +x "$tmp/bin/flutter" "$tmp/bin/dart" "$tmp/bin/sleep"
# The stub worker FLASH_CMD names: it marks the call, answers the preflight, writes the report its
# brief's report: line names and ends with STUB_RC.
cat > "$tmp/flash-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then echo "preflight ok (stub)"; exit 0; fi
brief=${2:-}
rep=$(sed -n 's/^report: *//p' "$brief")
mkdir -p "$(dirname "$rep")" && printf '## Summary\n\nstub report\n' > "$rep"
exit "${STUB_RC:-0}"
EOF
chmod +x "$tmp/flash-stub.sh"
FLASH_CMD="$tmp/flash-stub.sh"
export FLASH_CMD

stubs() { # stubs: the four tool stubs the case's repo runs instead of the real ones
  cat > "$repo/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
echo "check ok (stub)"
EOF
  cat > "$repo/tools/review.sh" <<'EOF'
#!/usr/bin/env bash
echo "RESULT: ok: nothing to report (stub)"
EOF
  cat > "$repo/tools/commit-job.sh" <<'EOF'
#!/usr/bin/env bash
git add -A && git commit -q -m "job: $(basename "$1" .md)" && echo "Committed: stub"
EOF
  cat > "$repo/tools/run-stop.sh" <<'EOF'
#!/usr/bin/env bash
printf 'STOP (stub)\ncause: %s\n' "${3:-}" > "${1%/}/STOP.md"
echo "RESULT: ok: STOP.md written (stub)"
EOF
  chmod +x "$repo"/tools/*.sh
}

template() { # template <kind> [nogate]: the repo every case of that kind copies, built once: the runner's
  # files, the stubs, one brief `runjob` and the base commit (one git init and commit per kind)
  local kind=$1 nogate=${2:-} dir="$tmp/tpl-$1"
  [ -d "$dir" ] && return 0
  repo=$dir
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" \
    "$loc/tools/churn.sh" "$loc/tools/run-limits.sh" "$loc/tools/run-wave.sh" \
    "$loc/tools/brief-check.sh" "$repo/tools/"
  if [ -z "$nogate" ] && [ -f "$loc/tools/run-gate.sh" ]; then cp "$loc/tools/run-gate.sh" "$repo/tools/"; fi
  stubs
  printf 'base\n' > "$repo/src/app.dart"
  printf '{}\n' > "$repo/.dart_tool/package_config.json"
  printf 'allow: src/app.dart · %s/runjob-report.md\nreport: %s/runjob-report.md\n' \
    "$batch" "$batch" > "$repo/$batch/runjob.md"
  printf 'runjob\n' > "$repo/$batch/waves.txt"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name t
  git -C "$repo" add -A
  git -C "$repo" commit -q -m base || exit 2
}

fixture() { # fixture <case> [nogate]: a copy of the template repo, a work folder, and the case's env
  local base="$tmp/$1" nogate=${2:-} kind=gate
  [ -n "$nogate" ] && kind=nogate
  template "$kind" "$nogate"
  repo="$base/repo" work="$base/work"
  mkdir -p "$base" "$work"
  cp -r "$tmp/tpl-$kind" "$repo"
  unset BRIEF_CHECK_SKIP BRIEF_CHECK_CMD # each case sets the ones it needs
  STUB_MARK="$base/flash-ran" STUB_RC="" PREFLIGHT_SKIP=1 RUN_MAX_MIN=
  FLASH_USAGE_LOG="$tmp/no-usage.tsv" # no real usage log reaches the turn counts
  RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1 NO_PUSH=1
  export STUB_MARK STUB_RC PREFLIGHT_SKIP RUN_MAX_MIN
  export FLASH_USAGE_LOG RUN_LIMIT_UNIT_S RUN_POLL_S NO_PUSH
}

overlap_briefs() { # two jobs of one wave that allow the same file: brief-check's wave FAIL
  printf 'allow: src/app.dart · %s/one-report.md\nreport: %s/one-report.md\n' \
    "$batch" "$batch" > "$repo/$batch/one.md"
  printf 'allow: src/app.dart · %s/two-report.md\nreport: %s/two-report.md\n' \
    "$batch" "$batch" > "$repo/$batch/two.md"
  printf 'one two\n' > "$repo/$batch/waves.txt"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "two briefs that overlap"
}

run_jobs() { # run_jobs [args]: the runner from the repo root, FLASH_CMD's stub worker; sets rc
  rc=0
  ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" \
    timeout -k 5 30 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
last_line() { tail -n 1 "$out"; }
done_has() { grep -q "^$1 " "$repo/$batch/done.txt" 2>/dev/null; } # done_has <job>: done.txt lists it

overlap_fail="FAIL wave two: one and two both allow src/app.dart" # brief-check's own FAIL line

# 1. The dry run asks the gate after its plan: brief-check's whole output (its FAIL line and its
#    RESULT line) is printed, the run exits 1, no job starts and no STOP.md is written.
fixture dryoverlap
overlap_briefs
run_jobs --dry-run
if [ "$rc" = 1 ] && grep -qF '  one: run' "$out" &&
  grep -qF "$overlap_fail" "$out" &&
  grep -qF 'RESULT: FAILED: 1 FAIL, 0 WARN (2 job(s) checked)' "$out" &&
  [ ! -f "$STUB_MARK" ] && [ ! -f "$repo/$batch/STOP.md" ]; then r=0; else r=1; fi
report "a dry run prints brief-check's whole output and exits 1 on two jobs of one wave sharing a file" "$r"

# 2. The start refuses at the gate: one STOPPED line naming brief-check's first FAIL line, the
#    result line the same, STOP.md through the stub, and no job started.
run_jobs --no-review
if [ "$rc" = 1 ] &&
  logged "STOPPED: brief gate: brief-check failed: $overlap_fail" &&
  [ "$(last_line)" = "RESULT: STOPPED: brief gate: brief-check failed: $overlap_fail" ] &&
  grep -qF "cause: brief gate: brief-check failed: $overlap_fail" "$repo/$batch/STOP.md" &&
  ! logged "start one" && [ ! -f "$STUB_MARK" ]; then r=0; else r=1; fi
report "a start stops with \`brief gate: brief-check failed:\` and the first FAIL line, no job started" "$r"

# 3. The same overlapping batch with BRIEF_CHECK_SKIP=rehearsal: the refusal is a logged WARN,
#    the run goes on and both jobs are committed (exit 0).
BRIEF_CHECK_SKIP=rehearsal
export BRIEF_CHECK_SKIP
run_jobs --no-review
if [ "$rc" = 0 ] && logged "WARN brief-check skipped: rehearsal" &&
  logged "committed one" && logged "committed two" && done_has one && done_has two &&
  [ "$(last_line)" = "RESULT: DONE: 2 jobs, 0 min" ]; then r=0; else r=1; fi
report "BRIEF_CHECK_SKIP=<reason> turns the start's refusal into a logged WARN and the jobs are committed" "$r"

# 4. A clean batch: brief-check passes (exit 0), the gate discards its output (nothing about
#    brief-check in run.log) and the run commits the job.
fixture clean
run_jobs --no-review
if [ "$rc" = 0 ] && done_has runjob && ! grep -qF 'brief-check' "$repo/$batch/run.log" &&
  [ "$(last_line)" = "RESULT: DONE: 1 jobs, 0 min" ]; then r=0; else r=1; fi
report "a clean batch starts (exit 0) and the passing check adds nothing to run.log" "$r"

# 5. A repo without tools/run-gate.sh (an older fixture, or a tools folder that predates the
#    gate): the runner skips the gate, so the same overlapping batch runs and commits as before.
fixture nogate nogate
overlap_briefs
run_jobs --no-review
if [ "$rc" = 0 ] && done_has one && done_has two &&
  [ "$(last_line)" = "RESULT: DONE: 2 jobs, 0 min" ]; then r=0; else r=1; fi
report "a repo without run-gate.sh runs the same overlapping batch as before (exit 0)" "$r"

# The stand-in check: it ignores the batch folder and prints two FAIL lines, so the two ways the
# gate reports them can be told apart.
cat > "$tmp/brief-check-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo "FAIL wave 1: runjob: first FAIL line"
echo "FAIL wave 1: runjob: second FAIL line"
echo "RESULT: FAILED: 2 FAIL, 0 WARN (1 job(s) checked)"
exit 1
EOF
chmod +x "$tmp/brief-check-stub.sh"

# 6. With BRIEF_CHECK_CMD standing in for brief-check, the dry run prints every line of its
#    output, not just the first FAIL line.
fixture stubcmd
BRIEF_CHECK_CMD="$tmp/brief-check-stub.sh"
export BRIEF_CHECK_CMD
run_jobs --dry-run
if [ "$rc" = 1 ] && grep -qF 'FAIL wave 1: runjob: first FAIL line' "$out" &&
  grep -qF 'FAIL wave 1: runjob: second FAIL line' "$out" &&
  grep -qF 'RESULT: FAILED: 2 FAIL, 0 WARN (1 job(s) checked)' "$out" && [ ! -f "$STUB_MARK" ]; then r=0; else r=1; fi
report "a dry run prints the check's whole output, not only its first FAIL line (stub BRIEF_CHECK_CMD)" "$r"

# 7. The start's stop carries the first FAIL line only: the later lines stay out of run.log, and
#    the run stops before a job starts.
run_jobs --no-review
if [ "$rc" = 1 ] &&
  logged "STOPPED: brief gate: brief-check failed: FAIL wave 1: runjob: first FAIL line" &&
  ! logged "second FAIL line" && ! logged "start runjob" && [ ! -f "$STUB_MARK" ]; then r=0; else r=1; fi
report "a start's stop carries the check's first FAIL line only (stub BRIEF_CHECK_CMD)" "$r"

# The environment leak: the wire tests unset every limit setting, so a caller's export of one
# cannot reach their cases (a leaked RUN_LIMIT_UNIT_S or RUN_POLL_S changes what each case times).
unset_block() { # unset_block <script>: the lines of its caller-environment unsets, CR dropped
  awk '{ sub(/\r$/, "") } /^unset / { on = 1 } on { print; if ($0 !~ /\\$/) exit }' "$1"
}

clears_env() { # clears_env <script> <var>: 0 when the script's own unset drops the caller's export
  local block
  block=$(unset_block "$1")
  [ -n "$block" ] || return 1
  ( export "$2=leaked"
    eval "$block"
    ! declare -p "$2" > /dev/null 2>&1 )
}

leak_case() { # leak_case: every setting must be cleared by both wire tests; prints the leaks
  local v s leaked=""
  for v in RUN_CHECK_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_TURN_CAP BRIEF_CHECK_SKIP; do
    for s in run-wire-test.sh run-limits-wire-test.sh; do
      clears_env "$loc/tools/tests/$s" "$v" || leaked="$leaked $s:$v"
    done
  done
  [ -z "$leaked" ] || echo "not cleared:$leaked"
  [ -z "$leaked" ]
}

# 8. Each caller export is gone after the wire test's own unset, in both wire tests.
if leak_case > "$out" 2>&1; then r=0; else r=1; fi
report "the wire tests' own unset clears each limit setting a caller exports (5 settings, both tests)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
