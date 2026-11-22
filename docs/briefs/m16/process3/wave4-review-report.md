# Wave 4 review: f1 (every job's limit in one poll, no retry for format/analyze, run's review not a job)

## Summary

- Verdict: **small fixes**.
- Counts: must 0 · should 4 · could 5.
- `tools/run-jobs.sh:352` tests every pending job's limit before asking whether that job has exited, so a job that
  finished inside the last poll, a second past its limit, is stopped as over its limit and its wave is lost.
- `tools/run-steps.sh:129` still retries a check that failed with no suite named in the log (a check.sh that died
  before the first suite), where the brief says retry only "when the log shows a failing suite".
- The report has no part A self-check, and neither it nor `run.log` shows the tests-first FAIL lines the brief's
  `tests-first: exempt` depends on.

## Findings

- **should** tools/run-jobs.sh:352 the poll stops a job whose limit has passed before it checks whether that job has
  exited, so a job that wrote its report and ended in the second before the poll is stopped as over its limit (the
  old per-job `while kill -0` accepted a job once it was gone) → test `kill -0` (or `wait -n`) first and only limit-stop
  a job still running, with a case where the job ends just past its limit inside one poll.
- **should** docs/briefs/m16/process3/f1-report.md:5 the report has no `## Self-check` block for review-rules part A
  items 1-6 (COMMON.md:7), unlike all six p3 reports → add the six lines, items 1, 3 and 6 being "not affected: shell
  tools".
- **should** docs/briefs/m16/process3/f1-report.md:9 the new script's 26 s is over the brief's "Whole script under
  25 s." (f1.md:12) and neither the report nor process3-fix1-test.sh:20 ("about 25 s") names the miss → cut the
  fixtures' cost to get under 25 s, or say why it cannot be.
- **should** docs/briefs/m16/process3/f1-report.md:12 the tests-first exemption (f1.md:4) turns on the new script
  showing FAIL lines against the old tools, and no recorded output has them (run.log:91 only says both test scripts
  pass; the report says "not re-verified by the driver") → run the four cases against a39fb18b and record the FAILs.
- **could** tools/run-steps.sh:129 excluding only `format` and `analyze` retries every other failed check, including a
  check.sh that exits before any suite prints a `FAIL` line, where the brief says retry only "when the log shows a
  failing suite other than format and analyze" → retry only when a `FAIL <suite>` line names a suite.
- **could** tools/run-steps.sh:131 `${bad% }` strips a trailing space that no `awk` output has, so the expression is a
  no-op in the stop text → write `${bad}`.
- **could** tools/run-steps.sh:132 the "(see …); nothing of this wave is committed" sentence goes in as `stop`'s second
  argument, which is the flash-log path and is dropped when it names no file (run-jobs.sh:151, 153), so it reaches
  neither STOP.md nor run.log (lines 139 and 144 lose theirs the same way) → pass the whole cause in one string.
- **could** docs/dev-tools.md:448 the paragraph still says the runner "runs `tools/check.sh` (once more after fetching
  packages if it fails)", which the new code never does for a format or analyze failure, and :149 does not list
  tools/tests/process3-fix1-test.sh among the self-tests → update both sentences.
- **could** docs/briefs/m16/process3/f1-report.md:30 the report ends at its commit message, with no STATUS row and no
  Delete section (the three closing sections a report ends with) → add both, as "wave 3 review" does.

## Decisions to confirm

- The new stop's wording (tools/run-steps.sh:131) is "checks failed on the combined tree after <jobs>: format cannot be
  fixed by a retry", not the "same stop text" f1.md:10 asked for; run-stop.sh:50's `*"checks failed"*` still classes it
  check-failed, so only the message changes — confirm the wording is what you want.
- tools/tests/run-jobs-split-test.sh:162 raises the runner's size promise from 380 to 400 lines for a 398-line runner
  (brief item 5 allowed it); confirm the next addition to tools/run-jobs.sh is a split, as the report's nit says.
- Case 3 of tools/tests/process3-fix1-test.sh:167 covers the suite retry, which the job did not change, so it passes on
  the old runner by design; only cases 1, 2 and 4 prove the fix (f1.md:12 asked for the case).

## Could not check

- Running anything: this sandbox refuses `bash tools/tests/…`, so only `bash -n` ran (PASS on the four changed
  scripts); the report's 4 PASS / 26 s and the FAIL-on-old-tools lines are its own numbers. By reading, cases 1, 2 and
  4 fail on the old code: the old per-job loop only looked at `quick` after `slow` ended (run-jobs.sh's old loop),
  `checks()` always fetched and re-ran, and wait-run parsed "the run's review" as a job, so 26 min > 1.5 × 15 OVERRAN
  (exit 2, not 4).
- The worker's worktree and log (flash-20261122-060044-645598) are not in this folder, so what the worker saw when it
  ran the new script against the old tools cannot be read.
- `docs/briefs/m16/process3/run-findings.md` does not exist, so there are no "passes on the old code" entries to fold
  in.

## Commit message

review: wave 4 f1, the runner's limits, retry and review state

Reviewed tools/run-jobs.sh's one-poll wave wait, tools/run-steps.sh's
format/analyze stop, tools/wait-run.sh's `reviewing` state, the new
tools/tests/process3-fix1-test.sh and the split test's 400-line limit against
f1.md, the guidelines and the review rules. No must; four should (the limit
check ahead of the exit check, the missing self-check, the 26 s against the
briefed 25 s, the unproved tests-first FAIL lines) and five could. This report
is the only change.

## Status row

wave4 review done (f1, findings only: 0 must, 4 should, 5 could); open: the four shoulds and five coulds for f1, and
the process3 run review.

## Delete

- none
