#!/usr/bin/env bash
# Tests tools/check.sh's parallel suites: -j N, -jN, --jobs N and CHECK_JOBS=N run format and
# analyze first, serially, then the suites N at a time (tools/check-par.sh). The PASS and FAIL
# lines print in the fixed check order after the run; the default (serial) run needs no check-par.sh.
# Every suite is a stub that sleeps 1 s, so the timing case compares real elapsed seconds: the
# serial run of eight suites takes at least 8 s, the -j 4 run well under half of that.
#
#   bash tools/tests/check-par-test.sh
#
# The stubs (dart and flutter, through CHECK_DART and CHECK_FLUTTER) log "<folder> <args>" to
# STUB_LOG. STUB_FAIL_SUITE names the folder whose suite fails; STUB_ANALYZE_RC makes analyze fail.
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
src="$(pwd)"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/check-par-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp/tmp" # check.sh keeps its per-check logs here, removed with $tmp
mkdir -p "$TMPDIR" || exit 2

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# report <case> <0 passed | 1 failed>: on a failure, show what check.sh printed.
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
SUITES="protocol connection metrics kit look arena puzzle host"
EXPECTED_PASS="$(for s in $SUITES; do echo "PASS $s"; done)"

# The copy: check.sh and check-par.sh under <tmp>/repo/tools, one folder per suite.
check="$tmp/repo/tools/check.sh"
par="$tmp/repo/tools/check-par.sh"
aside="$tmp/check-par.aside"
mkdir -p "$tmp/repo/tools" "$tmp/repo/packages/"{protocol,connection,metrics,game_kit,toy_look,test_game,puzzle_game,party_host}
cp "$src/tools/check.sh" "$check"
[ -f "$src/tools/check-par.sh" ] && cp "$src/tools/check-par.sh" "$par"

# The stubs: a test call sleeps 1 s and prints a suite's last line (a failing one for STUB_FAIL_SUITE).
cat > "$tmp/stub-body.sh" <<'FIXTURE'
echo "$(basename "$PWD") $*" >> "${STUB_LOG:?}"
case "${1:-}" in
  format) rc="${STUB_FORMAT_RC:-0}" ;;
  analyze) rc="${STUB_ANALYZE_RC:-0}" ;;
  *)
    sleep 1
    if [ "$(basename "$PWD")" = "${STUB_FAIL_SUITE:-none}" ]; then
      echo "+1 -1: Some tests failed."
      echo "  Expected: the stub's rule"
      rc=1
    else
      echo "+1: All tests passed!"
      rc=0
    fi
    ;;
esac
exit "$rc"
FIXTURE
for tool in dart flutter; do
  printf '#!/usr/bin/env bash\n. "$(dirname "$0")/stub-body.sh"\n' > "$tmp/$tool"
  chmod +x "$tmp/$tool"
done

set_env() { # set_env [NAME=value ...]: a fresh stub environment, then these overrides
  unset CHECK_JOBS CHECK_FAIL_FAST CHECK_SKIP
  export STUB_LOG="$tmp/calls.txt" CHECK_DART="$tmp/dart" CHECK_FLUTTER="$tmp/flutter"
  export STUB_FORMAT_RC=0 STUB_ANALYZE_RC=0 STUB_FAIL_SUITE=none
  for assignment in "$@"; do export "$assignment"; done
}

rc=0
secs=0
run() { # run <check.sh args>: runs the copy on the stubs, storing rc, out and the seconds it took
  : > "$STUB_LOG"
  local start
  start=$(date +%s)
  rc=0
  bash "$check" "$@" > "$out" 2>&1 || rc=$?
  secs=$(($(date +%s) - start))
}
calls() { wc -l < "$STUB_LOG" | tr -d ' '; } # how many stub calls ran
names() { # <file>: the case name of each PASS, FAIL or SKIPPED line, in printed order
  grep -E '^(PASS|FAIL|SKIPPED) ' "$1" | sed -E 's/ +\(.*//' | awk '{print $1, $2}'
}

# Cases 1 and 2: the eight suites run serially, then at -j 4.
set_env
run $SUITES
cp "$out" "$tmp/serial.txt"
serial_rc=$rc
serial_secs=$secs
set_env
run -j 4 $SUITES
cp "$out" "$tmp/par4.txt"
par_rc=$rc
par_secs=$secs
echo "INFO serial ${serial_secs}s, -j 4 ${par_secs}s"

if [ "$serial_rc" = 0 ] && [ "$par_rc" = 0 ] && [ "$serial_secs" -ge 8 ] &&
  [ $((par_secs * 2)) -lt "$serial_secs" ]; then r=0; else r=1; fi
report "-j 4 runs the eight stub suites in under half the serial time (serial takes at least 8 s)" "$r"

if [ "$par_rc" = 0 ] && [ "$(names "$tmp/par4.txt")" = "$EXPECTED_PASS" ] &&
  [ "$(names "$tmp/serial.txt")" = "$EXPECTED_PASS" ]; then r=0; else r=1; fi
report "-j 4 prints the eight PASS lines in check order, the same order as the serial run" "$r"

# Case 3: one failing suite does not stop the others.
set_env STUB_FAIL_SUITE=metrics
run -j 4 $SUITES
if [ "$rc" = 1 ] && grep -qE '^FAIL  metrics ' "$out" && grep -qF "Expected: the stub's rule" "$out" &&
  [ "$(grep -c '^PASS ' "$out")" = 7 ] && grep -qE '^1 failed: metrics ' "$out" && [ "$(calls)" = 8 ]; then r=0; else r=1; fi
report "-j 4 with one failing suite: its FAIL line and excerpt print, the other seven pass, exit 1" "$r"

# Case 4: CHECK_JOBS=3 works like -j 3.
set_env CHECK_JOBS=3
run $SUITES
if [ "$rc" = 0 ] && [ "$(names "$out")" = "$EXPECTED_PASS" ] && [ "$(calls)" = 8 ] &&
  [ "$secs" -lt "$serial_secs" ]; then r=0; else r=1; fi
report "CHECK_JOBS=3 runs the eight suites in check order, faster than the serial run, and exits 0" "$r"

# Case 5: the short forms and the long form of the job count parse alike.
set_env
run -j2 protocol kit
r1=$rc
n1="$(names "$out")"
run --jobs 2 protocol kit
r2=$rc
n2="$(names "$out")"
expected2="$(printf 'PASS protocol\nPASS kit')"
if [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$n1" = "$expected2" ] && [ "$n2" = "$expected2" ]; then r=0; else r=1; fi
report "-j2 and --jobs 2 run the two suites in check order and exit 0" "$r"

# Case 6: a bad or missing job count is bad input: exit 2 before any check runs.
bad=0
for args in "-j 0" "-j x" "--jobs x" "-jx" "-j -1" "-j" "--jobs"; do
  set_env
  run $args
  if [ "$rc" = 2 ] && [ "$(calls)" = 0 ]; then :; else bad=1; fi
done
set_env CHECK_JOBS=0
run protocol
if [ "$rc" = 2 ] && [ "$(calls)" = 0 ]; then :; else bad=1; fi
if [ "$bad" = 0 ]; then r=0; else r=1; fi
report "-j 0, -j x, --jobs x, -jx, -j -1, a missing -j or --jobs value and CHECK_JOBS=0 exit 2 and run nothing" "$r"

# Case 7: a failed analyze under --fail-fast starts no suite in parallel mode either.
set_env STUB_ANALYZE_RC=1
run -j 4 --fail-fast format analyze protocol metrics
if [ "$rc" = 1 ] && grep -qxF 'SKIPPED protocol (analyze failed)' "$out" &&
  grep -qxF 'SKIPPED metrics (analyze failed)' "$out" && ! grep -qE '^(PASS|FAIL) +(protocol|metrics) ' "$out" &&
  [ "$(calls)" = 2 ]; then r=0; else r=1; fi
report "-j 4 --fail-fast with a failed analyze: each suite prints SKIPPED, only format and analyze run, exit 1" "$r"

# Case 8: -j without tools/check-par.sh is bad input (exit 2), named in the message.
[ -f "$par" ] && mv "$par" "$aside"
set_env
run -j 4 protocol kit
if [ "$rc" = 2 ] && grep -qF 'check-par.sh' "$out" && [ "$(calls)" = 0 ]; then r=0; else r=1; fi
report "-j 4 without tools/check-par.sh exits 2 and names the missing file" "$r"

# Case 9: the serial run needs no tools/check-par.sh.
set_env
run protocol kit
if [ "$rc" = 0 ] && [ "$(names "$out")" = "$(printf 'PASS protocol\nPASS kit')" ]; then r=0; else r=1; fi
[ -f "$aside" ] && mv "$aside" "$par"
report "the serial run needs no tools/check-par.sh: protocol and kit pass and exit 0" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
