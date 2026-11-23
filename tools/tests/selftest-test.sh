#!/usr/bin/env bash
# Tests tools/selftest.sh against the rules in docs/briefs/m16/process2/script-rules.md.
#
#   bash tools/tests/selftest-test.sh
#
# Every case builds fixture folders in a temp folder and runs selftest.sh on
# them. SELFTEST_LOCK points inside the temp folder, so the cases work while
# another selftest.sh (the one running this file) holds its own lock.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
selftest="$(pwd)/tools/selftest.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/selftest-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# report <case> <0 passed | 1 failed>: on a failure, show what selftest printed.
report() {
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    pass "$1"
  else
    fail "$1"
    sed 's/^/    | /' "$out"
  fi
}

out="$tmp/out.txt"
rc=0
run() { # <dir> [SELFTEST_TIMEOUT]: runs selftest.sh on <dir>, storing rc and out
  rc=0
  SELFTEST_LOCK="$tmp/lock" SELFTEST_TIMEOUT="${2:-120}" bash "$selftest" "$1" > "$out" 2>&1 || rc=$?
}
last() { tail -n 1 "$out"; }

# Fixtures: one folder per case, so no case sees another's scripts.
pass_dir="$tmp/pass"
mkdir -p "$pass_dir"
cat > "$pass_dir/ok-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
echo "PASS the fixture's case"
FIXTURE

fail_dir="$tmp/fail"
mkdir -p "$fail_dir"
cat > "$fail_dir/broken-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
echo "PASS the fixture's case"
echo "FAIL the fixture's case that fails"
exit 1
FIXTURE

hang_dir="$tmp/hang"
mkdir -p "$hang_dir"
cat > "$hang_dir/slow-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
exec > /dev/null 2>&1 # an orphaned child then holds no file that cleanup removes
sleep 30
FIXTURE

space_dir="$tmp/dir with spaces"
mkdir -p "$space_dir"
cat > "$space_dir/spaced-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
echo "PASS a fixture in a path with spaces"
FIXTURE

empty_dir="$tmp/empty"
mkdir -p "$empty_dir"

run "$tmp/no-such-folder"
if [ "$rc" = 3 ] && last | grep -qF 'RESULT: BAD INPUT: no such folder'; then r=0; else r=1; fi
report "a missing folder is bad input (exit 3)" "$r"

run "$empty_dir"
if [ "$rc" = 3 ] && last | grep -qF 'RESULT: BAD INPUT: no *-test.sh'; then r=0; else r=1; fi
report "a folder with no *-test.sh is bad input (exit 3)" "$r"

run "$pass_dir"
if [ "$rc" = 0 ] && grep -qE '^PASS  .*ok-test\.sh \([0-9]+s\)$' "$out" &&
  last | grep -qF 'RESULT: ok:'; then r=0; else r=1; fi
report "a passing script prints PASS and exits 0" "$r"

run "$fail_dir"
if [ "$rc" = 1 ] && grep -qE '^FAIL  .*broken-test\.sh \([0-9]+s\)$' "$out" &&
  grep -qF "FAIL the fixture's case that fails" "$out" && last | grep -qF 'RESULT: FAILED:'; then r=0; else r=1; fi
report "a failing script prints FAIL, its FAIL lines and exits 1" "$r"

start=$(date +%s)
run "$hang_dir" 2
secs=$(($(date +%s) - start))
if [ "$rc" = 2 ] && grep -qE '^TIMEOUT .*slow-test\.sh \([0-9]+s\)$' "$out" &&
  grep -qF 'TIMEOUT: ' "$out" && last | grep -qF 'RESULT: TIMEOUT:' &&
  [ "$secs" -ge 2 ] && [ "$secs" -lt 20 ]; then r=0; else r=1; fi
report "a hanging script is stopped by SELFTEST_TIMEOUT=2 (exit 2, ${secs}s)" "$r"

run "$space_dir"
if [ "$rc" = 0 ] && grep -qE '^PASS  .*spaced-test\.sh \([0-9]+s\)$' "$out"; then r=0; else r=1; fi
report "a folder path with spaces works" "$r"

printf '%s\n' "$$" > "$tmp/lock"
run "$pass_dir"
if [ "$rc" = 3 ] && grep -qF 'another selftest.sh is running' "$out" &&
  last | grep -qF 'RESULT: BAD INPUT:' && [ "$(cat "$tmp/lock" 2> /dev/null)" = "$$" ]; then r=0; else r=1; fi
report "a second copy on a live lock is refused (exit 3)" "$r"
rm -f "$tmp/lock"

printf '%s\n' 999999 > "$tmp/lock"
run "$pass_dir"
if [ "$rc" = 0 ] && last | grep -qF 'RESULT: ok:' && [ ! -e "$tmp/lock" ]; then r=0; else r=1; fi
report "a stale lock is replaced and removed" "$r"

tmproot="$tmp/tmproot"
mkdir -p "$tmproot"
TMPDIR="$tmproot" SELFTEST_LOCK="$tmp/lock" SELFTEST_TIMEOUT=60 timeout 4 bash "$selftest" "$hang_dir" > "$out" 2>&1
rct=$?
if [ "$rct" = 124 ] && [ ! -e "$tmp/lock" ] && [ -z "$(ls -A "$tmproot" 2> /dev/null)" ]; then r=0; else r=1; fi
report "an interrupted run removes its lock and temp files (killed after 4s)" "$r"

# norm <file>: the output with every run time (s) replaced, so runs compare equal.
norm() { sed -E 's/[0-9]+s\)/Ns)/g' "$1"; }

# Parallel runs (-j): five fixtures with different sleeps, so they finish out of list order.
par_dir="$tmp/par"
mkdir -p "$par_dir"
for spec in a1:1 a2:0.2 a3:0.6 a4:0.2 a5:0.4; do
  name="${spec%%:*}"
  cat > "$par_dir/$name-test.sh" <<FIXTURE
#!/usr/bin/env bash
sleep ${spec#*:}
echo "PASS the fixture $name"
FIXTURE
done

rc=0
SELFTEST_LOCK="$tmp/lock" bash "$selftest" "$par_dir" > "$tmp/j1.txt" 2>&1 || rc=$?
rc3=0
SELFTEST_LOCK="$tmp/lock" bash "$selftest" -j 3 "$par_dir" > "$out" 2>&1 || rc3=$?
if [ "$rc" = 0 ] && [ "$rc3" = 0 ] && [ "$(norm "$tmp/j1.txt")" = "$(norm "$out")" ] &&
  [ "$(grep -oE 'a[0-9]-test\.sh' "$out" | tr '\n' ' ')" = \
    "a1-test.sh a2-test.sh a3-test.sh a4-test.sh a5-test.sh " ] &&
  last | grep -qF 'RESULT: ok: 5 script(s) passed'; then r=0; else r=1; fi
report "-j 3 over five fixtures prints the lines in list order and the same RESULT as -j 1" "$r"

# A failing and a timing-out script (2 s limit) under -j 2: the same exit code and lines as -j 1.
mix_dir="$tmp/mix"
mkdir -p "$mix_dir"
cat > "$mix_dir/a-broken-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
echo "PASS the fixture's case"
echo "FAIL the fixture's case that fails"
exit 1
FIXTURE
cat > "$mix_dir/b-slow-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
exec sleep 30
FIXTURE

rc=0
SELFTEST_LOCK="$tmp/lock" SELFTEST_TIMEOUT=2 bash "$selftest" -j 1 "$mix_dir" > "$tmp/j1.txt" 2>&1 || rc=$?
rc2=0
SELFTEST_LOCK="$tmp/lock" SELFTEST_TIMEOUT=2 bash "$selftest" -j 2 "$mix_dir" > "$out" 2>&1 || rc2=$?
if [ "$rc" = 2 ] && [ "$rc2" = 2 ] && [ "$(norm "$tmp/j1.txt")" = "$(norm "$out")" ] &&
  grep -qF "FAIL the fixture's case that fails" "$out" && grep -qE '^TIMEOUT .*b-slow-test\.sh' "$out" &&
  last | grep -qF 'RESULT: TIMEOUT:'; then r=0; else r=1; fi
report "-j 2 with a failing and a timing-out script gives the same exit code and lines as -j 1" "$r"

# bad_jobs <case> <selftest arguments...>: the arguments are bad input (exit 3), and nothing runs.
bad_jobs() {
  name="$1"
  shift
  rc=0
  SELFTEST_LOCK="$tmp/lock" bash "$selftest" "$@" > "$out" 2>&1 || rc=$?
  if [ "$rc" = 3 ] && last | grep -qF 'RESULT: BAD INPUT:'; then r=0; else r=1; fi
  report "$name" "$r"
}
bad_jobs "-j 0 is bad input (exit 3)" -j 0 "$pass_dir"
bad_jobs "-j x is bad input (exit 3)" -j x "$pass_dir"
bad_jobs "-j with no number is bad input (exit 3)" -j
bad_jobs "-j 17 is bad input (exit 3)" -j 17 "$pass_dir"

# Two fixtures that each wait (up to 3 s) for the other's start mark: they pass only when
# both run at the same time. MEET_DIR is emptied before each run.
meet_dir="$tmp/meet"
mkdir -p "$meet_dir"
cat > "$meet_dir/c1-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
touch "$MEET_DIR/c1.started"
n=0
while [ ! -e "$MEET_DIR/c2.started" ] && [ "$n" -lt 30 ]; do
  sleep 0.1
  n=$((n + 1))
done
if [ -e "$MEET_DIR/c2.started" ]; then echo "PASS c1 ran beside c2"; else echo "FAIL c1 never saw c2 start"; exit 1; fi
FIXTURE
cat > "$meet_dir/c2-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
touch "$MEET_DIR/c2.started"
n=0
while [ ! -e "$MEET_DIR/c1.started" ] && [ "$n" -lt 30 ]; do
  sleep 0.1
  n=$((n + 1))
done
if [ -e "$MEET_DIR/c1.started" ]; then echo "PASS c2 ran beside c1"; else echo "FAIL c2 never saw c1 start"; exit 1; fi
FIXTURE

meet_state="$tmp/meet-state"
rm -rf "$meet_state"
mkdir -p "$meet_state"
rc=0
MEET_DIR="$meet_state" SELFTEST_JOBS=2 SELFTEST_LOCK="$tmp/lock" bash "$selftest" "$meet_dir" > "$out" 2>&1 || rc=$?
if [ "$rc" = 0 ] && [ "$(grep -c '^PASS  ' "$out")" = 2 ] &&
  last | grep -qF 'RESULT: ok: 2 script(s) passed'; then r=0; else r=1; fi
report "SELFTEST_JOBS=2 runs the two fixtures at once (both pass)" "$r"

rm -rf "$meet_state"
mkdir -p "$meet_state"
rc=0
MEET_DIR="$meet_state" SELFTEST_JOBS=2 SELFTEST_LOCK="$tmp/lock" \
  bash "$selftest" -j 1 "$meet_dir" > "$out" 2>&1 || rc=$?
if [ "$rc" = 1 ] && grep -qF 'FAIL c1 never saw c2 start' "$out"; then r=0; else r=1; fi
report "-j 1 overrides SELFTEST_JOBS=2 (the fixtures run one at a time, c1 fails)" "$r"

# A TERM to a -j 2 run killed while two 30 s fixtures run: each fixture execs sleep, so its pid
# is the sleep's; after the TERM, neither pid is alive and the lock is gone (polled, 0.1 s steps).
hang_pair="$tmp/hang-pair"
mkdir -p "$hang_pair"
pids="$tmp/pids"
mkdir -p "$pids"
cat > "$hang_pair/h1-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
echo $$ > "$PIDS_DIR/h1.pid"
exec sleep 30
FIXTURE
cat > "$hang_pair/h2-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
echo $$ > "$PIDS_DIR/h2.pid"
exec sleep 30
FIXTURE
SELFTEST_LOCK="$tmp/lock" SELFTEST_TIMEOUT=60 PIDS_DIR="$pids" bash "$selftest" -j 2 "$hang_pair" > "$out" 2>&1 &
spid=$!
n=0
while { [ ! -s "$pids/h1.pid" ] || [ ! -s "$pids/h2.pid" ]; } && [ "$n" -lt 100 ]; do
  sleep 0.1
  n=$((n + 1))
done
both_started=0
[ -s "$pids/h1.pid" ] && [ -s "$pids/h2.pid" ] && both_started=1
kill -TERM "$spid" 2> /dev/null
rc=0
wait "$spid" 2> /dev/null || rc=$?
n=0
while { [ -e "$tmp/lock" ] || kill -0 "$(cat "$pids/h1.pid")" 2> /dev/null ||
  kill -0 "$(cat "$pids/h2.pid" 2> /dev/null)" 2> /dev/null; } && [ "$n" -lt 100 ]; do
  sleep 0.1
  n=$((n + 1))
done
if [ "$both_started" = 1 ] && [ "$rc" = 143 ] && [ ! -e "$tmp/lock" ] &&
  ! kill -0 "$(cat "$pids/h1.pid")" 2> /dev/null &&
  ! kill -0 "$(cat "$pids/h2.pid")" 2> /dev/null; then r=0; else r=1; fi
report "a TERM to a -j 2 run leaves no fixture process and no lock (exit 143, ${n} polls)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
