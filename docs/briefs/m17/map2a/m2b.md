job: map2a m2b — dynamic layer: tokens, built tiles, gate, cone and Bolts chips over the cached map
stop: no wiring into any game or menu, no Try-the-map entry. No import of night/. No rule or tuning change; do not edit city_layout.dart or city_painter.dart.
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/city/board.dart:44-178 (Board, Token, Bolts, Gate, GateKind) · packages/party_host/lib/src/city/rules.dart:18-135 · packages/party_host/lib/src/city/art/city_layout.dart (from job m2a: CityLayout.tileCenter, plazaCenter, tileSize) · packages/party_host/lib/src/city/art/city_painter.dart (how it draws)
changes: CityScene · CitySnapshot · CityScene.from · CityTokenArt · CityOverlayPainter (all new, under city/art/)
model: haiku
turns: 35
expected-min: 25
tests-first: exempt new files only; tests fail on an empty stub by construction
do:
1 New city/art/city_scene.dart: `CitySnapshot({board, rules, tilesBuilt: Map<String,int> by road id, tokens: List<Token>, bolts: Bolts?, roadworks: bool})` and pure `CityScene.from(CitySnapshot, CityLayout)` giving built tiles per road (clamped to rules.roadLength), token placements (absent flagged; badge number for the 7th and 8th player), the gate marker (on its tile, open flag from board.gateOpen), the cone flag, Bolts chips. Pure: same input, same scene.
2 New city/art/city_tokens.dart (token and badge drawing) and city_overlay_painter.dart (`CityOverlayPainter extends CustomPainter` paints a CityScene: built tiles, complete road, tokens with absent dimmed, gate marker, cone, chips). Late joiner at lateJoinTilePosition draws like any token.
3 Tests (write first) beside, test/city/art/city_scene_test.dart and city_overlay_painter_test.dart: scene table for empty board, mid-night, gate placed, gate open, roadworks, complete road, 8 players; absent dimmed; painter test per layer with a recording canvas.
4 Each file under 380 lines. Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/city/art/city_scene.dart · packages/party_host/lib/src/city/art/city_tokens.dart · packages/party_host/lib/src/city/art/city_overlay_painter.dart · packages/party_host/test/city/art/city_scene_test.dart · packages/party_host/test/city/art/city_overlay_painter_test.dart
check: format analyze
report: docs/briefs/m17/map2a/m2b-report.md
