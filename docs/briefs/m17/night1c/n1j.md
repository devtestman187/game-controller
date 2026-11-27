job: night1c n1j — the final scores crown the night's champions through NightState.championsAmong
stop: no new rule: championsAmong already equals the scoreboard's place 1 (night_scoring_test pins it); no layout change, no new widget; crown, winner mark and medals look as today
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/ui/night_scoreboard_widgets.dart:90-165 (the two places that test `row.place == 1`) · packages/party_host/lib/src/night/night_state.dart:325-340 (championsAmong) · packages/party_host/test/night_scoring_test.dart:40-90 · packages/party_host/test/night_scoreboard_card_test.dart (where the crown is tested) · owner decision O1 Nov 26 "I am good with the defaults suggested": Quick night champion = most points, ties share · code-health night1b: "championsAmong has no lib caller (wire it in B4 so the scoreboard and the champion share one rule)"
changes: _Scoreboard
model: haiku
turns: 35
expected-min: 20
tests-first: exempt behaviour is already right on the base (championsAmong equals place 1); the new test pins the wiring and the tie case and may pass on the base
do:
1 night_scoreboard_widgets.dart: compute `final champions = night.championsAmong(players)` once where the rows are built and use `champions.contains(row.id)` in place of `row.place == 1` for the crown (`badgeMark`) and `isWinner`. The medal for place stays `_medalOf(row.place)`.
2 Tests: add to NEW packages/party_host/test/night_scoreboard_champions_test.dart (final scores shown with a night that is over, as night_scoreboard_card_test.dart mounts them): one leader is the only crowned row; two players tied on top are both crowned; a leaver who finished top keeps the crown only while championsAmong names them, same as the rows' isHere rule (assert the crowned set equals `night.championsAmong(players)` in each case).
3 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/ui/night_scoreboard_widgets.dart · packages/party_host/test/night_scoreboard_champions_test.dart
check: format analyze
report: docs/briefs/m17/night1c/n1j-report.md
