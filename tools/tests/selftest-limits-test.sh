#!/usr/bin/env bash
# Tests tools/selftest.sh's per-script limits against the rules in
# docs/briefs/m16/process2/script-rules.md and the M16 process3 decision:
# SELFTEST_TIMEOUTS holds basename=seconds pairs, comma separated (default
# run-wire-test.sh=240,run-wire2-test.sh=240,run-stops-test.sh=300,check-cache-test.sh=420), SELFTEST_TIMEOUT stays the limit for every other script,
# and the TIMEOUT line names the limit that ran out.
#
#   bash tools/tests/selftest-limits-test.sh
#
# Every case builds fixture scripts in a temp folder and runs selftest.sh on
# them: one that sleeps 2 s and passes, one that hangs, so 1-6 s limits show.
# SELFTEST_LOCK points inside the temp folder, so the cases work while another
# selftest.sh (the one running this file) holds its own lock.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
selftest="$(pwd)/tools/selftest.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/selftest-limits-XXXXXX")" || exit 2
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
last() { tail -n 1 "$out"; }
run() { # <dir> <SELFTEST_TIMEOUTS> <SELFTEST_TIMEOUT>: runs selftest.sh on <dir>
  rc=0
  SELFTEST_LOCK="$tmp/lock" SELFTEST_TIMEOUTS="$2" SELFTEST_TIMEOUT="$3" \
    bash "$selftest" "$1" > "$out" 2>&1 || rc=$?
}

# Fixtures: one folder per case, so no case sees another's scripts.
quick_dir="$tmp/quick"
mkdir -p "$quick_dir"
cat > "$quick_dir/quick-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
sleep 2
echo "PASS the fixture's slow-enough case"
FIXTURE

slow_dir="$tmp/slow"
mkdir -p "$slow_dir"
cat > "$slow_dir/slow-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
exec > /dev/null 2>&1 # an orphaned child then holds no file that cleanup removes
sleep 30
FIXTURE

mixed_dir="$tmp/mixed"
mkdir -p "$mixed_dir"
cat > "$mixed_dir/other-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
echo "PASS the fixture's instant case"
FIXTURE
cat > "$mixed_dir/quick-test.sh" <<'FIXTURE'
#!/usr/bin/env bash
sleep 2
echo "PASS the fixture's slow-enough case"
FIXTURE

start=$(date +%s)
run "$quick_dir" "quick-test.sh=9" 1
secs=$(($(date +%s) - start))
if [ "$rc" = 0 ] && grep -qE '^PASS  .*quick-test\.sh \([0-9]+s\)$' "$out" &&
  last | grep -qF 'RESULT: ok:' && [ "$secs" -lt 6 ]; then r=0; else r=1; fi
report "a listed script gets its own limit (quick-test.sh=9, SELFTEST_TIMEOUT=1, ${secs}s)" "$r"

start=$(date +%s)
run "$slow_dir" "slow-test.sh=2" 6
secs=$(($(date +%s) - start))
if [ "$rc" = 2 ] && grep -qE '^TIMEOUT .*slow-test\.sh \([0-9]+s\)$' "$out" &&
  grep -qF 'TIMEOUT: ' "$out" && grep -qF 'exceeded 2s' "$out" &&
  last | grep -qF 'RESULT: TIMEOUT:' &&
  [ "$secs" -ge 2 ] && [ "$secs" -lt 5 ]; then r=0; else r=1; fi
report "a listed script is stopped at its own limit, and the TIMEOUT line names it (${secs}s)" "$r"

start=$(date +%s)
run "$slow_dir" "other-test.sh=30" 1
secs=$(($(date +%s) - start))
if [ "$rc" = 2 ] && grep -qF 'exceeded 1s' "$out" && last | grep -qF 'RESULT: TIMEOUT:' &&
  [ "$secs" -ge 1 ] && [ "$secs" -lt 5 ]; then r=0; else r=1; fi
report "an unlisted script still uses SELFTEST_TIMEOUT=1 (${secs}s)" "$r"

start=$(date +%s)
run "$mixed_dir" "other-test.sh=1,quick-test.sh=9" 1
secs=$(($(date +%s) - start))
if [ "$rc" = 0 ] && grep -qE '^PASS  .*quick-test\.sh ' "$out" &&
  last | grep -qF 'RESULT: ok: 2 script(s) passed' && [ "$secs" -lt 6 ]; then r=0; else r=1; fi
report "a comma-separated list matches the right basename (2 scripts pass in ${secs}s)" "$r"

run "$quick_dir" "quick-test.sh" 5
if [ "$rc" = 3 ] && grep -qF 'name=seconds' "$out" && last | grep -qF 'RESULT: BAD INPUT:'; then r=0; else r=1; fi
report "an entry without = is bad input (exit 3)" "$r"

run "$quick_dir" "quick-test.sh=soon" 5
if [ "$rc" = 3 ] && grep -qF 'must be whole seconds' "$out" && last | grep -qF 'RESULT: BAD INPUT:'; then r=0; else r=1; fi
report "an entry whose seconds aren't whole is bad input (exit 3)" "$r"

run "$quick_dir" "quick-test.sh=0" 5
if [ "$rc" = 3 ] && grep -qF 'at least 1 second' "$out" && last | grep -qF 'RESULT: BAD INPUT:'; then r=0; else r=1; fi
report "an entry with 0 seconds is bad input (exit 3)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
