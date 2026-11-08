# fix-f5 — where the mirror goes (G4)

Rule 8 is one placement rule in `camera.dart`: the box's top-left corner first, under the bar, then the gap
under the clock between the left hand's controls and the board. In each place the mirror takes the largest
scale that fits, up to the board fraction, and keeps it only if its smallest piece still draws at
`mirrorMinPieceMm`; where neither place is clear and readable, no mirror. The host phone now hands its own
pad to its own game through a `party_host` seam; the TV and "Show on this device" hand none.

## What changed

1. **One rule, two places.** `PuzzleCamera.mirrorPlace` is the only thing that decides where the mirror goes;
   the painter asks it and draws what it says, HUD included. The corner is `(hudMarginPx,
   box.height * hudTopFraction)` with the short-form HUD as the obstacle to its right — which is rule 5's
   picture, and reproduces today's rects exactly (below). The gap is `(max(hudMarginPx, right of the pad
   rects that reach into it), hud.rect.bottom + mirrorGapPx)` with today's HUD: the clock and counts stay
   where a phone without a mirror draws them, as the brief asks.
2. **The host phone's pad.** A new provider `hostPadProvider` in `party_host` holds `(pxPerMm, rects(Size))`;
   its default is a phone's density and no rects, so the TV and "Show on this device" pass nothing.
   `PuzzleScreen` calls `rects(box.biggest)` in the `LayoutBuilder` over the game, `JoinedView`'s shape; the
   app overrides it in `phoneHostOverrides` with `leftPadRects(box, mode:, mm:, sticks:)` while
   `host.service.shareView` (i.e. "Play on this phone"). **Provider, not constructor**: `PuzzleScreen` is
   built by `JoinScreen`, which the host package owns; a provider is the app's only way in without the
   screens growing a parameter only one host app can fill, and it keys off state the app already owns.
3. **Any puzzle.** The scale comes from `board.size` and the piece floor from
   `min(piece.shape.size)` — no puzzle ID, no tuned number. `_fitting` caps the rect by the box and by every
   obstacle inflated by `mirrorGapPx`, and returns the scale only if it clears the floor.
4. **Images.** `docs/design/m12-mirror-iphone-stick.png` is new (the mirror in the gap, the clock unchanged);
   `m12-mirror-iphone.png` and `m12-mirror-169.png` were redrawn and are byte-identical, which is the proof
   that the corner rule is today's picture.
5. **Code health.** `topBarHeightPx`'s 52 is now `barTopPaddingPx + barRowHeightPx` in
   `controller_app/lib/src/ui/top_bar_metrics.dart`, used by the bar, `leftPadRects`, `joined_view_test`
   (which now pins the pad's body to the bar's own height) and `puzzle_size_test`.

## Tests (each written first, and the first run failed for the reason below)

| Test | Failed first because |
| --- | --- |
| `camera.dart` had no pad rects and no gap at all | the old `mirrorPlace` returned the corner rect whenever the HUD had room |
| `puzzle_game` "the gap comes second" | the old rule put the mirror under the disc |
| `puzzle_game` "a board that only fits smaller" | the old rule had no `_fitting`: either the fraction or nothing |
| `puzzle_game` "every piece … at least mirrorMinPieceMm" | the old rule never measured a piece |
| `phone` "the corner with the D-pad, the gap with the stick, the tilt view over both" | stick mode drew no mirror at all (fix-f3) |
| `phone` "over boards of every shape and piece size" | same, and the old sizing was per puzzle |
| `phone` "gets this phone's pad rects and density" | the host phone passed nothing |
| `host` "the host phone's app hands its pad to the round" / "the TV has no pad" | `MatchView` had no `padRects`/`pxPerMm` |

Three expectations I had written down were wrong and were corrected against the printer, not by moving the
rule: the **boat** has no mirror at 852 in stick mode (the disc ends at 179 and its board starts at 245, so
the gap is 50 px where its mirror needs 73); a 2:1 board of 24-unit pieces needs `aspect: 2, side: 24` (a
`side: 12` one has no room at all); and pieces are measured by `PieceShape.size` (√2 × the side), not the
side — a `side: 8` square is 11.3 units, so it is over the floor at 852 and only `side: 7` is under.

## Test counts

| Check | Before (fix-f3/f4 reports; nothing touched these since) | After |
| --- | --- | --- |
| kit | 38 | 39 |
| puzzle | 121 | 126 |
| host | 117 | 121 |
| phone | 353 | 363 (362 once the two scratch printers are deleted; the third holds no test) |

`mirror_place_test.dart` is 8 tests, `mirror_pad_test.dart` 9 (was 5), `puzzle_screen_test.dart` 10 (was 8).

## The mirror's rect per pad mode (today's puzzles, a sample)

Box, mode, and the rect each puzzle's mirror gets (`–` = none). This is a sample, not the contract: the
contract is the made-up-board test above.

| Phone | Mode | house | rocket | tree | boat |
| --- | --- | --- | --- | --- | --- |
| 852 × 393 | D-pad (corner) | (8, 55.0) 69.0×71.3, s 1.1494 | (8, 55.0) 51.2×75.5, 1.2795 | (8, 55.0) 69.8×70.8, 0.9972 | (8, 55.0) 93.5×77.1, 1.2633 |
| 852 × 393 | stick (gap) | (187.0, 130.6) 68.9×71.3, 1.1494 | (187.0, 130.6) 51.2×75.5, 1.2795 | (187.0, 107.0) 69.8×70.8, 0.9972 | – |
| 852 × 393 | tilt | – | – | – | – |
| 734 × 370 | D-pad (corner) | (8, 51.8) 64.9×67.1, 1.0821 | (8, 51.8) 48.2×71.1, 1.2046 | (8, 51.8) 65.7×66.7, 0.9389 | – |
| 734 × 370 | stick (gap) | (173.6, 123.4) 60.0×62.0, 0.9989 | (173.6, 123.4) 48.2×71.1, 1.2046 | – | – |
| 734 × 370 | tilt | – | – | – | – |
| 667 × 375 | D-pad (corner) | – | – | (8, 52.5) 66.6×67.6, 0.9516 | – |
| 667 × 375 | stick (gap) | – | (175.3, 147.5) 48.8×72.0, 1.2209 | – | – |
| 667 × 375 | tilt | – | – | – | – |

**How many of today's puzzles gain a mirror.** With no pad every puzzle keeps the one it had (4/4 at 852,
3/4 at 734, 1/4 at 667: the corner rule is today's rects to 0.01 px). With the phone's own pad the D-pad
keeps its table and the stick gains **6 of the 12 puzzle × phone pairs** (3 at 852, 2 at 734, 1 at 667) that
fix-f3's rule had none for; the one that loses out is the boat, whose board leaves no gap at 852, and the
tree at 734 and everything but the rocket at 667 likewise. Under the tilt view (its whole left area) none
fits, as before.

**The gap's size per phone** (from the stick's disc to the board's left, less the 8 px the mirror keeps;
and from the clock's bottom to the box's bottom):

| Phone | gap left / top | free width house | rocket | tree | boat | free height |
| --- | --- | --- | --- | --- | --- | --- |
| 852 × 393 | 187.0 / 107.0–130.6 | 97.8 | 132.1 | 96.1 | 50.4 | 262.4 |
| 734 × 370 | 173.6 / 123.4 | 60.0 | 92.3 | 58.4 | 15.4 | 246.6 |
| 667 × 375 | 175.3 / 125.0–147.5 | 23.1 | 55.9 | 21.5 | −22.1 | 227.5 |

## Checks

- `tools/check.sh format analyze puzzle kit host phone tv`: **all PASS** — format; analyze; kit 39 tests;
  puzzle 126; host 121; phone 363; tv.
- `tools/review.sh`: **0 fail, 5 notes** — none of the notes is a fail; two are on this diff's lines:
  `camera.dart` 344 lines (aim 300) and `mirrorPlace` 48 lines (> 40), both under the hard limits.
- Test counts: see the table above.

## Files changed

| File | Change |
| --- | --- |
| `packages/puzzle_game/lib/src/camera.dart` | `MirrorPlacement`; `mirrorGapPx`; `mirrorPlace` is the one rule (corner, then gap); `_fitting` |
| `packages/puzzle_game/lib/src/piece_size.dart` | `phonePxPerMm` as the default density |
| `packages/puzzle_game/lib/src/view.dart` | `MatchView.pxPerMm`, passed to the painter |
| `packages/puzzle_game/lib/src/match_painter.dart` | asks `mirrorPlace` for the mirror and the HUD; `pxPerMm` in `shouldRepaint` |
| `packages/puzzle_game/lib/src/play_view.dart` | `padRects` and `pxPerMm` fields |
| `packages/puzzle_game/lib/src/puzzle_module.dart` | passes `view.pxPerMm` |
| `packages/puzzle_game/lib/src/mirror_painter.dart` | doc: the piece, not the dot, sets the floor |
| `packages/game_kit/lib/src/game_module.dart` | `ViewContext.pxPerMm` |
| `packages/game_kit/lib/src/frame_view.dart` | `pxPerMm` field, into the context |
| `packages/party_host/lib/src/providers.dart` | `hostPadProvider` and its `HostPad` type, empty by default |
| `packages/party_host/lib/src/ui/puzzle_screen.dart` | reads the seam in a `LayoutBuilder`, passes rects and density |
| `controller_app/lib/src/host/host_overrides.dart` | overrides the seam with this phone's pad while `shareView` |
| `controller_app/lib/src/ui/top_bar_metrics.dart` | new: the bar's own padding, row and height |
| `controller_app/lib/src/ui/controller_top_bar.dart` | uses `barPadding` |
| `controller_app/lib/src/ui/controller_screen.dart` | imports the bar's metrics |
| `controller_app/lib/src/ui/joined_view.dart` | the 52 is `topBarHeightPx`; passes `pxPerMm` |
| `packages/puzzle_game/test/mirror_place_test.dart` | the corner, the gap, no mirror, the floor, made-up boards |
| `packages/puzzle_game/test/support/mirror_helpers.dart` | `mirrorOf`, `madeUpPuzzle(aspect:, side:)` |
| `packages/puzzle_game/test/mirror_png_test.dart` | the stick frame; the three images |
| `packages/puzzle_game/test/mirror_test.dart`, `view_test.dart`, `puzzle_module_test.dart` | the new signatures; the density reaching the view |
| `packages/game_kit/test/frame_view_test.dart` | the density in the seam |
| `packages/party_host/test/puzzle_screen_test.dart` | the TV passes none; the override reaches the round |
| `controller_app/test/mirror_pad_test.dart` | per-mode rects, the made-up spread, the host phone's round |
| `controller_app/test/support/mirror_boards.dart` | new: `madeUpPuzzle` for the app's tests |
| `controller_app/test/joined_view_test.dart` | the pad's body pinned to `topBarHeightPx` |
| `controller_app/test/puzzle_size_test.dart` | uses `topBarHeightPx` instead of its own 52 |
| `docs/design/m12-mirror-iphone-stick.png` | new |
| `docs/design/m12-mirror-iphone.png`, `m12-mirror-169.png` | redrawn, unchanged |

`tv_test_app/windows/flutter/generated_*` show in `git status`: the check tools rewrite their line endings,
as they did in fix-f4; `git diff --ignore-cr-at-eol` on them is empty.

## Self-check (review-rules part A)

1. **Every host setup.** TV and "Show on this device": the empty default, so `MatchView.padRects` is empty
   (`host`, "the TV has no pad over the game, so it passes the game none…"; `phone`, `"Show on this device"
   draws no pad over its game, so it passes none`); "Play on this phone": the pad reaches the round
   (`phone`, "gets this phone's pad rects and density, as a joined phone does"); `host`, "the host phone's
   app hands its pad to the round through the hostPad seam"; a joined phone: unchanged, `JoinedView` asks the
   same `leftPadRects` (`phone`, "is where the left hand's controls are drawn, per mode, under the bar"); an
   older peer: nothing on the wire changed.
2. **When kept state starts and ends.** Nothing new is held: the seam is computed per read, `rects(box)` is
   called per layout, and nothing times or caches. No host running, or a host that doesn't share the view,
   gives the empty default (`phone`, the `"Show on this device"` test reads it with a host whose
   `shareView` is false); the round ending or the app hiding changes neither field
   (`host`, both round tests finish and dispose).
3. **How a new state combines.** The seam reads `hostingProvider`, `gyroProvider`'s mode and the stick
   settings; they combine exactly as the pad does, because the rects come from `leftPadRects` — the function
   the pad's drawing uses (`phone`, "is where the left hand's controls are drawn, per mode, under the bar").
   The mirror owns no state: it is asked for on a split, side camera and drawn from the frame
   (`puzzle`, "the corner comes first", and the made-up-board test), so pause, away, "Get ready", a dropped
   link and the results change nothing about it.
4. **Stay in the job's folder.** `git status` lists only the `allow:` paths above plus the scratch printers
   (listed below for deletion).
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`; one brief line is contradicted by
   the code — see Question 2.

## Questions

1. **Provider or constructor?** Chosen: provider (reasons in "What changed" 2). If you would rather
   `PuzzleScreen` took the pad as a parameter, the seam becomes one more thing `JoinScreen` must forward —
   say and I'll switch it in the next gate.
2. **Tilt mode has no mirror, but the brief expects "in the gap with the stick and tilt".** The tilt view
   fills its whole left area (`padLayout(...).leftArea`, 24..343 px wide at 852), which covers the corner
   *and* the gap, so `mirrorPlace` returns null there on all three phones, and the test says so rather than
   asserting a gap rect it cannot have. If the owner wants a mirror in tilt mode, the app would have to
   report a smaller area than the one the tilt view fills — a design call, not a bug fix.
3. **`mirrorPlace` is 48 lines** (`tools/review.sh` NOTE, under the 40-line aim). Splitting the corner and
   the gap into private helpers would clear it; I left it whole because the brief asks for "one placement
   rule" and reading the two places in order is the rule. Say if you'd rather have the split.
4. **The made-up board helper is copied** (`packages/puzzle_game/test/support/mirror_helpers.dart` and
   `controller_app/test/support/mirror_boards.dart`): a test file can't import another package's `test/`
   folder. If a third copy appears, a `testing.dart` in `puzzle_game` would be the place for it.
5. **The boat loses its mirror at 852 in stick mode** (50 px of gap, 73 needed). That follows rule 8's "if
   that gap can't hold it either, no mirror", but it is the one place today's content got smaller, so it is
   worth the owner's eye on the stick image.

## Commit message

```
Mirror goes to the corner, then the gap, clear of the pad

One rule in PuzzleCamera.mirrorPlace places the other side's mirror:
the box's top left first, then the gap under the clock between the
left hand's controls and the board, each at the largest scale that
fits and reads; no mirror where neither is clear. The host phone hands
its own pad to its game through a new party_host hostPadProvider, so
"Play on this phone" keeps the mirror off the thumb; the TV and "Show
on this device" pass none. The bar's 52 px is now one constant.
```

## Status row

fix-f5 done: rule 8's corner-then-gap placement with per-board sizing and the piece floor, the host phone's pad through `hostPadProvider`, the stick image and the bar's height constant; open: tilt mode has no mirror (its area covers both places — owner's call, Q2).

## Delete

- controller_app/test/scratch_f5_test.dart
- controller_app/test/scratch_f5b_test.dart
- packages/puzzle_game/test/scratch_f5c_test.dart
