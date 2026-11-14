## Summary

**small fixes.** 0 must · 3 should · 5 could.
- The still key has no canvas scale, so after a box resize (a phone turned mid-round, a resized window) the
  recorded picture keeps the old ink widths, card corners and slot dashes until the next lock or hint.
- The fourth test builds `PuzzleView` and compares two frames, which draws the same bytes on the old code, so it
  sees no hit or miss; the report's line 75 says all four tests fail to compile before the change.
- Nothing drives `stillKey` from snapshots: test 1 hand-builds keys, so a field left out of `stillKey` would
  freeze the board with every suite green — the one risk this whole change rests on is untested.

## Findings

- **should** packages/puzzle_game/lib/src/board_cache.dart:129 `stillKey` keys the board, box, field, look and piece flags but not the canvas scale, while the still parts bake in `_styles(px)` (`puzzle_painter.dart:122`), and the match paths pass a box in field units (`match_painter.dart:134,184`) that does not change when the widget box does → add the canvas's px (or `_pxPerUnit`'s value) to `StaticBoardKey`.
- **should** packages/puzzle_game/test/board_cache_test.dart:158 this test draws the same two frames the old painter draws (the painter is deterministic and `PuzzleView` takes no cache), so it passes unchanged on the old code and cannot tell a hit from a miss → drive a `BoardCache` through `PuzzlePainter` and count records instead.
- **should** packages/puzzle_game/test/board_cache_test.dart:58 test 1 (and test 3) hand-build `StaticBoardKey`s, so nothing checks that `stillKey` derives another key when a hint, a ready target, a lock, the sparkle or the glow changes → add a test that paints a cached `PuzzlePainter` over two snapshots and asserts a second record when a hint or a lock appears.
- **could** packages/puzzle_game/lib/src/board_cache.dart:129 the key holds no puzzle identity, so a view State given another puzzle keeps drawing the first one's mat, slots, outlines and locked pieces; `frame_view.dart:176` replaces the viewer with `setState` and keeps the element, so a new round that starts before the old game's `ViewEnded` reuses the State → put the puzzle in the key, or clear the cache in `didUpdateWidget` when `widget.puzzle` changes.
- **could** packages/puzzle_game/lib/src/board_cache.dart:105 eviction takes the oldest entry, so while one board re-records every frame (the finish celebration's `glowAgeMs`) the split screen's other board is evicted and recorded again each frame too → move a layer to the end when it is used, or keep three.
- **could** packages/puzzle_game/lib/src/board_cache.dart:58 the key compares `field` with `==` but `PuzzleField` (`puzzle.dart:35`) has no `operator ==`, so the cache hits only because `SplitLayout.of` (`split_layout.dart:126`) memoises its layouts and a per-frame field would silently disable it → give `PuzzleField` value equality or state the identity requirement in the key's doc.
- **could** packages/puzzle_game/lib/src/view.dart:74 neither view State has a `dispose` and `BoardCache` disposes no picture, so the two recorded pictures wait for the garbage collector, though self-check 2 says the cache "ends with it on dispose" → give `BoardCache` a `dispose` and call it from both States' `dispose`, or say the GC is relied on.
- **could** docs/briefs/m14/bugs3/p2-coop-fps-report.md:51 self-check 1 says the TV and "Play on this phone" draw `PuzzleView`, but both draw `MatchView` (`play_view.dart:174`, `puzzle_module.dart:133`), whose `_MatchViewState` is the State that owns the cache → name `MatchView`.

## Decisions to confirm

- The brief asked for a `RepaintBoundary` split and for player interpolation and the job declined both with one line each; if the TV still stutters, the layer split is now the only lever left without touching `toy_look`, so the owner's re-test decides whether B-016 is closed.
- `cache:` is a new public parameter of `PuzzlePainter` and `MatchPainter`, and `BoardCache` and `StaticBoardKey` are exported from `puzzle_game.dart` although only tests construct one: accept the wider surface, or keep the cache inside the views behind a test seam.
- `keptLayers = 2` with oldest-out eviction: during a celebration one board records every frame and the other records with it — is that acceptable, or one layer more?
- Whether a `view_start` for another puzzle can arrive while the previous game is still running (see the fourth finding): if it cannot, the missing puzzle in the key is harmless and worth a comment instead.

## Could not check

- The µs table in the report (`PuzzlePainter.paint` before and after): its benchmark is to be deleted, and I did not rebuild one.
- The GPU-side cost of the replayed picture (blurred slots, shader bodies): device only.
- Whether a round really reuses a `MatchView` State with another puzzle: I read `frame_view.dart:176-201` and `_stop`, but not the host's round chaining.
- The brief's whole check list: I ran `flutter analyze` in `packages/puzzle_game` (no issues) and `flutter test test/board_cache_test.dart` (4 pass); not the host or tv suites, not `dart format`.

## Commit message

Review p2-coop-fps: the still key misses the canvas scale

The still-layer cache and the piece-path cache are sound and the diff stays
inside the job's files, but the key leaves out the canvas scale, so a resized
or rotated box keeps the old ink widths and corners until the next lock. The
fourth test passes on the old code and the report says all four fail to
compile before it; no test drives `stillKey` from snapshots, the one risk the
change rests on. Five smaller notes: the puzzle identity, FIFO eviction, the
key's identity compare of `PuzzleField`, the undisposed pictures, and the
self-check naming `PuzzleView`. Findings: three should, five could.

## Status row

B-016 review done: the still-layer and path caches hold and the diff is inside the job (0 must, 3 should, 5 could) — open: add the canvas px and the puzzle to `StaticBoardKey`, dispose the pictures, close the two test gaps, and the owner's on-device re-test.

## Delete

- none
