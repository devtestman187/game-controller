job: board3a g3s — stubs behind interfaces for placing and champion
stop: no game rules, no numbers, no draft mechanics, no bots, no adapter; no import from night/ (ChampionChain is wired later in g3m)
read: docs/briefs/templates/COMMON.md · packages/game_kit/lib/src/round_result.dart:74-80 (points map shape, copy the shape only) · packages/party_host/lib/src/night/champion.dart:58-64 (ChampionChain, reference only)
changes: packages/party_host/lib/src/city/stubs.dart (abstract RoundPlacing + StubRoundPlacing · abstract ChampionDecider + StubChampionDecider)
model: haiku
turns: 35
expected-min: 20
do:
1 Write packages/party_host/test/city/stubs_test.dart first and run it (it fails to compile). Cover: StubRoundPlacing returns one placing per player, 1 = best; StubChampionDecider returns a champion set from entries carrying plazaDistance and bolts.
2 Create packages/party_host/lib/src/city/stubs.dart: abstract RoundPlacing (placing per player for one round, 1 = best, same shape as the points map) with StubRoundPlacing returning fixed canned values.
3 Abstract ChampionDecider picks the champion set from entries with plazaDistance and bolts; StubChampionDecider returns a canned set, no real tie-break logic.
4 Do not import from night/ or the host service. Pure Dart, no Flutter imports, file under 300 lines.
5 Run the tests until they pass. Run dart analyze on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/city/stubs.dart · packages/party_host/test/city/stubs_test.dart
check: format analyze host
report: docs/briefs/m17/board3a/g3s-report.md
