# Review of wave1 sp2 (tools/affected.sh) and sp5 (job-metrics WALL column)

## Summary

small fixes
must 1 · should 3 · could 4
1. tools/tests/affected-test.sh:90 — three "gives no suite" cases pass with tools/affected.sh absent (they expect empty output); add an exit-0 check.
2. tools/tests/job-metrics-test.sh:126 — no case shows a numeric `wall=` written by `--append`; a broken METRICS wiring passes all 10 cases.
3. tools/churn.sh:58 via tools/mine.sh — sp2's run reverted 22 files that were modified when it started; the owner must confirm no wanted work was lost.
Tests re-run here: affected-test 37 cases, 0 failed; job-wall-test 8 of 8 ok; job-metrics-test 10 of 10 ok.

## Findings

- **must** tools/tests/affected-test.sh:90 `docs/ gives no suite` (also :91 top-level .md, :118 clean tree) expect empty output, so they pass when tools/affected.sh is missing (the sp2 report's red run shows 34 FAIL of 37, so these 3 passed without the script) → add an exit-0 assert to each, so a missing script (exit 127) fails.
- **should** tools/tests/job-metrics-test.sh:126 every METRICS check expects `wall=-`, so no test shows `wall=<n>` written by `--append` (the brief's `wall=<n>`; the worked values are 7.5, 2.5, 15.0) → add a case with a start and finish pair in run.log and grep for `wall=7.5`.
- **should** tools/tests/job-metrics-test.sh:126-128 three grep strings run past 120 columns (the 120-column rule; the sp5 report calls them pre-existing, and the `wall=-` edit made them longer) → split each string across lines.
- **should** docs/briefs/m16/speed1/sp2-report.md:56 and :80 say `affected-out.tmp` in the repo root is a leftover to delete; the file is not there now (checked: no such file, and `git status` shows only the three tv_test_app generated files) → drop it from the hand-over and the status row.
- **could** tools/affected.sh:74-75 only `path:` values starting with `.` count as dependencies, so a valid `path: packages/x` is silently ignored → accept any relative path that resolves inside the repo, or say the limit in the header.
- **could** tools/tests/affected-test.sh:130-135 the real-repo expectations copy the suite list and the eight package folders, so adding a suite or package breaks the test with no change in behaviour → derive them from `bash tools/check.sh --list`.
- **could** tools/job-metrics.sh:82-89 the calendar constants (400, 153, 146097, 365, 146097 era step) have no reason in a comment → one line naming the days-from-civil algorithm it follows.
- **could** tools/job-metrics.sh:112-160 `read_log` is 49 lines against the guideline's about 40 → move the detail block (lines 151-158, the JSON subtype and terminal reason) into a helper.

## Decisions to confirm

- tools/mine.sh churn step (tools/churn.sh:43-62, run by sp2): 22 generated paths that were modified when sp2 started were reverted with `git checkout --`; the rule is designed to do this, but the owner should confirm nothing wanted was lost (docs/design PNGs, site/shots).
- tools/affected.sh:42 and :123 hard-wire the `tools` suite name and the two script paths; the brief asked for this, so confirm it stays if a new tool-only suite is added.
- tools/affected.sh:74 counts a dependency only when `path:` starts with `.` (see the could above); hosted packages are ignored on purpose.
- tools/job-metrics.sh:96-97 WALL is `-` for a job restarted after its finish line with no new finish; the brief is silent, and sp5 lists it as decision 1. Confirm `-` rather than the old finish time.

## Could not check

- The red runs (sp2: 34 FAIL; sp5: 8 FAIL) cannot be replayed without the old scripts; sp2's count matches 37 cases minus the 3 that pass without the script, and sp5's old table had no WALL cell, so the cases fail for that reason, but I did not reproduce either run.
- Whether the 22 files sp2's churn step reverted held uncommitted work when the job started: there is no snapshot in the repo.
- The real-repo expectations in affected-test.sh passed here, but I did not check the pubspec graph by hand.
- docs/briefs/m16/speed1/run-findings.md does not exist, so no run-findings entries were read.
- The brief asks for the report in four sections "in this order and nothing else"; the task also asks for the three closing sections below, which I added.

## Commit message — a draft

docs: review report for wave1 sp2 and sp5 (M16 speed1)

Read-only review of the sp2 (tools/affected.sh) and sp5 (job-metrics
WALL column) jobs against the guidelines, the review rules and their
briefs. Findings: one must (three affected-test cases pass without the
script), three should (no test for a numeric METRICS wall=, three lines
over 120 columns, a stale leftover claim in sp2's report), four could.
Only the report is written; no code or test changed.

## Status row

wave1-sp2-review: done (1 must, 3 should, 4 could; tests re-run: affected 37/0, job-wall 8/8, job-metrics 10/10). Open: fix the must and should items in sp2/sp5, and the owner's check of the 22 files mine.sh's churn step reverted.

## Delete

- none
