#!/usr/bin/env bash
# Tests the test-only WARN of tools/brief-check.sh (tools/brief-check-testonly.sh): a job whose
# allow: holds only *_test.dart files (and its report) and has no `tests-first: exempt` line WARNs,
# naming the job, and the batch still passes with exit 0. The exempt line, a lib file in the
# allow:, a shell-tool job (no .dart path) and a job with no test file at all give no WARN.
# Two jobs in one batch show the WARN is per job.
#
#   bash tools/tests/brief-check-testonly-test.sh
#
# Each case writes a temp batch (waves.txt and one brief per job) and runs tools/brief-check.sh
# on it. Prints PASS <case> / FAIL <case> (the tool's output indented under a failure) and exits 1
# if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/brief-check-testonly-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the tool printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
batch="$tmp/batch"
newbatch() { # newbatch <job>...: an empty batch whose waves.txt puts the jobs in one wave
  rm -rf "$batch"
  mkdir -p "$batch"
  echo "$*" > "$batch/waves.txt"
}
brief() { # brief <job> <allow> [extra line]: writes the job's brief into the batch
  { echo "job: $1"; echo "allow: $2"; [ -n "${3:-}" ] && echo "$3"; } > "$batch/$1.md"
}
check() { # check: runs the tool on the batch; sets rc and writes $out
  rc=0
  BRIEF_CHECK_ROOT="$tmp" BRIEF_CHECK_REF= bash tools/brief-check.sh "$batch" > "$out" 2>&1 || rc=$?
}
exact() { grep -qxF -- "$1" "$out"; } # exact <line>: $out has exactly that line
none() { ! grep -q "^$1" "$out"; }    # none <prefix>: $out has no line starting with it

# 1. A test-only allow: (a *_test.dart file and the report), no exempt line: one WARN naming the
#    job; the batch passes with exit 0 and the result counts the WARN.
newbatch job-a
brief job-a "packages/p/test/a_test.dart · docs/briefs/x/job-a-report.md"
check
if [ "$rc" = 0 ] && exact 'WARN testonly job-a: its allow: holds only test files and no tests-first: exempt line' &&
  exact 'RESULT: ok: 1 job(s), 1 WARN'; then r=0; else r=1; fi
report "a test-only allow: with no tests-first: exempt line WARNs, naming the job, and exits 0" "$r"

# 2. The same allow: with the exempt line: no testonly WARN.
newbatch job-a
brief job-a "packages/p/test/a_test.dart · docs/briefs/x/job-a-report.md" \
  "tests-first: exempt (shell tools: run the new test first)"
check
if [ "$rc" = 0 ] && none WARN && exact 'RESULT: ok: 1 job(s), 0 WARN'; then r=0; else r=1; fi
report "a test-only allow: with a tests-first: exempt line gives no WARN" "$r"

# 3. A lib file in the allow: with the test file: nothing to warn about.
newbatch job-a
brief job-a "packages/p/lib/a.dart · packages/p/test/a_test.dart · docs/briefs/x/job-a-report.md"
check
if [ "$rc" = 0 ] && none WARN && exact 'RESULT: ok: 1 job(s), 0 WARN'; then r=0; else r=1; fi
report "an allow: with a lib file and a test file gives no WARN" "$r"

# 4. A shell-tool job: its allow: names .sh files and a -test.sh file, no .dart path: no WARN.
newbatch job-a
brief job-a "tools/brief-check.sh · tools/tests/brief-check-testonly-test.sh · docs/briefs/x/job-a-report.md"
check
if [ "$rc" = 0 ] && none WARN && exact 'RESULT: ok: 1 job(s), 0 WARN'; then r=0; else r=1; fi
report "a shell-tool job (no .dart path) gives no WARN" "$r"

# 5. Only the report in the allow: no test file, so nothing is test-only: no WARN.
newbatch job-a
brief job-a "docs/briefs/x/job-a-report.md"
check
if [ "$rc" = 0 ] && none WARN && exact 'RESULT: ok: 1 job(s), 0 WARN'; then r=0; else r=1; fi
report "an allow: holding only the report gives no WARN" "$r"

# 6. Two jobs in one wave: the test-only one WARNs, the lib one does not; the result counts one.
newbatch job-a job-b
brief job-a "packages/p/test/a_test.dart · docs/briefs/x/job-a-report.md"
brief job-b "packages/q/lib/b.dart · docs/briefs/x/job-b-report.md"
check
if [ "$rc" = 0 ] && exact 'WARN testonly job-a: its allow: holds only test files and no tests-first: exempt line' &&
  none 'WARN testonly job-b' && exact 'RESULT: ok: 2 job(s), 1 WARN'; then r=0; else r=1; fi
report "two jobs: only the test-only job WARNs, the result counts one WARN" "$r"

echo "$cases case(s), $fails failed"
[ "$fails" -eq 0 ]
