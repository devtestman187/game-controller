job: board3b g3d2b — metrics over many nights, CSV and the command line
stop: no change to night_sim.dart or bots.dart; no report text; do not run the full matrix to commit CSVs (the driver does)
read: docs/briefs/templates/COMMON.md · docs/briefs/m17/board3b/sim-model.md (section Metrics) · tools/sim/night_sim.dart (NightConfig, NightResult, simulateNight, kidsRules) · tools/sim/bots.dart (childBot, adultBot) · tools/sim/night_sim_test.dart (check() style)
changes: SimCellStats · runSimCell · populationProfiles · simCsvHeader · simCsvRow · simMatrixRows (new, tools/sim/sim_report.dart) · run_sim.dart (new CLI)
model: haiku
turns: 60
expected-min: 35
tests-first: exempt new files only, nothing on the base to fail
do:
1 New tools/sim/sim_report_test.dart (plain Dart script): runSimCell with the same seed twice gives equal SimCellStats and equal simCsvRow text (seeded determinism); simCsvRow has as many fields as simCsvHeader; leaderPlazaRate <= anyPlazaRate and every rate is 0..1; with roadworks off meanBlocks is 0; populationProfiles('mixed', 4) has 2 adult then 2 child alternating starting with adult, ('adult', 8) 8 adults, ('kids', 4) 4 children; a 200-night 4-player 5-game mixed cell has tileSpread > 0.
2 New tools/sim/sim_report.dart: `populationProfiles(String name, int players)` (adult, mixed, kids); `SimCellStats runSimCell({population, players, games, roadworks, nights, seed, rules})` (kids population uses kidsRules and ignores the roadworks flag, reported as off); the metrics of sim-model.md (tileSpread, comebackRate, leaderPlazaRate, anyPlazaRate, meanFirstPlazaGame or null, meanBlocks); `simCsvHeader` = `population,players,games,roadworks,nights,seed,night_games,mean_tile_spread,comeback_rate,leader_plaza_rate,any_plaza_rate,mean_first_plaza_game,mean_blocks` and `simCsvRow(SimCellStats)` (rates with 4 decimals, empty field for a null); `List<SimCellStats> simMatrixRows(nights, seed, rules)` over populations adult and mixed x players 4,8 x games 3,5 x roadworks off,on, plus kids x 4,8 x 3,5 (roadworks off).
3 New tools/sim/run_sim.dart CLI: options `--nights N` (default 5000) `--seed S` (default 17) `--out <path>` (default docs/briefs/m17/city/sim-results.csv; create the folder); prints the CSV path and the row count. Uses CityRules.standard.
4 Run `bash tools/tests/sim-test.sh`, `dart format tools/sim`, `dart analyze tools/sim`; fix every info. Do not run run_sim.dart.
5 Report: test output lines; the runtime of one runSimCell of 200 nights.
allow: tools/sim/sim_report.dart · tools/sim/sim_report_test.dart · tools/sim/run_sim.dart
check: format analyze tools
report: docs/briefs/m17/board3b/g3d2b-report.md
