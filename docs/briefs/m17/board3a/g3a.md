job: board3a g3a — City Rush board model as pure Dart types
stop: no game rules, no numbers, no draft mechanics, no bots, no adapter; no night/ or host imports
read: docs/briefs/templates/COMMON.md · packages/game_kit/lib/src/round_result.dart:74-80 (shape reference only)
changes: packages/party_host/lib/src/city/board.dart (District · Tile · Plaza · Token · Bolts per player · RoadworksBlock · Gate with GateKind brokenBridge/potholeField/riverFerry)
model: haiku
turns: 35
ladder: 2
expected-min: 20
do:
1 Write packages/party_host/test/city/board_test.dart first and run it (it fails to compile). Cover: construction of each type; one fixed road per district (ordered list of tile ids, no branching); the Plaza is the last tile of every road; a gate starts closed (opened=false); a gate is shared (one flag for all players).
2 Create packages/party_host/lib/src/city/board.dart: District(id, road: ordered tile ids ending at the Plaza), Tile, Plaza, Token(playerId, tilePosition, absent flag), Bolts as a per-player map, RoadworksBlock, Gate(kind, opened, shared).
3 Constructors validate: a road is non-empty and ends at the Plaza.
4 Pure Dart, no Flutter imports, no imports from night/ or the host service, file under 300 lines.
5 Run the tests until they pass. Run dart analyze on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/city/board.dart · packages/party_host/test/city/board_test.dart
repair: The earlier tools/mine.sh run checked 0 files (it skips untracked folders), so format, analyze and tests never ran. Run only these allowed commands with explicit paths: dart format packages/party_host/lib/src/city/board.dart packages/party_host/test/city/board_test.dart · dart analyze packages/party_host/lib/src/city/board.dart packages/party_host/test/city/board_test.dart · flutter test packages/party_host/test/city/board_test.dart. Analyzer fix: board_test.dart line 82 col 21, add const to the constructor invocation (prefer_const_constructors). Re-run until analyze is clean and the test passes; do not use tools/mine.sh for these files.
check: format analyze host
report: docs/briefs/m17/board3a/g3a-report.md
