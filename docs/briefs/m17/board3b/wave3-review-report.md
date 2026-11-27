# wave3 review: g3d2b (acae9fc2)

## Summary

small fixes
must 0 · should 6 · could 7
- tools/sim/sim_report_test.dart:181 The kids check would still pass if runSimCell ignored kidsRules (sim_report.dart:165), so brief item 2 is untested → add a check that a kids cell with standard rules matches one given kidsRules(standard).
- tools/sim/sim_report.dart:160 runSimCell takes a value object instead of the brief's seven named parameters: a brief/guideline conflict the worker decided alone → Claude confirms or amends the brief.
- tools/sim/sim_report.dart:201 The night_games column repeats games (line 196) → Claude drops it or defines it.

## Findings

- **should** tools/sim/sim_report_test.dart:181 The kids check reads only the reported flag, so a kids cell that skips kidsRules (tools/sim/sim_report.dart:165) passes every check → add a check that a kids cell with CityRules.standard gives the same CSV row as one given kidsRules(CityRules.standard), and confirm it fails without line 165.
- **should** tools/sim/sim_report.dart:201 night_games repeats games (line 196), and the config's game count is fixed, so the column carries no information → drop it from simCsvHeader (line 36) and this row, or define it (Claude decides; the brief names the column).
- **should** tools/sim/sim_report.dart:160 runSimCell(SimCell) replaces the brief's seven named parameters, a conflict between the brief and guidelines §3 that the guidelines say to report, not decide → Claude confirms the value object and amends the brief.
- **should** tools/sim/run_sim.dart:34 The argument rules (unknown option, missing value, N < 1, exit 2 at line 37) and runSimCell's nights < 1 throw (tools/sim/sim_report.dart:161) have no test, and Decision 9 states the behaviour as fact → add checks in a test file, or drop the claim from the report.
- **should** tools/sim/sim_report.dart:361 The file is 361 lines, over the about-300 target, and mixes five jobs (profiles 147-155, cell run 160-187, tally 269-346, CSV 35-38 and 189-216, matrix 218-266) → move the CSV header, row and number format into their own file in the same job.
- **should** tools/sim/sim_report.dart:77 Comment lines run past 120 columns (also sim_report.dart:189, 218, 311; sim_report_test.dart:1, 26; found by a line-length search) → rewrap them.
- **could** tools/sim/sim_report.dart:226 _matrixCells is 41 lines, just over the about-40 limit → split the three loops into named helpers.
- **could** tools/sim/sim_report.dart:19 Five public constants (matrixPlayerCounts 20, matrixGameCounts 23, freeRoadworksCost 26, csvDecimalPlaces 29, multiHitBlocks 32) are used only in this file → make them private (guidelines §3, public surface).
- **could** tools/sim/sim_report.dart:163 The local `kids` is a noun for a boolean → rename to `isKids` (guidelines §4).
- **could** tools/sim/run_sim.dart:21 The public `usage` constant has no dartdoc → add one line (guidelines §10).
- **could** tools/sim/run_sim.dart:40 The CSV is written with a hand-made `\n` line ending (guidelines §6 says line endings come from .gitattributes), and an existing `--out` file is overwritten silently → decide both; the overwrite is not in the Decisions list.
- **could** tools/sim/sim_report_test.dart:76 The determinism check compares two fields that the CSV row check (line 75) already covers, not the stats object the brief asks for → compare the stats, or drop the two extra fields.
- **could** tools/sim/sim_report_test.dart:66 Player and game counts 4, 5, 3 are literals in six places (lines 66-67, 84-85, 92-94, 129-130, 176-177, 206-207) → name them as test constants (guidelines §2).

## Decisions to confirm

- Decision 1 (tools/sim/sim_report.dart:160): value object instead of the brief's named parameters. It is the rule-compliant shape, but it was chosen without stopping, as §3 requires for a brief conflict.
- night_games (tools/sim/sim_report.dart:201): a duplicate column, see the Findings above.
- Decision 2 (tools/sim/sim_report.dart:164): a kids cell that asked for Roadworks writes `false`, so the CSV cannot tell it from a kids cell that did not ask. Accept it, or write the requested flag.
- Decision 9 (tools/sim/run_sim.dart:34-37): exit 2 and the usage line are untested (see the Findings above).
- Silent overwrite of `--out` (tools/sim/run_sim.dart:40-41): a decision the report does not list.
- Decision 6 (tools/sim/sim_report.dart:295): `midLeaders.first` depends on the Set keeping the ranking order that tools/sim/night_sim.dart:150-153 builds. That holds, but it is an implicit contract.

## Could not check

- I did not run sim-test.sh, dart format, dart analyze or mine.sh (read-only job). The 16 PASS lines and the 11 ms runtime are unverified. Runner evidence: docs/briefs/m17/board3b/run.log:116 records "sim-test, analyze, format green" for the hand-fixed commit.
- The mine.sh failure (report Question 1): tools/mine.sh:253 runs `dart test` per touched package; I did not run it.
- The counts were computed from the source, not run: 16 `check(` calls in sim_report_test.dart; matrix rows 2 x 6 x 2 + 6 + 6 = 36.
- sim_report_test.dart is new, so it "fails on the old code" only through the missing import (run.log:109); that is not a finding.
- The output of `docs/briefs/m17/board3b/g3d2b.md` item 5 (test output lines) is only summarised in the worker report, not copied.

## Commit message — a draft

m17 board3b wave3 review: g3d2b findings

- Read-only review of acae9fc2 against g3d2b.md, guidelines and review rules.
- 0 must, 6 should, 7 could; the kids-rules test gap and the night_games column are the main ones.
- No code changed; the findings go to Claude for the fixes and the signature decision.
- Commit only this report.

## Status row

wave3 review of g3d2b: done, 0 must, 6 should, 7 could. Open: kidsRules test gap, night_games column, value-object signature decision, untested run_sim rules, 361-line file split.

## Delete

- none
