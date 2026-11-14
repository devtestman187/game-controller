## Summary

**Root cause.** Every frame `PuzzlePainter` rebuilt the whole board from nothing: a `Path` per piece,
a dashed re-walk of each empty target's contour, a blurred sunken stroke per slot, a
`FragmentShader` and two `Paint`s per shape, and for every locked piece a `Path` per later target
plus `Path.contains` hit tests for its ✓. None of it depends on the frame. With two players a frame
also draws two workers and moves two pieces at once; there is no `saveLayer` in the package.

**By file** (`packages/puzzle_game/`)
- `lib/src/board_cache.dart` (new): `StaticBoardKey` and `BoardCache` (up to two recorded still-part
  pictures, one per board a frame wants, one `Path` per piece per board while it lies where it did).
- `lib/src/puzzle_painter.dart`: optional `cache`; `paint` = the still parts from the cached picture,
  then the moving pieces, workers, cat, stars and HUD in the old order; `_recordStill` draws what the
  old `_picture` did; `_piece` takes its path from the cache.
- `lib/src/match_painter.dart`: optional `cache` for both boards; the phone HUD moved out.
- `lib/src/phone_hud.dart`: gained the phone HUD painting, moved verbatim (both files under 380).
- `lib/src/view.dart`: `part`, the `Picture`/`PictureRecorder` imports, a `BoardCache` per view state.
- `test/board_cache_test.dart` (new, four tests); two scratch files to delete (the benchmark and the
  first try at the byte-for-byte test, now in `board_cache_test.dart`).

**Decisions.** *No `RepaintBoundary`*: one full-frame `CustomPaint`, so a boundary caches nothing; a
layer split is a bigger job. *No player interpolation*: the TV runs the rules, so its dots are the
frame's own; joined phones already lerp. *The cache lives in the view's `State`*: two pictures and a
path per piece per board at most, no globals. *A locked piece is still*: a knock changes its state,
the finish pop's age is in the key. *No cache draws directly*, as before.

**Not done.** The HUD's laid-out text (≈ 96 µs a frame) and one `FragmentShader` per painter instead
of one per shape (`toy_look`, outside this job).

**On a device.** Re-run the reported round (co-op, two phones, Android TV): the board's fixed cost is
now paid once per lock, hint or celebration change. If it still stutters, read `GameDebugOverlay`'s
frame times and blame (in order) the blurred slots, the shader per shape, then the HUD text.

## Measurements

`PuzzlePainter.paint` into a 1920×1080 `PictureRecorder`, the `house` puzzle, 2 players, no moments
(Dart-side command building only, no GPU raster; this machine, so a slow TV box will scale it up):

| board state              | before | after |
| ------------------------ | ------ | ----- |
| all 6 pieces loose       | 930 µs | 514 µs |
| 3 locked, 3 loose        | 455 µs | 314 µs |
| all 6 locked             | 282 µs | 233 µs |
| all locked, `hud: false` | —      | 137 µs |
| all locked, no players   | —      | 156 µs |

## Self-check (review-rules part A)

1. **Every host setup.** Unchanged behaviour everywhere: the cache only decides whether a board's
   still parts are recorded again, never what is drawn. A TV/PC host and "Play on this phone" draw
   one board (`PuzzleView`); a split screen ("Show on this device") draws two, one cache key each
   (`look_paint_test` draws a 960×540 split match); a joined phone draws frames as they arrive
   through the same painter; an older peer is unaffected — nothing crosses the wire. Test:
   `board_cache_test` "the second frame of an unchanged board is the first, pixel for pixel" plus the
   existing `look_paint_test`/`placed_look_png_test`/`celebration_paint_test` pass unchanged.
2. **When kept state starts and ends.** Starts with the view's `State` (built by `initState`), ends
   with it on `dispose` — leaving the round, a new round, the game's route closing. It holds at most
   two pictures and one path per piece per board, so it cannot grow with a round's length. While the
   round is paused `PuzzlePlayView._tick` returns before `setState`, so no painter is built and
   nothing is recorded. Test: "a board's still parts are recorded once while nothing in them changes"
   (two keys, the second key's eviction, reuse of the kept one).
3. **How the new state combines with the others.** The cache is re-derived from the frame it paints
   on every paint and `shouldRepaint` is unchanged, so pause, host away, player away, Get ready, a
   dropped link, the results and leaving cannot leave a stale layer: the worst case is one frame
   recorded again. Pairs that can happen together: pause + a locked piece (no frame is drawn while
   paused); away + a finished picture (`glowAgeMs` re-records each frame while the celebration runs).
   Test: the same test above plus the pixel test's third frame (a piece locks, the board re-records).
4. **Stay in the job's folder.** Only `docs/briefs/m14/bugs3/p2-coop-fps-report.md` and files under
   `packages/puzzle_game` were written; no other file was touched.
5. **Stop rather than overstep.** No file outside `allow:` was needed and no rule had to be bent;
   `toy_look` (the shader-per-shape cost) is outside this job, so it is reported, not changed.

## Tests

`packages/puzzle_game/test/board_cache_test.dart` (new; every one of them fails to compile before this
change, since `BoardCache`, `StaticBoardKey` and the `cache:` argument did not exist):

1. *"a board's still parts are recorded once while nothing in them changes"* — two draws with an
   equal key: the same `Picture` and **1** record; a key with one filled target: a new picture
   (**2** records); then ready, hints, `lockedMoving`, `glowAgeMs: 300`, the Night look, board 1 and
   a 960×540 box each record again (**9** in all), and a second draw of the last key reuses it
   (**still 9**).
2. *"a piece's path is built once while it lies where it did"* — two calls at the same place, angle
   and scale: **1** build and the same `Path`; a move, a 90° turn and the tray's 0.75 scale: **4**
   builds; the other board's piece of the same index: **5**.
3. *"a board drawn from its cache is the board drawn without one, byte for byte"* — a two-piece
   board (one locked at (56, 63), one in the tray, one ready and hinted target, one player) drawn
   with `cache: BoardCache()` and drawn without one: `capturePng` bytes differ by **0**. So the
   cache changes the cost, not the picture. (It also shows that the `docs/design/puzzles/*.png` that
   `git status` lists as modified in this workspace were not changed by this job.)
4. *"the second frame of an unchanged board is the first, pixel for pixel"* — the tray piece at world
   (120, 25) is its own colour `0xE4572E` (gap ≤ 8); the second frame's bytes differ by **0**; then
   the piece locks and world (56, 57) is `0xE4572E` (gap ≤ 8), the tray point is no longer that
   colour, the slot pixel at (56, 63) has changed, and the frames differ (> 0), i.e. the still parts
   were recorded again.
The throwaway benchmark (to be deleted) printed the table above.

Every existing suite passes: `tools/check.sh format analyze puzzle host tv` → all PASS
(puzzle 401 tests, host 396, tv 13 s).

## Not looked at / open

- The GPU-side cost (the blurred slot recesses and the shader bodies still rasterise every frame,
  now from a replayed picture) cannot be measured here; only a device shows it.
- `toy_look`'s `toyShape` makes a new `FragmentShader` and two `Paint`s for every shape every frame —
  outside this job's `allow`, and the next big win for every game.

## Questions

1. Should the HUD's laid-out text be cached next (≈ 96 µs a frame at 1080p, and it grows with the
   phone HUD's lines)? It needs a small text cache passed into `text_paint.dart`'s call sites.
2. Is a full layer split (the still parts in their own `RepaintBoundary`, so the compositor keeps
   their raster and the blurred slots cost the GPU once) worth a follow-up job? It is the only way
   left to cut the GPU cost without touching `toy_look`.

## Suggestions

- Give `toyShape` one `FragmentShader` per painter and set its uniforms before each draw; today it
  creates one per shape per frame.
- If the tv still janks, measure with `GameDebugOverlay` before doing either of the above.

## Commit message

Cache a board's still parts and its pieces' paths between frames

The TV re-built the whole board every frame: a path per piece, a dashed
re-walk and a blurred recess per empty target, a shader per shape, and path
hit tests for every locked piece's tick. None of it depends on the frame.
BoardCache keeps a board's still parts as a recorded picture (mat, tray,
slots, glow, locked pieces) and each piece's path while it lies where it
did; the key covers box, field, look, filled/ready/hinted targets and motion.
A fresh co-op board's Dart paint cost fell from 930 to 514 us a frame at
1080p. The phone HUD painting moved to phone_hud.dart. No rule change.

## Status row

B-016: Shape Race co-op's per-frame board cost cut (still parts and piece paths cached between frames; TV no longer rebuilds the board every frame) — open: on-device re-test, plus the shader-per-shape and blurred-slot GPU costs and the HUD's text layout.

## Delete

- packages/puzzle_game/test/zz_scratch_bench_test.dart
- packages/puzzle_game/test/zz_scratch_same_test.dart
