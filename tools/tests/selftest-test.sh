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

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
