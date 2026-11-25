job: m16 m165 c0a — contract 1 of 2 for B-044: puzzle_game's draw chain accepts hudRects (controls only the HUD must clear); nothing uses them yet
stop: after the parameter chain. No change to place(), the mirror or board fit, no app, game_kit or party_host file; hudPlace takes the list and ignores it (job b1 uses it).
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/camera.dart:296-311 (hudPlace) · phone_hud.dart:60-112 · match_painter.dart:15-70,160-170,225-240 · match_view.dart:25-70,150-195 · play_view.dart:35-90,205-215 (every `padRects` there) · packages/puzzle_game/test/mirror_place_test.dart:1-40 (setup) · owner B-044 (Nov 25): "feed them to the HUD clearance only, not to the board or mirror fit"
changes: PuzzleCamera.hudPlace hudRects (new optional parameter) · MatchPainter.hudRects (new) · MatchView.hudRects (new) · PuzzlePlayView.hudRects (new) · phoneHud hudRects (new)
model: haiku
turns: 60
expected-min: 30
do:
1 Tests first: new packages/puzzle_game/test/hud_rects_plumbing_test.dart: (a) MatchPainter.shouldRepaint is true when only hudRects differs and false when equal (copy a painter construction from an existing match_painter test); (b) PuzzleCamera.hudPlace with hudRects: [Rect.fromLTWH(0, 0, 10, 10)] returns the same rect and form as without (documented as "not used yet"). Run it, see it fail to compile, then change lib.
2 Add `List<Rect> hudRects = const []` next to every `padRects` parameter or field in the files above (match_painter.dart incl. shouldRepaint with listEquals, match_view.dart, play_view.dart, phone_hud.dart, camera.dart hudPlace), pass it down the same way, and hand it to the hudPlace call in phone_hud.dart. The place() calls keep padRects only. Dartdoc on each: "controls the HUD keeps clear of, which the board and the mirror may go under (B-044)".
3 Run the new test, mirror_place_test.dart, portrait_hud_test.dart, match_view_whole_if_no_mirror_test.dart and `flutter test` for the puzzle_game files you touched; then `dart analyze` on the changed files and fix every info, warning and error.
allow: packages/puzzle_game/lib/src/camera.dart · packages/puzzle_game/lib/src/phone_hud.dart · packages/puzzle_game/lib/src/match_painter.dart · packages/puzzle_game/lib/src/match_view.dart · packages/puzzle_game/lib/src/play_view.dart · packages/puzzle_game/test/hud_rects_plumbing_test.dart · docs/briefs/m16/m165/c0a-report.md
check: format analyze puzzle
report: docs/briefs/m16/m165/c0a-report.md
