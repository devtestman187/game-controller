#!/usr/bin/env bash
# Tests the combined check's scope: tools/check.sh's CHECK_SKIP (a named check prints
# SKIPPED and does not run; an unknown name is bad input) and the FAIL lines it prints for a
# failed suite; tools/run-stop.sh, whose STOP.md names that suite, script and case; and
# tools/run-steps.sh's check_scope, which skips the tools suite when no job changed tools/.
#
#   bash tools/tests/check-scope-test.sh
#
# Every case works in a temp folder: check.sh runs from <tmp>/repo/tools with a stub selftest
# that prints the real failing shape, and dart and flutter are stubs, so no real test or
# self-test runs. The steps cases use a temp git repo of their own. Prints PASS <case> /
# FAIL <case> and exits 1 if any case failed.
set -u

cd "$(dirname "$0")/../.." || exit 2
src="$(pwd)"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/check-scope-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp/tmp" # check.sh keeps its per-check logs here, removed with $tmp
mkdir -p "$TMPDIR" || exit 2

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# report <case> <0 passed | 1 failed>: on a failure, show the output the case left in $out
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

# The stubs: dart and flutter log their arguments to STUB_LOG and pass; the stub selftest
# touches STUB_SELFTEST_MARK and prints a failing suite the way tools/selftest.sh does.
mkdir -p "$tmp/repo/tools"
cp "$src/tools/check.sh" "$tmp/repo/tools/check.sh"
cat > "$tmp/repo/tools/selftest.sh" <<'FIXTURE'
#!/usr/bin/env bash
touch "${STUB_SELFTEST_MARK:?}"
echo "FAIL  tools/tests/x-test.sh (1s)"
echo "  FAIL case one: expected the rule"
echo "  FAIL case two"
echo "RESULT: FAILED: tools/tests/x-test.sh"
exit 1
FIXTURE
for tool in dart flutter; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "${STUB_LOG:?}"\nexit 0\n' "$tool" > "$tmp/$tool"
  chmod +x "$tmp/$tool"
done

set_env() { # set_env [NAME=value ...]: a fresh stub environment, then these overrides
  unset CHECK_SKIP RUN_CHECK_SKIP CHECK_FAIL_FAST
  export STUB_LOG="$tmp/calls.txt" STUB_SELFTEST_MARK="$tmp/selftest-ran"
  export CHECK_DART="$tmp/dart" CHECK_FLUTTER="$tmp/flutter"
  rm -f "$STUB_SELFTEST_MARK" "$STUB_LOG"
  for assignment in "$@"; do export "$assignment"; done
}

rc=0
run() { # run <check.sh args>: runs the copied check.sh, storing rc and out
  rc=0
  bash "$tmp/repo/tools/check.sh" "$@" > "$out" 2>&1 || rc=$?
}

set_env CHECK_SKIP=tools
run format tools
if [ "$rc" = 0 ] && grep -qxF 'SKIPPED tools (CHECK_SKIP)' "$out" && [ ! -e "$STUB_SELFTEST_MARK" ] &&
  grep -qE '^PASS  format ' "$out" && grep -q '^All checks passed' "$out"; then r=0; else r=1; fi
report "CHECK_SKIP=tools prints SKIPPED for the tools suite, runs none of it, and exits 0" "$r"

set_env CHECK_SKIP="format,tools"
run format tools
if [ "$rc" = 0 ] && grep -qxF 'SKIPPED format (CHECK_SKIP)' "$out" && grep -qxF 'SKIPPED tools (CHECK_SKIP)' "$out" &&
  [ ! -s "$STUB_LOG" ] && [ ! -e "$STUB_SELFTEST_MARK" ]; then r=0; else r=1; fi
report "CHECK_SKIP takes a comma-separated list: both named checks are skipped, none runs" "$r"

set_env CHECK_SKIP="format tools"
run format tools
if [ "$rc" = 0 ] && grep -qxF 'SKIPPED format (CHECK_SKIP)' "$out" && grep -qxF 'SKIPPED tools (CHECK_SKIP)' "$out" &&
  [ ! -s "$STUB_LOG" ] && [ ! -e "$STUB_SELFTEST_MARK" ]; then r=0; else r=1; fi
report "CHECK_SKIP takes a space-separated list: both named checks are skipped, none runs" "$r"

set_env
run tools
if [ "$rc" = 1 ] && [ -e "$STUB_SELFTEST_MARK" ] && grep -qE '^FAIL +tools ' "$out" &&
  grep -qF 'FAIL  tools/tests/x-test.sh' "$out" && grep -qF '  FAIL case one' "$out" &&
  grep -qF '  FAIL case two' "$out"; then r=0; else r=1; fi
report "with CHECK_SKIP unset the tools suite runs; its failure prints the script and case FAIL lines (exit 1)" "$r"
cp "$out" "$tmp/real-fail.txt"

set_env CHECK_SKIP=nosuch
run format
if [ "$rc" = 2 ] && grep -qF 'Unknown check in CHECK_SKIP: nosuch' "$out" && [ ! -s "$STUB_LOG" ]; then r=0; else r=1; fi
report "an unknown CHECK_SKIP name is bad input (exit 2) and runs no check" "$r"

# STOP.md from the real failing output: the suite, the script and the case each show, and the
# failing-tests section holds them instead of "none found".
batch="$tmp/stop/batch"
work="$tmp/stop/work"
mkdir -p "$batch" "$work"
cp "$tmp/real-fail.txt" "$work/run-check.log"
echo "2026-11-22 00:00:00 log line" > "$batch/run.log"
bash "$src/tools/run-stop.sh" "$batch" "$work" "checks failed twice on the combined tree after s6" > /dev/null 2>&1
rc=$?
section="$(sed -n '/^failing tests and errors/,/^files outside allow/p' "$batch/STOP.md" 2> /dev/null)"
out="$batch/STOP.md"
if [ "$rc" = 0 ] && grep -qF 'FAIL  tools/tests/x-test.sh' <<< "$section" && grep -qF '  FAIL case one' <<< "$section" &&
  ! grep -qF 'none found' <<< "$section"; then r=0; else r=1; fi
report "STOP.md names the failing suite, script and case under failing tests, with no 'none found'" "$r"

# check_scope in tools/run-steps.sh, run in a temp git repo whose tools/ is committed: the stub
# check.sh records the CHECK_SKIP it was given, and note and stop are recorded, not run.
steps_repo() { # steps_repo <name>: a fresh repo with a committed tools/ folder; sets repo
  repo="$tmp/steps-$1"
  mkdir -p "$repo/tools"
  printf '#!/usr/bin/env bash\necho "${CHECK_SKIP-unset}" >> "$SKIP_LOG"\nexit 0\n' > "$repo/tools/check.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$repo/tools/review.sh"
  git -C "$repo" init -q
  git -C "$repo" add tools
  git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm base
}

run_checks() { # run_checks <repo>: sources run-steps.sh there and runs checks; sets rc, out, skip_log, notes
  local name
  name="$(basename "$1")"
  skip_log="$tmp/$name-skip.txt"
  notes="$tmp/$name-notes.txt"
  out="$tmp/$name-out.txt"
  : > "$skip_log"
  : > "$notes"
  (
    cd "$1" || exit 2
    unset CHECK_SKIP RUN_CHECK_SKIP
    export SKIP_LOG="$skip_log"
    WORK="$tmp/work-$name"
    mkdir -p "$WORK"
    SIZE_STOP=380
    . "$src/tools/run-steps.sh"
    note() { echo "NOTE: $*" >> "$notes"; }
    stop() { echo "STOP: $*" >> "$notes"; exit 1; }
    unchurn() { :; }
    check_stop() { :; }
    kill_tree() { :; }
    checks "s1"
  ) > "$out" 2>&1
  rc=$?
}

steps_repo clean
run_checks "$repo"
if [ "$rc" = 0 ] && [ "$(cat "$skip_log")" = tools ] &&
  grep -qxF 'NOTE: combined check: the tools suite is skipped (no job changed a file under tools/)' "$notes" &&
  [ "$(wc -l < "$notes" | tr -d ' ')" = 1 ]; then r=0; else r=1; fi
report "checks skips the tools suite when no job changed a file under tools/, and logs one line" "$r"

steps_repo changed
echo "# a job's change" > "$repo/tools/new-tool.sh"
run_checks "$repo"
if [ "$rc" = 0 ] && [ "$(wc -l < "$skip_log" | tr -d ' ')" = 1 ] && [ -z "$(cat "$skip_log")" ] &&
  grep -qxF 'NOTE: combined check: the tools suite runs (a job changed a file under tools/)' "$notes" &&
  [ "$(wc -l < "$notes" | tr -d ' ')" = 1 ]; then r=0; else r=1; fi
report "checks runs the tools suite after a file under tools/ changed, and logs one line" "$r"

# selftest.sh clears the runner's settings, so a test never sees WORKER or NO_PUSH from the combined check.
mkdir -p "$tmp/envtests"
printf '#!/usr/bin/env bash\n[ -z "${WORKER:-}${NO_PUSH:-}${CHECK_SKIP:-}${CHECK_FAIL_FAST:-}" ] || { echo "FAIL leaked"; exit 1; }\necho "PASS clean"\n' > "$tmp/envtests/e-test.sh"
out="$tmp/envtests-out.txt"
SELFTEST_LOCK="$tmp/envtests.lock" WORKER=claude NO_PUSH=1 CHECK_SKIP=tools CHECK_FAIL_FAST=1 bash tools/selftest.sh "$tmp/envtests" > "$out" 2>&1
if [ $? = 0 ] && grep -q '^PASS  ' "$out"; then r=0; else r=1; fi
report "selftest.sh hides WORKER, NO_PUSH and CHECK_* from the tests" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
