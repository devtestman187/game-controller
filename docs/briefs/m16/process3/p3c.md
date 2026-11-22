job: M16 process3 p3c: runner limit helpers (run-limits.sh), a combined check that watches the limits and the STOP file, review limits
pub: no
stop: after it. Helpers and run-steps.sh/run-review.sh only; run-jobs.sh is p3d's (wave 2) and calls what you add.
tests-first: exempt (shell tools: the new test script is run against the old tools first and must show FAIL lines; say so in the report).
expected-min: 40
read: docs/briefs/templates/COMMON.md · tools/run-steps.sh (whole: checks() lines 97-120 runs check.sh synchronously; time_check; lock) · tools/run-review.sh (run_review, start_reviews, flash.sh calls) · tools/run-jobs.sh lines 60-130 (RUN_MAX_MIN, check_stop, stop) · tools/wait-run.sh lines 150-175 (expected_min: copy its rule) · tools/tests/run-wire-test.sh (the wiring fixtures; its 114 s is why you add a fast new test instead) · docs/briefs/m16/identity1/WAVE1.md
decisions (owner, Nov 22): per-step limits: a job stops at its brief estimate x1.5 (`expected-min:` field, else the usage median, else 20 min); combined check about 12 min; a review about 10 min; the whole-run backstop is the sum of the estimates +25% computed from the briefs, replacing the fixed 360. Limits and the STOP file are checked DURING the combined check. Env overrides for tests.
do:
1 NEW tools/run-limits.sh (sourced, no side effects): run_expected_min <brief>; run_job_limit_s; run_backstop_min <waves.txt> (sum of the estimates of jobs not done or dropped, +25%); env RUN_JOB_FACTOR_PCT (150), RUN_CHECK_MAX_MIN (12), RUN_REVIEW_MAX_MIN (10), RUN_EXPECT_DEFAULT_MIN (20), RUN_POLL_S (5).
2 run-steps.sh: run check.sh in the background (CHECK_FAIL_FAST=1 set) and poll: after RUN_CHECK_MAX_MIN or when check_stop fires, kill its tree and stop with a cause naming the limit; keep the retry rules.
3 run-review.sh: the review wait stops at RUN_REVIEW_MAX_MIN; call `${FLASH_CMD:-tools/flash.sh}` instead of tools/flash.sh.
4 NEW tools/tests/run-limits-test.sh: backstop arithmetic from fake briefs; a stand-in check.sh that sleeps with RUN_CHECK_MAX_MIN as a fraction via RUN_POLL_S and a seconds override (RUN_LIMIT_UNIT_S=1 meaning one "minute" is one second) stops it; a STOP file during the check stops it. Under 20 s.
allow: tools/run-limits.sh · tools/run-steps.sh · tools/run-review.sh · tools/tests/run-limits-test.sh · docs/briefs/m16/process3/p3c-report.md
check: tools
report: docs/briefs/m16/process3/p3c-report.md
rules: aim 85-100 turns · no file you touch ends over 380 lines · write only inside allow: · tools/review.sh: no FAIL on your lines.
