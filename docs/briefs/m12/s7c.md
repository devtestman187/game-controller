job: m12 step7 s7c G4 — cameras, painters and the viewer for the phones world; the Arena's HUD on a phone
stop: after G4.
read: docs/design/m12-phone-layout.md (contract: §0.6, §2, §3, §4) · docs/briefs/m12/s7b-g3-report.md (your G3 report and s7c plan) · docs/coding-guidelines.md · packages/puzzle_game/lib (split_layout, view, match_painter, puzzle_painter, puzzle_module, play_view) · packages/puzzle_game/test (view_test, puzzle_module_test, split_layout_test) · packages/game_kit/lib/src/{game_module,frame_view}.dart · packages/game_kit/test · packages/party_host/lib/src/ui/puzzle_screen.dart · packages/party_host/lib/src/providers.dart · packages/test_game/lib/src/{arena_module,arena_view_widgets,arena_view}.dart · packages/test_game/test/arena_view_test.dart

Claude's answers to your G3 questions: Q1 accept `_computeScreen` (120) and `packTray` (104) as tech debt; don't split them here · Q2 yes, until this job · Q3 dormant is fine · Q4 yes: the check's floor is now `minPieceMm = 8.5` (contract §0.3), and this report retires the plan's figures.

do:
1 game_kit: `ViewContext` gains `bool wholeMatch` (record field; every literal updated). `FrameView` takes `wholeMatch` (default false) and passes it.
2 puzzle_game `camera.dart`: `PuzzleCamera` (`whole`, `side(Side.left|right)` — reuse the side type the match already has) and pure `PuzzleCamera.scale(SplitLayout layout, PuzzleCamera camera, Size box)` → px per world unit, per contract §2 (side: one world fitted, bottom-aligned; whole on phones: side by side when the box is wider than 3:1, else stacked left on top; whole on screen: today's `fieldIn`). Also `PuzzleCamera.offset(...)` or a returned transform, whatever the painters need — one source for both.
3 Painters: `MatchView`/`MatchPainter` take the target and a camera (defaults: screen, whole → today's picture, unchanged). For phones they draw through the camera, and draw the HUD in `layout.hud`: the clock, "You 2/4" for the camera's side and "Right 3/6" (or "Left") for the other, and the time bar; whole on phones draws each side's own HUD. A one-board phones match draws `layout.left` the same way with only its own count.
4 The viewer: `ShapeRaceViewer.build` picks `side` for the side `ViewContext.playerId` plays on (from the snapshot or the setup's teams; say which), and `whole` when the player isn't in the match, when `wholeMatch` is true, or for a screen match.
5 party_host: `ownPlayerIdProvider` (`Provider<String?>`, default null), doc per contract §3. The puzzle screen draws with the same camera rule as the viewer, from that ID and a `wholeMatchProvider` (`Provider<bool>`, default false, for the phone app to set on a tablet). The TV leaves both alone: nothing changes there.
6 test_game: the Arena's HUD on a phone box (contract §4): test at 667×375 and 852×393; if it overflows or takes more than 15% of the height, a one-line form below a box height you name (a named constant with its reason).

tests:
- camera: `side` at 667×375 and 734×372 gives your G3 table's px/unit for each puzzle (seed 1), bottom-aligned (the world's bottom on the box's bottom); `whole` on phones side by side at 1600×400 (wider than 3:1) and stacked at 1024×768; `whole` on screen equals `fieldIn` (4.167 at 667×375).
- viewer (puzzle_module_test, view_test): playerId on the left side → side(left); on the right → side(right); not in the match → whole; `wholeMatch` → whole; a screen setup → today's picture. The HUD text: "Right 3/6" style for the other side, the clock.
- party_host: `ownPlayerIdProvider` set to a player on the right of a phones match → the host's puzzle screen draws side(right); null → whole.
- Arena: no overflow at 667×375 and 852×393; the HUD height share.
- existing: screen pictures unchanged (view_test's comparisons keep their values); list any old → new.

in the report: line counts (flag > 300), test counts per check before and after, the camera's numbers, a screenshot-like description of what a phone side shows (top to bottom, px at 734×372).
rules: no lib file over 400 (tests 500); `split_layout.dart` (384) gains no lines — the camera goes in its own file · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s7c-report.md · packages/game_kit · packages/puzzle_game · packages/party_host · packages/test_game · controller_app/lib · controller_app/test
check: format analyze kit arena puzzle host phone tv
report: docs/briefs/m12/s7c-report.md
