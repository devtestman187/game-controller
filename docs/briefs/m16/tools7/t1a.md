job: M16 tools7 t1a: split run-wire-test.sh in two, one shared fixture helper, a template repo copied per case, condition waits
pub: no
turns: 35
expected-min: 45
tests-first: exempt (refactor of a shell test: every case keeps its name and its check; run the old file first and note its wall time, then the new files and their times)
stop: after it. Touch no other test script (run-gate-test.sh reads run-wire-test.sh's `unset` block; keep that block intact).
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/tools7/context.md (goal and rules) · tools/tests/run-wire-test.sh (whole file, 444 lines: header 1-33, stubs 60-165, fixture 167-200, helpers 200-247, cases 249-444) · tools/tests/run-gate-test.sh:214-248 (the leak case: both wire tests must keep a top `unset RUN_CHECK_MAX_MIN RUN_POLL_S RUN_LIMIT_UNIT_S RUN_TURN_CAP BRIEF_CHECK_SKIP ...` block) · docs/flash-lessons.md rules 19-21
changes: run-wire-lib.sh · run_wire_template · run-wire2-test.sh
decisions (owner, Nov 22): speed up `check.sh tools` to about 2 min without weakening any test; one fixture repo per script; condition waits instead of fixed sleeps.
do:
1 NEW tools/tests/run-wire-lib.sh (not a *-test.sh, so selftest skips it; sourced, no exit): the stubs() text, fixture(), run_jobs, start_jobs, lock_pid, end_runner, logged, more_briefs, seed_report, stopmd, stop_committed, report/pass/fail. fixture() copies a template repo built ONCE per script (git init, config, base commit, made by `run_wire_template`) with `cp -r` instead of rebuilding and committing per case; re-point the STUB_* paths per case as today.
2 Split the cases by measured time into tools/tests/run-wire-test.sh (keeps its name, header and top `unset ... BRIEF_CHECK_SKIP` block, sources the lib) and NEW tools/tests/run-wire2-test.sh (same top unset block, sources the lib); aim for equal wall time (measure each case with `date +%s`, print nothing new). Keep every case's PASS/FAIL text unchanged.
3 Replace fixed sleeps with condition waits where a case only waits for a file or log line (poll every 0.1 s up to a cap, fail the case on the cap). Do not shorten the stub's 30 s guard sleeps that the runner must kill.
4 Header comments: each file says what it covers; the lib says which scripts source it. Each file stays under 380 lines.
5 Run the old run-wire-test.sh first (note seconds), then after the change run-wire-test.sh, run-wire2-test.sh, run-gate-test.sh, run-jobs-split-test.sh, selftest-limits-test.sh; all pass. Report each script's seconds before and after.
allow: tools/tests/run-wire-test.sh · tools/tests/run-wire2-test.sh · tools/tests/run-wire-lib.sh · docs/briefs/m16/tools7/t1a-report.md
check: format
report: docs/briefs/m16/tools7/t1a-report.md
