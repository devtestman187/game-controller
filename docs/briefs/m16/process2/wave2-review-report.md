# Wave2 review: p2-mine, p2-wait, p2-stop

## Summary

Verdict: **small fixes** — all three jobs built every brief item and run green here (`tools/check.sh tools`
PASS, 104 s, which runs the three new self-tests through tools/selftest.sh); the misses are knobs that can
break a documented limit, an input check and a RESULT line the script rules require, and one test that
asserts less than its own name.
Counts: 0 must, 4 should, 7 could.
1. **Should** tools/run-stop.sh:121 — the STOP_* knobs can push STOP.md past the 40-line hard limit its
   header promises, and a non-numeric knob aborts before the file is written.
2. **Should** tools/wait-run.sh:43 — a failed `cd` prints no reason and no RESULT line; the three new test
   scripts repeat it with exit 2 (the timeout code), against script-rules.md:5-6.
3. **Should** tools/tests/mine-test.sh:131 — the renamed case never checks that the old basename's test
   still runs, the behaviour p2-mine-report.md:24 promises.

## Findings

- **should** tools/run-stop.sh:121 the 40-line hard limit of :20 is a fixed budget (7 + `STOP_LOG_TAIL` + capped sections), so `STOP_LOG_TAIL=60` writes a 69-line STOP.md, `STOP_MAX_LINES=10` still writes 29, and a non-numeric knob aborts in `$(( ))` before the write, with no RESULT line → check the four knobs are whole numbers and cap the tail at `STOP_MAX_LINES - 8` before computing `room`.
- **should** tools/wait-run.sh:174 `WAIT_STALL_MIN` (also `WAIT_POLL_S` at :267 and `WAIT_RECENT_ROWS` at :151) is used unvalidated, so `WAIT_STALL_MIN=abc` aborts with "abc: unbound variable" under `set -u` and prints no RESULT line (script-rules.md:5-6) → validate the three knobs up front like `MINE_TIMEOUT` (tools/mine.sh:44-48) and exit 3 through `bad`.
- **should** tools/wait-run.sh:43 `cd "$(dirname "$0")/.." || exit 3` gives no one-line reason and no RESULT line, and tools/tests/mine-test.sh:14, wait-run-test.sh:14 and run-stop-test.sh:14 do the same with exit 2 (the timeout code), against script-rules.md:5-6 → print `RESULT: BAD INPUT: ...` and exit 3 in all four, or move `bad` above the cd.
- **should** tools/tests/mine-test.sh:131 the case is named "a renamed file is formatted under its new path (and its tests still run)" but only the format paths are asserted, so p2-mine-report.md:24 decision 2 (old basenames keep their tests) has no test → also assert `grep -qF 'flutter test test/screen_test.dart' "$stub/log"`.
- **could** tools/wait-run.sh:249 every call starts with a `WAIT: ...` banner (and the `NOTE:` at :220), while p2-wait.md:24 asks it to print only the lines new since the last call, and neither line is under Decisions → keep `RESULT:` and the cap NOTE, drop the banner or list it as a decision.
- **could** tools/wait-run.sh:126 `unfinished_jobs` counts only `start <job>` lines, so a job the runner `resume`s (tools/run-jobs.sh:405) is never finished-tracked: exit 4 names "preflight (no job started yet)" while it runs and OVERRUN never fires for it → record a `resume <job>` line as that job's start time.
- **could** tools/tests/mine-test.sh:163 the only `.rc` stub is the test failure's, so mine.sh:207-209 (`FAILED dart format`) and :217-219 (`FAILED dart analyze`, the analyzer-error filter) print untested output → add one case with `dart-format.rc` and one with `dart-analyze.rc`.
- **could** tools/tests/wait-run-test.sh:22 `fail()` is defined and never called (`report` increments `fails` itself at :32), a leftover in a new file → delete the function or call it from `report`.
- **could** docs/briefs/m16/process2/p2-stop-report.md:104 the detail fixture's STOP.md is 32 lines, not 31: 4 head + 3 headings + 4 error lines (the `package:` line is excluded) + the outside section's "none found" + 20 run.log lines → correct the value.
- **could** docs/briefs/m16/process2/p2-wait-report.md:48 "Two env knobs beyond the brief's list" undercounts: `WAIT_MAX_S`, `WAIT_POLL_S`, `WAIT_EXPECT_DEFAULT_MIN`, `WAIT_RECENT_ROWS` and `RUN_WORK` (tools/wait-run.sh:27-31) also go beyond it → list them, or drop the ones no caller needs.
- **could** docs/briefs/m16/process2/p2-mine-report.md:93 the stray folder the mistyped path created (`E:\AI\game-controller-m16-jobs\flash-20261121-155004-86602`) still needs deleting and no owner action points at it → delete it (a review-rules A4 slip, disclosed by the worker).

## Decisions to confirm

- p2-wait-report.md:40 / p2-stop-report.md:71: waiting on run.log runs no git check and run-stop.sh takes no
  lock or timeout, although script-rules.md:8 asks for both — the reasons are sound; confirm the two exceptions.
- p2-mine-report.md:26: untracked churn stays in the change list — confirm that a test run leaving an untracked
  `site/shots/*.png` in a worker's status is acceptable.
- p2-wait-report.md:48–50: `WAIT_LOGS`/`WAIT_STATE_DIR` and the five knobs in the finding above are all extra
  surface — decide which are wanted before the driver scripts rely on them.
- tools/wait-run.sh:249: the per-call `WAIT:` banner and the `NOTE:` line are presentation choices the brief
  does not name — confirm.

## Could not check

- The per-case PASS lines and timings (44/29/18 s) of the three new self-tests: `bash tools/tests/<name>-test.sh`
  is refused by this session's Bash allow-list, so only the aggregate `tools/check.sh tools` PASS (104 s) was seen.
- Any script against a live batch or a real worker run: none is possible from this job.
- `E:\AI\game-controller-m16-jobs\flash-20261121-155004-86602` (outside the working directory; listing it is
  refused).
- A real `~/.thumbparty/flash-usage.tsv`: tools/flash.sh:135 and tools/flash_usage.dart:69-77 store the task's
  first line cut to 100 chars, so a brief path longer than that would never match tools/wait-run.sh:149 and
  OVERRUN would quietly use the 15-minute default; no real log was readable here.
- run-stop.sh's unwritable-folder branch (`chmod` is a no-op in this Git Bash; the job's report says the same).

## Commit message

```
Review wave2 (p2-mine, p2-wait, p2-stop): no must, four should

Read the three briefs, their reports and the diff 1f2973d..83b7bdd
against docs/coding-guidelines.md and docs/review-rules.md parts A and B,
and ran tools/check.sh tools (PASS, 104 s, all three new self-tests).
The shoulds: the STOP_* knobs can break STOP.md's 40-line limit, three
WAIT_* knobs abort unvalidated, four scripts skip the RESULT line on a
failed cd, and mine-test's renamed case does not check its test runs.
The coulds: the WAIT banner, resumed jobs, untested format/analyze output,
an unused fail(), two report values and the stray folder outside the repo.
Findings only; this report is the only file the job writes.
```

## Status row

**Wave2 review (Nov 21):** p2-mine, p2-wait and p2-stop checked against their briefs, the guidelines and review
rules A-B; `tools/check.sh tools` PASS (104 s, all three new self-tests); 11 findings, no must. Open: four should
fixes (knob validation in run-stop and wait-run, the missing RESULT on a failed cd, the renamed-case assertion)
and seven coulds (resume lines, untested format/analyze failures, unused `fail`, two report values, the extra
WAIT knobs, the stray folder outside the repo).

## Delete

- none
