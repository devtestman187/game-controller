job: M13 device fixes 8: the board fills a tablet (owner's iPad in landscape, joined, a solo boat, Nov 9, 2026: "On iPad, the puzzle area should take up more of the screen. It's only taking a small portion here." The screenshot: the tray and board in the top middle, about a third of the screen's width and under half its height; the clock on the left; the pad's sticks, D-pad and buttons in the bottom corners; the space between them empty.)
pub: no
stop: after it.
read: packages/puzzle_game/lib/src/camera.dart (`forPlayer` and `wholeMatch`, `place`, `hudPlace`, `mirrorPlace`, `wholeSideBySideAspect`), split_layout.dart, match_painter.dart, view.dart · controller_app/lib/src/ui/joined_view.dart and where it decides `wholeMatch` (a tablet) and passes the box and the pad rects · docs/design/m12-phone-layout.md §2 and §0.7c (with s16's "device test 3" lines) · docs/briefs/m13/s16-portrait-hud-report.md · the camera and layout tests in puzzle_game/test and controller_app/test · docs/review-rules.md · docs/coding-guidelines.md

The cause (Claude, from the code; confirm it): on a tablet the phone draws the whole match (`wholeMatch`), and `place` for the whole match always makes room for two worlds, stacked (`box.height / (2 * world.height)`) or side by side. A one-board round (solo, or a team on one board) has one world, so it is drawn at half the size the box allows, at the top.

Claude's rules:
1. **A one-board round fills the box with its one world**, as a phone's side camera does: the largest scale that fits, centred across. A split race on a tablet still draws both sides as now.
2. **The world keeps clear of what the phone draws over it**: the app's top bar (as `hudTopFraction` does today) and the clock area (s16's rules: beside the world, else under it, else the corner). On a tablet, where the pad's controls sit in the bottom corners, the world may sit between them: it must not meet the pad rects the app passes (each with `mirrorGapPx` of air). Choose the largest world that meets these, landscape and portrait; say in the report what you chose and why.
3. Phones are unchanged: a phone on its side and a phone's side camera place exactly as before (pin today's rects in tests).
4. Say in m12-phone-layout.md, "Decided at device test 3" (owner, Nov 9): on a tablet a one-board round fills the screen with its board.

tests (each failing first):
- A landscape iPad box (1366 × 1024, and 1180 × 820) with a joined phone's pad rects, solo boat: the world is at least 1.5 times today's scale, clear of the pad rects, the top bar and the clock area, and the clock area is still placed by s16's rules.
- The same in portrait (1024 × 1366): the world fills the width, and the clock area is under it or beside it, clear of the pad.
- A split race on a landscape iPad: both sides as today (pin the rects).
- A phone on its side (852 × 393), solo and split: as today (pin the rects).
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit); the m12 mirror PNGs come out unchanged.
- Pictures: `docs/design/m13-tablet-board.png`, the joined view of the boat, solo, on a landscape iPad box (1366 × 1024) and on a portrait one (1024 × 1366), with the pad's rects drawn as light outlines so I can see the clearance. Sunny, deterministic.

in the report: the cause as you found it; test counts before and after; the files changed; the world's rect and scale before and after for each tested box.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch packages/party_host, the puzzle files or puzzle_painter.dart (other jobs are working there) · the puzzle tests rewrite docs/design/m12-mirror-*.png: they must come out unchanged; if one changes, stop and say why.
allow: docs/briefs/m13/s18-tablet-board-report.md · docs/design/m12-phone-layout.md · docs/design/m13-tablet-board.png · packages/puzzle_game/lib/src/camera.dart · packages/puzzle_game/lib/src/match_painter.dart · packages/puzzle_game/lib/src/view.dart · packages/puzzle_game/lib/src/play_view.dart · packages/puzzle_game/test · controller_app/lib · controller_app/test
check: format analyze look puzzle phone tv
report: docs/briefs/m13/s18-tablet-board-report.md
