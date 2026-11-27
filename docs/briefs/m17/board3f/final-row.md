job: board3f final-row — a "final rules" row in the simulator: the owner's night built through SimRules.forNight
stop: no change to the matrix cells or their numbers, no change to CityRules, sim_rules.dart or night_sim.dart; never tools/mine.sh
read: docs/briefs/templates/COMMON.md · tools/sim/sim_cell.dart (whole, after the split) · tools/sim/sim_report.dart (whole) · tools/sim/sim_rules.dart:60-150 · tools/sim/run_sim.dart:1-47 · tools/sim/sim_report_test.dart:1-60 and 110-138 · owner Nov 27: "add a final rules row built through the existing SimRules.forNight from base rules. Never apply forPlayers to a road-variant copy: cityRulesWith leaves tileCostLargeNight alone, so that would make a hybrid price nobody chose."
changes: SimCell (gains optional field `rules`, type SimRules?, default null; when set the cell plays exactly those rules and `road` is ignored) · runSimCell (uses cell.rules when set) · simCsvRow (a rules cell writes road `final`, and road_length and tile_cost from rules.city; roadworks and gate columns from rules) · finalRulesCells (new function in sim_report.dart) · run_sim.dart (appends the final cells) · sim_final_test.dart (new)
model: haiku
turns: 60
expected-min: 35
tests-first: exempt the new test needs the new function
do:
1 sim_cell.dart: add `final SimRules? rules` to SimCell (named, optional, null default, doc: "the exact rules of the night; when set the road variant is not applied"). A rules cell keeps a `road` value only because the field is required: document it.
2 sim_report.dart: `List<SimCell> finalRulesCells(int nights, int seed, CityRules base)`: for population in adult and mixed, for players in matrixPlayerCounts, a SimCell with games nightGames, roadworks RoadworksVariant.r2, gate true, rwAlways false, rules `SimRules.forNight(base, players: players)` (never forPlayers on a road copy, never cityRulesForRoad), road RoadVariant.v0. runSimCell: when cell.rules is set use it as `rules` (kids false) else keep the current code. simCsvRow: for a rules cell road column `final`, road_length `rules.city.roadLength`, tile_cost `rules.city.tileCost`, roadworks and gate from the rules. The file must stay under 380 lines (say so in the report; move code to sim_stats.dart or a new file only if it does not).
3 run_sim.dart: write the matrix cells, then finalRulesCells, into the same CSV (header unchanged). Update its top comment in one line.
4 New test tools/sim/sim_final_test.dart (use sim_report_test.dart's style): (a) for adult and mixed, players 2-8 with 40 nights seed 3, the final cell's CSV fields equal those of the matrix cell it should match, except the road column (v0 cell at 2-4 players, v2 cell at 5-8, roadworks r2, gate true, rwAlways false, same population): the shipped road length 6, price 3 at 2-4 and 2 at 5-8; (b) the final cell at 6 players has tile_cost 2 and road_length 6 in its CSV row; (c) the final cell at 4 players has tile_cost 3. If (a) fails for a player count, do NOT change code to force it: report the player counts and both rows in full as `OWNER FINDING` in the report.
5 Run `dart format tools/sim`, `dart analyze tools/sim`, `dart test tools/sim/sim_final_test.dart tools/sim/sim_report_test.dart`.
6 Report: whether (a) held for all 14 cells (numbers if not), line counts.
allow: tools/sim/sim_cell.dart · tools/sim/sim_report.dart · tools/sim/sim_stats.dart · tools/sim/run_sim.dart · tools/sim/sim_final_test.dart
check: format analyze
report: docs/briefs/m17/board3f/final-row-report.md
