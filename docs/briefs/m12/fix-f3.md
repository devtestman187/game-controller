job: m12 build 4 fix-f3 G4 — the mirror: a dot you can see, clear of the stick, the palette's orange
stop: after G4.
read: docs/code-health.md N3, N4 and the look-and-sound row · docs/briefs/m12/build4-review-r3-report.md findings 2, 3 and the later · docs/design/m12-opponent-mirror.md (the owner's rules: the dot is what matters) · docs/briefs/m12/s11-report.md (sizes) · packages/puzzle_game/lib/src/{mirror_painter,camera,piece_size,view,match_painter}.dart · the pad's layout in controller_app (`stickLayout` and the D-pad's, read only) · packages/puzzle_game/test/mirror_test.dart · docs/coding-guidelines.md
do:
1 N3: their dot (and its ring) gets a size floor in mm, like the pieces: at least the mirror's smallest-piece floor (`mirrorMinPieceMm`) across, on every phone size; the held piece stays where it is relative to the dot. Say the size you chose and why.
2 N4: the mirror's rect stays clear of the left stick's disc and the D-pad's buttons in every pad mode on the three phone sizes the tests use (852×393, 734×370, 667×375). The pad's geometry is the app's and the game can't import it: get the area to keep clear through what the view is given (a rect or inset the app passes in, through the existing view/module seam), not by copying numbers. Where the mirror can't fit clear of the pad, no mirror (today's HUD), as the contract says for a narrow phone. Say which puzzles lose it on which phone.
3 The look row: the mirror's orange refers to `playerColors[1]` (or a named "other side" colour that does), not a copied literal.
tests (each failing first): the dot's drawn size ≥ the floor on each phone size (fails at today's 2.6 units); the mirror's rect doesn't meet the stick's disc or the D-pad in each mode and size; the orange equals the palette's. Redraw docs/design/m12-mirror-iphone.png and m12-mirror-169.png. Existing tests: list any old → new.
in the report: test counts before and after, the files changed, computed values.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/fix-f3-report.md · docs/design/m12-mirror-iphone.png · docs/design/m12-mirror-169.png · packages/puzzle_game · packages/game_kit/lib/src/frame_view.dart · packages/game_kit/lib/src/game_module.dart · packages/game_kit/test · controller_app/lib/src/ui/joined_view.dart · controller_app/lib/src/host · controller_app/test
check: format analyze puzzle kit phone
report: docs/briefs/m12/fix-f3-report.md
