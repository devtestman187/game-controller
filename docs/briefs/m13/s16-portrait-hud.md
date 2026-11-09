job: M13 device fixes 6: the clock area on a portrait tablet (owner's iPad in portrait, joined to a phone host, Nov 9, 2026: "Clock blocks the puzzle." The screenshot: a solo Shape Race board filling the width at the top of the screen; the clock area, "7:44", "0/6" and the time bar, on a panel about a third of the board wide over the board's top-left corner, with half a screen of empty space under the board above the pad.)
pub: no
stop: after it.
read: packages/puzzle_game/lib/src/camera.dart (`hudPlace`, `_hudRoom`, `_hudSize`, the `hud*Fraction`s, `HudForm`, `mirrorPlace`, `place`) · how the view and the painter use the placement (play_view.dart, view.dart, board_hud.dart, match_hud.dart, puzzle_painter.dart) · how the phone app passes the box and its pad rects (controller_app/lib, the joined puzzle view) · docs/briefs/m12 m12-phone-layout §0.7c and m12-opponent-mirror (rules 5, 8) · the camera and layout tests in puzzle_game/test and controller_app/test · docs/review-rules.md · docs/coding-guidelines.md

The cause (Claude, from the code): every HUD size is a fraction of the box's **height** (`hudClockFraction` 0.08 and so on), chosen for a phone on its side, 393 px tall. On a portrait iPad the box is about 1,366 px tall, so the clock area is about 3.5 times as big. And in portrait the world fills the box's width, so there's no room beside it for any form; `hudPlace` falls back to `HudForm.corner`, over the board.

Claude's rules:
1. **The size follows the box's shorter side**, not its height: every `hud*Fraction` and `hudTopFraction` is a fraction of `min(box.width, box.height)`. A phone on its side is unchanged (its shorter side is its height), so the landscape phone layouts, their tests and the m12 mirror pictures must not change.
2. **A new place before the corner: under the world.** When no form fits beside the world, the clock area goes under the world (the board and tray as drawn), `hudWorldGapPx` below it, starting at the world's left edge, in the first form that fits the world's width (one line, two lines, short), if it fits there: inside the box and clear of the pad rects the app passes (each with `mirrorGapPx` of air). Pass the pad rects to `hudPlace` the way `mirrorPlace` gets them.
3. **The corner stays the last resort**, for a box with room neither beside nor under the world.
4. The mirror (a split race on a phone) keeps its rules; where it uses `hudPlace`, it gets the same new place. A portrait race should still never put the mirror over the board or the pad.
5. `HudForm` gains the new place if the painter needs to know it (e.g. `under`); the painter draws it like the forms beside the world (no panel), since it is off the board.
6. Say in docs/design (the m12 phone-layout section the code cites, or look-and-sound.md if that's where the phone HUD is now described), "Decided at device test 3" (owner, Nov 9): the clock area sizes by the shorter side, and in portrait it goes under the board.

tests (each failing first):
- A portrait iPad box (1024 × 1366 with the joined phone's pad rects at the bottom, as the app passes them; and 820 × 1180), a solo board: the clock area is under the world, clear of the world and of the pad, its clock no taller than 0.08 of 1024.
- A landscape phone (852 × 393) and a landscape iPad (1366 × 1024): exactly the placement and form they had before (pin today's rects).
- A portrait box with no room under the world (the pad right under it): the corner, as before.
- A portrait split race with a mirror: neither the clock area nor the mirror meets the board, the tray or the pad.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). The m12 mirror PNGs must come out unchanged; list any test you change, and why.
- A picture, `docs/design/m13-portrait-hud.png`: the phone's joined view of the house puzzle, solo, on a portrait iPad box (1024 × 1366) with its pad, Sunny. Deterministic.

in the report: test counts before and after; the files changed; the clock area's rect and form before and after for each tested box.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · the puzzle tests rewrite docs/design/m12-mirror-*.png: they must come out unchanged; if one changes, stop and say why · don't touch packages/party_host (another job is working there).
allow: docs/briefs/m13/s16-portrait-hud-report.md · docs/design · packages/puzzle_game · controller_app/lib · controller_app/test
check: format analyze look puzzle phone tv
report: docs/briefs/m13/s16-portrait-hud-report.md
