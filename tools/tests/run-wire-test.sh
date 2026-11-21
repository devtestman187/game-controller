#!/usr/bin/env bash
# Tests the runner's wiring (tools/run-jobs.sh) as the p2-wire brief asks: every stop
# (a failed check, the STOP file, the brief lint) writes <batch>/STOP.md through
# tools/run-stop.sh and commits it, the next start removes it and commits the removal;
# a failing tools/run-stop.sh never changes the runner's exit; a result-4 job whose only
# outside files are generated churn is applied, never a stop; one runner per batch (a
# second is refused, a stale lock is replaced); RUN_MAX_MIN=0 runs out with STOPPED:
# TIMEOUT; and the dry run prints its plan, takes no lock and leaves no STOP.md.
#
#   bash tools/tests/run-wire-test.sh
#
# Every case builds a throwaway git repo in a temp folder: the four runner files are
# copies, and tools/flash.sh, check.sh, review.sh, commit-job.sh and run-stop.sh are stubs
# driven by FLASH_MODE and the STUB_* variables, so no worker, test suite or check runs.
# The briefs folder sits inside the repo, because the runner asks git about its paths.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-wire-test-XXXXXX")" || exit 2
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
repo=""
batch="docs/briefs/fix" # relative: the runner's paths must be repo paths for git
work=""
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/flutter"
cp "$tmp/bin/flutter" "$tmp/bin/dart"
chmod +x "$tmp/bin/flutter" "$tmp/bin/dart"

FLASH_MODE=plain STUB_CHECK_FAIL=0 STUB_STOP_FAIL=0 PREFLIGHT_SKIP=1 RUN_MAX_MIN=360
export FLASH_MODE STUB_CHECK_FAIL STUB_STOP_FAIL PREFLIGHT_SKIP RUN_MAX_MIN

# The five stubs. They lean on the STUB_* variables fixture exports.
stubs() {
  cat > "$repo/tools/flash.sh" <<'EOF'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then
  [ "${FLASH_MODE:-}" = preflight ] && touch "$STUB_BATCH/STOP"
  echo "preflight ok (stub)"
  exit 0
fi
write_report() { mkdir -p "$(dirname "$1")"; printf '## Summary\n\nstub report\n' > "$1"; }
case "${FLASH_MODE:-plain}" in
  churn) # a kept worktree whose only outside files are generated churn
    git worktree add --detach -q "$STUB_TREE" HEAD || exit 3
    printf 'changed\n' >> "$STUB_TREE/src/app.dart"
    write_report "$STUB_TREE/$STUB_REPORT"
    echo "---- flash: CHANGED FILES OUTSIDE --allow (stub):"
    echo "  site/shots/join.png"
    echo "  $STUB_RESULTS"
    echo "---- flash: the worktree is kept: $STUB_TREE"
    echo "---- flash: result 4"
    exit 4 ;;
  *) write_report "$STUB_REPORT"; exit 0 ;;
esac
EOF
  cat > "$repo/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
if [ "${STUB_CHECK_FAIL:-}" = 1 ]; then
  echo '00:01 +1 -1: test/app_test.dart: works [E]'
  echo '00:01 +1 -1: Some tests failed.'
  exit 1
fi
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
printf '%s\n' "${3:-}" >> "$STUB_STOP_CALLS"
[ "${STUB_STOP_FAIL:-}" = 1 ] && { echo "RESULT: BAD INPUT: stub failure"; exit 3; }
printf 'STOP (stub)\ncause: %s\n' "${3:-}" > "${1%/}/STOP.md"
echo "RESULT: ok: STOP.md written (stub)"
EOF
  chmod +x "$repo"/tools/*.sh
}

fixture() { # fixture <case> [badreport]: a fresh repo, batch and work folder, and the default knobs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"
  FLASH_MODE=plain STUB_CHECK_FAIL=0 STUB_STOP_FAIL=0 PREFLIGHT_SKIP=1 RUN_MAX_MIN=360
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool" "$work"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" "$loc/tools/churn.sh" "$repo/tools/"
  stubs
  printf 'base\n' > "$repo/src/app.dart"
  printf '{}\n' > "$repo/.dart_tool/package_config.json"
  printf 'allow: src/app.dart · %s/runjob-report.md\n' "$batch" > "$repo/$batch/runjob.md"
  if [ "${2:-}" = badreport ]; then
    printf 'report: %s/runjob-report.md extra\n' "$batch" >> "$repo/$batch/runjob.md"
  else
    printf 'report: %s/runjob-report.md\n' "$batch" >> "$repo/$batch/runjob.md"
  fi
  printf 'runjob\n' > "$repo/$batch/waves.txt"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name t
  git -C "$repo" add -A
  git -C "$repo" commit -q -m base || exit 2
  STUB_MARK="$base/flash-ran" STUB_BATCH="$batch" STUB_REPORT="$batch/runjob-report.md"
  STUB_TREE="$base/tree" STUB_RESULTS="$batch/runjob-results.json" STUB_STOP_CALLS="$base/stop-calls"
  export STUB_MARK STUB_BATCH STUB_REPORT STUB_TREE STUB_RESULTS STUB_STOP_CALLS
}

run_jobs() { # run_jobs [args]: the runner from the repo root, stubs first on PATH; sets rc and out
  rc=0
  ( cd "$repo" && PATH="$tmp/bin:$PATH" NO_PUSH=1 RUN_WORK="$work" bash tools/run-jobs.sh "$batch" "$@" ) \
    > "$out" 2>&1 || rc=$?
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
stopmd() { [ -f "$repo/$batch/STOP.md" ] && grep -qF "$1" "$repo/$batch/STOP.md"; } # stopmd <text>
stop_committed() { git -C "$repo" cat-file -e "HEAD:$batch/STOP.md" 2>/dev/null; }

# 1. A failed check: STOP.md, committed, and the run stops after trying the check twice.
fixture checkfail
STUB_CHECK_FAIL=1
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: checks failed twice on the combined tree after runjob" &&
  stopmd "checks failed twice" && stop_committed; then r=0; else r=1; fi
report "a failed check writes STOP.md with the cause and commits it (exit 1)" "$r"

# 2. The STOP file, made by the preflight stub: STOP.md names it and is committed.
fixture stopfile
FLASH_MODE=preflight PREFLIGHT_SKIP=""
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: stop file" && stopmd "stop file" && stop_committed; then r=0; else r=1; fi
report "the STOP file writes STOP.md with its cause and commits it (exit 1)" "$r"

# 3. The brief lint, before wave 1: STOP.md too.
fixture lint badreport
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: brief lint" && stopmd "report: line" && stop_committed; then r=0; else r=1; fi
report "the brief lint writes STOP.md with its cause and commits it (exit 1)" "$r"

# 4. A failing run-stop.sh (at the lint stop): the runner still exits 1, says so and commits its log.
fixture stopfail badreport
STUB_STOP_FAIL=1
run_jobs --no-review
if [ "$rc" = 1 ] && [ ! -f "$repo/$batch/STOP.md" ] && logged "STOPPED: brief lint" &&
  grep -qF "STOP.md was not written" "$repo/$batch/run-findings.md" 2>/dev/null &&
  git -C "$repo" cat-file -e "HEAD:$batch/run.log" 2>/dev/null; then r=0; else r=1; fi
report "a failing run-stop.sh leaves the runner's exit at 1, says so and commits the log" "$r"

# 5. Result 4 with only generated churn outside: applied (the churn dropped), never a stop.
fixture churn
FLASH_MODE=churn
run_jobs --no-review
if [ "$rc" = 0 ] &&
  logged "runjob: dropped generated churn outside its list: site/shots/join.png docs/briefs/fix/runjob-results.json" &&
  logged "committed runjob" && ! logged "STOPPED" && [ ! -f "$repo/$batch/STOP.md" ] &&
  git -C "$repo" grep -q changed HEAD -- src/app.dart &&
  git -C "$repo" cat-file -e "HEAD:$batch/runjob-report.md" 2>/dev/null; then r=0; else r=1; fi
report "result 4 with only generated churn (site/shots, the test's *-results.json) is applied (exit 0)" "$r"

# 6. A live lock: a second runner on the same batch is refused with exit 2.
fixture lockrefused
sleep 30 &
sleeper=$!
printf '%s\n' "$sleeper" > "$work/lock"
run_jobs --no-review
live=$(tail -n 1 "$out")
kill "$sleeper" 2>/dev/null
wait "$sleeper" 2>/dev/null
if [ "$rc" = 2 ] && [ "$live" = "RESULT: refused, a run is active (pid $sleeper)" ] &&
  [ ! -f "$repo/docs/briefs/fix/run.log" ]; then r=0; else r=1; fi
report "a second runner on the same batch exits 2 with the RESULT: refused line" "$r"

# 7. A stale lock (its pid is gone) is replaced, and the run goes on to its own stop.
fixture stalelock
printf '2147483\n' > "$work/lock"
RUN_MAX_MIN=0
run_jobs --no-review
if [ "$rc" = 1 ] && logged "replaced a stale lock (pid 2147483 is gone)" && logged "STOPPED: TIMEOUT" &&
  [ ! -f "$work/lock" ]; then r=0; else r=1; fi
report "a stale lock is replaced and the trap removes the lock on exit (exit 1)" "$r"

# 8. RUN_MAX_MIN=0: the first step past the limit stops with TIMEOUT and writes STOP.md.
fixture timeout
RUN_MAX_MIN=0
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: TIMEOUT" && stopmd "RUN_MAX_MIN=0" && stop_committed; then r=0; else r=1; fi
report "RUN_MAX_MIN=0 stops with TIMEOUT and STOP.md (exit 1)" "$r"

# 9. The next start removes the last stop's committed STOP.md and commits the removal.
fixture removal
printf 'old stop\n' > "$repo/$batch/STOP.md"
git -C "$repo" add -f "$batch/STOP.md"
git -C "$repo" commit -q -m "the last stop's STOP.md"
RUN_MAX_MIN=0 # the run stops at once, so this start leaves a STOP.md of its own
run_jobs --no-review
if [ "$rc" = 1 ] && logged "removed the last stop's STOP.md" && stopmd "RUN_MAX_MIN=0" &&
  git -C "$repo" log --format=%s -- "$batch/STOP.md" | grep -q "removal of the last stop"; then r=0; else r=1; fi
report "the next start removes the last stop's STOP.md and commits the removal (exit 1)" "$r"

# 10. The dry run: the same plan as before, no lock, no STOP.md, no job started.
fixture dryrun
RUN_MAX_MIN=0 # a dry run has no time limit either
expected="$tmp/expected.txt"
{
  echo "wave 1:"
  echo "  runjob: run"
  echo "then: the run's review -> $batch/REVIEW.md"
} > "$expected"
run_jobs --dry-run
if [ "$rc" = 0 ] && diff -u "$expected" "$out" > "$tmp/diff.txt" && [ ! -f "$work/lock" ] &&
  [ ! -f "$repo/$batch/STOP.md" ] && [ ! -f "$STUB_MARK" ]; then r=0; else r=1; fi
report "the dry run prints its plan and takes no lock, writes no STOP.md, starts no job (exit 0)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
