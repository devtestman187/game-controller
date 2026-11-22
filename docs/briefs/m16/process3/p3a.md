job: M16 process3 p3a: tools/wait-run.sh three fixes (OVERRUN once, "checking" state, resume as a job start)
pub: no
stop: after it. Only tools/wait-run.sh and its new test; the runner is not touched.
tests-first: exempt (shell tool: the new test script is run against the old tool first and must show FAIL lines; say so in the report).
expected-min: 30
read: docs/briefs/templates/COMMON.md · tools/wait-run.sh (whole file, 279 lines) · tools/tests/wait-run-test.sh (fixtures to copy: fake run.log, temp state folder, env knobs) · tools/run-jobs.sh lines 250-300 (the exact log lines: `start <job>`, `resume <job> (applied by hand, not committed yet)`, `<job> finished: result`, `checks failed`, `DONE:`/`STOPPED:`) · docs/briefs/m16/identity1/WAVE1.md (the three defects as seen)
decisions (owner, Nov 22): fix three defects only: (1) OVERRUN is reported once per job, then acknowledged: later calls say `running` (job, minutes, "overrun already reported") and keep waiting the full window; remember it in WAIT_STATE_DIR. (2) After the last job's `finished` line and before DONE/STOPPED, the result says `checking: the combined check for <n> min` instead of "preflight (no job started yet)". (3) A `resume <job>` line counts as a job start (with that line's time), so the job shows as running until its `finished`/commit line.
do:
1 NEW tools/tests/wait-run3-test.sh (copy fixtures from wait-run-test.sh, each case under about 3 s with WAIT_MAX_S=2, WAIT_POLL_S=1, fake run.log lines, no real sleeps beyond that): OVERRUN exit 2 on the first call, exit 4 on the second; checking text; resume shown as running. Whole script under 20 s.
2 Fix tools/wait-run.sh; keep the existing wait-run-test.sh passing.
Run: bash tools/tests/wait-run3-test.sh and bash tools/tests/wait-run-test.sh.
allow: tools/wait-run.sh · tools/tests/wait-run3-test.sh · docs/briefs/m16/process3/p3a-report.md
check: tools
report: docs/briefs/m16/process3/p3a-report.md
rules: aim 60-80 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
