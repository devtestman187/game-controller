job: board3b g3g — fix the three test findings of the wave-2 review (night_sim_test.dart only)
stop: no change to night_sim.dart, bots.dart or any other file; never tools/mine.sh
read: docs/briefs/templates/COMMON.md · docs/briefs/m17/board3b/sim-model.md (Setup and step 5) · tools/sim/night_sim.dart:17-135 (NightConfig, NightResult, rulesWith) · tools/sim/night_sim_test.dart:1-100 and 195-232 (the checks to replace)
changes: night_sim_test.dart checks only (gate cap check, mid-ranking field checks, roadworks cost 0 check)
model: haiku
turns: 35
expected-min: 20
tests-first: exempt the checks pin behaviour already correct on the base
do:
1 Replace the vacuous gate check ("before the gate game", it cannot fail: with standard rules a player has 1 tile after game 1). Use `rulesWith(CityRules.standard, tileCost: 1)` so Bolts allow 3 tiles a stop. A 5-game 4-player night, 300 seeds: tilesAfterGame[0] and [1] never exceed gateTileIndex (gate game is 3); some night has tilesAfterGame[1] equal to gateTileIndex for a player (the cap binds); some night has a player above gateTileIndex after game 3. Read gateTileIndex from the rules, no literal 4.
2 Add checks for the mid-ranking fields, 4 players 5 games, 200 seeds: midLast is an id of the night's players; midLeaders is not empty and holds only ids of the night's players; firstPlazaGame is null or between 1 and games and equals the first index i (+1) where any value of tilesAfterGame[i] equals roadLength; leaderReachedPlaza is true exactly when some id of champions has tiles equal to roadLength (player id 'p<i>' is index i).
3 Replace "roadworks cost 0 still runs": profiles with roadworksChance 1 and saveChance 0, roadworks on, 300 seeds, the same seeds with `rulesWith(standard, roadworksCost: 0)` and with the standard cost: the sum of all final bolts over the nights is higher with cost 0.
4 Run `bash tools/tests/sim-test.sh`, `dart format tools/sim`, `dart analyze tools/sim`; fix every info. Do not touch other test files.
5 Report: the new check names and their PASS lines.
allow: tools/sim/night_sim_test.dart
check: format analyze
report: docs/briefs/m17/board3b/g3g-report.md
