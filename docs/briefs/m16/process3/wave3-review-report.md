# Wave 3 review: p3f (the runner refuses a wave whose base does not compile)

## Summary

- Verdict: **small fixes**.
- Counts: must 0 · should 2 · could 4.
- The new test script runs in 29 s (34 s on its tests-first run) against the brief's "Under 20 s" (p3f.md:11), and
  the report states the number without naming the miss.
- The report's "so the tree kill works" (p3f-report.md:23) is not what the test measures: `wait` returns when the
  direct child dies, so case 4 would pass with a plain `kill` too.
- `tools/run-jobs.sh:92` sources the helper without the `|| exit 2` of the sources above it, so a `run-base.sh` that
  fails to source leaves the runner with no base check and no message.

## Findings

- **should** docs/briefs/m16/process3/p3f-report.md:18 the script's 29 s (and 34 s in its own tests-first run) is over
  the brief's "Under 20 s." (p3f.md:11), and neither the report nor the hand-over says the budget was not met → cut the
  four fixtures' start-up cost (one shared fixture, or fewer runner runs) to get under 20 s, or state why it cannot be.
- **should** tools/tests/run-base-test.sh:172 case 4's only timing assertion is `elapsed_s -lt 20`, which also passes
  if `run_base_check` sends a plain `kill`: `wait` returns as soon as the direct child (the stub) dies and its
  `sleep 10` grandchild (line 69) keeps running → have the stub start a grandchild that writes a marker file after a
  few seconds, then assert after the run that the marker never appears, which is what the report's tree-kill claim
  needs.
- **could** tools/run-jobs.sh:92 the guarded source has no `|| exit 2`, unlike the three sources above it (lines
  86-88), so a `run-base.sh` that fails to source leaves the runner with no base check and no message → use
  `[ -f "$dir/run-base.sh" ] && { . "$dir/run-base.sh" || exit 2; }`.
- **could** tools/run-jobs.sh:59 the added header line is 136 columns, the only line of the header block over 120 (the
  block wraps at 120 or less and `-h` prints it, line 111) → wrap it over two lines.
- **could** docs/dev-tools.md:448 the paragraph says the check is "watched against `RUN_BASE_CHECK_MAX_MIN` (5 min)"
  but not what happens past it, while the code and test 4 stop the run with `the base check passed its limit
  (RUN_BASE_CHECK_MAX_MIN=<n> min)` after killing the tree → add that stop to the sentence.
- **could** tools/run-base.sh:31 the header says the helper can be sourced on its own, but `RUN_LIMIT_UNIT_S` is only
  validated by tools/run-limits.sh (run-limits.sh:44): a non-numeric unit makes the `$(( ))` fail, leaves `limit_s`
  empty, skips the clamp on line 32 and the limit never fires → validate the unit the way `RUN_BASE_CHECK_MAX_MIN` is
  validated on line 19.

## Decisions to confirm

- `RUN_BASE_WHY` as a caller-read global (report decision 1): safe as used (cleared at entry, read only after a
  non-zero return) but it splits the result between exit code and shell variable; confirm that is preferred to an
  out-variable name passed in.
- "a 0 min limit is raised to 1 s" is in the Summary (p3f-report.md:7) but not under Decisions; confirm that
  `RUN_BASE_CHECK_MAX_MIN=0` meaning one second, rather than no limit, is what the owner wants.
- The base check runs on a restart where every job is already done (report Hand-over, p3f-report.md:89-91): up to 5 min
  of format and analyze before a "DONE"; confirm whether it should be skipped when the wave has nothing left to start.
- Decision 4 (order): the base check runs before the "more than 3 jobs" guard, so a misconfigured `waves.txt` waits up
  to the full limit before the cheap refusal; safe, but confirm the order is intended.

## Could not check

- Running the new test: `bash tools/tests/run-base-test.sh` and the script itself both need approval in this review
  sandbox, so the 4 PASS lines, the 29 s and the tests-first 34 s with 4 FAIL lines are the report's own numbers; by
  reading, every case asserts the new log, note or STOP, so none passes on the old runner.
- `tools/check.sh tools` (the report's 355 s) and `tools/review.sh` were not re-run, for the same reason.
- The real cost of `dart format` plus `dart analyze` of this workspace was not measured, so whether the 5 min default
  is generous is not checked.

## Commit message

review: wave 3 p3f, the base check (findings only)

Reviewed tools/run-base.sh, its wiring in tools/run-jobs.sh, the new
tools/tests/run-base-test.sh and docs/dev-tools.md against the brief, the
guidelines and the review rules. No must; two should (the test's 29 s against
the briefed 20 s, and a tree-kill claim the test does not measure) and four
could (the unguarded source, a 136-column header line, the undocumented
over-limit stop, the unvalidated unit). This report is the only change.

## Status row

wave3 review done (p3f, findings only: 0 must, 2 should, 4 could); open: the two shoulds and the four coulds for p3f,
and the process3 run review.

## Delete

- none
