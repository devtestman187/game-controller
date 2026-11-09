# M13 s18: the board fills a tablet (device fix 8)

The owner's iPad, joined to a phone and playing a solo boat, drew the tray and board in the top middle at about half the size the box allowed. A one-board round now fills the box with its one world: centred across, its board and tray clear of the app's pad, the top bar and the clock area. A split race on a tablet, and every phone's side camera and whole camera, are unchanged.

## The cause

`PuzzleCamera.place` always fitted two worlds for the whole camera (a tablet draws `wholeMatch`): stacked, `box.height / (2 * world.height)`, or side by side when the box is wider than 3:1. A one-board round has one world, so it was drawn at half the scale the box allowed, top-aligned, with the rest of the height showing the empty world's bottom margin. That is exactly the owner's screenshot.

## What I chose, and why

`place` with a whole camera and `split` false takes a new branch, `PuzzleCamera._oneBoard` (`camera.dart`):

- the one world is centred across;
- its **tray row's top sits at the top bar's band** (`hudTopFraction`), so nothing drawn is under the bar, as with the clock area today;
- the scale is the largest of: the box's width fit; the box's height fit with the tray's top at the band; and the room the clock area needs — beside the world in the short form's width or under it in the one-line height, whichever is bigger;
- two passes then cap the scale so the **board** stays `mirrorGapPx` above every pad whose x range the board's width reaches (the board widens in px as the scale grows, so the second pass rechecks at the scale the first leaves).

Why that reading and not a stricter one: a literal "the world's rectangle keeps clear of the pads" counts the world's empty margin, and the left stick's disc sits at a y only that margin reaches. That caps the box at about 9.05 px/unit on 1366 × 1024 and 6.98 on 1180 × 820 — 1.42× and 1.37× today's scale, both **below the brief's 1.5×**. Checking what is drawn is how the same rule is already read for the mirror (`mirrorPlace`'s `boardAndTray`), and the tray rather than the world's top is what `hudTopFraction` protects. With that the boat is 1.52× and 1.51× today's scale, the house 1.76×, and the portrait boat fills the 1024 px width exactly. The clock keeps s16's rules unchanged: beside the world at the band in the first form that fits, else under it, else the corner; its under place already shifted right of a pad whose band it meets (`_hudUnder`).

The world's empty margin may reach past the band or a pad's air: nothing is drawn there, and the world's margins are the layout's, not content.

## Files changed

- `packages/puzzle_game/lib/src/camera.dart` — `place`/`scale` take `split` and `padRects`; the new `_oneBoard`; `hudPlace`'s beside and under places use the same world; docs compacted to stay under 400 lines (399).
- `packages/puzzle_game/lib/src/match_painter.dart` — the phones painter passes `split: s.split` and `padRects` to `place` (and to `hudPlace`/`mirrorPlace`, as before).
- `packages/puzzle_game/lib/src/view.dart` — `fieldIn` moved here (from `camera.dart`) to keep the 400-line limit; unchanged behaviour.
- `packages/puzzle_game/test/support/portrait_pads.dart` — the sticks-mode pad rectangle sets the app draws on 1366 × 1024, 1180 × 820 and 1024 × 1366, and a phone on its side 852 × 393.
- `packages/puzzle_game/test/tablet_board_test.dart` — new: landscape solo boat at 1366 and 1180 (≥1.5×, pad/top-bar/clock clear, clock at the band), portrait 1024 (world fills the width, clock under it, right of the stick), a split race at 1366 (pinned rects, pad changes nothing), a phone at 852 × 393 solo and split (pinned rects).
- `packages/puzzle_game/test/tablet_board_png_test.dart` — new: writes `docs/design/m13-tablet-board.png`.
- `packages/puzzle_game/test/camera_test.dart` — the whole-camera tablet HUD tests now say `split: true` (they mean a race's two worlds).
- `packages/puzzle_game/test/portrait_hud_test.dart` — the s16 portrait place uses the one-board world (with the pad) and expects the clock right of the pad; the "no room under the world" case stays a race (`split: true`).
- `packages/puzzle_game/test/worker_paint_test.dart` — the smallest-phone worker test draws through the one-board place and puts the player on the board's flat top left (the tree's faint target fill hid the board the walk looks for once the board was drawn bigger).
- `controller_app/test/tablet_board_test.dart` — new: the app's real `leftPadRects` (sticks, iPad px/mm) at 1366 × 1024, 1180 × 820 and 1024 × 1366, with the bar, pad and clock clearances and the pinned scales.
- `controller_app/test/portrait_hud_test.dart` — the s16 clock test uses the one-board world; the clock under it starts right of the pad.
- `docs/design/m12-phone-layout.md` — the new "Decided at device test 3" line (7c).
- `docs/design/m13-tablet-board.png` — new: the boat, solo, on 1366 × 1024 and 1024 × 1366, pad rects as light outlines, Sunny.

`packages/puzzle_game/lib/src/play_view.dart` shows in `git status` from another job's working tree (round music `onClock`); I did not change it, and it is not part of this job.

## Tests first

With the `_oneBoard` branch disabled (the line commented out for the run, then restored), the new `tablet_board_test.dart` failed exactly the two one-board tests ("a solo boat on a landscape iPad…", "a solo boat in portrait…"); the split-race and phone pins passed, as they should. With the branch back, all four pass. The picture test and the app test then went from failing (old placement) to passing.

## Counts

- puzzle: 227 before → 232 after (233 with the throwaway print test; the new file has 4, the picture 1).
- phone: 435 before → 437 after (438 with the throwaway scratch test; the new file has 2).
- look 111, tv unchanged. The counts are worked out by subtracting the new tests from the check's totals.

## World rects and scales, before and after

Before is the whole camera's left world for a one-board round (the old two-world place); after is the one-board place. Pads as `controller_app` passes them.

| Box | Round | Before | After |
| --- | --- | --- | --- |
| 1366 × 1024 | solo boat | 6.358966 px/unit, (392.560, 0)–(973.440, 512) | **9.671142**, (241.280, 124.018)–(1124.720, 902.702) — 1.52×; clock short (8, 143.36)–(233.28, 319.488) |
| 1180 × 820 | solo boat | 5.092141, (357.421, 0)–(822.579, 410) | **7.708648**, (237.915, 99.383)–(942.085, 720.054) — 1.51×; clock short (8, 114.8)–(188.4, 255.84). The rounded pad support gives 7.708168 (1.5137×). |
| 1024 × 1366 | solo boat | 8.482762, (124.558, 0)–(899.442, 683) | **11.209872**, (0, 120.940)–(1024, 1023.517) — the width filled; clock one line (173.8, 1031.517)–(712.424, 1146.205), right of the stick |
| 1366 × 1024 | split boat | 6.358966, (392.560, 0)–(973.440, 512) and (392.560, 512)–(973.440, 1024) | unchanged |
| 1366 × 1024 | split house | 5.785311, (438.684, 0)–(927.316, 512) and (438.684, 512)–(927.316, 1024) | unchanged |
| 852 × 393 | solo boat (side camera) | 4.881003, (203.065, 0)–(648.935, 393) | unchanged |
| 852 × 393 | split boat | 2.440502, (314.532, 0)–(537.468, 196.5) and (314.532, 196.5)–(537.468, 393) | unchanged |
| 852 × 393 | solo house (side camera) | 4.440678, (238.468, 0)–(613.532, 393) | unchanged |
| 852 × 393 | split house | 2.220339, (332.234, 0)–(519.766, 196.5) and (332.234, 196.5)–(519.766, 393) | unchanged |

For context, the house, one board: 1366 → 10.180809 (1.76×), 1180 → 8.152601 (1.76×), 1024 portrait → 11.228671 (1.45×; its taller board is what stops it, the stick's air does the rest), world (37.808, 120.903)–(986.192, 1114.640). That 1.45× is the pad doing its job; the brief's ≥1.5× is asked of the boat.

## The picture

`docs/design/m13-tablet-board.png` (2486 × 1414) is the two boxes side by side on the Sunny sky: the joined boat, solo, at 1366 × 1024 and at 1024 × 1366, with the app's sticks (and their D-pad arms) drawn as faint ink outlines so the clearance reads. Fresh match, 10:00 clock, the look's own fonts: the same picture each run. `docs/design/m13-tablet-board.png` is the only new design file.

## Self-check (review-rules part A)

1. **Every host setup.** The screen target (TV, PC, "Show on this device") is untouched: `camera_test` "the whole camera on the screen is today's field". A joined phone and "Play on this phone" draw their side: `tablet_board_test`'s 852 pins. A host/phone with a whole camera in a one-board round now fills its box (the same rule); `worker_paint_test`'s smallest-phone case pins the 7 mm worker floor there. No protocol change, so an older build draws as before (`test:` unchanged snapshots).
2. **When kept state starts and ends.** Nothing is kept: the camera is a pure function of layout, box and pad rects — no timer, cache or flag (`camera_test` calls `place` twice and compares; `tablet_board_test` calls it with and without pads).
3. **How a new state combines.** No new pause/hide/wait state; only drawn rects move. Solo and race are covered side by side (`tablet_board_test`), and the pause/away/ready pairings are on paths this diff does not touch.
4. **Stay in the job's folder.** Only the files in `allow:` changed; `git status` shows the puzzle/phone sources, tests, the two design files and the report; the party_host, assets and `play_view.dart` changes in the tree are another job's.
5. **Stop rather than overstep.** `docs/design/m13-portrait-hud.png` (s16's picture) is outside `allow:` and its test now redraws the one-board portrait. I restored the committed picture rather than ship a change I may not make; see question 1.

## Checks

`tools/check.sh format analyze look puzzle phone tv`: **all PASS** — format 2 s, analyze 11 s (also `dart analyze --fatal-infos`: no issues), look 111 tests, puzzle 233 tests, phone 438 tests, tv 12 s. The m12 mirror pictures came out **unchanged** (`git status` lists none of them after the picture tests ran), as did `m13-carry-side.png` and `m13-worker-run.png`.

## Questions

1. **s16's picture.** `docs/design/m13-portrait-hud.png` is outside `allow:`, but its test now draws the one-board portrait (a bigger board and the clock under it), so the puzzle check rewrites it. I restored the committed bytes. Should the picture be regenerated (and `allow:` extended), or is it the s16 job's to refresh?
2. **A whole camera on a phone.** A one-board round on a phone with the whole camera (a spectator or a host with no own side) now fills the box too, by rule 1's first sentence. Is that wanted, or should the fill be tablets only? `worker_paint_test` pins the worker there either way.
3. **The pad cap is conservative.** The two passes only ever shrink: on 1180 × 820 the first pass's pad cap (7.708168 with the rounded support) survives although the board no longer meets that pad at the final scale; a third pass or a fixed point could recover a little size. The brief's ≥1.5× holds as it stands.

## Suggestions (not acted on)

- `PuzzleCamera.scale` now takes `split`/`padRects`; any caller that knows a round is one-board should pass them, so the size check and the painter agree. Today `_oneBoard` only runs when the painter says `split` false, and no other caller asks for `scale` on a one-board round.
- The `_shortFormWidth` constant is `_clockChars * glyphEm * hudClockFraction`, used only by `_oneBoard`; `_hudSize` still computes the same number inline. One of the two could call the other.

## Commit message

Fill a tablet's one-board round with its board

`place` now fits one world for a whole camera on a one-board match
(`split` false), at the largest scale that keeps the board and tray
clear of the app's pad, the top bar and the clock area, centred across
and with the tray at the bar's band. A split race, a phone's side
camera and the whole camera are unchanged. The clock keeps s16's
beside/under/corner rules. Adds the tablet tests, the app-level test
with the real pad rects, and `m13-tablet-board.png`.

## Status row

M13 s18 done: a tablet's one-board round fills the box with its board (1.52× / 1.51× today's scale in landscape, the width in portrait), clear of the pad, bar and clock; races and phones unchanged; s16's picture is stale and waits on question 1.

## Delete

- controller_app/test/zz_scratch_test.dart
- packages/puzzle_game/test/zz_pins_test.dart
- packages/puzzle_game/test/zz_carry_side.orig.png
- packages/puzzle_game/test/zz_portrait_hud.orig.png
- packages/puzzle_game/test/zz_worker_run.orig.png

## Claude's review

- Accepted. `m13-tablet-board.png`: the boat fills a landscape iPad's height down to the pad, and a portrait one's width with the clock under it. All checks pass on the combined tree (puzzle 235, phone 437).
- Answers: 1) `m13-portrait-hud.png` and the three m12 mirror pictures changed only in their dashed target edges (s19a's square caps; checked by a pixel diff); committed here. 2) A phone's whole-match one-board round (a phone showing the game, no own side) filling its box: wanted. 3) The conservative pad cap is fine.
