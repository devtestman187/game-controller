job: M16 process3 p3f: the runner refuses a wave whose base does not compile
pub: no
stop: after it. A new sourced helper, a few lines in tools/run-jobs.sh, a new test.
tests-first: exempt (shell tool: the new test script is run against the old runner first and must show FAIL lines; say so in the report).
expected-min: 15
read: docs/briefs/templates/COMMON.md · tools/run-jobs.sh (the wave loop after the preflight, `stop`, `note`, STOP.md writing; p3d has just rewritten it) · tools/run-steps.sh (how checks() calls check.sh and stops) · tools/run-limits.sh (env limits, RUN_LIMIT_UNIT_S) · tools/tests/run-limits-wire-test.sh (fake repo and stub FLASH_CMD to copy) · docs/briefs/m16/identity1/WAVE1.md (i1b's job check could never pass on a base without i1a2's fix and ran 60 min)
decisions (owner and main session, Nov 22): "the runner preflight analyzes the base (format+analyze via check.sh or mine.sh on the base) and refuses to start a wave whose base doesn't compile, writing STOP.md with the reason".
do:
1 NEW tools/run-base.sh (sourced): `run_base_check`: runs `${RUN_BASE_CHECK_CMD:-bash tools/check.sh --fail-fast format analyze}` (the base is the repo's last commit, which is what the wave's job folders are cut from), output to `$WORK/run-base-check.log`, limit RUN_BASE_CHECK_MAX_MIN (default 5, unit RUN_LIMIT_UNIT_S from run-limits.sh); returns non-zero on failure or on the limit (kill its tree).
2 tools/run-jobs.sh: before each wave starts (wave 1 included) call it; on failure `stop "the base does not compile: <first failing line of the log> (log <path>); no job of wave <n> was started"`, so STOP.md names the reason and RESULT: STOPPED prints. `RUN_BASE_CHECK_SKIP=1` skips it (note it in run.log); source the helper like run-limits.sh. Add at most 8 lines to run-jobs.sh; if it would pass 380 lines, stop and say so.
3 NEW tools/tests/run-base-test.sh: fake repo and stub FLASH_CMD as in run-limits-wire-test.sh; RUN_BASE_CHECK_CMD is a stub that exits 1 printing a fake analyze error: the run stops before any job starts, STOP.md holds the error line, RESULT: STOPPED says the base does not compile; a passing stub lets the wave start; RUN_BASE_CHECK_SKIP=1 skips; a stub that sleeps past the limit (RUN_LIMIT_UNIT_S=1, RUN_BASE_CHECK_MAX_MIN=2) stops with the limit named. Under 20 s.
allow: tools/run-base.sh · tools/run-jobs.sh · tools/tests/run-base-test.sh · docs/dev-tools.md · docs/briefs/m16/process3/p3f-report.md
check: tools
report: docs/briefs/m16/process3/p3f-report.md
rules: aim about 30 turns · run-jobs.sh ends at or under 380 lines · write only inside allow: · tools/review.sh: no FAIL on your lines.
