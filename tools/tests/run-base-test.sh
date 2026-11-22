#!/usr/bin/env bash
# Tests the runner's base check (tools/run-base.sh): a base that does not format or analyze stops
# the run before any job of that wave with `the base does not compile: <its first failing line>`,
# which STOP.md quotes; a base that passes lets the wave start; a base check that runs past
# RUN_BASE_CHECK_MAX_MIN stops the run with that limit named; RUN_BASE_CHECK_SKIP=1 skips the check
# and says so in run.log.
#
#   bash tools/tests/run-base-test.sh
#
# Every case builds a throwaway git repo in a temp folder: the runner's seven files are copies
# (tools/run-base.sh and tools/run-limits.sh included), tools/check.sh, review.sh, commit-job.sh
# and run-stop.sh are stubs, RUN_BASE_CHECK_CMD is a stub check (fail, pass or sleep) and FLASH_CMD
# points at a stub worker that writes the brief's report, so no worker, test suite or real check
# runs. RUN_LIMIT_UNIT_S=1 makes one "minute" of every limit one second and RUN_POLL_S=1 makes the
# runner look every second, so each case ends in a few seconds. Prints PASS <case> / FAIL <case>
# and exits 1 if any case failed.
set -u
# The caller's limit and poll settings must not reach the runner: each case sets its own below.
unset RUN_CHECK_MAX_MIN RUN_REVIEW_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_JOB_FACTOR_PCT \
  RUN_EXPECT_DEFAULT_MIN RUN_TURN_CAP RUN_BASE_CHECK_MAX_MIN BRIEF_CHECK_SKIP RUN_BASE_CHECK_SKIP
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-base-test-XXXXXX")" || exit 2
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
chmod +x "$tmp/bin/flutter" "$tmp/bin/dart"
# The stub worker FLASH_CMD names: it marks the call and writes the report the brief asks for.
cat > "$tmp/flash-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then echo "preflight ok (stub)"; exit 0; fi
rep=$(sed -n 's/^report: *//p' "${2:-}")
mkdir -p "$(dirname "$rep")" && printf '## Summary\n\nstub report\n' > "$rep"
EOF
chmod +x "$tmp/flash-stub.sh"
FLASH_CMD="$tmp/flash-stub.sh"
export FLASH_CMD
# The stub checks RUN_BASE_CHECK_CMD names: every one marks its call; the fail stub prints two
# error lines, so the case can tell which one the stop quotes.
cat > "$tmp/base-fail.sh" <<'EOF'
#!/usr/bin/env bash
echo ran >> "$BASE_MARK"
echo 'error: fake analyze error'
echo 'error: a second line that must not be quoted'
exit 1
EOF
cat > "$tmp/base-pass.sh" <<'EOF'
#!/usr/bin/env bash
echo ran >> "$BASE_MARK"
echo 'All checks passed (stub)'
EOF
cat > "$tmp/base-sleep.sh" <<'EOF'
#!/usr/bin/env bash
echo ran >> "$BASE_MARK"
sleep "${BASE_SLEEP_S:-3}"
echo 'All checks passed (stub)'
EOF
chmod +x "$tmp"/base-*.sh

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

fixture() { # fixture <case>: a fresh repo, batch and work folder, default knobs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool" "$work"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" \
    "$loc/tools/churn.sh" "$loc/tools/run-limits.sh" "$loc/tools/run-base.sh" "$loc/tools/run-wave.sh" \
    "$repo/tools/"
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
  STUB_MARK="$base/flash-ran" BASE_MARK="$base/base-ran" PREFLIGHT_SKIP=1 RUN_MAX_MIN=
  RUN_BASE_CHECK_CMD="$tmp/base-pass.sh" RUN_BASE_CHECK_SKIP="" RUN_BASE_CHECK_MAX_MIN=5
  BASE_SLEEP_S=1 FLASH_USAGE_LOG="$tmp/no-usage.tsv"
  RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1 NO_PUSH=1
  export STUB_MARK BASE_MARK PREFLIGHT_SKIP RUN_MAX_MIN RUN_BASE_CHECK_CMD RUN_BASE_CHECK_SKIP
  export RUN_BASE_CHECK_MAX_MIN BASE_SLEEP_S FLASH_USAGE_LOG RUN_LIMIT_UNIT_S RUN_POLL_S NO_PUSH
}

run_jobs() { # run_jobs [args]: the runner from the repo root; sets rc
  rc=0
  ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" \
    timeout -k 5 30 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
last_line() { tail -n 1 "$out"; }
stop_cause() { printf 'the base %s (log %s/run-base-check.log); no job of wave 1 was started' "$1" "$work"; }

# 1. The base does not analyze: the run stops before the job starts, the stop names the log's first
#    failing line (never the second), the RESULT line says the base does not compile, STOP.md quotes
#    it, and the worker never ran and no job log was written.
fixture fail
RUN_BASE_CHECK_CMD="$tmp/base-fail.sh"
export RUN_BASE_CHECK_CMD
run_jobs --no-review
cause=$(stop_cause 'does not compile: error: fake analyze error')
if [ "$rc" = 1 ] && logged "STOPPED: $cause" && [ "$(last_line)" = "RESULT: STOPPED: $cause" ] &&
  grep -qF "error: fake analyze error" "$repo/$batch/STOP.md" 2>/dev/null &&
  ! grep -qF "second line" "$repo/$batch/STOP.md" 2>/dev/null &&
  [ -f "$work/run-base-check.log" ] && [ -f "$BASE_MARK" ] && [ ! -f "$STUB_MARK" ] &&
  [ ! -f "$repo/$batch/flash-runjob.log" ] && ! logged "start runjob"; then r=0; else r=1; fi
report "a base with an analyze error stops before the job with its first failing line (no job started)" "$r"

# 2. A base that passes lets the wave start: the base check ran once and the job ran to DONE.
fixture pass
run_jobs --no-review
if [ "$rc" = 0 ] && [ -f "$BASE_MARK" ] && grep -qxF 'All checks passed (stub)' "$work/run-base-check.log" 2>/dev/null &&
  logged "start runjob" && logged "committed runjob" &&
  [ "$(last_line)" = "RESULT: DONE: 1 jobs, 0 min" ] && ! logged "STOPPED"; then r=0; else r=1; fi
report "a base that passes lets the wave start and the job finish with RESULT: DONE (exit 0)" "$r"

# 3. RUN_BASE_CHECK_SKIP=1 runs no base check at all (the failing stub is never called) and says so.
fixture skip
RUN_BASE_CHECK_CMD="$tmp/base-fail.sh" RUN_BASE_CHECK_SKIP=1
export RUN_BASE_CHECK_CMD RUN_BASE_CHECK_SKIP
run_jobs --no-review
if [ "$rc" = 0 ] && logged "base check skipped (RUN_BASE_CHECK_SKIP)" && [ ! -f "$BASE_MARK" ] &&
  logged "committed runjob" && [ "$(last_line)" = "RESULT: DONE: 1 jobs, 0 min" ]; then r=0; else r=1; fi
report "RUN_BASE_CHECK_SKIP=1 skips the base check, notes it in run.log and the wave runs" "$r"

# 4. The base check runs past its limit: 2 "minutes" of 1 s, so the run stops at 2-3 s with the
#    limit named, though the stub check would sleep 10 s.
fixture limit
RUN_BASE_CHECK_CMD="$tmp/base-sleep.sh" RUN_BASE_CHECK_MAX_MIN=2 BASE_SLEEP_S=10
export RUN_BASE_CHECK_CMD RUN_BASE_CHECK_MAX_MIN BASE_SLEEP_S
start_s=$SECONDS
run_jobs --no-review
elapsed_s=$((SECONDS - start_s))
cause=$(stop_cause 'check passed its limit (RUN_BASE_CHECK_MAX_MIN=2 min)')
if [ "$rc" = 1 ] && [ "$(last_line)" = "RESULT: STOPPED: $cause" ] &&
  grep -qF "RUN_BASE_CHECK_MAX_MIN=2 min" "$repo/$batch/STOP.md" 2>/dev/null &&
  [ ! -f "$STUB_MARK" ] && [ "$elapsed_s" -lt 20 ]; then r=0; else r=1; fi
report "a base check over RUN_BASE_CHECK_MAX_MIN (2 s) stops the run with the limit named (${elapsed_s}s)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
