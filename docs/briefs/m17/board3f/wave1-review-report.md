# board3f wave-1 review: split (sim_report.dart)

## Summary

Verdict: small fixes.
Counts: must 0 · should 8 · could 3.
1. `sim_stats.dart:14` doc links `[runSimCell]`, which this file cannot resolve (dartdoc warning).
2. `sim_stats.dart:100` `CellTally` is now public with undocumented fields and `stats`; guidelines §10 applies.
3. `split-report.md:1` has no review-rules part A self-check, and the brief's named tests were not run by the worker (I ran them: 15 and 29 PASS lines, no failure lines).

## Findings

- **should** tools/sim/sim_stats.dart:14 The dartdoc says "Built by [runSimCell]", but `runSimCell` lives in sim_report.dart, which this file does not import → write it as plain text: "Built by `runSimCell` in sim_report.dart".
- **should** tools/sim/sim_stats.dart:100 `CellTally` is now public (was `_CellTally`) and its fields (lines 101-122) and `stats` (line 177) have no dartdoc → add a one-line dartdoc to each, or keep the fields private to the class.
- **should** docs/briefs/m17/board3f/split-report.md:1 The report has no part A self-check (review-rules.md §A, one line per item: host setups, kept state, state combinations, folder, stop, looks), which guidelines §11 requires → add the six lines; "not affected" is an acceptable answer for a pure move.
- **should** docs/briefs/m17/board3f/split-report.md:43 The brief's step 1 (baseline `dart test` of sim_report_test.dart) and step 4 (both test files) were not run; the worker relied on mine.sh → run the two named test files and put their result in the report (I computed: sim_report_test 15 PASS lines, 0 FAIL/error lines; night_sim_test 29 PASS lines, 0 FAIL/error lines; exit codes not captured, see Could not check).
- **should** tools/sim/sim_stats.dart:68 Line is 121+ columns; code is formatted at 120 → rewrap the doc comment.
- **should** tools/sim/sim_cell.dart:16 Line is 121+ columns (moved text) → rewrap the doc comment.
- **should** docs/code-health.md:386 Still says sim_report.dart is 361 lines and needs a split; line 394 says it is 423 lines and "split before its next change". Both are stale after this job → Claude to update when touching code-health; line 389 (comment lines over 120 columns in sim_report.dart at 77, 189, 218, 311) is also stale since the moved lines are now in other files.
- **should** docs/briefs/m17/board3f/run-findings.md:1 Entry says the split's report has no Summary block in its first 40 lines; that is a finding about this job, and the report still has no Summary block → add one (the wave-review format) to the next report.
- **could** tools/sim/sim_report.dart:1 Lines 1, 2, 29, 72, 110, 111 are also over 120 columns (carried over, not moved by this job) → rewrap when the file is next touched.
- **could** tools/sim/sim_cell.dart:1 Library doc line 2 is a fragment ("The population names, and the bots each population plays with.") → "It names the populations and gives the bots each one plays with."
- **could** tools/sim/sim_stats.dart:65 The doc on `rwPairs` says "(null shares below when zero)", but `rwPairs` is an int that is never null; the remark belongs on the share fields → move or reword it.

## Decisions to confirm

- `tools/sim/sim_report.dart:7-8` `export 'sim_stats.dart';` makes `CellTally` and `multiGateCount` public to every importer of sim_report.dart; guidelines §3 says export only what callers need. The brief asked for the export, so this is as briefed; Claude to confirm the wider surface is accepted.
- `tools/sim/sim_stats.dart:100` The rename `_CellTally` → `CellTally` was needed for the file boundary; a reader of the brief should know the tally is now public API.
- `multiGateCount` moved to sim_stats.dart (not named in the brief's move list); the worker's reason (only the tally uses it) holds, and the constant is still exported.
- The worker ran `tools/mine.sh` although the brief's stop line says "never tools/mine.sh" (the job's own instructions asked for it). Claude to confirm which rule wins.
- Removed `dart:math` and `bots.dart` imports from sim_report.dart: safe, since `dart analyze tools/sim` reports no issues.

## Could not check

- `dart run` was refused by the approval prompt, and the test files are plain `main()` scripts that `dart test` reports as "No tests were found" while printing PASS lines. I counted lines: sim_report_test 15 PASS, 0 FAIL/error/exception; night_sim_test 29 PASS, 0 FAIL/error/exception. Exit codes were not captured.
- Moved bodies were read, not diffed line by line; I did not prove byte-identical bodies.
- `tools/mine.sh` was not run by me (not one of this review's checks).
- `dart analyze tools/sim`: "No issues found!" (run by me, read-only).

Files changed by this review: none besides this report.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

Review board3f wave-1 split: findings only

Review of the sim_report.dart split against the guidelines and the brief.
Report written to docs/briefs/m17/board3f/wave1-review-report.md; no code
changed. Findings are for Claude to verify and act on.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- board3f wave-1 review of the split: done, verdict small fixes (0 must, 8 should, 3 could); open: the should items (CellTally dartdoc, dangling runSimCell link, 120-column comments, part A self-check, stale code-health lines, test runs with exit codes).

## Delete

- none
