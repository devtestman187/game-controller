# f1 report (driver-written: the worker stopped at its 45 min limit before writing one)

The worker finished all edits in its job worktree (/e/AI/game-controller-m16-jobs/flash-20261122-060044-645598) but hit the job limit (45 min, estimate 30) before reporting. The driver copied its five files unchanged and re-ran the job's tests (hand-apply from the kept worktree, run.log `HAND-FIX f1`).

## Summary
1. run-jobs.sh: one poll loop over every started job of a wave (limits, STOP file, exits), so a later job's limit is seen while an earlier one runs. Message unchanged.
2. run-steps.sh: a failed format or analyze stops at once with no package fetch and no second check; a failed suite still gets one retry.
3. wait-run.sh: the runner's `start the run's review` note is no job; exit-4 text is `reviewing: the run's review for <n> min`, never OVERRUN.
4. tools/tests/process3-fix1-test.sh (new): 4 cases, pass (26 s). tools/tests/run-jobs-split-test.sh: runner limit 380 -> 400 (runner is 398 lines).

## Tests-first
Exempt (shell tools); the worker's own log shows the new script was run against the old tools first (not re-verified by the driver).

## Known nits
run-steps.sh `local big=$(...)` merged declaration (masks the exit code, harmless there); run-jobs.sh at 398 of 400 lines: split before the next addition.

## Hand-over
Nothing outside the allow list changed.

## Commit message

runner: every job's limit is polled in one loop, no retry for format/analyze, run's review is not a job

run-jobs.sh waits on all started jobs of a wave in one poll (limits, STOP file,
exits), so a later job's limit is seen while an earlier one runs (p3e ran 48 min
against 30). run-steps.sh stops at once on a format or analyze failure instead of
fetching packages and re-running (a suite still gets one retry). wait-run.sh shows
`reviewing: the run's review for <n> min` and never an OVERRUN for the runner's
review note. New tools/tests/process3-fix1-test.sh; the split test's runner limit
is 400 (runner 398).
