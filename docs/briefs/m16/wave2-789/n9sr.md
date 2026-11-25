job: wave2-789 n9sr — Shape Race HUD says the night's "Round N of M"
stop: Arena is done (n9d2). No protocol, snapshot-wire or party_host change. No new settings.
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/board_hud.dart:31-60 (the name text, drawn per board) · packages/puzzle_game/lib/src/puzzle_painter.dart:14-60 (constructor) · packages/puzzle_game/lib/src/play_view.dart:40-52,100-120,140-160,175-207 (round and rounds already reach the session) · packages/puzzle_game/lib/src/view.dart:100-130 · packages/puzzle_game/lib/src/match_view.dart:185-205 · packages/puzzle_game/lib/src/match_painter.dart:120-185 (the painters for two boards) · packages/puzzle_game/test/portrait_hud_test.dart:1-60 and test/support/match_helpers.dart (how HUD tests run) · docs/briefs/m16/wave1-789/n9d2.md (Arena did the same) · owner decision (plan item 9): the night's round shows as "Round N of M" in Shape Race; HUD only.
changes: roundLabel · Round ${round} of ${rounds}
turns: 60
expected-min: 35
do:
1 Tests FIRST, new file packages/puzzle_game/test/round_label_test.dart: a puzzle HUD built with round 2 and rounds 3 draws 'Round 2 of 3' (find the way portrait_hud_test or points_paint_test reads drawn text; a painter test with a recording or a PuzzlePlayView text capture), without them draws no round text; with two boards only board 0 draws it. Menu and TV look.
2 PuzzlePainter gets an optional `String? roundLabel`. board_hud.dart draws it before the puzzle name ('Round 2 of 3 · <name>') on board 0 only, same style as the name; the name keeps its place and the label never pushes the clock or the count (cut the label with an ellipsis rather than overlap).
3 PuzzlePlayView builds the label as 'Round $round of $rounds' when both are set and passes it through view.dart, match_view.dart and match_painter.dart to the painters. A one-board round (no night) is unchanged.
4 Fix pinned tests that break (portrait_hud_test, match tests): grep first. No file you touch ends over 380 lines.
5 Before finishing run `dart analyze` on the files you changed and fix every info.
allow: packages/puzzle_game/lib/src/board_hud.dart · packages/puzzle_game/lib/src/puzzle_painter.dart · packages/puzzle_game/lib/src/play_view.dart · packages/puzzle_game/lib/src/view.dart · packages/puzzle_game/lib/src/match_view.dart · packages/puzzle_game/lib/src/match_painter.dart · packages/puzzle_game/test/round_label_test.dart · packages/puzzle_game/test/portrait_hud_test.dart
check: format analyze
report: docs/briefs/m16/wave2-789/n9sr-report.md
