#!/usr/bin/env bash
# Tests the per-job wiring of the limits in the runner (tools/run-jobs.sh): a job's own limit
# (its `expected-min:` x1.5) stops the run when it runs out, a job over the 120-turn cap stops it
# after the job and before the checks (a brief's `turns: <n>` line raises the cap for that job),
# the run's limit is the computed backstop when RUN_MAX_MIN is not given (logged once), every run
# ends with a `RESULT: DONE: <n> jobs, <m> min` or `RESULT: STOPPED: <cause>` line (printed and in
# run.log), and FLASH_CMD is the worker of the preflight and of every job start.
#
#   bash tools/tests/run-limits-wire-test.sh
#
# Every case builds a throwaway git repo in a temp folder: the runner's five files are copies
# (tools/run-limits.sh included), tools/check.sh, review.sh, commit-job.sh and run-stop.sh are
# stubs, and FLASH_CMD points at a stub worker that sleeps and writes the brief's report, so no
# worker, test suite or check runs. RUN_LIMIT_UNIT_S=1 makes one "minute" of every limit one
# second and RUN_POLL_S=1 makes the runner look every second, so each case ends in a few
# seconds. Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-limits-wire-test-XXXXXX")" || exit 2
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
# The stub worker FLASH_CMD names: it marks the call, answers the preflight, sleeps, then writes
# the report the brief's own report: line asks for.
cat > "$tmp/flash-stub.sh" <<'EOF'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then echo "preflight ok (stub)"; exit 0; fi
brief=${2:-}
[ -n "${STUB_SLEEP_S:-}" ] && sleep "$STUB_SLEEP_S"
rep=$(sed -n 's/^report: *//p' "$brief")
mkdir -p "$(dirname "$rep")" && printf '## Summary\n\nstub report\n' > "$rep"
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

fixture() { # fixture <case> [extra brief lines]: a fresh repo, batch and work folder, default knobs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool" "$work"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" \
    "$loc/tools/churn.sh" "$loc/tools/run-limits.sh" "$repo/tools/"
  stubs
  printf 'base\n' > "$repo/src/app.dart"
  printf '{}\n' > "$repo/.dart_tool/package_config.json"
  printf 'allow: src/app.dart · %s/runjob-report.md\nreport: %s/runjob-report.md\n%s\n' \
    "$batch" "$batch" "${2:-}" > "$repo/$batch/runjob.md"
  printf 'runjob\n' > "$repo/$batch/waves.txt"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name t
  git -C "$repo" add -A
  git -C "$repo" commit -q -m base || exit 2
  STUB_MARK="$base/flash-ran" STUB_SLEEP_S="" PREFLIGHT_SKIP=1 RUN_MAX_MIN=
  FLASH_USAGE_LOG="$tmp/no-usage.tsv" # no real usage log reaches the turn counts
  RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1 NO_PUSH=1
  export STUB_MARK STUB_SLEEP_S PREFLIGHT_SKIP RUN_MAX_MIN
  export FLASH_USAGE_LOG RUN_LIMIT_UNIT_S RUN_POLL_S NO_PUSH
}

run_jobs() { # run_jobs [args]: the runner from the repo root, FLASH_CMD's stub worker; sets rc
  rc=0
  ( cd "$repo" && PATH="$tmp/bin:$PATH" RUN_WORK="$work" \
    timeout -k 5 30 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
last_line() { tail -n 1 "$out"; }
usage_row() { # usage_row <turns> <minutes>: one flash usage row for the job's brief
  printf 'job\tbrief\t%s\t%s\t0\t0\t0\t0\t0\t%s\n' "$1" "$(( ${2:-1} * 60 ))" "$batch/runjob.md" > "$tmp/usage.tsv"
  FLASH_USAGE_LOG="$tmp/usage.tsv"
  export FLASH_USAGE_LOG
}

# 1. A job past its own limit: 2 min x 1.5 = 3 "minutes" of 1 s, and the runner stops at 3-4 s
#    even though the stub worker sleeps 30 s.
fixture overlimit 'expected-min: 2'
STUB_SLEEP_S=30
start_s=$SECONDS
run_jobs --no-review
elapsed_s=$((SECONDS - start_s))
if [ "$rc" = 1 ] && logged "STOPPED: job runjob passed its limit (3 min, estimate 2)" &&
  [ "$(last_line)" = "RESULT: STOPPED: job runjob passed its limit (3 min, estimate 2)" ] &&
  grep -qF "job runjob passed its limit" "$repo/$batch/STOP.md" 2>/dev/null &&
  [ "$elapsed_s" -lt 20 ]; then r=0; else r=1; fi
report "a job over its limit (2 min x1.5 = 3 s) stops the run with the RESULT: STOPPED line (${elapsed_s}s)" "$r"

# 2. The 120-turn cap: the job's usage row says 130 turns, so it stops after the job and before
#    its checks (nothing is committed).
fixture turncap
usage_row 130 20 # its minutes are the job's estimate too: 20 min is a 30 s limit here
STUB_SLEEP_S=1
run_jobs --no-review
if [ "$rc" = 1 ] && logged "STOPPED: job runjob used 130 turns, over its cap of 120" &&
  [ "$(last_line)" = "RESULT: STOPPED: job runjob used 130 turns, over its cap of 120" ] &&
  ! logged "committed runjob"; then r=0; else r=1; fi
report "a job at 130 turns stops on the 120-turn cap before its checks, with the RESULT: STOPPED line (exit 1)" "$r"

# 3. A brief's `turns: 140` line raises the cap for that job, so the same 130 turns runs on to
#    DONE, whose RESULT: line is printed and in run.log.
fixture turnraise 'turns: 140'
usage_row 130 20
STUB_SLEEP_S=1
run_jobs --no-review
if [ "$rc" = 0 ] && logged "committed runjob" && ! logged "STOPPED" &&
  [ "$(last_line)" = "RESULT: DONE: 1 jobs, 0 min" ] && logged "RESULT: DONE: 1 jobs, 0 min"; then r=0; else r=1; fi
report "a brief's turns: 140 raises the cap and 130 turns finishes with RESULT: DONE (exit 0)" "$r"

# 4. The run's limit without RUN_MAX_MIN: the computed backstop of the one job (20 min, its
#    default, x1.25 = 25, floored at 45 by p4e), logged once; the preflight runs through FLASH_CMD too.
fixture backstop
PREFLIGHT_SKIP=""
STUB_SLEEP_S=1
run_jobs --no-review
if [ "$rc" = 0 ] && logged "preflight ok: the worker ran flutter --version and tools/check.sh --list" &&
  logged "RUN_MAX_MIN=45 min" && [ -f "$STUB_MARK" ] && ! logged "RUN_MAX_MIN=360"; then r=0; else r=1; fi
report "the computed backstop is the logged RUN_MAX_MIN (one job, 20 min default -> floor 45 min) and FLASH_CMD ran the preflight" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
