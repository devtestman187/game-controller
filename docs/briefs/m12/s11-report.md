# M12 step 11 s11 — G4 report: the other player's live mirror on a phone in a race

Stopped at G4 as the brief says. A phone that draws its own side of a race now has the other side's
board small at its top left: their panel, their picture's outlines faint, the pieces they have placed
filled in their colours, every dot of theirs in orange at its place on it (pinned to the mini board's top
edge while they are up in their tray row), and the piece they hold drawn with them, turned as they turn
it. The clock area moves to its right, and its count line reads "Them n/N" in orange. The mirror draws at
2.2 mm per smallest piece or more, and is left out on a solo or team game, a tablet's whole match, the TV
and a box with no room for it. Nothing but drawing changed: no protocol, no snapshot.

## What was done

### 1. The floor and where the mirror goes (`piece_size.dart` 16 → 29, `camera.dart` 209 → 264)

- **`mirrorMinPieceMm = 2.2`** (`piece_size.dart`), beside `minPieceMm` (8.5) and reasoned the same way:
  a quarter of a board drawn at the size floor puts the smallest piece at 8.5 × 0.25 = 2.13 mm, a smudge
  at arm's length; 2.2 mm is the smallest that reads. It is a **screen** mm, so the constant is a floor
  on the drawn size, not on a puzzle's data.
- **`PuzzleCamera.mirrorFraction = mirrorMinPieceMm / minPieceMm`** = 0.25882 — the mirror's scale as a
  fraction of the board's. The piece's diameter cancels out: the board's mm per unit is at least
  `minPieceMm / smallest diameter`, and the mirror's is `mirrorFraction` of that, so every piece in the
  mirror is at `mirrorMinPieceMm` or more whatever the puzzle. "About a quarter" (the sketch) becomes
  0.26, and the mirror tests check it per puzzle on both phones.
- **`PuzzleCamera.hudMirrorGapPx = 8.0`**: the gap between the mirror's right edge and the clock area.
- **`PuzzleCamera.mirrorPlace(layout, camera, box, {split, text})` → `({Rect rect, double scale})?`**:
  null when `!split` (solo or a team's one board), `camera.side == null` (the whole match, i.e. a
  tablet), `layout.target != LayoutTarget.phones` (the TV), when **today's** HUD form is already `short`
  or `corner` (the box has no room beside the world), and when the width left after the mirror is short
  of the short form. Otherwise `(hudMarginPx, box.height × hudTopFraction)` and their board's size at
  `place(…, side).scale × mirrorFraction`.
- **`_hudRoom`** now shared by `mirrorPlace` and `hudPlace`: the clock area starts at `hudMarginPx`, or at
  the mirror's right edge + `hudMirrorGapPx`, and its spare width is `world.origin.dx − hudWorldGapPx −
  left`. **`hudPlace` gains `{Rect? mirror}`**: with one, only the short form is tried (the clock, then
  "You n/N" and "Them n/N" on a line each, which is what fits beside the mirror), and the area starts
  right of it. The form the gate reads is the one the box would draw *without* a mirror, so the decision
  can't chase its own tail.

### 2. What the mirror draws (`mirror_painter.dart`, new, 146 lines)

`MirrorPainter(puzzle, theirs, field, {rect, scale})`, a part of `view.dart` like the other painters. One
pass each, no more than one board draw a frame:

- the board's panel (`_board`) clipped to the rect's rounded corners;
- their picture's outlines (`_targets`): every target faint — coloured on easy, grey on medium and hard,
  as the board draws them — so the picture reads even where nothing is placed;
- the pieces they have placed (`_placed`): those with `PieceState.locked`, filled in their colours at
  their own positions and angles;
- every dot of theirs (`_players`): circles of `PuzzleGame.dotRadius` in `_them` with a white ring, at
  their place on the board, and the piece each holds (`_held`) drawn at the dot's place plus the dot's
  pinning offset, in the piece's colour with an orange outline, at its own angle;
- the orange frame around the rect, stroked last so it sits on top.

Their board is `_boardOf(s, _otherSide(camera.side!))` in `layout.left`'s world: on phones both sides
share one world shape (`SplitLayout._computePhones` returns the same field for left and right), so their
piece and dot coordinates go straight into the mirror.

While their dot is above the board — in their tray row, which is where the pieces start on a phone — it
is pinned to the board's top edge at its place across it (`_pinned`: `x` clamped one dot radius inside
the board, `y` at `board.top + dotRadius`), and what they hold moves with it.

### 3. The HUD beside it (`match_painter.dart` 300 → 332, `view.dart` 84 → 94)

- `view.dart` gains the shared colours `_board` (the panel, now used by `PuzzlePainter` and the mirror)
  and `_them` (0xFFFFA040, player 2's colour), and `part 'mirror_painter.dart'`. `PuzzlePainter` loses
  its private `_board` (257 → 256 lines).
- `MatchPainter._hud`: `phoneHud(s, camera.side)` → `scores`; `mirrorPlace(…, split: s.split, text:
  scores)`; if there is a mirror the drawn text is `phoneHud(…, mirrored: true)` and the area starts
  right of it, then `_mirror` draws it before the texts, which are the short form.
- **`phoneHud(s, side, {mirrored})`** names the other side "Them" ("You 2/4 · Them 3/4"); with no mirror
  it is still the side's name. **`_hudTexts(…, {mirrored})`** draws the last short line in `_them`. The
  widths are measured on the sides' names, the widest the short form gets, so the area is the same
  whether it says "Right 3/4" or "Them 3/4".
- No other file in the app or the package changed: `PuzzleCamera.place/scale`, `hudPlace` without a
  mirror, `phoneHud` without `mirrored`, the snapshot and the protocol are as they were.

## The numbers (seed 1, side camera on the left, `PuzzleCamera.mirrorPlace`)

px and mm (px ÷ 6.299, the iPhone's 160/25.4); "smallest" is the smallest piece's diameter as the mirror
draws it; "board mm" is the same piece at the board's own size, from the size test's print.

| box | puzzle | today's form | mirror rect (px) | scale px/unit | mirror mm | smallest mm | board mm |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 852 × 393 | house | twoLines | (8, 55.02) 68.96 × 71.26 | 1.1494 | 10.95 × 11.31 | 2.55 | 9.87 |
| 852 × 393 | rocket | twoLines | (8, 55.02) 51.18 × 75.49 | 1.2795 | 8.13 × 11.98 | 2.44 | 9.42 |
| 852 × 393 | tree | oneLine | (8, 55.02) 69.81 × 70.80 | 0.9972 | 11.08 × 11.24 | 2.53 | 9.79 |
| 852 × 393 | boat | twoLines | (8, 55.02) 93.49 × 77.06 | 1.2633 | 14.84 × 12.23 | 2.81 | 10.85 |
| 667 × 375 | tree | twoLines | (8, 52.50) 66.61 × 67.56 | 0.9516 | 10.58 × 10.73 | 2.42 | 9.34 |
| 667 × 375 | house, rocket, boat | **short** | none | — | — | — | — |
| 734 × 370 | house | twoLines | (8, 51.80) 64.93 × 67.09 | 1.0821 | 10.31 × 10.65 | 2.40 | 9.29 |
| 734 × 370 | rocket | twoLines | (8, 51.80) 48.18 × 71.07 | 1.2046 | 7.65 × 11.28 | 2.29 | 8.87 |
| 734 × 370 | tree | twoLines | (8, 51.80) 65.72 × 66.66 | 0.9389 | 10.43 × 10.58 | 2.38 | 9.21 |
| 734 × 370 | boat | twoLines | none | — | — | — | 10.21 |

The top is 0.14 of the box's height (55.02 / 52.50 / 51.80) and the left is `hudMarginPx` (8). Beside the
mirror the clock area starts at its right edge + 8 px (house 84.96, rocket 67.18, tree 85.81, boat 109.49
at 852 × 393) and is the short form, 0.2 of the height wide (78.6 px at 393, 75 at 375), which is what the
room check compares: the boat at 734 × 370 has 45.1 px left of the 74 the short form needs (its mirror
would be 88.0 px wide), so it keeps today's HUD; the house (101.5), rocket (94.9) and tree (129.3) keep
their mirrors.

## Tests

| check | before | after |
| --- | --- | --- |
| `format` (whole repo) | PASS | PASS |
| `analyze --fatal-infos` | PASS | PASS |
| `puzzle` | 106 tests | **119 tests** (118 once `scratch_mirror_test.dart` is deleted) |
| `host` | 106 tests | 106 tests |

New: `test/mirror_test.dart` (10) and `test/mirror_png_test.dart` (2). `test/scratch_mirror_test.dart`
is the numbers file this report's tables came from; it is listed for deletion below. `view_test.dart`
went from 398 to 358 lines by moving its `capture`/`difference` helpers to a shared
`test/support/frames.dart` (71 lines, with `captureImage`, `capturePng` and `pixel` added), which the two
new files need as well.

- **`mirror_test`** — "where the mirror goes": the four puzzles at 852 × 393 with their rects above
  (within 0.01 px), each rect the board's own size at `place.scale × mirrorFraction` (so it is never
  stretched), today's form per puzzle, and the clock area at the mirror's right edge + 8 px in the short
  form, ending left of the world − 8; then 667 × 375, where the house, rocket and boat HUDs are already
  `short` and there is no mirror, and the tree's 66.61 × 67.56 at (8, 52.5). "No mirror on a one-board
  match, the whole match, the screen, or a box too narrow for it": `split: false`, the `whole` camera at
  1024 × 768, `LayoutTarget.screen` at 960 × 540, a 380 × 375 box (today's form there is `corner`), and
  the boat at 667 × 375. "Every piece the mirror draws is at least `mirrorMinPieceMm`": house 2.55,
  rocket 2.44, tree 2.53, boat 2.81 at 852 × 393 and tree 2.42 at 667 × 375, computed from the puzzle's
  smallest diameter and the mirror's scale (asserted to 0.01 mm and against the floor). "The count beside
  the mirror names the other side 'Them'": `phoneHud(…, mirrored: true)` gives `['You 0/4', 'Them 0/4']`
  and "You 0/4 · Them 0/4"; without the flag it is still "Right 0/4".
- **`mirror_test` pixel checks** (a real `MatchView` captured through a `RepaintBoundary`, as `view_test`
  does, at 852 × 393): a crown they have placed shows 0x27AE60 at its place in the mirror and a spot
  with nothing in it shows the panel 0x242B36; their dot at the crown's place shows 0xFFA040 and 10 board
  units away it does not; a dot 15 units above the board is pinned at `board.top + dotRadius` at its own
  x (the pixel there is orange, 10 units along it is not, above the mirror it is not, and 15 units below
  it is not); the trunk they hold is 0x8E5B3A 7 units below the dot upright and 7 units to its right when
  turned 90°, and the other way round for each; a 2-v-1's two dots both show at their places. "A
  one-board match, a tablet's whole match and the TV draw no mirror" scans the box's top-left corner for
  the orange frame: found with the side camera, absent in all three.
- **`mirror_png_test`** — plays a real race of the tree (the crown and sun placed on the right, the trunk
  carried onto their board and turned 54° with the X button, one piece placed on the left), draws it
  through the left side's camera and writes `docs/design/m12-mirror-iphone.png` (852 × 393) and
  `docs/design/m12-mirror-169.png` (667 × 375), 20.6 kB and 17.9 kB. The HUD's texts are blocks: the test
  font draws every glyph as a box, so the frames show the clock, "You n/N" and the orange "Them n/N" as
  bars; the mirror itself is the picture.

## Files changed

- `packages/puzzle_game/lib/src/piece_size.dart` — `mirrorMinPieceMm` 2.2, reasoned from `minPieceMm`.
- `packages/puzzle_game/lib/src/camera.dart` — `mirrorPlace`, `mirrorFraction`, `hudMirrorGapPx`,
  `_hudRoom`, and `hudPlace`'s optional `mirror`.
- `packages/puzzle_game/lib/src/mirror_painter.dart` — new: their board, their placed pieces, their dots
  and what they hold.
- `packages/puzzle_game/lib/src/match_painter.dart` — the HUD computes, places and draws the mirror, says
  "Them" and draws that line in orange.
- `packages/puzzle_game/lib/src/view.dart` — the new part and the shared `_board` and `_them` colours.
- `packages/puzzle_game/lib/src/puzzle_painter.dart` — its private `_board` moved to `view.dart`.
- `packages/puzzle_game/test/support/frames.dart` — new: `captureImage`, `capture`, `capturePng`,
  `difference`, `pixel` (the first four moved out of `view_test.dart`).
- `packages/puzzle_game/test/view_test.dart` — uses those helpers; the bar test follows the mirror.
- `packages/puzzle_game/test/mirror_test.dart` — new, the 10 tests above.
- `packages/puzzle_game/test/mirror_png_test.dart` — new, writes the two frames.
- `docs/design/m12-mirror-iphone.png`, `docs/design/m12-mirror-169.png` — written by that test.
- `packages/puzzle_game/test/scratch_mirror_test.dart` — the numbers file the tables came from, to delete.
- `docs/briefs/m12/s11-report.md` — this report.

## Checks run

- `tools/check.sh format analyze puzzle host`: **PASS** on all four (format 2 s, analyze 6 s, puzzle
  119 tests, host 106 tests).
- `git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
  `generated_plugins.cmake` as modified; `git diff --numstat` is empty for all three, so only their line
  endings differ (`flutter pub get` touching them). I did not edit them.
- `tools/review.sh`: **0 fail, 2 note** — `match_painter.dart` 332 lines (lib limit 400, aim 300) and the
  literal on `piece_size.dart:29` (`mirrorMinPieceMm = 2.2`, which is meant to be a named constant). No
  FAIL on my lines.
- No lib file is over 400 (largest: `match_painter.dart` 332). `mirror_test.dart` is 393 lines, under the
  500 the tests keep to.

## Questions

1. **The HUD beside the mirror is the short form, not the sketch's two lines.** The sketch puts the clock
   and "You 1/4" on one line with "Them 2/4" beneath; that one-line form is 0.2 h + 0.02 h + 0.02 h ×
   len(score) wide — 235.8 px at 393 for "You 0/4 · Right 0/4" (227.9 for "Them") — and the boat has
   93.6 px beside its mirror at 852 × 393, so it would lose the mirror. So with a mirror the clock is on
   its own line, then "You n/N", then "Them n/N", 78.6 × 91.2 px at 393. Say if you want the sketch's
   shape instead and the boat without a mirror on the owner's phone.
2. **The mirror is 0.259 of the board, not a quarter.** A quarter would draw the house's sun at 2.13 mm
   at the 8.5 mm floor. 0.259 makes the floor a guarantee rather than a clamp: a board at exactly the
   size floor would draw the mirror's smallest piece at exactly 2.2 mm, and the phones the app ships on
   give 2.29 to 2.81 mm.
3. **The boat has no mirror at 667 × 375 or 734 × 370** (its HUD is already `short` at the first, and at
   the second the mirror would leave the HUD 45.1 px of the 74 it needs). On an iPhone SE or 8 only the
   tree shows one; on the owner's 734 × 370, three of four. Fitting the boat needs about 0.2 of the board
   (1.9 mm per piece) or a narrower clock area — a design call, so I left the floor as computed.
4. **Orange is `playerColors[1]`**, reused as "the other side" for the frame, every dot and "Them n/N",
   as m12-opponent-mirror rule 4 says. In a 2-v-1 both dots are orange, so their numbers are not
   distinguishable in the mirror; the board they see on their own phone still has them.
5. **The mirror draws no text of its own.** The count is the HUD's "Them n/N" line to the right of the
   frame rather than a label under it, so the mirror stays one board draw with three passes.

## Suggestions (not acted on)

- `match_painter.dart` is 332 lines, over `review.sh`'s aim of 300. `phoneHud` and its helpers (`_clock`,
  `_boardOf`, `_otherSide`, `_sideName`) are a self-contained HUD concern and would make a natural part
  file, which would bring the painter back to about 240.
- `mirrorMinPieceMm` is flagged by `review.sh`'s "numeric literal" note although it is a documented
  constant; the check could skip `const` declarations.

## Commit message

```
Show the other side's live board on a phone in a race

A phone drawing its own side of a race now has the other side's board
small at its top left: their outlines faint, their placed pieces filled,
every dot of theirs in orange at its place on that board — pinned to its
top edge while they are up in their tray row — and the piece they hold
turning as they turn it. The clock area moves to its right and its count
reads "Them n/N" in orange. The mirror draws every piece at 2.2 mm or
more, and is left out on a solo or team game, a tablet's whole match, the
TV and a box too narrow for it. Drawing only: no protocol change.
```

## Status row

s11 — the other player's live mirror on a phone in a race: **done (G4)**; open: the sketch's
clock-and-"You" line beside the mirror is not used (the short form is), and the boat gets no mirror at
667 × 375 or 734 × 370.

## Delete

- packages/puzzle_game/test/scratch_mirror_test.dart
