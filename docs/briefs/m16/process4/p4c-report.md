# p4c report (hand-finished by the driver)

The worker was stopped when p4d passed its limit (the old runner stops every job with it). Its tree held tools/run-wave.sh (85 lines, poll loop, park, cap WARN), tools/run-jobs.sh (366 lines, `gate_step` seam), run-wave-test.sh (4 cases) and the copy-list and env-unset edits of the five wire tests. The driver copied them from the kept tree; run-wave, run-jobs-split, run-limits-wire, process3-fix1 and run-base tests pass; review.sh 0 fail. Not verified here: the full tools suite (batch check).

## Commit message

```
runner: stopped jobs park alone, turn cap WARN, poll loop in run-wave.sh (p4c)

Move the wave poll loop, limit_stop, finished_job and turn_cap to tools/run-wave.sh. A job past its
limit or failed is parked and its siblings finish and are committed; the run then stops naming the
parked job (a restart reruns it). Over the turn cap with result 0 is accepted with a WARN. run-jobs.sh
gets a gate_step seam for tools/run-gate.sh. Tests: run-wave-test (4 cases), copy lists, env unsets.
Hand-finished after the worker was stopped.
```
