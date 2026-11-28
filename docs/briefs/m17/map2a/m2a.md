job: map2a m2a — static 2.5D city painter cached as a ui.Image, plus pure layout geometry
stop: no tokens, gate, cone or Bolts (job m2b). Do not wire the map into any game or menu. No rule or tuning change.
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/city/board.dart:25-70 · packages/party_host/lib/src/city/rules.dart:18-135 (roadLength, corners, forPlayers, assignStarts :237-247) · packages/toy_look/lib/src/toy_shaders.dart:10-50 · packages/toy_look/lib/src/toy_shape.dart:86-140 · packages/party_host/test/support/all_looks.dart · owner: "Style = mock-up panel 3" (Nov 26); Centre Plaza = the Plaza tile that ends every road
changes: CityLayout · CityLayout.compute · CityPainter · CityStaticCache (all new, under city/art/)
model: sonnet
turns: 80
expected-min: 30
tests-first: exempt new files only; the tests fail on an empty stub by construction
do:
1 New city/art/city_layout.dart (pure Dart, no dart:ui widgets beyond Size/Offset/Rect): `CityLayout.compute({required Size size, required Board board, required CityRules rules})` gives `tileCenter(String roadId, int index) -> Offset`, `plazaCenter`, `tileSize` (double), `districtRect(String districtId)`. Tiles per road = rules.roadLength (never a literal 6); players 2-8 (up to 8 districts: 4 corners plus 4 lanes beside corners). Every centre inside size; no two tile rects overlap.
2 New city/art/city_painter.dart: `CityPainter extends CustomPainter` draws districts, corner starts, road lanes and the Centre Plaza in the toy_look style (ToyShaders shade when loaded, plain Canvas path when null). `CityStaticCache` renders the static layer once per size to a ui.Image (PictureRecorder + toImage, never keep a Picture) and reuses it; later frames only drawImage. Expose a counter of static builds for tests.
3 Tests in test/city/art/city_painter_test.dart (write first, run first): geometry for 2..8 players (bounds, no overlap, distinct centres, road length follows a CityRules with another roadLength); cache built once per size and rebuilt on a size change; fake canvas proves the second paint is one drawImage and no static draws; fallback path paints with shade null; widget test at TV 1920x1080 and phones 360x640 and 640x360 under every look (forEachLook).
4 Each file under 380 lines. Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/city/art/city_layout.dart · packages/party_host/lib/src/city/art/city_painter.dart · packages/party_host/test/city/art/city_painter_test.dart
check: format analyze
report: docs/briefs/m17/map2a/m2a-report.md
