## Summary

Verdict: small fixes. Reviewed m2a (commit a1606249): city_layout.dart, city_painter.dart, city_painter_test.dart, m2a-report.md.
Counts: must 0 · should 6 · could 7.
1. The plaza square can overlap the nearest road tile on a 45° corner spoke: the fit ignores the Plaza's 1.25× side (city_layout.dart:127).
2. A failed `toImage` is an uncaught async error with no log, and the painter then redraws the whole static layer on every frame (city_painter.dart:151).
3. `paint` ignores its `size` argument and draws the cached image at `layout.size` (city_painter.dart:53).

## Findings

- **should** city_layout.dart:127 The fit `tightest * 0.9 / √2` ignores the Plaza square (1.25 tile, half-side 0.625T); on a 45° corner spoke the centres are 0.707·s apart per axis, so T in (0.629·s, 0.636·s] puts the Plaza and the first tile's squares overlapping → include the Plaza side (`cityPlazaScale`) in the fit and test the Plaza rect against the tile rects at 8 players.
- **should** city_painter.dart:151 `unawaited(build(...))` has no catch: a `toImage` failure (line 164) is an uncaught async error, `_wantedSize` stays set so no retry, and every frame redraws the static layer directly → catch at the `toImage` boundary, log through `LogSink`, clear `_wantedSize` so a later paint can retry, and add a test with a failing build.
- **should** city_painter.dart:53 `paint(canvas, size)` uses `layout.size` for the cache lookup and `drawImage` at `Offset.zero`; a caller passing a layout for another size gets a misplaced image with no error → draw from `size`, or assert `size == layout.size` and say so in the doc.
- **should** city_painter.dart:168 and 179 the superseded-build discard (line 168) and `dispose` (lines 179-184, drops the image and ignores an in-flight build) have no test; guidelines §5 require a test that dispose leaves nothing running → add: dispose during a build leaves no image and no notify; a size change during a build keeps only the newest size (city_painter_test.dart group at line 154).
- **should** city_layout.dart:60 tile size comes only from the screen's shorter side, with no mm floor and no `pxPerMm` (review-rules B5, guidelines §6); on a small phone the tiles shrink with no lower bound → take the injected px-per-mm and a named minimum tile size in mm, or write down why the box alone is enough.
- **should** city_layout.dart:133 `steps == 0 ? road : road.take(steps)` is a dead branch: `compute` throws at line 45 for `roadLength < 2`, so `steps` is never 0 → remove the branch (`road.take(steps)`).
- **could** city_layout.dart:125 `if (roads.isNotEmpty)` sits inside the loop that already needs a point, so it never changes the result → remove the check, or move the Plaza distance out of the loop.
- **could** city_painter.dart:60-61 while a build is in flight (`imageFor` is null) every frame draws the whole static layer directly; the first frame of a size pays it twice (line 60, then inside `build`) → accept and say so in the report's decisions, or draw a cheap placeholder.
- **could** city_layout.dart:95 `tileRect` and city_layout.dart:71 `size`, city_painter.dart:65 `paintStatic` and city_painter.dart:156 `build` are public but not in the brief's list → make `paintStatic` private (the tear-off works from inside the class) and keep the rest only if a caller needs them.
- **could** city_painter.dart:141 the doc says `buildCount` is "one per size", but it also counts builds that were discarded (lines 157-158 run before the discard check at 168) → say "one per started build".
- **could** city_painter_test.dart:123 `expect(box.left >= 0 && ..., isTrue)` gives no reason on failure → use a `contains` predicate like lines 114-117, with a reason string.
- **could** city_painter_test.dart:225-226 the screen test "paints under every look without an error" checks only `buildCount == 1` and no exception; it does not show the look reached the painter → name it for what it checks, or assert a colour/draw from the look.
- **could** m2a-report.md:21 self-check line 2 says the cache "is disposed by its owner", but nothing in this job creates or owns a cache, and the dispose path has no test (see the should above) → reword to "no owner yet; dispose untested".

## Decisions to confirm

- Cache at logical pixels (city_painter.dart:164, report Decisions): soft on a high-DPI phone; the owner should confirm this is accepted before wiring.
- Start-tile colours (city_painter.dart:109: corner start `good`, lane start `focus`, other tiles `paper`) and the Plaza's `caution` (line 77) are not in the report's Decisions; confirm.
- `CityStaticCache extends ChangeNotifier` (city_painter.dart:134) is how the painter repaints when the image lands; not in the report; confirm.
- Ellipse layout: `reach` uses width and height separately (city_layout.dart:44), so spoke spacing depends on the aspect ratio; not stated in the report.
- Tuning constants `cityInsetShare` 0.08, `cityTileFitShare` 0.9, `cityDistrictPadShare` 0.25 (city_layout.dart:16, 20, 23) and `cityPlazaScale` 1.25 are untested by eye on a device.

## Could not check

- Test results: docs/briefs/m17/map2a/run.log has no pass or fail lines for the m2a check (03:08:10 to 03:11:24 is only "combined check ... skips"), so the report's "29 tests, all passing" is not backed by runner evidence here. The count of 29 matches the file (21 + 2 layout, 3 cache, 3 screen).
- docs/briefs/m17/map2a/run-findings.md does not exist; nothing from it was used.
- `dart analyze` output is not in the log; not checked. The toy_look names used (`ToyShapeStyle`, `toyShadeOf`, `toyShape`, `look.colors.*`) were not opened, except that `getTransform` (used by the `_CountingCanvas` override) is used by toy_shape.dart:154.
- The 1.25× Plaza overlap (should, city_layout.dart:127) is from arithmetic on the code, not a run.
- Look and legibility on a device were not checked.
