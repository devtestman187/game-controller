job: M16 process3 p3d: run-jobs.sh wiring: per-job limits, computed backstop, 120-turn cap, RESULT line, FLASH_CMD
pub: no
stop: after it. Only tools/run-jobs.sh and a new test; the helpers of wave 1 are used, not changed.
tests-first: exempt (shell tool: the new test script is run against the old runner first and must show FAIL lines; say so in the report).
expected-min: 45
read: docs/briefs/templates/COMMON.md · tools/run-jobs.sh (whole, 326 lines; it must end at or under 380) · tools/run-limits.sh and docs/briefs/m16/process3/p3c-report.md (what wave 1 added) · tools/run-steps.sh (stop helpers) · tools/tests/run-wire-test.sh (fixtures: fake repo, stub flash) · tools/tests/run-limits-test.sh
decisions (owner, Nov 22): per-step limits, computed backstop, the 120-turn cap per job, a RESULT: line at the end of every run, and FLASH_CMD for a stand-in worker.
do:
1 RUN_MAX_MIN default: computed by run_backstop_min from waves.txt and the briefs; an explicit RUN_MAX_MIN still wins; log the computed value once at the start.
2 The wave loop's wait for each job also stops at its limit (run_job_limit_s): stop with `job <j> passed its limit (<n> min, estimate <m>)`, STOP.md as for any stop.
3 Turn cap: after a job finishes, read its turns from the usage line (the usage helper); more than RUN_TURN_CAP (120; a brief line `turns: <n>` raises it for that job) stops with a cause naming job, turns and cap, before the checks.
4 RESULT line: print and append to run.log a last line `RESULT: DONE: <jobs> jobs, <min> min` or `RESULT: STOPPED: <cause>` on every exit path (stop(), the end, the lock refusal already has one).
5 `${FLASH_CMD:-tools/flash.sh}` for every job start (and the preflight); an unset FLASH_CMD behaves as today.
6 NEW tools/tests/run-limits-wire-test.sh: a fake repo with stub FLASH_CMD (sleeps 1-2 s, writes the report), env limits in seconds (RUN_LIMIT_UNIT_S=1 from p3c): job over limit stops; turn cap stops; RESULT lines for DONE and STOPPED. Under 20 s each case.
allow: tools/run-jobs.sh · tools/tests/run-limits-wire-test.sh · docs/dev-tools.md · docs/briefs/m16/process3/p3d-report.md
check: tools
report: docs/briefs/m16/process3/p3d-report.md
rules: aim 90-110 turns · run-jobs.sh ends at or under 380 lines (keep additions compact; helpers stay in run-limits.sh, which this job does not edit) · write only inside allow: · tools/review.sh: no FAIL on your lines.
