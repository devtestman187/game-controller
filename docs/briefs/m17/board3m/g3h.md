job: board3m g3h — fix the wave-1 review findings 1-3 (rules.dart and its tests)
stop: no new rule, no board change, no simulator logic beyond the one constructor call; never tools/mine.sh
read: docs/briefs/templates/COMMON.md · docs/briefs/m17/board3m/wave1-review-report.md (Findings 1-3 and 6) · packages/party_host/lib/src/city/rules.dart:10-135 · packages/party_host/test/city/rules_test.dart:1-30 and 60-90 and 140-175 · packages/party_host/test/city/roadworks_offer_test.dart:1-22 · tools/sim/sim_rules.dart:105-135
changes: CityRules (gateTileIndex removed · new field tileCostSmallNight) · CityRules.forPlayers · cityRulesWith (tools/sim/sim_rules.dart)
model: haiku
turns: 60
expected-min: 30
tests-first: exempt finding 3's test needs the new field; the rest deletes dead code
do:
1 Delete `gateTileIndex` everywhere: rules.dart (doc, field, constructor, `standard`, forPlayers copy), rules_test.dart (the copy helper line 19, line 80, and the test "the gate tile is on the road, before the Plaza"), roadworks_offer_test.dart:18, tools/sim/sim_rules.dart:125. grep -rn gateTileIndex packages tools must then find nothing.
2 Chained re-pricing: add required field `tileCostSmallNight` (3, doc "tile price with 2-4 players") and make `tileCost` the price of the copy in hand: forPlayers sets tileCost to tileCostLargeNight from largeNightFrom players, else to tileCostSmallNight, whatever the receiver's own tileCost. Test first: `CityRules.standard.forPlayers(6).forPlayers(2).tileCost` is 3 and `.forPlayers(6).tileCost` is 2. Update every full constructor copy (rules_test.dart helper, roadworks_offer_test.dart, forPlayers, cityRulesWith in tools/sim/sim_rules.dart).
3 In the forPlayers "keeps every other field" test add expects for tileCostLargeNight, largeNightFrom, tileCostSmallNight.
4 Run `flutter test packages/party_host/test/city`, `bash tools/tests/sim-test.sh`, `dart format` and `dart analyze` on the files you changed; fix every info, warning and error.
5 Report: grep result for gateTileIndex and the test names.
allow: packages/party_host/lib/src/city/rules.dart · packages/party_host/test/city/rules_test.dart · packages/party_host/test/city/roadworks_offer_test.dart · tools/sim/sim_rules.dart
check: format analyze host
report: docs/briefs/m17/board3m/g3h-report.md
