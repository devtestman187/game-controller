# r3d report: present painter and fuse warning

## Summary

STATUS: stopped at the wiring step. The painter and its tests are done and pass; the call from the board painter is blocked (see Blocked).

What changed:
- `packages/puzzle_game/lib/src/present_paint.dart` (new): `paintPresent(canvas, present, {field, look, side})`, a standalone library. Draws the gift box near the top centre of the board, and the fuse bar under it (always, with the effects off too). The bar and the box edge use `look.colors.caution` once `fuseMs <= 3000`. The box wiggles only with the effects on. Popped: 8 rays, only with the effects on. Nothing is drawn when `present.holder != side`.
- `packages/puzzle_game/test/present_paint_test.dart` (new): 16 tests, four per look (Sunny, Night, Sunny effects off, Night effects off). Pixel-based: the picture is the field at 4 px per unit (640 x 360).

Test counts seen: `tools/mine.sh` ran the touched tests: `OK 16 tests packages/puzzle_game`.

Geometry used for the expectations (field units, `PuzzleField.single`):
- Field 160 x 90; board 16..96 x, 13..85 y; the box is 9 wide, centred at (56, 17.5), so it spans y 13..22.
- Fuse track: x 48..64, y 23.5..24.7 (hangs 1.5 below the box). The test band `barBand` is 40..72 x, 23..25.5 y: the bar only, clear of the box edge.
- Warning test: `warning` is 3000 of 10000 ms, so the caution fill is 30% of the track. `full` is 8000 of 10000 ms: no caution pixel anywhere on the picture.

Decisions:
- `paintPresent` is in its own library so the test can reach it without the view. Its own `_pxPerUnit` copy: `text_paint.dart`'s is private to the view.
- Warning colour = `colors.caution`; the bar's good fill = `colors.good`; box body = `colors.bad`; ribbon and bow = `colors.focus`; edge = `colors.ink`.
- The wiggle uses `sin(fuseMs * 2π / 400) * 0.12` rad, so it runs off the fuse's clock.

## Blocked

- `puzzle_painter.dart` is `part of 'view.dart'`. It cannot have `import 'present_paint.dart'` (imports are not allowed in a part file), and `present_paint.dart` cannot be a `part` without a `part 'present_paint.dart';` line in `view.dart`. `view.dart` is not in `allow:`.
- The `present` field and the `paintPresent` call were therefore not added to `puzzle_painter.dart`. `match_painter.dart` is unchanged. Adding them now would not compile.
- Also needed in `view.dart` for the constructor type: `import 'present.dart';` (`PresentState` is not in scope in the view library).

## Hand-over

Files changed:
- `packages/puzzle_game/lib/src/present_paint.dart` (new): `paintPresent` and three private helpers (box, fuse bar, burst). 140 lines including the dartdoc, over the brief's "under 90 lines" for this file; the function itself is about 25 lines. Trimming the helpers into a second file is a choice for the reviewer.
- `packages/puzzle_game/test/present_paint_test.dart` (new): 16 tests, one per rule per look.

Checks:
- `tools/mine.sh`: format ok (2 files formatted, after one const fix), analyze: one info (`prefer_const_constructors` at `present_paint.dart:78`), fixed; the rerun is clean. Touched tests: `OK 16 tests packages/puzzle_game`. Final: `RESULT: ok`.
- Self-check (R part A): item 1 (hosts): the painter paints the holder's board only; a pixel test checks the other side is empty. Item 2 (state starts/ends): the present is drawn only while `holder == side`; popped draws nothing but the burst. Item 3 (combinations with pause, away, etc.): not covered here; the painter has no inputs for them. Item 4: only allowed files. Item 5: stopped at the wiring. Item 6 (every look): all four looks in each test.

Not verified: no test checks the wiggle's rotation; no test runs the match or the split screen with the present (wiring is blocked).

## Questions

1. Approve adding `part 'present_paint.dart';` and `import 'present.dart';` to `view.dart` (not in `allow:`), then the wiring in `puzzle_painter.dart` and `match_painter.dart` can be done in one follow-up job?
2. Should `present_paint.dart` be trimmed under 90 lines (split the box and fuse into their own files), or is 140 lines acceptable?

## Suggestions

- The wiring is a two-line `view.dart` change plus the `puzzle_painter.dart` field and call the brief already describes.

## Commit message — a draft

Add the present's box and fuse bar painter (M17 r3d)

paintPresent draws the gift box and its fuse bar on the holder's board. The bar is
drawn with the effects off too, turns to the caution colour at 3000 ms, and the pop
draws a burst only with the effects on. Not yet called from the board painter: that
needs one part line in view.dart, which is outside this job.

## Status row

r3d: present box, fuse bar and pop burst painter (`paintPresent`) done and tested under all four looks (16 tests); open: the board painter call and the match painter pass, blocked on a `view.dart` part line.

## Delete

- none
