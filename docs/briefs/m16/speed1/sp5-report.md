# M16 speed1 sp5 report: tools/job-metrics.sh gets a WALL column

## Summary

- `tools/job-metrics.sh`: new WALL column after MINUTES (start-to-finish minutes, one decimal). It reads the job's
  last `start <job>` or `resume <job>` line in run.log and the `<job> finished: result` line after it. `-` when there
  is no such pair, for a review log (`-review`, `wave<N>-review`), or when there is no run.log. `--append` adds
  `wall=<n>` after `min=` in each METRICS line. Header comment and `--help` range (2,37) updated.
- `tools/tests/job-wall-test.sh` (new): 8 cases, written first and run against the old tool (8 of 8 FAIL), then against
  the change (8 of 8 PASS).
- `tools/tests/job-metrics-test.sh`: the column list (ten columns now), the rows that gained the `-` WALL cell, and the
  METRICS greps (`wall=-`) updated. Its case names and the rest are unchanged.
- Checks: `bash tools/tests/job-wall-test.sh` RESULT ok 8/8; `bash tools/tests/job-metrics-test.sh` RESULT ok 10/10;
  `tools/mine.sh` ran with 0 files formatted, 0 packages analyzed, 0 tested (no Dart touched).
- Decisions: (1) a restart (`start`/`resume`) after a finish line with no new finish shows `-`, because the job has no
  finish after its last start; (2) WALL uses the job's last start or resume, as the brief says; (3) the day count is
  computed in awk from the run.log date, so a run past midnight is right; (4) no lines are added to run.log by the tool
  itself, only METRICS lines on `--append`.

## Test runs (red first)

The new test was run before the change. All eight cases FAIL, because the table had no WALL column:

```
FAIL a job started at 10:00:00 and finished at 10:07:30 shows WALL 7.5
FAIL a resumed job counts from its last resume line: 10:05:00 to 10:07:30 is 2.5
FAIL a job that runs past midnight counts across the date: 23:50:00 to 00:05:00 is 15.0
FAIL a job started again after its finish line, with no new finish, shows -
FAIL a job with a finish line and no start line shows -
FAIL a job with a start line and no finish line shows -
FAIL a job's name matches exactly: lines for jobx give job no WALL
FAIL a batch with no run.log shows - for every job
RESULT: FAILED: 8 of 8 case(s) failed
```

After the change, `bash tools/tests/job-wall-test.sh` gives `RESULT: ok: 8 case(s) passed`, and
`bash tools/tests/job-metrics-test.sh` gives `RESULT: ok: 10 case(s) passed` (the same ten case names as before).

Values computed for the expectations (seconds, then minutes):

- Job 10:00:00 to 10:07:30: 450 s, so 7.5.
- Resumed: start 10:00:00, resume 10:02:00, resume 10:05:00, finish 10:07:30: counts from 10:05:00, 150 s, so 2.5.
- Midnight: 2026-11-23 23:50:00 to 2026-11-24 00:05:00: 900 s, so 15.0.
- Table fixtures (from the existing test): 1234 s is 20.6 min; 1386 s is 23.1 min; cache 50000 + 7000 = 57000;
  9000 + 1000 = 10000. WALL is `-` for all of them, since their batch has no run.log job pair.

## Self-check (docs/review-rules.md part A)

1. Host setups: not applicable, a shell tool with no host; covered by the test folder with and without run.log.
2. Kept state: none; the tool reads run.log and writes only METRICS lines on `--append` (test 7 in job-metrics-test.sh).
3. Combinations: restart after finish, resume, past midnight, jobx prefix, no run.log (job-wall-test.sh cases 2-8).
4. Files: only the five allowed paths were changed (see FILES below); `git status` shows the three tool files.
5. Stops: none.
6. Looks: not applicable (no UI).

## Files changed

- `tools/job-metrics.sh`: WALL column and `wall=` in METRICS; `wall_minutes` helper (awk, run.log); header comment and help range.
- `tools/tests/job-wall-test.sh`: new, 8 cases for WALL.
- `tools/tests/job-metrics-test.sh`: ten-column header, rows with the WALL cell, METRICS greps with `wall=-`.

## Hand-over

- Not run: `tools/check.sh` (the brief says the script runs its format step after the job).
- Pre-existing: three grep lines in `tools/tests/job-metrics-test.sh` (the METRICS checks in case 7) are over 120 columns; they were already, and adding `wall=-` makes them longer. Left as they were.

## Questions

1. `tools/mine.sh` printed `churn: reverted 22 generated file(s)` on its first run. The 22 files are the ones that the session's
   starting git status listed as modified (docs/design/*.png, site/shots/*.png, tv_test_app/windows/flutter/generated_plugin_registrant.* and
   generated_plugins.cmake). They are not in this worktree's status now. I did not run any git command to check or restore them, because git
   changes are not allowed here. Please confirm whether those were the user's uncommitted work and whether they need restoring from another checkout.
2. docs/briefs/templates/COMMON.md asks for `## Summary` first and `## Hand-over` last. This brief asks for three closing sections. I gave both: Summary first, then the three sections at the end (Hand-over is inside the body).
3. Should a restart after a finish with no new finish show `-` (as here) or the old finish time? I chose `-`.
4. The `--help` range (`sed -n '2,37p'`) is a hard line number; any future header change needs it updated. Worth a test, or a range that stops at the first blank line?

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
tools: job-metrics.sh gets a WALL column (start-to-finish minutes)
  
Owner decision (Nov 23): the batch table shows wall time next to model
minutes, because checks and waits are 35-70% of a wave.
WALL is minutes from the job's last start or resume line in run.log to
its finish line, one decimal; - for review logs and when a pair is
missing. --append adds wall=<n> to each METRICS line.
job-wall-test.sh (new) is written red first: 8 of 8 failed on the old
tool, 8 of 8 pass now; job-metrics-test.sh 10 of 10 with the new columns.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 speed1 sp5 done: job-metrics.sh has a WALL column and METRICS wall=, job-wall-test 8/8 and job-metrics-test 10/10 pass; open: tools/check.sh format is run by the script after the job, and 22 generated files reverted by mine.sh need the owner's check (Questions 1).

## Delete

- none
