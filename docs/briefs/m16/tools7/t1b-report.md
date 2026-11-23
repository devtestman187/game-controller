# t1b report: load-tolerant, faster run-gate, wait-run, run-worker-switch and process3-fix1 tests

## Summary

STATUS: stopped. No test script was edited, and no test script could be run in this job.

- Blocked: running any of the four test scripts (`bash tools/tests/<name>.sh`, or the script run directly) was refused with "This command requires approval". The same refusal came for `tools/tests/run-gate-test.sh` by its path. So the "before" timings (step 1) could not be measured.
- Without the baseline runs, the refactor cannot be checked: the brief requires each case to keep its name and assertion, and the leak case (run-gate-test.sh 218-250) to keep working. Changing four shell test files that I cannot run would mean shipping unverified test changes, so I did not edit them.
- Ran and passed: `tools/check.sh format` → PASS (13s).
- Not run: the four scripts (before and after), `selftest-limits-test.sh`, `run-jobs-split-test.sh`, and the flake repeats.

Decisions: none taken in code. I read the brief, the templates/COMMON.md rules, `docs/briefs/m16/tools7/context.md`, and the lessons (19-21 in docs/flash-lessons.md; those lessons concern size gates and fixture analyzer-cleanness, not the test timing work).

## Checks

| Check | Result |
|---|---|
| `tools/check.sh format` | PASS (13s) |
| run-gate-test.sh before / after | not run (approval refused) |
| wait-run-test.sh before / after | not run (approval refused) |
| run-worker-switch-test.sh before / after | not run (approval refused) |
| process3-fix1-test.sh before / after | not run (approval refused) |
| selftest-limits-test.sh, run-jobs-split-test.sh | not run (approval refused) |

Seconds before and after: not measured.

## Self-check (review-rules part A)

Not applicable: no code or test changed. The one run was the format check.

## Files changed

None.

## Hand-over

To finish the job, run each of the four scripts once for a baseline (timed with `date +%s`), then apply the template change (fixture built once into a template folder, copied per case with `cp -r`), replace file/log waits with 0.1 s polls capped and failing on the cap, shorten stub sleeps only to the smallest value that still passes each case's own limit logic, then re-run all four twice plus `selftest-limits-test.sh` and `run-jobs-split-test.sh`. The job needs approval for the test-script runs to go ahead.

## Questions

1. Can the test script runs (`bash tools/tests/<name>.sh`) be pre-approved for this job, so the baseline and after timings can be taken?

## Commit message — a draft

tools7 t1b: build each runner test fixture once, poll for waits (NOT COMMITTED: job stopped before edits)

Not drafted as a commit: no test file changed. If the job is resumed, the subject would be:
tools7 t1b: fixture template per test, polls instead of sleeps in four runner tests

## Status row

tools7 t1b: stopped before any edit; format check PASS; the four test scripts could not be run (approval refused), so the timing and the refactor are open.

## Delete

- none
