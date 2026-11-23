job: M16 identity1-fix ft: check.sh tools suite runs selftest.sh -j 4; claude-worker-test tolerates load
expected-min: 45
turns: 50
tests-first: exempt tools job; the proof is the test run under load
pub: no
stop: after it. No other change.
read: docs/briefs/templates/COMMON.md · tools/check.sh:45-60 · tools/selftest.sh:1-30 (the -j option) · tools/tests/claude-worker-test.sh (whole file, 165 lines) · tools/claude-worker.sh · tools/fake-claude-worker.sh · docs/dev-tools.md:60-70 and :142-155 · tools/tests/check-scope-test.sh:165-180
changes: selftest.sh -j 4 · claude-worker-test.sh
decision (owner, Nov 23): switch `check.sh tools` to `selftest.sh -j 4`; first make claude-worker-test load-tolerant.
do:
1 Find why tools/tests/claude-worker-test.sh could fail under load: run it four times at once with `bash tools/tests/claude-worker-test.sh` (separate calls, one at a time is fine too) and read the cases for timing, shared temp names, shared files or a start-up cost with a tight limit. Fix the cause in the test file (unique temp names, longer limits, no shared state). If no cause is found, say so in the report and change nothing else in that file.
2 tools/check.sh line 58: the `tools` suite command becomes `bash tools/selftest.sh -j 4`. Update docs/dev-tools.md lines that quote the old command (line 66) and the HANDOFF.md:250 sentence only if it quotes the command.
3 Run these, each as the bare command line, nothing wrapped in time, cd, pipes or redirects: `bash tools/tests/check-scope-test.sh` · `bash tools/tests/check-failfast-test.sh` · `bash tools/tests/selftest-test.sh` · `bash tools/tests/selftest-limits-test.sh` · `bash tools/tests/claude-worker-test.sh`. Do NOT run the whole tools suite.
allow: tools/check.sh · tools/tests/claude-worker-test.sh · tools/tests/check-scope-test.sh · tools/tests/check-failfast-test.sh · tools/tests/selftest-test.sh · tools/tests/selftest-limits-test.sh · docs/dev-tools.md · docs/HANDOFF.md
check: format
report: docs/briefs/m16/identity1-fix/ft-report.md
