job: board3m g3m — adapter: the real round placing and the real champion chain behind the City interfaces
stop: no rules, no wiring into any game or the night flow, no change to stubs.dart or night/; never tools/mine.sh
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/city/stubs.dart:1-72 · packages/party_host/test/city/stubs_test.dart:1-44 · packages/party_host/lib/src/night/champion.dart:28-110 (ChampionEntry, ChampionChain.cityRush) · packages/game_kit/lib/src/round_result.dart:68-110 (RoundResult.stats) · packages/test_game/lib/src/arena.dart:209-229 (the race sets stats[id]['place'], 1 = best)
changes: RoundResultPlacing · NightChampionDecider (both new, packages/party_host/lib/src/city/night_adapter.dart)
probe: docs/briefs/m17/board3m/probe-g3m.patch
model: haiku
turns: 60
expected-min: 30
tests-first: exempt new files only
do:
1 Tests first: new packages/party_host/test/city/night_adapter_test.dart. RoundResultPlacing(RoundResult) implements RoundPlacing: placeRound returns each id's `place` stat; ids with no place stat are placed after the placed ones, in the order listed; a duplicate id throws ArgumentError (like the stub). NightChampionDecider([ChampionChain? chain]) implements ChampionDecider, default ChampionChain.cityRush: the entry closest to the Plaza (least plazaDistance) wins; equal distance goes to the most bolts; equal on both shares the win; empty input gives an empty set. Also run the shared contract on the stub and the adapter: one id per player for placeRound; decideChampions never returns an id that is not in the entries.
2 New packages/party_host/lib/src/city/night_adapter.dart: the two classes. It is the only city file allowed to import night/ (champion.dart) and game_kit (RoundResult); say so in the library doc. Map CityChampionEntry to ChampionEntry(id: playerId, points: 0, plazaDistance, bolts). Pure Dart, no Flutter, under 150 lines, doc comment on every public member.
3 Run `flutter test packages/party_host/test/city/night_adapter_test.dart packages/party_host/test/city/stubs_test.dart`, `dart format` and `dart analyze` on your files; fix every info, warning and error.
4 Report: the classes and the test names; list any case you had to choose (assumptions).
allow: packages/party_host/lib/src/city/night_adapter.dart · packages/party_host/test/city/night_adapter_test.dart
check: format analyze host
report: docs/briefs/m17/board3m/g3m-report.md
