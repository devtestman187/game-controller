# p4g report (applied by the driver with tools/apply-job.sh)

The worker passed its limit (37 min, estimate 25: too low for a tools job; floor rule 9 says 30-40) and was parked by the new runner. Its tree held tools/run-gate.sh (51 lines) and tools/tests/run-gate-test.sh. One expectation in the test was wrong (brief-check prints `FAIL wave two:`), fixed by hand. 8 cases pass, review.sh 0 fail.

## Commit message

```
runner: brief gate (run-gate.sh) with BRIEF_CHECK_SKIP, env-leak regression test (p4g)

brief_gate dry prints brief-check's whole output and fails on a FAIL; start refuses with
`brief-check failed: <first FAIL line>` unless BRIEF_CHECK_SKIP=<reason> (logged as a WARN).
Test: 8 cases incl. the wire tests with each limit variable exported.
```
