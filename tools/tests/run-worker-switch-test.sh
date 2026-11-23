#!/usr/bin/env bash
# Tests the runner's WORKER switch (tools/run-jobs.sh, the p5c brief): WORKER unset runs
# tools/flash.sh and logs `worker: flash`; WORKER=claude with no FLASH_CMD logs `worker: claude`
# and calls tools/claude-worker.sh, the preflight included; an explicit FLASH_CMD still wins over
# WORKER=claude; any other WORKER ends the run before it starts, with exit 2 and its message; and
# a finished run has the METRICS lines tools/job-metrics.sh appends, with no error when that
# script is not in the folder.
#
#   bash tools/tests/run-worker-switch-test.sh
#
# Every case builds a throwaway git repo in a temp folder: the five runner files are copies, and
# flash.sh, claude-worker.sh, my-worker.sh, check.sh, review.sh, commit-job.sh, run-stop.sh and
# (in the METRICS case) job-metrics.sh are stubs, so no worker, test suite or check runs. Each
# worker stub records `basename $0 $*` in $STUB_MARK, so a case can say which command ran and
# with which argument. RUN_POLL_S=1 keeps a run to a few seconds: the wave wait polls that often.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
# The caller's knobs must not reach the runner: no case starts on a claude worker or a skipped
# preflight because the shell it was started from did.
unset RUN_CHECK_MAX_MIN RUN_REVIEW_MAX_MIN RUN_LIMIT_UNIT_S RUN_JOB_FACTOR_PCT \
  RUN_EXPECT_DEFAULT_MIN RUN_TURN_CAP RUN_BASE_CHECK_MAX_MIN BRIEF_CHECK_SKIP RUN_MAX_MIN \
  PREFLIGHT_SKIP WORKER FLASH_CMD
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-worker-switch-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/flutter"
cp "$tmp/bin/flutter" "$tmp/bin/dart"
chmod +x "$tmp/bin/flutter" "$tmp/bin/dart"
RUN_POLL_S=1
export RUN_POLL_S

fails=0
cases=0
dbg="$loc/.dart_tool/worker-switch-debug.log" # DEBUG (removed before the report)
: > "$dbg"
pass() { echo "PASS $1"; echo "PASS $1" >> "$dbg"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); echo "FAIL $1" >> "$dbg"; }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the runner printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
repo=""
work=""
batch="docs/briefs/fix" # relative: the runner's paths must be repo paths for git

worker_stub() { # worker_stub <tool>: a stand-in worker that records the call and writes the report
  cat > "$repo/tools/$1" <<'EOF'
#!/usr/bin/env bash
# A stand-in worker: records which command ran and how it was called, then writes the job's report.
echo "$(basename "$0") $*" >> "$STUB_MARK"
[ "${1:-}" = --preflight ] && { echo "preflight ok (stub)"; exit 0; }
mkdir -p "$(dirname "$STUB_REPORT")"
printf '## Summary\n\nstub report\n' > "$STUB_REPORT"
exit 0
EOF
}

fixture() { # fixture <case> [metrics]: a fresh repo, batch and work folder, and the stubs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool" "$work"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" "$loc/tools/churn.sh" \
    "$loc/tools/run-wave.sh" "$repo/tools/"
  worker_stub flash.sh
  worker_stub claude-worker.sh
  worker_stub my-worker.sh
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
  if [ "${2:-}" = metrics ]; then
    cat > "$repo/tools/job-metrics.sh" <<'EOF'
#!/usr/bin/env bash
# A stand-in tools/job-metrics.sh: one METRICS line for the run's job, or the --append is missing.
[ "${2:-}" = --append ] || { echo "job-metrics: needs --append" >&2; exit 2; }
echo "METRICS runjob worker=stub model=stub turns=1 in=0 out=0 cache=0 min=0.0 result=0" >> "$1/run.log"
echo "appended 1 METRICS line(s) to $1/run.log"
EOF
  fi
  chmod +x "$repo"/tools/*.sh
  printf 'base\n' > "$repo/src/app.dart"
  printf '{}\n' > "$repo/.dart_tool/package_config.json"
  printf 'allow: src/app.dart · %s/runjob-report.md\n' "$batch" > "$repo/$batch/runjob.md"
  printf 'report: %s/runjob-report.md\n' "$batch" >> "$repo/$batch/runjob.md"
  printf 'runjob\n' > "$repo/$batch/waves.txt"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name t
  git -C "$repo" add -A
  git -C "$repo" commit -q -m base || exit 2
  STUB_MARK="$base/flash-ran" STUB_REPORT="$batch/runjob-report.md" FLASH_USAGE_LOG="$base/none.tsv"
  export STUB_MARK STUB_REPORT FLASH_USAGE_LOG
}

run_jobs() { # run_jobs [args]: the runner from the repo root, stubs first on PATH; sets rc and out
  # 40 s is a whole case's run (a run here takes seconds): a hung runner fails its case, not this script.
  local t0=$SECONDS
  echo "start ${repo#"$tmp"/} $*" >> "$dbg"
  rc=0
  ( cd "$repo" && PATH="$tmp/bin:$PATH" NO_PUSH=1 RUN_WORK="$work" \
    timeout -k 5 40 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
  echo "end ${repo#"$tmp"/} rc=$rc ${SECONDS}s ($((SECONDS - t0))s)" >> "$dbg"
  sed 's/^/  out| /' "$out" >> "$dbg" # DEBUG
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
ran() { grep -qx "$1" "$STUB_MARK" 2>/dev/null; } # ran <tool line>: a worker stub recorded it

# 1. WORKER unset: the flash worker, unchanged, and the line job-metrics.sh reads.
fixture unset
unset WORKER FLASH_CMD
run_jobs --no-review
if [ "$rc" = 0 ] && logged "worker: flash" && ran "flash.sh --preflight" &&
  ran "flash.sh --brief $batch/runjob.md"; then r=0; else r=1; fi
report "WORKER unset runs tools/flash.sh and logs worker: flash (exit 0)" "$r"

# 2. WORKER=claude with no FLASH_CMD: the preflight and the job call tools/claude-worker.sh.
fixture claude
export WORKER=claude
unset FLASH_CMD
run_jobs --no-review
if [ "$rc" = 0 ] && logged "worker: claude" && ran "claude-worker.sh --preflight" &&
  ran "claude-worker.sh --brief $batch/runjob.md" && ! ran "flash.sh --preflight"; then r=0; else r=1; fi
report "WORKER=claude without FLASH_CMD logs worker: claude and calls tools/claude-worker.sh (exit 0)" "$r"

# 3. WORKER=claude with an explicit FLASH_CMD: that command wins over tools/claude-worker.sh.
fixture explicit
export WORKER=claude FLASH_CMD=tools/my-worker.sh
run_jobs --no-review
if [ "$rc" = 0 ] && logged "worker: claude" && ran "my-worker.sh --preflight" &&
  ran "my-worker.sh --brief $batch/runjob.md" && ! ran "claude-worker.sh --preflight"; then r=0; else r=1; fi
report "WORKER=claude with an explicit FLASH_CMD uses that command (exit 0)" "$r"

# 4. Any other WORKER: exit 2 with its message, before the lock, the log or any worker call.
fixture bad
export WORKER=bad
unset FLASH_CMD
run_jobs --no-review
if [ "$rc" = 2 ] && grep -qx 'WORKER must be flash or claude, got bad' "$out" &&
  [ ! -f "$repo/$batch/run.log" ] && [ ! -f "$STUB_MARK" ] && [ ! -f "$work/lock" ]; then r=0; else r=1; fi
report "WORKER=bad exits 2 with 'WORKER must be flash or claude, got bad' and starts nothing" "$r"

# 5. A finished run: tools/job-metrics.sh's METRICS line comes before RESULT: DONE.
fixture metrics metrics
unset WORKER FLASH_CMD
run_jobs --no-review
order=$(awk '/METRICS runjob/ { m = NR } /RESULT: DONE/ { print (m && m < NR) ? "before" : "after"; exit }' \
  "$repo/$batch/run.log" 2>/dev/null)
if [ "$rc" = 0 ] && logged "METRICS runjob worker=stub" && [ "$order" = before ]; then r=0; else r=1; fi
report "a finished run appends the METRICS lines of tools/job-metrics.sh before RESULT: DONE (exit 0)" "$r"

# 6. A folder without tools/job-metrics.sh: the run ends the same way, with no error of its own.
fixture nometrics
unset WORKER FLASH_CMD
run_jobs --no-review
if [ "$rc" = 0 ] && logged "RESULT: DONE" && ! grep -q 'job-metrics' "$out" &&
  ! grep -q 'METRICS' "$repo/$batch/run.log"; then r=0; else r=1; fi
report "a folder without tools/job-metrics.sh finishes with no METRICS line and no error (exit 0)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
