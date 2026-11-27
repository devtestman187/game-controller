job: board3f split — split tools/sim/sim_report.dart (423 lines) into files under 380 lines, no behaviour change
stop: no logic change, no rename of public names the tests use, no CSV change, no other tool; never tools/mine.sh
read: docs/briefs/templates/COMMON.md · tools/sim/sim_report.dart:1-423 · tools/sim/sim_report_test.dart:1-138 (must pass unchanged, never edit it) · tools/sim/run_sim.dart:1-47 · owner Nov 27: "split sim_report.dart so every resulting file is under 380 lines; no behaviour change"
changes: tools/sim/sim_cell.dart (new: population name constants, SimCell, populationProfiles) · tools/sim/sim_stats.dart (new: SimCellStats and the tally class, _CellTally becomes public CellTally, with _placeOf _worstPlace _ratio _ratioOrNull) · tools/sim/sim_report.dart (keeps the other constants, runSimCell, simCsvRow, simMatrixCells, _csvNumber; adds `export 'sim_cell.dart';` and `export 'sim_stats.dart';` so every import of sim_report.dart still sees every name)
model: haiku
turns: 35
expected-min: 20
tests-first: exempt pure move of code; sim_report_test.dart is the unchanged proof and passes before and after
do:
1 Run `dart test tools/sim/sim_report_test.dart` first and note the result.
2 Create tools/sim/sim_cell.dart and tools/sim/sim_stats.dart by MOVING the code named in changes: (cut and paste, doc comments included, no edits to bodies; the only edit is dropping the leading underscore of the tally class and its uses; each new file gets a 2-line library doc and the imports it needs). A moved helper that sim_report.dart still uses stays public in its new file only if needed; otherwise keep it private with its user. Each file must be under 380 lines; sim_report.dart too.
3 sim_report.dart: remove the moved code, add the two exports, keep every constant and function not named above.
4 Run `dart format tools/sim`, `dart analyze tools/sim`, `dart test tools/sim/sim_report_test.dart tools/sim/night_sim_test.dart` and `wc -l tools/sim/*.dart`; all pass, no file over 379 lines.
5 Report: the move map (what went to which file, line counts) and the test output lines.
allow: tools/sim/sim_report.dart · tools/sim/sim_cell.dart · tools/sim/sim_stats.dart
check: format analyze
report: docs/briefs/m17/board3f/split-report.md
