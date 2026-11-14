## Summary

All four items done; no behaviour change.

1. **Done.** The old last test ("a board drawn from its cache is the board drawn without one, byte
   for byte") proved nothing — it drew the same bytes with and without the cache — so it is deleted;
   its `support/frames.dart` import is still used (`difference`, `pixel`). Its replacement is
   `test/board_cache_state_test.dart`: one view's
   frames through one `BoardCache`, and a hint, a ready target or the glow's age each records the
   board again while an unchanged state does not.
2. **Done.** `BoardCache.onRecord` is `@visibleForTesting`; `view.dart`'s `flutter/foundation.dart`
   import gained `visibleForTesting` to its `show` list.
3. **Done.** phone_hud.dart's fill inset `track.height / 4` is `track.height * _barFillInsetShare`,
   `const _barFillInsetShare = 0.25`, documented as the fill's inset from the bar's rounded ends.
4. **Done.** board_hud.dart's `/ 1000` is `const _msPerSecond = 1000`, used by `_barFill` and the
   clock's `ceil`.

**Decisions.**
- *One cache, a painter per frame*: `PuzzlePainter` holds its snapshot, so "one cached painter" is
  one `BoardCache` handed to each frame's painter, as a view does it.
- *The glow frame uses `PieceMoments`*: observe the playing board, then the finished one at the same
  `nowMs` (age 0), then paint 100 ms later; nothing else in the key moves between those frames.
- *A share, not a divisor*: `_barFillInsetShare = 0.25` is the same value as `/ 4` and names its unit
  like the other shares (guideline §4).
- *Both `/ 1000`s in board_hud.dart* use `_msPerSecond`: the same conversion in one file, and a bare
  one would break guideline §2. The `/ 1000`s in phone_hud.dart, puzzle_painter.dart and the worker
  files are outside this brief and untouched.

## The new test

`packages/puzzle_game/test/board_cache_state_test.dart`, one test: "a hint, a ready target or a glow
each makes the cache record the board again". A 640 × 360 box (4 px a world unit on the 160 × 90
field), the two-piece `pair` puzzle, the first piece locked at board (40, 50) = field (56, 63), the
second in the tray at (120, 25), the second target empty. Each `draw` is one frame of one view:
`moments.observe` the snapshot at `nowMs`, then a painter built from it with the shared
`BoardCache(onRecord: recorded.add)`, painted into the box.

| frame | snapshot | recorded | why |
| --- | --- | --- | --- |
| 1 | plain | 1 | nothing kept yet |
| 2 | plain | 1 | nothing in the key changed |
| 3 | `hints: {1}` | 2 | a hinted slot and edge are drawn differently |
| 4 | `hints: {1}` | 2 | replayed |
| 5 | `ready: {1}` | 3 | a ready target is drawn differently |
| 6 | `ready: {1}` | 3 | replayed |
| 7 | `ready: {1}`, finished, `nowMs` 0 | 4 | the glow under the picture is in the still parts |
| 8 | the same, `nowMs` 100 | 5 | the glow at another age is another picture |

Computed values: `recorded.last.hints == [1]`, `.ready == [1]`, `.glowAgeMs` 0 then 100 —
`Celebration.totalMs` is 2500 and `isRunning(100)` is true, so both ages are in the celebration.

## Proof it fails for the right reason

Temporarily edited `StaticBoardKey.==`, ran the test, restored it, and re-read the restored
`operator ==` (it matches the version in `95da0ac`'s file, with hints, ready and glow back):

- hints, ready and glow removed from the equality: failed at frame 3, `Expected: an object with
  length of <2>`, `Actual: [Instance of 'StaticBoardKey']`, which has length 1 — the hinted board
  was replayed from the plain one.
- only the glow removed (hints and ready back): failed at frame 7, `Expected: an object with length
  of <4>`, actual length 3 — the finished board was replayed from the ready one.

## Self-check (review-rules part A)

1. **Every host setup.** Unchanged drawing everywhere: the change is a test, an annotation and two
   named constants with the same values. Test: `puzzle` suite, 403 tests pass; the new test passes.
2. **When kept state starts and ends.** The cache still starts in the view's `State` and ends on
   `dispose`; the test's cache lives for one test. Test: "a hint, a ready target or a glow each
   makes the cache record the board again", plus the unchanged "the layer a frame has not drawn is
   the one the next recording takes".
3. **How a new state combines with the others.** No new state: no pause, hide, wait or input change.
   Not affected.
4. **Stay in the job's folder.** Only `docs/briefs/m14/cleanup1/` and `packages/puzzle_game/` were
   written. Test: `git status` shows this job's changes in those paths only (the PNGs and
   `generated_plugin*` files it lists were dirty before the job and were not touched).
5. **Stop rather than overstep.** Nothing needed outside `allow:`; no stop.

## Questions and suggestions

1. board_hud.dart's `_bar` still insets its fill with `_barHeight / 4` — the same share the phone bar
   now names. One constant for both bars (they share the library) would finish the job; not done
   because the brief names only phone_hud.dart's line.
2. The glow's age is in the key, so a finished board's still parts are recorded every frame for the
   celebration's 2500 ms (about 150 recordings). That is what the old code did too (it rebuilt every
   frame), so this is not a regression, but a coarser glow age would let the cache keep the picture
   during the celebration. Left as is: it is a design change, not a cleanup.

## Commit message

Test the board cache's hint, ready and glow keys

The last test in board_cache_test.dart drew the same bytes with and without the cache, so it could
not see a key that ignored hints, ready targets or the finish's glow. A new
board_cache_state_test paints one view's frames through one cache: a hint, a ready target or a glow
age each record the board again, and an unchanged state does not. It fails at the hinted frame
(expected 2, got 1) and at the glow frame (expected 4, got 3) when those fields leave the key.
onRecord is now @visibleForTesting, and the phone bar's fill inset and board_hud's ms-to-s 1000 are
named constants. No behaviour change.

## Status row

- M14 cleanup1 c2: board cache keys for hints, ready targets and the glow are now tested (the
  byte-for-byte look-alike test replaced); `onRecord` is test-only, the bar's fill inset and
  ms-to-s are named constants. Open: nothing from this brief.

## Delete

- none
