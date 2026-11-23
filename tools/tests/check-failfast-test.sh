#!/usr/bin/env bash
# Tests tools/check.sh's fail-fast rule and its toolchain hooks: CHECK_FAIL_FAST=1
# (or --fail-fast) makes a failed format or analyze print SKIPPED for every check
# after it and run none of them (exit 1), while off by default; CHECK_DART and
# CHECK_FLUTTER name the commands, so a case never reaches the real toolchain.
#
#   bash tools/tests/check-failfast-test.sh
#
# The stubs log every "<command> <args>" call to STUB_LOG and exit with
# STUB_FORMAT_RC, STUB_ANALYZE_RC or STUB_TEST_RC; every case asks check.sh for
# format, analyze and one or two of the Dart suites only (never the tools suite),
# so no real test runs. Prints PASS <case> / FAIL <case> and exits 1 if any case
# failed.
set -u
export CHECK_CACHE=0 # these cases rerun the same stub tree with other outcomes: no result cache

cd "$(dirname "$0")/../.." || exit 2
check="$(pwd)/tools/check.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/check-failfast-XXXXXX")" || exit 2
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
last() { tail -n 1 "$out"; }

# The stubs: each logs "<command> <args>" and exits with the stub's rc for its
# first word; a test call also prints a suite's last line, so check.sh counts it.
cat > "$tmp/stub-body.sh" <<'FIXTURE'
echo "$stub_name $*" >> "${STUB_LOG:?}"
case "${1:-}" in
  format) rc="${STUB_FORMAT_RC:-0}" ;;
  analyze) rc="${STUB_ANALYZE_RC:-0}" ;;
  *) rc="${STUB_TEST_RC:-0}"; echo "+1: All tests passed!" ;;
esac
exit "$rc"
FIXTURE
cat > "$tmp/dart" <<'FIXTURE'
#!/usr/bin/env bash
stub_name=dart
. "$(dirname "$0")/stub-body.sh"
FIXTURE
cat > "$tmp/flutter" <<'FIXTURE'
#!/usr/bin/env bash
stub_name=flutter
. "$(dirname "$0")/stub-body.sh"
FIXTURE
chmod +x "$tmp/dart" "$tmp/flutter"

# set_env [NAME=value ...]: the stub environment for the next run, then these
# overrides (a fresh case never sees the one before: the rc knobs reset, and
# CHECK_FAIL_FAST is unset unless the case names it).
set_env() {
  unset CHECK_FAIL_FAST
  export STUB_LOG="$tmp/calls.txt" CHECK_DART="$tmp/dart" CHECK_FLUTTER="$tmp/flutter"
  export STUB_FORMAT_RC=0 STUB_ANALYZE_RC=0 STUB_TEST_RC=0
  for assignment in "$@"; do export "$assignment"; done
}

rc=0
run() { # <check.sh args>: runs check.sh on the stubs, storing rc and out
  : > "$STUB_LOG"
  rc=0
  bash "$check" "$@" > "$out" 2>&1 || rc=$?
}
calls() { # <first word>: how many stub calls ran it (format, analyze or test)
  grep -cE "^(dart|flutter) $1( |$)" "$STUB_LOG" 2> /dev/null
}

set_env STUB_ANALYZE_RC=1
run --fail-fast format analyze protocol metrics
if [ "$rc" = 1 ] && grep -qE '^FAIL  analyze ' "$out" &&
  grep -qxF 'SKIPPED protocol (analyze failed)' "$out" &&
  grep -qxF 'SKIPPED metrics (analyze failed)' "$out" &&
  ! grep -qE '^PASS  (protocol|metrics)' "$out" && last | grep -qF '1 failed: analyze' &&
  [ "$(calls format)" = 1 ] && [ "$(calls test)" = 0 ]; then r=0; else r=1; fi
report "--fail-fast: a failed analyze prints SKIPPED for each suite after it, runs none, exits 1" "$r"

set_env CHECK_FAIL_FAST=1 STUB_ANALYZE_RC=1
run format analyze protocol
if [ "$rc" = 1 ] && grep -qxF 'SKIPPED protocol (analyze failed)' "$out" &&
  [ "$(calls test)" = 0 ]; then r=0; else r=1; fi
report "CHECK_FAIL_FAST=1 skips like --fail-fast (environment turn-on)" "$r"

set_env STUB_ANALYZE_RC=1
run format analyze protocol metrics
if [ "$rc" = 1 ] && ! grep -q '^SKIPPED' "$out" &&
  grep -qE '^PASS  protocol ' "$out" && grep -qE '^PASS  metrics ' "$out" &&
  [ "$(calls test)" = 2 ]; then r=0; else r=1; fi
report "off by default: a failed analyze still runs every remaining suite" "$r"

set_env STUB_FORMAT_RC=1
run --fail-fast format analyze protocol
if [ "$rc" = 1 ] && grep -qE '^FAIL  format ' "$out" &&
  grep -qxF 'SKIPPED analyze (format failed)' "$out" &&
  grep -qxF 'SKIPPED protocol (format failed)' "$out" &&
  [ "$(calls analyze)" = 0 ] && [ "$(calls test)" = 0 ]; then r=0; else r=1; fi
report "--fail-fast: a failed format skips analyze and the suites too" "$r"

set_env STUB_TEST_RC=1
run --fail-fast format analyze protocol metrics
if [ "$rc" = 1 ] && ! grep -q '^SKIPPED' "$out" &&
  grep -qE '^FAIL  protocol ' "$out" && grep -qE '^FAIL  metrics ' "$out" &&
  [ "$(calls test)" = 2 ]; then r=0; else r=1; fi
report "--fail-fast stops only after format or analyze, not after a failed suite" "$r"

set_env
run --fail-fast format analyze protocol
if [ "$rc" = 0 ] && ! grep -q '^SKIPPED' "$out" &&
  last | grep -qF 'All checks passed' && [ "$(calls test)" = 1 ]; then r=0; else r=1; fi
report "--fail-fast with everything passing prints no SKIPPED line and exits 0" "$r"

set_env
run --list
cp "$out" "$tmp/list-default.txt"
run --fail-fast --list
if [ "$rc" = 0 ] && cmp -s "$tmp/list-default.txt" "$out" &&
  [ "$(grep -c . "$out")" = 13 ] && [ ! -s "$STUB_LOG" ]; then r=0; else r=1; fi
report "--list prints the same 13 rows with or without --fail-fast and runs no check" "$r"

set_env CHECK_DART="$tmp/no-such-dart"
run format
if [ "$rc" = 2 ] && grep -qF "$tmp/no-such-dart isn't on the PATH" "$out"; then r=0; else r=1; fi
report "a missing CHECK_DART command is bad input (exit 2)" "$r"

set_env CHECK_FAIL_FAST=maybe
run analyze
if [ "$rc" = 2 ] && grep -qF 'CHECK_FAIL_FAST must be 0 or 1' "$out"; then r=0; else r=1; fi
report "CHECK_FAIL_FAST other than 0 or 1 is bad input (exit 2)" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
