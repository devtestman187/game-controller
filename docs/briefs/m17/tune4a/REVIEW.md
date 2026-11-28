# tune4a run review

## Summary

Verdict: needs Claude's design (the v3 run is not done; the gate question and the 5-tile road choice are open).
Counts: must 0 · should 8 · could 9. No HAND-FIX lines in run.log; no fix jobs; no phone-pinned finding (all in tools/sim and docs/briefs/m17/tune4a).
Fix sizing: run_sim_v3.dart and run_sim_v3_test.dart are shared by most findings, so fixes run as one job per file in sequence, each with at most 3 findings, after the owner's answers to Open questions 1-3.
Top five:
1. The v3 run never produced sim-results-v3.csv or sim-tables-v3.md: the run was refused (h4a-report.md:5-7); h4b is blocked on it (h4b-report.md:5-8).
2. `tools/mine.sh` tests step runs `dart test` on the plain `main()` file run_sim_v3_test.dart (mine.sh:230-234); h4a's own gate fails.
3. Option parsing, the rule-change path (exit 1) and `v3Tables` have no test (run_sim_v3.dart:58, :147, :159).
4. Bare magic numbers: `64` and `16` at run_sim_v3.dart:47-49, :134.
5. The rules digest covers 2 files, while cells also run through night_sim.dart and sim_stats.dart (run_sim_v3.dart:29-33, :137-138).

Questions for the owner: see Open questions.

## Findings

- **should** docs/briefs/m17/tune4a/h4a-report.md:29 The report has no review-rules part A self-check (six host and state lines) → add the six one-line answers, each with its test or "not affected". (from: h4a)
- **should** docs/briefs/m17/tune4a/h4a-report.md:5-7 Brief item 5 is not done: the two output files are absent, so the plaza-rate range and row count are not reported → run the default command after approval, then report both. (from: h4a, h4b)
- **should** tools/mine.sh:230-234 and tools/sim/run_sim_v3_test.dart:28 The tests step runs `dart test` on a plain `main()` file, so the job's own gate fails → decide whether `tools/tests/sim-test.sh` is the gate for tools/sim tests, or the test becomes a package test. (from: h4a; wave1)
- **should** tools/sim/run_sim_v3.dart:58-64 Option parsing and exit 2 have no test (odd count, unknown flag, `--nights 0`, `--seed x`) → move parsing into a function that returns null on bad input, and test those cases. (from: wave1)
- **should** tools/sim/run_sim_v3.dart:145-147 The rule-change path (null, nothing written, exit 1) has no test → take the rule-file list as a parameter and test that a changed file gives null and no output. (from: wave1)
- **should** tools/sim/run_sim_v3.dart:39, :159-184 `tableColumns` (13) and `tableHeader` must change together; no test counts the columns → test that the header and each row have `tableColumns` cells. (from: wave1)
- **should** tools/sim/run_sim_v3.dart:29-33, :137-138 The digest covers `rules.dart` and `sim_rules.dart` only; `night_sim.dart` and `sim_stats.dart` change results too, yet the doc says the rows match "the rules on disk" → widen the digest to every file the cells run through, or reword the doc. (from: wave1)
- **should** tools/sim/run_sim_v3.dart:47-49, :134 Bare `64` (`BigInt.one << 64`, `_mask64`), `radix: 16` and `padLeft(16, '0')` break the no-magic-number rule → name them (`fnvBitCount`, `digestHexDigits`) with a doc line each. (from: wave1)
- **could** tools/sim/run_sim_v3.dart:165, :175-176 The table text hard-codes "a 5-game night" and "(3 Bolts)", while :168 prints the real game count → build those words from `nightGames` and `fiveTileRoad`. (from: wave1)
- **could** tools/sim/run_sim_v3.dart:26, :51 `usage` and `main` have no dartdoc → add one line each. (from: wave1)
- **could** tools/sim/run_sim_v3.dart:52-55 A repeated option (`--seed 3 --seed 4`) is silently overwritten → reject a duplicate with exit 2. (from: wave1)
- **could** tools/sim/run_sim_v3.dart:58 `wellFormed` is not question-shaped → rename `isWellFormed`. (from: wave1)
- **could** tools/sim/run_sim_v3_test.dart:40-41 `rwOn` and `rwOff` are not question-shaped → rename `hasRoadworksOn`, `hasRoadworksOff`. (from: wave1)
- **could** tools/sim/run_sim_v3_test.dart:50-60 The 5-tile check compares with the same `fiveTileRoad` constant the script uses, so it passes if that constant changes to v3 → also assert the tile count of `fiveTileRoad` is 5. (from: wave1)
- **could** tools/sim/run_sim_v3_test.dart:62-95 The temp directory is deleted only on the last line, so an earlier throw leaks it → wrap the checks in try/finally. (from: wave1)
- **could** tools/sim/run_sim_v3_test.dart:66 `runSimCell(cells.first)` result is discarded; the check reads only the digest → drop the call, or assert on its rows. (from: wave1)
- **could** tools/sim/run_sim_v3.dart:52-55 and tools/sim/run_sim.dart:19-36 The option loop, the `wellFormed` test and exit 2 are copied from run_sim.dart → share one parser for both commands. (from: across jobs)

## Open questions

1. Approve `dart run tools/sim/run_sim_v3.dart` (writes only docs/briefs/m17/city/sim-results-v3.csv and sim-tables-v3.md)? Suggested: yes, then h4b can run. (h4a Q1, h4b Q1)
2. Is `tools/tests/sim-test.sh` the gate for tools/sim/*_test.dart, since mine.sh runs `dart test` on plain `main()` files? Suggested: yes. (h4a Q2)
3. Is the 5-tile road RoadVariant.v1 (5 tiles, 3 Bolts) the one meant? Suggested: keep v1 and state it in the tables. (h4a Q3)
4. Mixed cells use `SimRules.forNight` with no kids flag (wave1 decision 2). Suggested: keep, as sim_report.dart:167 does, and say so in the tables.
5. Tables have one row per cell, not per player count (h4a decision 2). Suggested: keep, and say so in the report.
6. Should the digest cover every file the cells run through (wave1 decision 3)? Suggested: yes.
7. h4b: use the v2 CSV instead of waiting for v3 (h4b Q2)? Suggested: no; the brief names v3.

## Numbers against targets

- Row count: 56 = 28 final cells (2 populations × 7 player counts × 2 Roadworks states, sim_report/run_sim_v3.dart:86-89) + 28 five-tile cells (7 player counts × 4 `RoadworksVariant` values, sim_rules.dart:9-20, sim_report.dart:134-143). Computed by reading; the file was not written.
- Plaza rate: target 0.90 (run_sim_v3.dart:165); no measured value, the run was refused.

## Could not check

- The test run (`dart run tools/sim/run_sim_v3_test.dart`): refused by the permission prompt ("requires approval"), so the h4a claim of PASS lines (h4a-report.md:31) is unverified. Fixed, unverified: none (no fix job exists).
- The default run's plaza-rate range and row count: not measured (the run was refused).
- STATUS.md, run-findings.md and REVIEW-VERDICTS.md do not exist in the folder, so nothing was carried over from them; the carry-over is the two per-job reviews only.
- The per-job review findings were checked against the committed files by line: all still hold (no later job changed tools/sim).
- The h4a tests-first proof (run.log:14): "fails on the old code" for a file that is new in this run; the old code is absent, so the proof is a compile failure, not a behaviour check.
- `dart format` and `dart analyze`: not run (no change to any code file in this review).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

tune4a run review: 8 should, 9 could on the h4a/h4b run

Writes the run's review as docs/briefs/m17/tune4a/REVIEW.md: one findings list
for the v3 simulator script, its tests and the h4a report. No code changed.
Verdict: needs Claude's design. The v3 run was refused, so the CSV and tables
are absent and h4b is blocked. Seven questions for the owner are listed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

tune4a run review done: 17 findings (8 should, 9 could), 0 must; open: v3 run approval, mine.sh test gate, 5-tile road v1 choice, test run not verified.

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`.

- none
