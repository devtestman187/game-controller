job: M16 process3 p3b: check.sh fails fast (analyze or format fail skips the suites) and selftest.sh per-script limits
pub: no
stop: after it. Only tools/check.sh, tools/selftest.sh and their new tests.
tests-first: exempt (shell tools: each new test script is run against the old tool first and must show FAIL lines; say so in the report).
expected-min: 25
read: docs/briefs/templates/COMMON.md · tools/check.sh (121 lines: the checks array, the loop that runs them) · tools/selftest.sh (130 lines: line 41 SELFTEST_TIMEOUT, the per-script loop at ~95) · tools/tests/selftest-test.sh (fixtures to copy) · tools/tests/run-wire-test.sh (head only: it takes 114 s alone) · docs/briefs/m16/identity1/WAVE1.md (why)
decisions (owner, Nov 22): "Combined check fails fast: if analyze (or format) fails, skip the test suites and report." "selftest per-script limit: run-wire-test.sh gets 240 s; the rest keep 120."
do:
1 check.sh: env CHECK_FAIL_FAST=1 (also `--fail-fast`): when format or analyze fails, print `SKIPPED <suite> (analyze failed)` for each remaining suite, run none, exit 1. Off by default (the runner turns it on later). Add an env hook so a test can stub the commands (for example CHECK_DART and CHECK_FLUTTER, default dart and flutter); keep the --list output unchanged.
2 selftest.sh: per-script limits: SELFTEST_TIMEOUTS="run-wire-test.sh=240" style list (basename=seconds, comma separated), default `run-wire-test.sh=240`; SELFTEST_TIMEOUT stays the default for the rest. The TIMEOUT line names the limit used.
3 NEW tools/tests/check-failfast-test.sh and tools/tests/selftest-limits-test.sh: stub dart/flutter, stand-in scripts that sleep 1-2 s with limits of 1-3 s via env; each under 20 s.
allow: tools/check.sh · tools/selftest.sh · tools/tests/check-failfast-test.sh · tools/tests/selftest-limits-test.sh · docs/briefs/m16/process3/p3b-report.md
check: tools
report: docs/briefs/m16/process3/p3b-report.md
rules: aim 50-70 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
