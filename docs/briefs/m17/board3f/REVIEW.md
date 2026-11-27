# board3f run review

## Summary

Verdict: needs Claude's design. One must (the new test file fails the gate); the rest is one fix batch in five files.
Counts: must 1 · should 14 · could 9.
1. must: `tools/sim/sim_final_test.dart:1` is a plain script that `tools/mine.sh` reports as "No tests ran" and FAILED (final-row-report.md:84); the gate is red for this run. Design call: accept plain-script sim tests in mine.sh, or move them to `package:test` (a new dependency, so the owner decides).
2. should: `tools/sim/sim_final_test.dart:64` check (a) only equates the final row with its matrix row; the brief's road_length 6 and tile_cost 3 (2-4) / 2 (5-8) are asserted only for adult 4 and 6 players.
3. should: `tools/sim/sim_final_test.dart:25-32` a FAIL only prints and sets `exitCode`; if the runner ignores the exit code, a failing check passes (not verified).
4. should: `tools/sim/sim_report_test.dart` and `tools/sim/night_sim_test.dart` have no exit-code run after the split (split-report.md Questions 1; run.log has none).
5. should: `tools/sim/sim_cell.dart:66` the `rules` doc omits `rwAlways`, which `runSimCell` still applies to rules cells (`sim_report.dart:46`) and `simCsvRow` writes (`sim_report.dart:85`).

Questions only the owner can answer: see Open questions (mine.sh rule, test style, gate column, split tests-first exemption).

## Findings

- **must** tools/sim/sim_final_test.dart:1 The new check file is a plain script whose PASS/FAIL lines `tools/mine.sh` does not count, so the gate reports "No tests ran" and FAILED → decide whether mine.sh accepts plain-script sim tests or the file moves to `package:test` (new dependency, owner call) (from: final-row)
- **should** tools/sim/sim_final_test.dart:64 Check (a) equates each final row with its matrix row only; it never asserts road_length 6 or tile_cost 3 (2-4 players) / 2 (5-8) for counts other than adult 4 and 6 → add per-count asserts on `tileCostColumn` and `roadLengthColumn` (brief item 4) (from: final-row)
- **should** tools/sim/sim_final_test.dart:25-32 `check` prints FAIL and sets `exitCode`, and nothing throws, so a FAIL may not fail the run under `flutter test` (not verified) → throw (or fail the test) on FAIL, once the test style is decided (from: final-row)
- **should** tools/sim/sim_final_test.dart:27 and :29 `print` in a test file, which the worker rule bars → keep only if the gate accepts plain-script output; otherwise remove with the style change (from: final-row)
- **should** tools/sim/sim_final_test.dart:36 `main()` runs lines 36-101 (66 lines) over the ~40-line rule → one function per check (checkFinalMatchesMatrix, checkTileCostAndRoadLength, checkFinalRowNames) (from: final-row)
- **should** tools/sim/sim_cell.dart:66 The `rules` doc says the rules give the exact night, but `runSimCell` still applies `rwAlways` (sim_report.dart:46) and `simCsvRow` writes it (sim_report.dart:85) → name `rwAlways` in the doc, or assert it is false in `finalRulesCells` (from: final-row)
- **should** tools/sim/sim_report.dart:40 `kidsPreset` is passed only on the matrix branch (lines 35-44); a future kids rules cell silently skips it → pass it on the rules branch or assert no kids rules cell (from: final-row; latent, no cell today)
- **should** tools/sim/sim_stats.dart:14 Doc says "Built by [runSimCell]", which sim_stats.dart does not import, so the link does not resolve → write `runSimCell` as plain text, naming sim_report.dart (from: split)
- **should** tools/sim/sim_stats.dart:100 `CellTally` is public (was `_CellTally`); its fields at lines 101-122 and `stats` at line 177 have no dartdoc → add a one-line dartdoc to each, or keep the fields private (from: split)
- **should** tools/sim/sim_stats.dart:68 Doc line over 120 columns → rewrap (from: split)
- **should** tools/sim/sim_cell.dart:16 Doc line over 120 columns → rewrap (from: split)
- **should** tools/sim/sim_report.dart:1 Lines 1, 2, 72, 112 and 152 are over 120 columns (152 added by final-row; the others predate this run) → rewrap the five lines (from: split and final-row)
- **should** docs/code-health.md:386 Says sim_report.dart is 361 lines and needs a split; line 394 says 423 lines "split before its next change"; line 389 lists comment lines at 77, 189, 218, 311 → update to the post-split state (sim_report.dart 172 lines, the rest in sim_cell.dart and sim_stats.dart) (across jobs)
- **should** tools/sim/sim_report_test.dart:1 and tools/sim/night_sim_test.dart:1 Neither test file was run with a recorded exit code after the split; the reviewer's counts (15 and 29 PASS lines) are line counts only → run both and record the exit codes (across jobs)
- **should** docs/briefs/m17/board3f/split-report.md:1 No Summary block and no part-A self-check (run-findings.md entry; wave-1 finding) → add both in the next report of this milestone (from: split)
- **could** tools/sim/sim_report.dart:154 `finalRulesCells` repeats the cell constructor of `simMatrixCells` (lines 115-133) → share one helper for both lists (from: final-row)
- **could** tools/sim/sim_report.dart:86 The gate column reads `rules.targetedGate`, not `rules.gateOn`, so a kids rules cell would print gate true with no gate → read `gateOn`, or document the choice (from: final-row)
- **could** tools/sim/sim_report.dart:160 `games: nightGames` while the rules carry `city.nightGames`; both are 5 today, so the game count has two sources → read one (from: final-row)
- **could** docs/briefs/m17/board3f/final-row-report.md:75 "five files (plus this report)"; the job changed four code files, and line 51 lists sim_stats.dart as not changed → correct the self-check line (from: final-row)
- **could** tools/sim/sim_stats.dart:65 The remark "(null shares below when zero)" sits on the `int rwPairs` field, which is never null → move it to the share fields (from: split)
- **could** tools/sim/sim_cell.dart:2 Library doc is a fragment ("The population names, and the bots each population plays with.") → make it a sentence (from: split)
- **could** tools/sim/sim_final_test.dart:25 `check` and :34 `csvFields` are public top-level functions with no dartdoc → add one line each (from: final-row)
- **could** tools/sim/run_sim.dart:21 `const usage` is public with no dartdoc → add one line (from: final-row)
- **could** docs/briefs/m17/board3f/split-report.md:1 The split was a pure move; its report has no tests-first exemption line (G9) → record "tests-first: exempt, pure move" (from: split)

## Open questions

1. Which rule wins for `tools/mine.sh`: final-row.md's stop line says "never", the worker was told to run it → suggest: run it, since it is the gate.
2. Plain-script sim tests (sim_report_test.dart, night_sim_test.dart, sim_final_test.dart) fail mine.sh → suggest: teach mine.sh to run them and read their FAIL lines, and do not add a dependency.
3. Gate column for rules cells: `targetedGate` or `gateOn` → suggest `gateOn` (it is what plays).
4. Keep the fourth check (road final, r2, gate true) that the brief did not ask for → suggest keep.
5. Keep `CellTally` and `multiGateCount` public through the `export` in sim_report.dart (wave-1 decision) → suggest keep, as briefed.
6. Split job: the `tests-first` proof is missing from run.log and from the report → suggest record a pure-move exemption.
7. Game count for rules cells: `nightGames` or `rules.city.nightGames` → suggest `nightGames` now and a check that they match.
8. The brief's stop line for final-row and mine.sh failure: should final-row be re-run after the test-style decision → suggest yes, once.

## Numbers against targets

- Brief item 4 targets (final-row.md:13): road_length 6 at every count; tile_cost 3 at 2-4 players, 2 at 5-8. Asserted directly: tile_cost at adult 4 (3) and 6 (2), road_length at adult 6 only. Other counts are checked only by equality with the matrix row. Not verified by me: the matrix values themselves (sim_rules.dart not read).
- Test counts: final-row 17 PASS (`flutter test`, final-row-report.md:83, not reproduced); split sim_report_test 15 PASS and night_sim_test 29 PASS (line counts by wave-1 reviewer, exit codes missing).
- Gate: `tools/mine.sh` RESULT FAILED for final-row (final-row-report.md:84). Target: pass. Missed.
- File size: sim_report.dart 151 → 172 lines, sim_cell.dart 80, sim_stats.dart 211, sim_final_test.dart 101, run_sim.dart 50. Target under 380 (gate) and about 300: all met.
- Columns: 7 lines over 120 in the changed code files (sim_stats.dart:68; sim_cell.dart:16; sim_report.dart:1, 2, 72, 112, 152). Target 120: missed.
- Hand-fixes: 0 HAND-FIX lines in run.log.

## Could not check

- Nothing was run: this is a read-only review. The test exit codes, the 17/15/29 PASS counts and the 6/3/2 values are unverified.
- sim_rules.dart (`SimRules.forNight`, `roadworksInForce`, `CityRules.standard`) and night_sim.dart were not read, so the claims that forNight sets R2 and the gate are unverified.
- Whether `flutter test` fails on a FAIL line that only sets `exitCode` (sim_final_test.dart:25-32).
- The per-commit file list behind "five files" (final-row-report.md:75): read from the range diff only.
- docs/coding-guidelines.md and docs/review-rules.md were not opened in full; the worker extract was used for the rules.
- The suite name for tools/sim (tools/check.sh <suite>) was not read, so the fix jobs' check line is for Claude to set.
- The job files are in docs/briefs/m17/board3f/: no STATUS.md and no REVIEW-VERDICTS.md exist, so no finding was skipped as verdicted.

## Fix-job sizing (for Claude)

No finding touches controller_app or packages, so no finding is phone-pinned; no `phone` in check:.
- Job A, tools/sim/sim_stats.dart: lines 14, 65, 68, 100 (4 items, one file; merge 65 into 14 if 3 is the cap).
- Job B, tools/sim/sim_cell.dart: lines 2, 16, 66 (3 items).
- Job C, tools/sim/sim_report.dart: columns at 1, 2, 72, 112, 152; plus 40 (kidsPreset), 86 (gate), 154 (constructor), 160 (games). Keep the column rewrap as one job and defer the four could-level items.
- Job D, tools/sim/sim_final_test.dart: 64, 36, 25-32, 27, 29, 25/34 docs, plus the gate decision (must 1). Needs Claude's decision first.
- Job E, docs/code-health.md: 386, 389, 394 (1 file).
- Not code: the sim test runs (should 4), and the report corrections (split-report.md:1, final-row-report.md:75).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 board3f: run review of the sim split and final-rules row

Read-only review of the run's commits (split 29af9c4d, final-row dfe83a5f)
against the guidelines and review rules. Findings only: one must (the new
sim test fails the mine.sh gate, which takes no plain-script tests), 14
should, 9 could. Nothing in tools/sim was changed; the findings are for
Claude to verify and batch.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- board3f run review: done, verdict needs Claude's design (1 must, 14 should, 9 could); open: the mine.sh gate for plain-script sim tests, check (a) target asserts, the sim test runs with exit codes, 120-column lines in sim_stats, sim_cell and sim_report, and the stale code-health lines.

## Delete

- none

## Status after the fixes (driver, Nov 27)
Open after fixes: must 0 (1 invalid) · should 7 (deferred to code-health) · could 9 (deferred). Fixed 5 should, 2 invalid. Verdicts: REVIEW-VERDICTS.md.
