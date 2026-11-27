job: board3a f3a — fix review findings F2, F4, F5, F6 of wave 1 (board types and stubs)
stop: no import from night/ (batch rule: the board line imports nothing from night/); no shared file (tools/mine.sh and night/champion.dart are not touched); the untracked-folder gap in tools/mine.sh is owner/main's, not this job's
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/city/stubs.dart:20-35 · packages/party_host/lib/src/city/board.dart:1-30 · packages/party_host/lib/src/city/board.dart:78-90 · (packages/party_host/lib/src/night/champion.dart:31-40 for the shape to compare)
changes: packages/party_host/lib/src/city/stubs.dart (CityChampionEntry documented against night ChampionEntry) · packages/party_host/lib/src/city/board.dart (unique-id check, GateKind dartdoc)
model: haiku
turns: 35
expected-min: 20
do:
1 Tests first: in packages/party_host/test/city/board_test.dart add a test that a board with duplicate district or tile ids is refused (ArgumentError or assert), and in packages/party_host/test/city/stubs_test.dart a test that StubRoundPlacing.placeRound with duplicate player ids throws ArgumentError. Run them; they must fail first.
2 board.dart: enforce unique ids (assert or validating factory) so the test passes; keep "[id] is unique on the board" true in code.
3 stubs.dart: placeRound throws ArgumentError on duplicate ids. Do NOT import ChampionEntry from night/. Keep CityChampionEntry as its own type and add one dartdoc paragraph stating how its shape differs from night ChampionEntry and why no import is used.
4 board.dart near line 83: one-line dartdoc on each GateKind value (brokenBridge, potholeField, riverFerry).
5 Run dart format, dart analyze and flutter test on the two changed lib files and the two test files by explicit path. Do not use tools/mine.sh for them (it skips untracked folders). Fix every info, warning and error.
allow: packages/party_host/lib/src/city/board.dart · packages/party_host/lib/src/city/stubs.dart · packages/party_host/test/city/board_test.dart · packages/party_host/test/city/stubs_test.dart
check: format analyze host
report: docs/briefs/m17/board3a/f3a-report.md
