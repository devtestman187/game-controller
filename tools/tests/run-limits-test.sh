#!/usr/bin/env bash
# Tests the run's per-step limits (tools/run-limits.sh) and the two places the runner watches
# one: a job's limit is its `expected-min:` x1.5 (else the usage median, else the default), the
# whole run's backstop is the undone jobs' estimates +25% (rounded up), the combined check
# (tools/run-steps.sh) is killed at RUN_CHECK_MAX_MIN with its children, and a STOP file raised
# while that check runs stops the run at once.
#
#   bash tools/tests/run-limits-test.sh
#
# A stand-in tools/check.sh records its pid and a child's and sleeps, and RUN_LIMIT_UNIT_S=1
# makes one "minute" of the limits one second, so every case ends in a few seconds (the whole
# script in about 10 s). Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/run-limits-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the case printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
batch="$tmp/briefs"
FLASH_USAGE_LOG="$tmp/no-usage.tsv" # no real usage log reaches the estimates the cases check
export FLASH_USAGE_LOG
mkdir -p "$batch"
printf 'expected-min: 10\n' > "$batch/a.md"
printf 'expected-min: 20\n' > "$batch/b.md"
printf 'expected-min: 4\n' > "$batch/c.md"
printf 'expected-min: 6\n' > "$batch/d.md"
printf 'job: e\n' > "$batch/e.md" # no expected-min: line: the 20 min default
printf 'expected-min: 7\n' > "$batch/f.md"
printf 'job: g\n' > "$batch/g.md" # no line: the usage median
printf 'job: h\n' > "$batch/h.md" # neither: the default
printf 'a b  # wave 1\n\nc d e\n' > "$batch/waves.txt"
printf 'c 2026-11-22 01:00:00 committed fix\n' > "$batch/done.txt"
printf 'd\n' > "$batch/dropped.txt"

limits() { # limits <helper> <args>...: one run-limits.sh helper in a plain shell; prints its value
  ( . "$loc/tools/run-limits.sh" && "$@" )
}

# 1. The backstop: the jobs still to do (not in done.txt or dropped.txt), +25%, rounded up.
#    a 10 + b 20 + e (default) 20 = 50; 50 x 1.25 = 62.5 -> 63.
v=$(limits run_backstop_min "$batch/waves.txt")
echo "backstop=$v (want 63)" > "$out"
if [ "$v" = 63 ]; then r=0; else r=1; fi
report "the backstop is the undone jobs' estimates +25%, rounded up (10+20+20 -> 63)" "$r"

# 2. Neither file: every job of waves.txt counts. 10+20+4+6+20 = 60; 60 x 1.25 = 75.
mkdir -p "$tmp/all-briefs"
cp "$batch"/*.md "$tmp/all-briefs/"
printf 'a b\nc d e\n' > "$tmp/all-briefs/waves.txt"
v=$(limits run_backstop_min "$tmp/all-briefs/waves.txt")
echo "backstop=$v (want 75)" > "$out"
if [ "$v" = 75 ]; then r=0; else r=1; fi
report "with no done.txt or dropped.txt every job of the wave counts (10+20+4+6+20 -> 75)" "$r"

# 3. A job's expected minutes: its brief's line, else the median of its last usage rows, else
#    the default. Rows of 600 s and 1200 s for g: median 900 s = 15 min.
printf 'job\tbrief\t5\t600\t0\t0\t0\t0\t0\t%s\n' "$batch/g.md" > "$tmp/usage.tsv"
printf 'job\tbrief\t5\t1200\t0\t0\t0\t0\t0\t%s\n' "$batch/g.md" >> "$tmp/usage.tsv"
f=$(limits run_expected_min "$batch/f.md")
g=$(FLASH_USAGE_LOG="$tmp/usage.tsv" limits run_expected_min "$batch/g.md")
h=$(limits run_expected_min "$batch/h.md")
echo "brief=$f median=$g default=$h (want 7 15 20)" > "$out"
if [ "$f" = 7 ] && [ "$g" = 15 ] && [ "$h" = 20 ]; then r=0; else r=1; fi
report "a job's expected minutes: its brief line, else the usage median, else the default (7, 15, 20)" "$r"

# 4. A job's limit: expected minutes x RUN_JOB_FACTOR_PCT in RUN_LIMIT_UNIT_S-second minutes.
#    a (10 min) x 150% = 15 min = 900 s, and with 1 s units 15.
v=$(limits run_job_limit_s "$batch/a.md")
w=$(RUN_LIMIT_UNIT_S=1 limits run_job_limit_s "$batch/a.md")
echo "limit=$v units1=$w (want 900 15)" > "$out"
if [ "$v" = 900 ] && [ "$w" = 15 ]; then r=0; else r=1; fi
report "a job's limit is expected minutes x 150% (10 min -> 900 s, 1 s units -> 15)" "$r"

# The runner's globals and helpers for one checks() call: the runner's own check_stop and
# kill_tree, and stubs for the rest (nothing is logged, committed or reviewed).
run_checks() { # run_checks <case>: checks() from tools/run-steps.sh in a copy of the tools
  (
    cd "$tmp/$1/repo" || exit 2
    dir="$tmp/$1/repo/tools" B=docs/briefs/fix WORK="$tmp/$1/work" SIZE_STOP=380
    note() { :; }
    finding() { :; }
    stop() { # as tools/run-jobs.sh has it, without STOP.md: name the cause, kill the children
      echo "STOPPED: $1"
      for p in $(jobs -p); do kill_tree "$p"; done
      exit 1
    }
    check_stop() { [ -f "$B/STOP" ] && stop "stop file"; }
    kill_tree() { local c; for c in $(ps -ef 2>/dev/null | awk -v p="$1" '$3==p{print $2}'); do kill_tree "$c"; done; kill "$1" 2>/dev/null; }
    unchurn() { :; }
    . tools/run-steps.sh
    checks
  )
}
check_fixture() { # check_fixture <case>: a repo whose stand-in check.sh records its pids and sleeps
  local base="$tmp/$1"
  mkdir -p "$base/repo/tools" "$base/repo/docs/briefs/fix" "$base/work"
  cp "$loc/tools/run-steps.sh" "$loc/tools/run-limits.sh" "$base/repo/tools/"
  cat > "$base/repo/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
echo $$ > "$STUB_CHECK_PID"
sleep 30 &
echo $! > "$STUB_CHECK_CHILD"
wait
EOF
  chmod +x "$base/repo/tools/check.sh"
  STUB_CHECK_PID="$base/check.pid" STUB_CHECK_CHILD="$base/check.child"
  export STUB_CHECK_PID STUB_CHECK_CHILD
}
alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2> /dev/null; } # alive <pid file>: its process runs

# 5. The combined check's own limit: 2 "minutes" of 1 s. It and its child are killed, and the
#    stop names the limit.
check_fixture limit
start_s=$SECONDS
RUN_CHECK_MAX_MIN=2 RUN_LIMIT_UNIT_S=1 RUN_POLL_S=1
export RUN_CHECK_MAX_MIN RUN_LIMIT_UNIT_S RUN_POLL_S
run_checks limit > "$out" 2>&1
rc=$?
elapsed_s=$((SECONDS - start_s))
if [ "$rc" = 1 ] && grep -q "STOPPED: CHECK TIMEOUT" "$out" && grep -q "RUN_CHECK_MAX_MIN=2" "$out" &&
  [ "$elapsed_s" -lt 8 ] && ! alive "$tmp/limit/check.pid" && ! alive "$tmp/limit/check.child"; then r=0; else r=1; fi
report "the combined check is killed at RUN_CHECK_MAX_MIN with its children, naming the limit (2 min = 2 s, ${elapsed_s}s)" "$r"

# 6. A STOP file raised while the check runs stops the run and kills the check at once.
check_fixture stopfile
( sleep 1; touch "$tmp/stopfile/repo/docs/briefs/fix/STOP" ) &
toucher=$!
start_s=$SECONDS
RUN_CHECK_MAX_MIN=30
export RUN_CHECK_MAX_MIN
run_checks stopfile > "$out" 2>&1
rc=$?
elapsed_s=$((SECONDS - start_s))
wait "$toucher" 2> /dev/null
if [ "$rc" = 1 ] && grep -q "STOPPED: stop file" "$out" && [ "$elapsed_s" -lt 8 ] &&
  ! alive "$tmp/stopfile/check.pid" && ! alive "$tmp/stopfile/check.child"; then r=0; else r=1; fi
report "a STOP file during the combined check stops the run and kills the check (${elapsed_s}s)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
