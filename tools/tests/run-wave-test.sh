#!/usr/bin/env bash
# Tests the wave wait of the runner (tools/run-jobs.sh with tools/run-wave.sh): a job that passes
# its own limit is parked alone, its siblings finish and are committed (done.txt), and the run then
# stops naming the parked one, which a restart runs again; a job over its turn cap whose own run
# ended with result 0 and a report is accepted with a WARN and committed, with any other result it
# is parked.
#
#   bash tools/tests/run-wave-test.sh
#
# The fixture git repo is built once in a temp folder and every case copies it: the runner's files are copies
# (tools/run-limits.sh included), tools/check.sh, review.sh, commit-job.sh and run-stop.sh are
# stubs, and FLASH_CMD points at a stub worker that sleeps a brief's `stub-sleep:` seconds (else
# STUB_SLEEP_S), writes the brief's report and ends with STUB_RC, so no worker, test suite or
# check runs. RUN_LIMIT_UNIT_S=1 makes one "minute" of every limit one second and RUN_POLL_S=1
# makes the runner look every second; a sleep stub shortens the runner's 25 s wait between one
# wave's starts to 1 s, so the whole script runs in about 45 s. Prints PASS <case> / FAIL <case>
# and exits 1 if any case failed.
set -u
# The caller's limit and poll settings must not reach the runner: each case sets its own below.
# The runner is started with WORKER=claude MAX_JOBS=n (tools/run-jobs.sh header); the stub worker FLASH_CMD must run as flash, so
# those settings must not reach the nested runner (board3c s0: run-wave/run-wire2 failed in every runner check).
unset RUN_CHECK_MAX_MIN RUN_REVIEW_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_JOB_FACTOR_PCT \
  RUN_EXPECT_DEFAULT_MIN RUN_TURN_CAP RUN_BASE_CHECK_MAX_MIN BRIEF_CHECK_SKIP
unset WORKER MAX_JOBS
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-wave-test-XXXXXX")" || exit 2
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
# The runner's one 25 s wait between the starts of a wave's jobs: 1 s is enough here, and every
# other sleep (RUN_POLL_S=1) is the caller's own.
cat > "$tmp/bin/sleep" <<EOF
#!/usr/bin/env bash
case "\${1:-}" in 25) exec "$real_sleep" 1 ;; *) exec "$real_sleep" "\$@" ;; esac
EOF
chmod +x "$tmp/bin/flutter" "$tmp/bin/dart" "$tmp/bin/sleep"
# The stub worker FLASH_CMD names: it marks the call, answers the preflight, sleeps (a brief's
# `stub-sleep:` seconds, else STUB_SLEEP_S), then writes the report its brief's report: line names
# and ends with STUB_RC.
cat > "$tmp/flash-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then echo "preflight ok (stub)"; exit 0; fi
brief=${2:-}
nap=$(sed -n 's/^stub-sleep: *//p' "$brief" | head -n 1)
[ -n "$nap" ] || nap=${STUB_SLEEP_S:-}
[ -n "$nap" ] && sleep "$nap"
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

template_repo="$tmp/template/repo"
build_template() { # build_template: the fixture repo, built once; fixture copies it for each case
  repo="$template_repo"
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" \
    "$loc/tools/churn.sh" "$loc/tools/run-limits.sh" "$loc/tools/run-wave.sh" "$repo/tools/"
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

fixture() { # fixture <case>: a copy of the template repo with its own batch and work folder, default knobs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"
  mkdir -p "$base" "$work"
  cp -r "$template_repo" "$repo" || exit 2
  STUB_MARK="$base/flash-ran" STUB_SLEEP_S="" STUB_RC="" PREFLIGHT_SKIP=1 RUN_MAX_MIN=
  FLASH_USAGE_LOG="$tmp/no-usage.tsv" # no real usage log reaches the turn counts
  RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1 NO_PUSH=1
  export STUB_MARK STUB_SLEEP_S STUB_RC PREFLIGHT_SKIP RUN_MAX_MIN
  export FLASH_USAGE_LOG RUN_LIMIT_UNIT_S RUN_POLL_S NO_PUSH
}

run_jobs() { # run_jobs [args]: the runner from the repo root, FLASH_CMD's stub worker; sets rc
  rc=0
  ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" \
    timeout -k 5 30 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
last_line() { tail -n 1 "$out"; }
done_has() { grep -q "^$1 " "$repo/$batch/done.txt" 2>/dev/null; } # done_has <job>: done.txt lists it
usage_row() { # usage_row <turns> <minutes>: one flash usage row for the job's brief
  printf 'job\tbrief\t%s\t%s\t0\t0\t0\t0\t0\t%s\n' "$1" "$(( ${2:-1} * 60 ))" "$batch/runjob.md" > "$tmp/usage.tsv"
  FLASH_USAGE_LOG="$tmp/usage.tsv"
  export FLASH_USAGE_LOG
}

build_template

# 1. One wave of three jobs: hang sleeps 30 s past its 1 s limit (expected-min: 1 x1.5), one and
#    two finish at once. hang is parked alone; the other two are checked and committed, then the
#    run stops naming hang (not in done.txt, so a restart runs it again).
fixture parked
printf 'allow: src/app.dart · %s/hang-report.md\nreport: %s/hang-report.md\nexpected-min: 1\nstub-sleep: 30\n' \
  "$batch" "$batch" > "$repo/$batch/hang.md"
printf 'allow: src/app.dart · %s/one-report.md\nreport: %s/one-report.md\n' \
  "$batch" "$batch" > "$repo/$batch/one.md"
printf 'allow: src/app.dart · %s/two-report.md\nreport: %s/two-report.md\n' \
  "$batch" "$batch" > "$repo/$batch/two.md"
printf 'hang one two\n' > "$repo/$batch/waves.txt"
git -C "$repo" add -A && git -C "$repo" commit -q -m "three briefs"
start_s=$SECONDS
run_jobs --no-review
elapsed_s=$((SECONDS - start_s))
if [ "$rc" = 1 ] && logged "job hang passed its limit (1 min, estimate 1) (parked, siblings continue)" &&
  logged "committed one" && logged "committed two" && ! logged "committed hang" &&
  done_has one && done_has two && ! done_has hang &&
  [ "$(last_line)" = "RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): hang (their logs: $batch/flash-<job>.log)" ] &&
  grep -qF "jobs that failed or passed their limit (parked, not committed): hang" "$repo/$batch/STOP.md" 2>/dev/null &&
  [ ! -e "$repo/$batch/hang-report.md" ]; then r=0; else r=1; fi
report "one wave's job past its limit is parked while its two siblings are committed, then the run stops naming it (${elapsed_s}s)" "$r"

# 2. A restart runs the parked job only: the two committed jobs are skipped and hang (its brief
#    edited so the stub no longer sleeps and its estimate is a whole run's) runs and is committed.
printf 'allow: src/app.dart · %s/hang-report.md\nreport: %s/hang-report.md\nexpected-min: 20\n' \
  "$batch" "$batch" > "$repo/$batch/hang.md"
git -C "$repo" add -A && git -C "$repo" commit -q -m "hang no longer sleeps"
run_jobs --no-review
if [ "$rc" = 0 ] && logged "skip one (already done)" && logged "skip two (already done)" &&
  logged "committed hang" && done_has hang && [ "$(last_line)" = "RESULT: DONE: 3 jobs, 0 min" ]; then r=0; else r=1; fi
report "a restart runs the parked job only and skips the two committed ones (exit 0)" "$r"

# 3. Over the 120-turn cap with its own run at result 0 and a report: accepted with the WARN and
#    committed (the job's own checks passed).
fixture capwarn
usage_row 130 20
run_jobs --no-review
if [ "$rc" = 0 ] &&
  logged "WARN: job runjob used 130 turns, over its cap of 120 (its own checks passed; accepted)" &&
  logged "committed runjob" && ! logged "STOPPED" &&
  [ "$(last_line)" = "RESULT: DONE: 1 jobs, 0 min" ]; then r=0; else r=1; fi
report "a job over its 120-turn cap with result 0 and a report is accepted with the WARN and committed (exit 0)" "$r"

# 4. Over the 120-turn cap with result 5 (a failed check; result 1, the turn cap itself, is applied: tune4 T3, run-stops case 8): parked, never committed, and the run stops naming it.
fixture capfail
usage_row 130 20
STUB_RC=5
run_jobs --no-review
if [ "$rc" = 1 ] &&
  logged "job runjob used 130 turns, over its cap of 120 (parked, siblings continue)" &&
  ! logged "committed runjob" &&
  [ "$(last_line)" = "RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): runjob (their logs: $batch/flash-<job>.log)" ]; then r=0; else r=1; fi
report "a job over its 120-turn cap with result 5 is parked, not accepted (exit 1)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
