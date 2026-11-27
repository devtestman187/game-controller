# board3f split: report

Status: the split is done and `tools/mine.sh` passes. The two test files the brief names were not run (see Questions).

## Files changed

- `tools/sim/sim_cell.dart` (new, 74 lines): the population name constants, `SimCell`, `populationProfiles`. Moved from sim_report.dart lines 11-18, 39-86, 176-185.
- `tools/sim/sim_stats.dart` (new, 211 lines): `multiGateCount`, `SimCellStats`, the tally (`_CellTally` → public `CellTally`), `_placeOf`, `_worstPlace`, `_ratio`, `_ratioOrNull`. Moved from sim_report.dart lines 29-30, 88-174, 308-420.
- `tools/sim/sim_report.dart` (151 lines, was 423): keeps the matrix constants, `runSimCell`, `simCsvHeader`, `simCsvRow`, `simMatrixCells`, `_csvNumber`. Adds `export 'sim_cell.dart';` and `export 'sim_stats.dart';`. The `dart:math` and `bots.dart` imports are dropped because nothing left in the file uses them.

Bodies and doc comments are unchanged except for the tally rename. `multiGateCount` moved with the tally because only the tally uses it, and sim_stats cannot import sim_report without a cycle. It stays public and is still reachable through the export.

## Move map

| Name | From (old lines) | To |
|---|---|---|
| population constants (3) | 11-18 | sim_cell.dart |
| `SimCell` | 39-86 | sim_cell.dart |
| `populationProfiles` | 176-185 | sim_cell.dart |
| `multiGateCount` | 29-30 | sim_stats.dart |
| `SimCellStats` | 88-174 | sim_stats.dart |
| `_CellTally` → `CellTally` | 308-408 | sim_stats.dart |
| `_placeOf`, `_worstPlace` | 410-416 | sim_stats.dart |
| `_ratio`, `_ratioOrNull` | 418-420 | sim_stats.dart |
| `matrixPlayerCounts`, `nightGames`, `csvDecimalPlaces`, `simCsvHeader` | 20-27, 32-37 | sim_report.dart |
| `runSimCell` | 187-228 | sim_report.dart |
| `simCsvRow` | 230-266 | sim_report.dart |
| `simMatrixCells` | 268-306 | sim_report.dart |
| `_csvNumber` | 422-423 | sim_report.dart |

Line counts: sim_report.dart 151, sim_cell.dart 74, sim_stats.dart 211. All are under 380.

## Checks

- `tools/mine.sh`: `RESULT: ok: 3 file(s) formatted, 1 package(s) analyzed, 0 package(s) tested`. The analyze step passed.
- `tools/mine.sh` printed `NO TESTS .` because no test file was touched, so it ran no tests.
- `git status`: only the three files under `tools/sim/` changed, plus this report.

No test values were computed, because no tests were run.

## Questions

1. The brief asks for `dart test tools/sim/sim_report_test.dart tools/sim/night_sim_test.dart` to pass. My instructions say to check with `tools/mine.sh` only, so I did not run them. These two tests are the real proof of "no behaviour change". Someone should run them, or the brief should say how.
2. The brief's "stop" line says "never tools/mine.sh", but the job's instructions say to check with it. I followed the job's instructions.
3. The doc comment on `SimCellStats` says "Built by [runSimCell]". `runSimCell` now lives in sim_report.dart, which sim_stats.dart does not import. The reference does not resolve in that file. I left the text unchanged because the brief says to move doc comments unchanged. Dartdoc may warn about it.
4. `sim_report.dart` no longer imports `dart:math` or `bots.dart`. If the tests rely on those imports reaching them through sim_report, they will fail to compile. I believe they do not, but I have not run them.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 board3f: split sim_report.dart into cell, stats and report

sim_report.dart was 423 lines, over the 380-line limit. Its population
and cell types move to sim_cell.dart, and the stats type and the cell
tally move to sim_stats.dart. sim_report.dart keeps the run, the CSV
and the matrix, and re-exports both new files so every existing import
still sees every name. This is a pure move; the tally is renamed from
_CellTally to CellTally because it now crosses a file boundary. No
behaviour change; sim_report_test.dart is unchanged and still has to be
run.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- board3f split: sim_report.dart (423) split into sim_cell.dart (74), sim_stats.dart (211) and sim_report.dart (151), all under 380 lines, names re-exported; done: mine.sh passes. Open: sim_report_test.dart and night_sim_test.dart not yet run.

## Delete

- none
