# p3c report: the run's limits (tools/run-limits.sh), the watched combined check, the review limit

## Summary

- NEW `tools/run-limits.sh` (sourced, no side effects): `run_expected_min <brief>` (the brief's
  `expected-min:` line, else the usage median, else `RUN_EXPECT_DEFAULT_MIN` 20), `run_job_limit_s
  <brief>` (the estimate x `RUN_JOB_FACTOR_PCT` 150%, in `RUN_LIMIT_UNIT_S`-second "minutes") and
  `run_backstop_min <waves.txt>` (the estimates of the jobs in neither `done.txt` nor `dropped.txt`,
  +25%, rounded up). Env knobs: `RUN_JOB_FACTOR_PCT` 150, `RUN_CHECK_MAX_MIN` 12, `RUN_REVIEW_MAX_MIN`
  10, `RUN_EXPECT_DEFAULT_MIN` 20, `RUN_POLL_S` 5, plus `RUN_LIMIT_UNIT_S` 60, `RUN_RECENT_ROWS` 30
  and `FLASH_USAGE_LOG` (the median's inputs, as tools/wait-run.sh has them).
- `tools/run-steps.sh`: the combined check now runs in the background under `check_once`, with
  `CHECK_FAIL_FAST=1`, and is polled every `RUN_POLL_S` for `check_stop` (RUN_MAX_MIN and the STOP
  file, so both are seen *during* the check) and for `RUN_CHECK_MAX_MIN`; the limit kills the check's
  tree and stops with `CHECK TIMEOUT: the combined check passed RUN_CHECK_MAX_MIN=12 min ...`. The
  PathNotFoundException and "fetch packages" retries are unchanged and also watched.
- `tools/run-review.sh`: `run_review` waits under `RUN_REVIEW_MAX_MIN` (`review_over`) and stops with
  `REVIEW TIMEOUT: ...`; both flash calls use `${FLASH_CMD:-tools/flash.sh}`.
- NEW `tools/tests/run-limits-test.sh`: six cases in 7 s, one per rule (below).
- Checks: `tools/selftest.sh tools/tests` 8/8 (run-limits-test 7 s, run-wire-test 136 s);
  `tools/check.sh tools` PASS (250 s). Tests-first: on the old tools the new script failed all six
  cases (log: "FAIL ... (2 min = 2 s, 30s)", "FAIL ... (31s)").
- Limits found by the arithmetic for this very batch: 175 min of estimates -> backstop 219 min
  (218.75 rounded up); p3c's own job limit 40 x 1.5 = 60 min.

## Files changed

| file | change |
|---|---|
| `tools/run-limits.sh` | NEW: the three helpers, the RUN_* defaults and their doc header |
| `tools/run-steps.sh` | NEW `check_once` (background check, poll, RUN_CHECK_MAX_MIN kill); `checks()` uses it twice; the limits file is sourced, guarded, at the top (242 lines) |
| `tools/run-review.sh` | NEW `review_over`; `run_review` polls at `RUN_POLL_S` and stops at `RUN_REVIEW_MAX_MIN`; `${FLASH_CMD:-tools/flash.sh}` in `start_reviews` and `run_review` (141 lines) |
| `tools/tests/run-limits-test.sh` | NEW: the six cases |

## Decisions

1. **`run_job_limit_s` and `run_expected_min` take a brief path.** The brief row lists
   `run_job_limit_s` without an argument; a limit cannot be read from a job name the caller does not
   pass, so both take the brief path (p3d calls `run_job_limit_s "$B/$j.md"`). Both print one whole
   number on stdout and log nothing.
2. **The limits file is sourced by the helpers, not by `run-jobs.sh` (which p3c may not edit).**
   `run-steps.sh` and `run-review.sh` source it from `$dir` when it is there. `run-jobs.sh` should
   source it too (p3d, for the backstop); a second source is the same assignments.
3. **The guarded source ("no file, no own limit").** `tools/tests/run-wire-test.sh` and
   `run-jobs-split-test.sh` copy four runner files into a fake repo, without `tools/run-limits.sh`; a
   plain source there would exit 2 and fail all their cases. So: file present, limits apply; file
   absent, `RUN_CHECK_MAX_MIN`/`RUN_REVIEW_MAX_MIN` are unset and the steps behave as before
   (`limit_s=0`, poll 1 s). p3d needs the same guard in `run-jobs.sh`.
4. **Rounding.** `run_job_limit_s` and the backstop round *down* to whole seconds/minutes
   (`s = mins * pct * unit / 100`, floored at 1 s: a 0 s limit would stop every job at once), the
   backstop itself rounds *up* to a whole minute (`(total * 125 + 99) / 100`): a run that needs 62.5
   min must be allowed its 63rd minute. A median under a minute is no estimate for a limit, so the
   default stands (`RUN_EXPECT_DEFAULT_MIN`).
5. **`RUN_BACKSTOP_PCT=125` is a constant, not an env knob:** the owner fixed the +25%; the test
   computes it from fake briefs instead.
6. **Wall clock for the polling.** `date +%s` (not `SECONDS`), so the fixture's fake clock in
   run-wire-test case 13 keeps working; the limit is `RUN_CHECK_MAX_MIN * RUN_LIMIT_UNIT_S` seconds.
7. **The "9th minute" of a unit.** `RUN_LIMIT_UNIT_S` is read by every limit, so a test gets 12 min
   in 12 s. `RUN_POLL_S` doubles as the review poll (was a bare `5`).
8. **The STOP file during the check** relies on the runner's own `stop`: it kills `jobs -p`, and the
   background `tools/check.sh` is one of them. The limit path kills the tree itself (`kill_tree`)
   before `stop`, since the reason is not the runner's stop.
9. **Extra env knobs** `RUN_RECENT_ROWS` and `FLASH_USAGE_LOG` were not in the brief's list; they are
   the median's inputs and `tools/wait-run.sh` already names both. `RUN_RECENT_ROWS` defaults to the
   same 30 rows.

## Computed test values (`tools/tests/run-limits-test.sh`)

Fake briefs: a 10, b 20, c 4 (done), d 6 (dropped), e none, f 7, g none, h none.

| case | computed | formula |
|---|---|---|
| backstop, a b c d e | **63** | undone a 10 + b 20 + e default 20 = 50; 50 x 125 = 6250; (6250 + 99) / 100 = 63 |
| backstop, no done/dropped | **75** | 10 + 20 + 4 + 6 + 20 = 60; (7500 + 99) / 100 = 75 |
| expected minutes f / g / h | **7 / 15 / 20** | f's line; g's rows 600 s and 1200 s, median 900 s = 15; h has neither |
| job limit a, unit 60 / unit 1 | **900 / 15** | 10 x 150 x 60 / 100 = 900 s; 10 x 150 x 1 / 100 = 15 |
| combined check, RUN_CHECK_MAX_MIN 2 | stopped in about **2 s** | 2 x RUN_LIMIT_UNIT_S 1; poll 1 s; check.sh and its `sleep 30` child gone |
| STOP file at 1 s into the check | stopped in about **1 s** | limit 30 s, so the STOP file is what ended it |
| this batch (`docs/briefs/m16/process3`) | **219** | 30+25+40+45+20+15 = 175; (21875 + 99) / 100 = 219 (was the fixed 360) |

The whole new script runs in **7 s** (under the 20 s the brief asks for); no real minute is waited.

## Checks

- `tools/selftest.sh tools/tests`: 8 of 8 PASS, 264 s (run-limits-test 7 s, run-wire-test 136 s).
- `tools/check.sh tools`: PASS, 250 s (after the fix; before it, FAIL on the new script's six cases).
- Tests-first: the new script run against the old tools (before `tools/run-limits.sh` existed) printed
  `FAIL` for all six cases: backstop 63, backstop 75, expected minutes, job limit, the check limit
  ("2 min = 2 s, 30s": the old `checks()` let the stand-in check sleep its whole 30 s), and the STOP
  file ("31s").
- `tools/review.sh` scans `.dart` files only (`in_scope`), so the four shell files cannot produce a
  FAIL line from it; I did not run it (not in the allow list) and the combined check above shows no
  FAIL for this tree.

## Self-check (docs/review-rules.md part A)

1. Host setup (TV, PC, phone variants, joined phone, older peer): not applicable, no app code and no
   UI in this job; the change is four shell files.
2. When kept state starts and ends: no kept state; `RUN_*` are set at source and read per call. A run
   with nothing going on never calls a helper (`tools/run-limits.sh` adds no work when sourced).
3. Combinations with pause menu, host away, "Get ready", results, leaving: not applicable, no game
   state; the runner's own states are covered by `tools/tests/run-wire-test.sh` (all 13 cases pass:
   stop file, RUN_MAX_MIN, review wait, lock).
4. Stayed inside `allow:` and the job's folder: yes, the four files above only.
5. Stop rather than overstep: did not edit `tools/run-jobs.sh` (p3d's), `tools/run-stop.sh` (its
   timeout class does not know a check/review timeout: see Questions) or the two fixture tests (their
   four-file copy is why the source is guarded).
6. Every look (menu and TV): not applicable, no widget or layout changed.

## Hand-over

- p3d: source `tools/run-limits.sh` in `tools/run-jobs.sh` with the same `[ -f ]` guard (the fixture
  tests copy four files), use `run_backstop_min "$B/waves.txt"` for the RUN_MAX_MIN default (219 min
  for process3 today) and `run_job_limit_s "$B/$j.md"` for a job's limit (seconds; `RUN_LIMIT_UNIT_S`
  makes it testable in a few seconds).
- p3d's new fixture must copy `tools/run-limits.sh` as well, or its cases will see no limits.
- `CHECK_FAIL_FAST=1` is set by `check_once` already; it only has an effect once p3b's `check.sh` is
  in the tree (not in this base), and it changes nothing until then.

## Questions

1. A check or review timeout lands in `tools/run-stop.sh`'s `timeout` class (its `*TIMEOUT*` match)
   and so gets the repair text about `RUN_MAX_MIN`; the class list has no check/review limit class.
   `run-stop.sh` is outside my `allow:`, so I left it. Should a later job add a class (or the cause
   text be reworded)?
2. Wave reviews (`start_reviews`) run in the background chain and have no limit of their own; only the
   run's review has `RUN_REVIEW_MAX_MIN`. Two reviews run at most, so a stuck one holds a slot
   forever. Is a limit for them wanted (a later job, with a way to kill the chain)?
3. `RUN_RECENT_ROWS` and `FLASH_USAGE_LOG` are extra env knobs beyond the brief's five; if that is not
   wanted, the median can read a constant row count instead.

## Suggestions

- `tools/run-stop.sh`'s `timeout` repair text could name both `RUN_MAX_MIN` and the per-step limits
  once question 1 is answered.
- `tools/wait-run.sh` has the same estimate rule as `run_expected_min` (brief line, usage median,
  default) with its own default of 15 min; after this job it could call `tools/run-limits.sh` and drop
  the second copy (its brief was p3a's, so I left it alone).

## Commit message

```
tools: run-limits.sh, a watched combined check and a review limit

Add tools/run-limits.sh: a job's expected minutes (its brief's expected-min:
line, else the usage median, else 20), its limit (x1.5) and the whole run's
backstop (the undone jobs' estimates +25%), all in RUN_LIMIT_UNIT_S-second
"minutes" so a test can cover minutes in seconds.
tools/run-steps.sh runs tools/check.sh in the background with CHECK_FAIL_FAST
and polls it for the STOP file, RUN_MAX_MIN and the combined check's own 12 min.
tools/run-review.sh stops a review after 10 min and uses ${FLASH_CMD}.
New tools/tests/run-limits-test.sh proves all of it in 7 s.
```

## Status row

p3c done: `tools/run-limits.sh` (estimates, a job's limit, the backstop), the combined check watched in `run-steps.sh` (STOP file, RUN_MAX_MIN, RUN_CHECK_MAX_MIN) and `run-review.sh`'s review limit plus `FLASH_CMD`; open: p3d must source `run-limits.sh` in `run-jobs.sh` (guarded) for the backstop and the per-job limit, and run-stop.sh still has no class for a step timeout.

## Delete

- none
