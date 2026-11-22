job: M16 process4 p4g: brief-check gate in the runner (dry-run and start), BRIEF_CHECK_SKIP, env-leak regression test
pub: no
stop: after it. One new sourced file and its test; run-jobs.sh and the existing tests are p4c's and are not edited here (a needed change goes in the report).
tests-first: exempt (shell tool: the new test runs without run-gate.sh first and must show FAIL lines; say so in the report).
expected-min: 25
turns: 120
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process4/PLAN.md (goals 1, 5) · docs/briefs/m16/process4/p4c-report.md (the seam it added) · tools/run-jobs.sh (the `brief_gate dry|start` calls; `note`, `result`, `stop`) · tools/brief-check.sh (p4a: exit codes, FAIL lines) · tools/tests/run-wave-test.sh (fake repo, stub FLASH_CMD to copy)
decisions (owner, Nov 22): 1 `brief_gate dry` runs `bash tools/brief-check.sh <dir>` (env BRIEF_CHECK_CMD overrides the command, for tests), prints its output, returns 1 on exit 1. 2 `brief_gate start` runs it after the brief lint; on a FAIL it sets the message `brief-check failed: <first FAIL line>` and returns 1 unless BRIEF_CHECK_SKIP=<reason> is non-empty: then it logs `WARN brief-check skipped: <reason>` and returns 0. No tools/brief-check.sh: returns 0. 3 Env leak: a regression test exports each of RUN_CHECK_MAX_MIN=3, RUN_POLL_S, RUN_LIMIT_UNIT_S, RUN_TURN_CAP, BRIEF_CHECK_SKIP=x in turn and runs run-wire-test.sh (and run-limits-wire-test.sh), which must pass.
do:
1 NEW tools/tests/run-gate-test.sh (copy run-wave-test.sh's fake repo): dry-run on a batch with two overlapping jobs exits 1 with FAIL overlap (stub BRIEF_CHECK_CMD); a real start logs STOPPED with `brief-check failed:`; with BRIEF_CHECK_SKIP="rehearsal" it starts and logs the WARN; a clean batch starts; no run-gate.sh: unchanged. Then the leak cases of decision 3. Under 60 s.
2 NEW tools/run-gate.sh (sourced by run-jobs.sh through p4c's seam; header comment says so).
allow: tools/run-gate.sh · tools/tests/run-gate-test.sh · docs/briefs/m16/process4/p4g-report.md
check: tools
report: docs/briefs/m16/process4/p4g-report.md
rules: aim 70-100 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
