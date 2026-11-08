# M12 build 4 fix-f3 — G4 report: the mirror's dot you can see, its place clear of the pad, the palette's orange

Stopped at G4 as the brief says. Three fixes from the build 4 review, each with its test failing first:

1. **N3 — the dot's floor.** Their dot (and its 1 px ring) is now as big as the smallest piece the mirror
   draws, so it is at least `mirrorMinPieceMm` (2.2 mm) across on every phone size. The dot is 0.8 to
   1.1 mm today, which is the "dot I can't see" of the review.
2. **N4 — clear of the pad.** The app now tells the game where this phone's left hand draws its controls,
   through the existing view/module seam (`ViewContext.padRects`), and the game draws no mirror where one
   of those areas is. D-pad mode is unchanged on all three phones; sticks and gyro mode lose the mirror
   on all three.
3. **The look row.** The mirror's orange is `playerColors[1]` (the protocol's palette), not a copy of the
   literal.

Nothing but drawing and placement changed: no protocol message, no snapshot, no rules.

## What was done

### 1. The dot's size floor (`mirror_painter.dart` 146 → 167)

- **`mirrorDotRadius(Puzzle)`** (public, in `mirror_painter.dart`, a part of `view.dart`): the smallest
  piece's radius in board units — `max(PuzzleGame.dotRadius, smallestDiameter / 2)`. `_players` and
  `_pinned` both use it, so the dot, its ring and its clamping to the mirror's edges all agree.
- **The size chosen, and why.** The dot's diameter is *the smallest piece's drawn diameter*. That is the
  cheapest size that can't miss the floor: `PuzzleCamera.mirrorFraction` is `mirrorMinPieceMm /
  minPieceMm`, so a mirror piece is `mirrorMinPieceMm` or more across whatever the puzzle and the phone
  — and the game needs no px per millimetre to know it. `PuzzleGame.dotRadius` (2.6 units) stays as the
  floor for a puzzle whose pieces are under 5.2 units; every shipped puzzle's smallest is 12 units or
  more, so in practice the piece's radius always wins.
- **The held piece stays where it is relative to the dot**: `_held` is still drawn at the dot's drawn
  centre plus the pin offset, and now *over* the dot (the dot is drawn first), so a dot this big doesn't
  hide the piece's whole fill. Its orange outline still says whose it is.
- The ring is drawn at `_targetPx / scale`, so on-screen it is still 1 px whatever the dot's size.

### 2. Clear of the pad (`game_module.dart`, `frame_view.dart`, `joined_view.dart`, then `view.dart`,
`match_painter.dart`, `puzzle_module.dart`, `camera.dart`)

- **The seam**: `ViewContext` (the record a game's viewer is built with) gains a fourth field,
  `List<Rect> padRects` — the areas this phone's own pad draws over, in the game's box's px. `FrameView`
  takes the same list and passes it in. The game's `MatchView` → `MatchPainter` → `PuzzleCamera.mirrorPlace`
  pass it down; `mirrorPlace` returns null when the mirror's rect overlaps any of them.
- **The app says where, not what.** `leftPadRects(box, mode:, mm:, sticks:)` in `joined_view.dart`
  computes from the app's own layouts (`padLayout`, `stickLayout`, `dpadArms`), so no pad number is copied
  into the game: D-pad mode → the four drawn arms (its square's empty corners stay usable, as today);
  stick mode → the left stick's disc (its whole zone while the stick floats) plus the D-pad's arms; gyro
  mode → the whole tilt area.
- **A list, not one rect**: the D-pad's bounding square would have removed the mirror in today's default
  D-pad mode, where the mirror sits above the arms unused.
- `JoinedView` builds the list in a `LayoutBuilder` from the gyro mode, the stick settings and the px per
  mm it already watches, and the bar's height (`topBarHeightPx = 52.0`: 4 px padding + its 48 px row).
- `MatchPainter.shouldRepaint` compares `padRects` with `listEquals`, so a mode change redraws a mirror in
  or out at once.

### 3. The palette's orange (`view.dart`)

`final _them = Color(playerColors[1]);` — the frame, every dot and the "Them" count now come from the
protocol's palette (`packages/protocol/lib/src/messages.dart`), so a re-skin moves them with the pads'
badges.

### 4. Tests, and old → new

New, each failing for the bug's reason first:

- `packages/puzzle_game/test/mirror_test.dart` · *their dot is drawn at least mirrorMinPieceMm across on
  every phone* — 8 cases (four puzzles at 852, three at 734, the tree at 667), drawing a dot on the middle
  of their board, measuring the ink run through its centre at pixel ratio 2 (orange + white ring +
  antialiased edge) and dividing by the mirror's px per mm. Fails at `PuzzleGame.dotRadius` (2.6 units ≈
  0.8–1.1 mm).
- `packages/puzzle_game/test/mirror_test.dart` · *the mirror's orange is the palette's other-side colour*
  — the dot and the frame are drawn in `playerColors[1] & 0xFFFFFF`, read from the protocol.
  *(It cannot fail first: the old literal `0xFFFFA040` already equalled `playerColors[1]`. It is a guard
  against a re-skin, and it fails if the palette's player 2 changes and `view.dart` doesn't follow.)*
- `packages/puzzle_game/test/mirror_test.dart` · *the mirror keeps clear of the pad the app passes* — a
  control below the mirror leaves it exactly where it was; a control over its place removes it; a rect
  that only meets an edge leaves it.
- `controller_app/test/mirror_pad_test.dart` (new, 5 tests) — the app's side of the seam and the whole
  size × mode table.
  - *the pad the app passes the game … per mode, under the bar*: `leftPadRects` equals the arms, the disc
    and arms, the floating zone, the tilt area; empty for a 40 px screen.
  - *puts the D-pad exactly where the app says it is*: a joined phone's rendered `Key('dpad')` rect equals
    the arms' union, and starts below the 52 px bar.
  - *the mirror never meets the left stick's disc or the D-pad, in any mode or phone size*: all four
    puzzles × 3 modes × 3 sizes, checked against shapes worked out independently from the layouts
    (`ControlShape.distanceTo > 0`), not just against the same list the game was given.
  - *which puzzles keep the mirror, phone by phone and mode by mode*: the table below.
  - *a control anywhere else leaves the mirror where it is*: D-pad mode's mirror equals the pad-less one.
- `packages/game_kit/test/frame_view_test.dart` · *the viewer is told where this phone draws its pad, so
  it can keep clear of it* — `padRects` arrives in the game's `ViewContext`.
- `packages/puzzle_game/test/puzzle_module_test.dart` · the viewer's `padRects` reach the painter (added
  to the shared widget test).

Old → new:

| Test | Old | New | Why |
| --- | --- | --- | --- |
| `mirror_test` *their placed pieces are drawn in it* | the empty-board probe at board unit (18, 22) | (18, 60) | the bigger dot now covers the old probe; the probe moved below it |
| `mirror_test` *placed above the board, their dot is pinned* | pinned dot placed at a fixed `PuzzleGame.dotRadius` inside the edge | at `mirrorDotRadius(puzzle)` inside the edge | the dot's radius is the puzzle's now |
| `mirror_test` (file) | 545 lines | 276 lines + new `mirror_place_test.dart` (155) + `support/mirror_helpers.dart` (132) | the 500-line test limit; the "where the mirror goes" group moved out untouched |
| `puzzle_module_test` `draw` helper | 3-field `ViewContext` | 4-field | the seam's new field |
| `frame_view_test` `underTest`/`mount` | no `padRects` | `padRects = const []` default | the seam's new field |

### 5. The design images

`docs/design/m12-mirror-iphone.png` and `m12-mirror-169.png` redrawn by `mirror_png_test.dart`: the dot
is now the size of the smallest piece, at the trunk's base on the mirror's top edge.

## Computed values

The dot's drawn diameter — its diameter in board units is the smallest piece's (`mirrorDotRadius × 2`):

| Puzzle | 852 × 393 | 734 × 370 | 667 × 375 |
| --- | --- | --- | --- |
| house | 17.5 px = 2.78 mm (dot 14 u, 16.09 px) | 16.0 px = 2.54 mm | — (no mirror) |
| rocket | 16.5 px = 2.62 mm (12 u, 15.35 px) | 15.5 px = 2.46 mm | — (no mirror) |
| tree | 17.0 px = 2.70 mm (16 u, 15.96 px) | 16.0 px = 2.54 mm | 16.5 px = 2.62 mm (15.23 px) |
| boat | 19.0 px = 3.02 mm (14 u, 17.69 px) | — (no mirror) | — (no mirror) |

Measured in the test at pixel ratio 2 and halved; the measured run is ~1.4 px wider than the dot's
diameter, which is its 1 px white ring plus the antialiased edge. The floor is 2.2 mm = 13.86 px. The
smallest dot is the rocket at 734: 2.46 mm measured, 2.29 mm nominal — over the floor both ways.

The mirror's rect and scale (no pad), the box's px:

| Puzzle | 852 × 393 | 734 × 370 | 667 × 375 |
| --- | --- | --- | --- |
| house | (8, 55.02) 68.96 × 71.26, scale 1.1494 | (8, 51.8) 64.93 × 67.09, 1.0821 | no mirror (HUD short) |
| rocket | (8, 55.02) 51.18 × 75.49, 1.2795 | (8, 51.8) 48.18 × 71.07, 1.2046 | no mirror (HUD short) |
| tree | (8, 55.02) 69.81 × 70.80, 0.9972 | (8, 51.8) 65.72 × 66.66, 0.9389 | (8, 52.5) 66.61 × 67.56, 0.9516 |
| boat | (8, 55.02) 93.49 × 77.06, 1.2633 | no mirror (HUD room) | no mirror (HUD short) |

The pad, in the same px (as `leftPadRects` reports it):

- **852 × 393**, body 852 × 341: left stick disc centre (97.5, 189.5) r 81.5 → it spans (16, 108) to
  (179, 271), reaching up to y = 108 while the mirror's bottom is 118.9 to 132.1; tilt area (24, 60) to
  (343, 377) covers the mirror (24 < 77.8); the D-pad's square is (25, 60) to (342, 377) and its arms
  start at x = 129.6 (the top one) and y = 164.6 (the left one), clear of the mirror's right (101.5) and
  bottom (132.1) — the square's top-left corner is empty, as it is today.
- **734 × 370**, body 734 × 318: disc centre (90.8, 182.8) r 74.8, spans to y = 108; mirror bottoms 118.5
  to 122.9; tilt area (24, 60) to (284, 354).
- **667 × 375**, body 667 × 323: disc centre (91.7, 183.7) r 75.7, spans to y = 108; mirror bottom 120.1;
  tilt area (24, 60) to (250.5, 359).

**Which puzzles keep the mirror** (D-pad / sticks / gyro):

| Phone | D-pad | Sticks | Gyro |
| --- | --- | --- | --- |
| 852 × 393 | house, rocket, tree, boat | none | none |
| 734 × 370 | house, rocket, tree | none | none |
| 667 × 375 | tree | none | none |

So the mirror loses nothing in D-pad mode — the same table s11 pinned — and loses the mirror to **all four
puzzles on all three phones** in stick mode (the disc reaches the mirror's place everywhere) and in gyro
mode (the tilt view fills it). That is the brief's "where the mirror can't fit clear of the pad, no
mirror": the box keeps today's HUD.

## Test counts

| Check | Before | After |
| --- | --- | --- |
| kit | 36 | 37 |
| puzzle | 118 | 121 |
| phone | 348 | 354 (353 once `scratch_f3_test.dart` is deleted) |

`mirror_test.dart` was split (545 → 276 lines) into `mirror_test.dart` (what it draws),
`mirror_place_test.dart` (where it goes) and `support/mirror_helpers.dart`: same tests, one copy of the
helpers.

## Files changed

| File | Change |
| --- | --- |
| `packages/puzzle_game/lib/src/mirror_painter.dart` | `mirrorDotRadius`; the dot is the smallest piece's radius; the dot drawn under the held piece |
| `packages/puzzle_game/lib/src/camera.dart` | `mirrorPlace` takes `padRects` and returns null when the mirror overlaps one |
| `packages/puzzle_game/lib/src/view.dart` | `_them = Color(playerColors[1])`; `MatchView.padRects` |
| `packages/puzzle_game/lib/src/match_painter.dart` | `padRects` field, passed to `mirrorPlace`, in `shouldRepaint` |
| `packages/puzzle_game/lib/src/puzzle_module.dart` | passes `view.padRects` to `MatchView` |
| `packages/game_kit/lib/src/game_module.dart` | `ViewContext` gains `List<Rect> padRects` |
| `packages/game_kit/lib/src/frame_view.dart` | `padRects` field, into the `ViewContext` |
| `controller_app/lib/src/ui/joined_view.dart` | `topBarHeightPx`, `leftPadRects`, `LayoutBuilder` passing it to `FrameView` |
| `packages/puzzle_game/test/mirror_test.dart` | dot-floor, palette and pad tests; helpers moved out; 545 → 276 lines |
| `packages/puzzle_game/test/mirror_place_test.dart` | new: the "where the mirror goes" group, moved out |
| `packages/puzzle_game/test/support/mirror_helpers.dart` | new: the helpers the two mirror tests share |
| `packages/puzzle_game/test/puzzle_module_test.dart` | 4-field `ViewContext`; the padRects pass-through assertion |
| `packages/game_kit/test/frame_view_test.dart` | `padRects` in the harness; the seam test |
| `controller_app/test/mirror_pad_test.dart` | new: the app's pad rects and the size × mode table |
| `controller_app/test/scratch_f3_test.dart` | temporary measuring test (delete) |
| `docs/design/m12-mirror-iphone.png`, `m12-mirror-169.png` | redrawn with the bigger dot |

## Self-check (`docs/review-rules.md` part A)

1. **Every host setup.** A TV or PC host draws the whole match and gets no mirror (test *no mirror on a
   one-board match, the whole match, the screen…*); "Play on this phone" is drawn by `party_host`'s
   `PuzzleScreen`, not `JoinedView`, so it keeps today's placement (see Questions); "Show on this device"
   goes through `JoinedView`, which passes a pad even though none is drawn there (see Questions); a joined
   phone is the case the new seam serves (test *puts the D-pad exactly where the app says it is*); an
   older host sends no `padRects` and the game defaults to `const []`, today's picture (test *the mirror
   keeps clear of the pad the app passes* — the pad-less branch).
2. **When kept state starts and ends.** Nothing is held between frames: `padRects` is rebuilt every build
   from the gyro mode, the stick settings and px per mm, and `leftPadRects` returns empty when the body has
   no room (test *the pad the app passes the game …*, the 40 px screen); the mirror itself is recomputed
   each frame and the painter repaints when the list changes (test *the viewer is told where this phone
   draws its pad* watches the value arrive; `listEquals` in `shouldRepaint`).
3. **How a new state combines.** The change adds no pause, hide or input state — only placement. The pairs
   that matter are the pad mode and the floating stick, which can change at any moment mid-round: the
   mirror goes in or out on the next frame (test *which puzzles keep the mirror, phone by phone and mode by
   mode*, and the floating-zone case in *the pad the app passes the game …*). Not tested with the pause
   menu, away players or the results: none of them changes the pad's geometry.
4. **Stay in the job's folder.** Every path written is in `allow:` (list above); `tools/review.sh` reports
   0 fail (2 notes: the `52.0` bar height in `joined_view.dart`, `match_painter.dart` at 338 lines).
5. **Stop rather than overstep.** Nothing needed outside `allow:` was changed. `party_host`'s
   `PuzzleScreen` (the host phone's own game) is outside it and keeps the old placement; it and the
   "Show on this device" case are under Questions rather than fixed here.

## Questions

- **The host phone's own game.** "Play on this phone" draws the game through `party_host`'s `PuzzleScreen`,
  which is not in `allow:` and still calls the game with no `padRects` — so that screen keeps today's
  mirror, over the pad. It needs the same `leftPadRects` pass-through; say if you want a job for it.
- **"Show on this device".** `JoinedView` passes the pad unconditionally. Today it is only used with a
  pad, but a phone showing its game without controls would now lose the mirror needlessly. A provider
  saying "no pad is drawn" (`padMode` has no such value) would fix it; I did not add one.
- **`topBarHeightPx = 52.0`** duplicates the top bar's height (its 4 px padding and 48 px row live in
  `controller_top_bar.dart`, outside `allow:`). The new widget test pins it against the rendered D-pad, so
  a change to the bar fails a test rather than drifting; `review.sh` notes the literal. A public constant
  in `controller_top_bar.dart` would be cleaner.
- **Gyro's keep-clear area is conservative**: it is the whole `leftArea`, while the tilt view draws a
  smaller circle in it. It costs the mirror in gyro mode on all three phones, which is the safe side.
- **The palette test cannot fail first**: `0xFFFFA040` already was `playerColors[1]`. It is a guard for the
  look-and-sound milestone, not a bug reproduction.
- **`tv_test_app/windows/flutter/generated_*`** show as modified in `git status`; the Flutter tool rewrote
  them during `flutter test`, not me, and they are outside this job's `allow:`.
- The new test files push the mirror helpers into `support/`; if you would rather the placement tests live
  in `camera_test.dart` (the camera owns `mirrorPlace`), that is a move, not a rewrite.

## Commit message

```
Make the mirror's dot readable, keep it clear of the pad, and use the palette's orange

Their dot on the other side's mirror is now as big as the smallest piece
the mirror draws, so it is at least 2.2 mm across on every phone (it was
0.8 to 1.1 mm), and the piece they hold still sits on it, turned as they
turn it. The app now tells the game where this phone's left hand draws
its controls through the view seam (ViewContext.padRects), and the game
draws no mirror over one: D-pad mode is unchanged on all three phones,
stick and gyro mode keep today's HUD instead of a mirror under the thumb.
The mirror's orange comes from the protocol's palette (playerColors[1]),
not a copied literal.
```

## Status row

fix-f3 — the mirror's dot size floor, its place clear of the pad, and the palette's orange: **done (G4)**;
open: the host phone's own `PuzzleScreen` ("Play on this phone") and the "Show on this device" case still
place the mirror as before, and the top bar's 52 px is duplicated in `joined_view.dart`.

## Delete

- controller_app/test/scratch_f3_test.dart
