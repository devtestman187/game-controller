#!/usr/bin/env bash
# Tests the three process3 review fixes of the runner and its waiter:
#   1. tools/run-jobs.sh checks every started job's own limit in the same poll (tools/run-wave.sh),
#      so a later job of a wave that passes its limit while an earlier one still runs is parked
#      while that one finishes and is committed (p3e ran 48 min against 30 because its loop only
#      began after p3d finished), and the run then stops naming the parked job;
#   2. tools/run-steps.sh retries a failed check only when the log names a failing suite
#      other than format or analyze (or a PathNotFoundException): a failed format check
#      stops the run at once with one check run, a failed suite's is tried once more;
#   3. tools/wait-run.sh shows the runner's `start the run's review` note as
#      `reviewing: the run's review for <n> min`, never as a job with an OVERRUN.
#
#   bash tools/tests/process3-fix1-test.sh
#
# Cases 1 and 2 build a throwaway git repo in a temp folder: the runner's files are copies
# (tools/run-limits.sh included), tools/check.sh, review.sh, commit-job.sh and run-stop.sh are
# stubs, and FLASH_CMD points at a stub worker that sleeps and writes the brief's report, so no
# worker, test suite or real check runs. RUN_LIMIT_UNIT_S=1 makes one limit "minute" one second
# and RUN_POLL_S=1 makes the runner look every second. The runner waits 25 s between the starts
# of one wave's jobs, so a sleep stub in the case's PATH shortens that one wait to 0.1 s. The repo
# is built once and copied per case. Case 4 builds a fake run.log (no repo).
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
# The caller's limit and poll settings must not reach the runner: each case sets its own below.
unset RUN_CHECK_MAX_MIN RUN_REVIEW_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_JOB_FACTOR_PCT \
  RUN_EXPECT_DEFAULT_MIN RUN_TURN_CAP RUN_BASE_CHECK_MAX_MIN BRIEF_CHECK_SKIP
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/process3-fix1-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: a failure names the exit code and the last line
  # printed (tools/selftest.sh shows only FAIL lines); the whole output follows for a direct run.
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1 (rc=$rc, last: $(last_line))"; sed 's/^/    | /' "$out"; fi
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
# starts, and all other sleeps (RUN_POLL_S=1) are the caller's own.
cat > "$tmp/bin/sleep" <<EOF
#!/usr/bin/env bash
case "\${1:-}" in 25) exec "$real_sleep" 0.1 ;; *) exec "$real_sleep" "\$@" ;; esac
EOF
chmod +x "$tmp/bin/flutter" "$tmp/bin/dart" "$tmp/bin/sleep"
# The stub worker FLASH_CMD names: it marks the call, answers the preflight, sleeps (a brief's
# `stub-sleep:` seconds, else STUB_SLEEP_S), then writes the report its brief's report: line names.
cat > "$tmp/flash-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo "flash ${1:-}" >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then echo "preflight ok (stub)"; exit 0; fi
brief=${2:-}
nap=$(sed -n 's/^stub-sleep: *//p' "$brief" | head -n 1)
[ -n "$nap" ] || nap=${STUB_SLEEP_S:-}
[ -n "$nap" ] && sleep "$nap"
rep=$(sed -n 's/^report: *//p' "$brief")
mkdir -p "$(dirname "$rep")" && printf '## Summary\n\nstub report\n' > "$rep"
EOF
chmod +x "$tmp/flash-stub.sh"
FLASH_CMD="$tmp/flash-stub.sh"
export FLASH_CMD

stubs() { # stubs: the four tool stubs the case's repo runs instead of the real ones
  # The check stub prints the lines tools/check.sh prints and counts its own runs, so a case
  # can tell one check run from a retry.
  cat > "$repo/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
echo check >> "$STUB_CHECK_CALLS"
case "${STUB_CHECK_MODE:-ok}" in
  format) printf 'FAIL  format      (exit 1, 0s)  log: /tmp/format.log\n\n1 failed: format (0s). Logs: /tmp\n'; exit 1 ;;
  suite) printf 'FAIL  tools       (2 tests, exit 1, 0s)  log: /tmp/tools.log\n\n1 failed: tools (0s). Logs: /tmp\n'; exit 1 ;;
esac
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

template() { # template: the repo every case copies, built once: the runner's files, the stubs, one brief
  # `runjob` and the base commit (one git init and commit for the whole script)
  [ -d "$tmp/tpl" ] && return 0
  repo="$tmp/tpl"
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" \
    "$loc/tools/churn.sh" "$loc/tools/run-limits.sh" "$loc/tools/run-wave.sh" "$repo/tools/"
  stubs
  printf 'base\n' > "$repo/src/app.dart"
  printf '{}\n' > "$repo/.dart_tool/package_config.json"
  printf 'allow: src/app.dart · %s/runjob-report.md\nreport: %s/runjob-report.md\nexpected-min: 10\n' \
    "$batch" "$batch" > "$repo/$batch/runjob.md"
  printf 'runjob\n' > "$repo/$batch/waves.txt"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name t
  git -C "$repo" add -A
  git -C "$repo" commit -q -m base || exit 2
}

fixture() { # fixture <case>: a copy of the template repo, a work folder, and the case's default knobs
  local base="$tmp/$1"
  template
  repo="$base/repo" work="$base/work"
  mkdir -p "$base" "$work"
  cp -r "$tmp/tpl" "$repo"
  STUB_MARK="$base/flash-ran" STUB_SLEEP_S="" PREFLIGHT_SKIP=1 RUN_MAX_MIN=
  STUB_CHECK_MODE=ok STUB_CHECK_CALLS="$base/check-calls"
  FLASH_USAGE_LOG="$tmp/no-usage.tsv" # no real usage log reaches the turn counts
  RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1 NO_PUSH=1
  export STUB_MARK STUB_SLEEP_S PREFLIGHT_SKIP RUN_MAX_MIN
  export STUB_CHECK_MODE STUB_CHECK_CALLS FLASH_USAGE_LOG RUN_LIMIT_UNIT_S RUN_POLL_S NO_PUSH
}

run_jobs() { # run_jobs [args]: the runner from the repo root with the stubs; sets rc
  rc=0
  ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" \
    timeout -k 5 25 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
last_line() { tail -n 1 "$out"; }
check_runs() { # check_runs: how many times the case's check stub ran
  if [ -f "$STUB_CHECK_CALLS" ]; then wc -l < "$STUB_CHECK_CALLS" | tr -d ' '; else echo 0; fi
}

# 1. Two jobs of one wave: `slow` may run 150 s and `quick` 1 min x1.5 = 1 s (both 1 s
#    "minutes"). slow starts first and sleeps 4 s, quick starts next and sleeps 3 s: quick
#    passes its limit and is parked while slow still runs, so the old order (wait slow out, then
#    test quick, already gone) never saw it; slow then finishes and is committed, and the run
#    stops naming quick.
fixture wave-limit
printf 'allow: src/app.dart · %s/slow-report.md\nreport: %s/slow-report.md\nexpected-min: 100\nstub-sleep: 4\n' \
  "$batch" "$batch" > "$repo/$batch/slow.md"
printf 'allow: src/app.dart · %s/quick-report.md\nreport: %s/quick-report.md\nexpected-min: 1\nstub-sleep: 3\n' \
  "$batch" "$batch" > "$repo/$batch/quick.md"
printf 'slow quick\n' > "$repo/$batch/waves.txt"
git -C "$repo" add -A && git -C "$repo" commit -q -m "two briefs"
start_s=$SECONDS
run_jobs --no-review
elapsed_s=$((SECONDS - start_s))
if [ "$rc" = 1 ] && logged "job quick passed its limit (1 min, estimate 1) (parked, siblings continue)" &&
  logged "committed slow" && ! logged "quick finished" && ! logged "committed quick" &&
  [ "$(last_line)" = "RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): quick (their logs: $batch/flash-<job>.log)" ] &&
  [ "$elapsed_s" -lt 25 ]; then r=0; else r=1; fi
report "a wave's second job over its own limit is parked while the first finishes and is committed (${elapsed_s}s)" "$r"

# 2. A failed format check: no retry and no package fetch, one check run, the stop names format.
fixture check-format
STUB_CHECK_MODE=format
STUB_SLEEP_S=0
start_s=$SECONDS
run_jobs --no-review
elapsed_s=$((SECONDS - start_s))
if [ "$rc" = 1 ] && [ "$(check_runs)" = 1 ] && ! logged "fetching packages" &&
  [ "$(last_line)" = "RESULT: STOPPED: checks failed on the combined tree after runjob: format cannot be fixed by a retry" ] &&
  grep -qF "cannot be fixed by a retry" "$repo/$batch/STOP.md" 2>/dev/null; then r=0; else r=1; fi
report "a failed format check stops at once with one check run and no package fetch ($(check_runs) run(s), ${elapsed_s}s, exit 1)" "$r"

# 3. A failed suite: one retry (packages fetched), the second failure stops with the old text.
fixture check-suite
STUB_CHECK_MODE=suite
STUB_SLEEP_S=0
start_s=$SECONDS
run_jobs --no-review
elapsed_s=$((SECONDS - start_s))
if [ "$rc" = 1 ] && [ "$(check_runs)" = 2 ] && logged "fetching packages and trying once more" &&
  logged "STOPPED: checks failed twice on the combined tree after runjob"; then r=0; else r=1; fi
report "a failed suite is tried once more ($(check_runs) check runs) and then stops the run (${elapsed_s}s, exit 1)" "$r"

# 4. The runner's `start the run's review` note: the run is reviewing, not running a job, so
#    no OVERRUN (the guess of 15 min is well past 1.5 x at 26).
wait_sh="$loc/tools/wait-run.sh"
d="$tmp/review"
mkdir -p "$d"
ago() { date -d "-$1 minutes" '+%F %T'; }
{
  echo "$(ago 30) start at abc1234 on m16"
  echo "$(ago 30) start a"
  echo "$(ago 28) a finished: result 0 (20 turns, 3 min)"
  echo "$(ago 27) committed a: 1234567 a example job"
  echo "$(ago 26) start the run's review"
} > "$d/run.log"
rc=0
env WAIT_STATE_DIR="$tmp/wait-state" FLASH_USAGE_LOG="$tmp/no-usage.tsv" WAIT_MAX_S=1 WAIT_POLL_S=1 \
  bash "$wait_sh" "$d" > "$out" 2>&1 || rc=$?
if [ "$rc" = 4 ] && [ "$(last_line)" = "RESULT: running: reviewing: the run's review for 26 min" ]; then r=0; else r=1; fi
report "the run's review shows as reviewing for 26 min, not as a job with an OVERRUN (exit 4)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
