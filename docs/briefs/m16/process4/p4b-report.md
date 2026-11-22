# p4b report (hand-finished by the driver)

The worker was stopped at its limit (52 min, estimate 35) before writing a report. Its tree held tools/probe-deps.sh (342 lines), tools/tests/probe-deps-test.sh (260 lines) and fixtures under tools/tests/fixtures/probe-deps/. The driver copied them from the kept tree, ran the test (14 cases pass, 23 s) and tools/review.sh (0 fail). The full `tools` suite runs with the batch check. Not verified: probe-deps on the real identity1 history (rehearsal 2c/2d).

## Commit message

```
tools: probe-deps.sh, the stub-patch dependence check of a batch

Add tools/probe-deps.sh: applies a brief's probe: stub in a throwaway worktree, runs the
workspace dart analyze and the review.sh layer rules, and FAILs when an error file is in no
job's allow, or only in a same-wave or later job's allow (a dependence). PROBE_MAX_MIN,
exit 0/1/2/3. Test with 14 cases and fixtures under tools/tests/fixtures/probe-deps.
Hand-finished after the worker passed its limit.
```
