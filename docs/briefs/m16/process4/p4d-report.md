# p4d report (hand-finished by the driver)

The worker was stopped when p4d passed its limit (45 min) with tools/apply-job.sh and tools/tests/apply-job-test.sh written. The driver copied them from the kept tree and ran the test (10 cases pass); review.sh 0 fail.

## Commit message

```
tools: apply-job.sh replaces freehand hand-fixes (p4d)

Copies a job's allowed changed, new and deleted files and its report from the kept tree, skips files
outside allow and churn, refuses dirty targets, logs the HAND-FIX line. Test with 10 cases.
Hand-finished after the worker passed its limit.
```
