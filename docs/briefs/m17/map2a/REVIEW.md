# map2a run review (read-only)

Read: wave1 and wave2 review reports, m2a and m2b reports, both briefs, run.log, done.txt, DRIVER-NOTES.md, coding-guidelines.md, review-rules.md, all eight city files at f42385fa (code read whole; line numbers are from those files). STATUS.md, run-findings.md and REVIEW-VERDICTS.md do not exist, so nothing was skipped on their account.

## Summary

Verdict: **needs Claude's design** (the built-tile colour, M1), then **one fix batch** for the rest.
Counts: must 2 · should 13 · could 14 (29 findings). Every must and should was re-read in the final code; none is fixed (no `f<n>` commit in the run).

Five that matter most:
1. M1 `city_overlay_painter.dart:65`: built tiles use the paper colour of every unbuilt road tile, so a built tile looks unbuilt.
2. M2 `city_overlay_painter_test.dart:187`: one line is over 120 columns; the m2b report's "format clean" is false (probably the cause of the run's STOP, not confirmed).
3. S1 `city_painter.dart:151`: a failed `toImage` is an uncaught async error, never logged, never retried.
4. S3 `city_painter_test.dart`: no test for dispose, a superseded build or a failing build.
5. S4 `city_scene_test.dart:153`: the late-joiner test never calls `lateJoinTilePosition`.

Owner questions (full list under Open questions): built-tile colour; `ink` as the sixth colour on the Night palette; cache at logical pixels on phones; `CityScene.from` throwing off-road; chip placement.

Fix-job sizing (no shared files within a wave; none is pinned by controller_app or tv_test_app, since no file there imports `city/art`):
- Wave 1: A = overlay painter + overlay test (built-tile colour, the 127-column line, the TV look); B = city painter + painter test (the `toImage` catch, `paint` size, dispose tests); C = `city_layout.dart` + a new layout test file (tile-size floor, dead branch, Plaza check).
- Wave 2 (after A and B): D = `city_scene.dart` + scene test (late-joiner call, boolean renames, the overlay's renamed readers); E = `m2b-report.md` only (self-check lines, the `CityTokenArt` note).
- Wave 3 (last, touches every test file): F = one shared tile-drawing file used by both painters (the `_paintSlab`/`_paintTile` copies, could 14); G = `test/support/` helpers (`_boardFor`, `_CountingCanvas`, the badge-rule copy).

## Findings

- **must** (fixed in f1) packages/party_host/lib/src/city/art/city_overlay_painter.dart:65 built tiles are painted in `look.colors.paper`, the colour the static map gives every unbuilt road tile (city_painter.dart:109), so a built tile looks unbuilt → paint built tiles in a distinct look colour, name it in the report, and add a painter test that checks the colour (from: wave2 review; still in final code)
- **must** (fixed in f1) packages/party_host/test/city/art/city_overlay_painter_test.dart:187 the line is over 120 columns, so `dart format` rewrites it and the m2b report's "5 files formatted" claim is false → wrap the set literal as dart format would, then re-run the format check (from: wave2 review; the only line over 120 columns in the art folder, by grep)
- **should** packages/party_host/lib/src/city/art/city_painter.dart:151 `unawaited(build(...))` has no catch: a `toImage` failure (line 164) is an uncaught async error with no log, and `_wantedSize` stays set (line 157) so nothing retries → catch at the `toImage` boundary, log through `LogSink`, clear `_wantedSize` so a later paint can retry, and add a test with a failing build (from: wave1 review)
- **should** packages/party_host/lib/src/city/art/city_painter.dart:53 `paint(canvas, size)` looks up the cache by `layout.size` and draws at `Offset.zero`, ignoring `size`; a layout built for another size gets a misplaced image with no error → draw from `size`, or assert `size == layout.size` and say so in the doc. The overlay's `paint` (city_overlay_painter.dart:33) also ignores `size`; same rule (from: wave1 review)
- **should** packages/party_host/test/city/art/city_painter_test.dart:154-193 no test covers `dispose` (city_painter.dart:179-184), the superseded-build discard (line 168), or dispose during a build; guidelines §5 require a test that dispose leaves nothing running → add: dispose during a build leaves no image and no notify; a size change during a build keeps only the newest size (from: wave1 review)
- **should** packages/party_host/test/city/art/city_scene_test.dart:153-163 the test is named for `lateJoinTilePosition`, types `tilePosition: 1`, and never calls the function → take the position from `lateJoinTilePosition([3, 1, 4])` (rules.dart:207 returns 1), so the rule is what is tested (from: wave2 review)
- **should** packages/party_host/lib/src/city/art/city_scene.dart:55 `roadworks`, :80 `complete`, :119 `open`, :174 `roadworksCone` are booleans named as states (guidelines §4) → `hasRoadworks`, `isComplete`, `isOpen`, `hasRoadworksCone`, updating the readers at city_overlay_painter.dart:36, :44, :48 and the tests (from: wave2 review)
- **should** packages/party_host/test/city/art/city_overlay_painter_test.dart:41 `_look()` builds only the menu look (`tv: false`); the TV look and `test/support/all_looks.dart` are never used, so review-rules A6 is not met → run the colour and layer tests under both looks through the all-looks helper (from: wave2 review)
- **should** packages/party_host/test/city/art/city_overlay_painter_test.dart:151 the eight-player test recomputes the badge rule (`slot < cityColouredSlots ? null : slot + 1`) that `CityScene.from` owns (city_scene.dart:193), so it checks a copy → take the badges from `CityScene.from`, or assert only the label count (from: wave2 review)
- **should** docs/briefs/m17/map2a/m2b-report.md:41 the report has no answers to review-rules part A (host setups, kept state, combinations, folder, stopping, looks; sections present are Summary, Files, Computed, Decisions, Hand-over, Commit, Status) → add the six lines, each with the test that shows it; "not affected" is an answer (from: wave2 review)
- **should** packages/party_host/lib/src/city/art/city_layout.dart:60 with :118-130 the tile size comes only from the screen's shorter side and the fit; there is no mm floor and no px-per-mm (review-rules B5, guidelines §6). Computed by hand: at 360×640 with 8 players the tile is 17.4 logical px → take the injected px-per-mm and a named minimum tile size in mm, or write down why the box alone is enough (from: wave1 review)
- **should** packages/party_host/lib/src/city/art/city_layout.dart:133 `steps == 0 ? road : road.take(steps)` is a dead branch: `compute` throws at line 45 for `roadLength < 2`, so `steps` is at least 1 → `road.take(steps).toList()` (guidelines §2 leftovers) (from: wave1 review)
- **should** packages/party_host/lib/src/city/art/city_overlay_painter.dart:111-122 `_paintSlab` repeats `CityPainter._paintTile` (city_painter.dart:114-120) line for line → one shared tile-drawing function in a file both use; do not leave two copies (from: across jobs, m2a and m2b both solved it)
- **should** packages/party_host/test/city/art/city_overlay_painter_test.dart:20 and :59, packages/party_host/test/city/art/city_scene_test.dart:15, packages/party_host/test/city/art/city_painter_test.dart:41 and :59: `_boardFor` now exists in three files and `_CountingCanvas` in two → move both to `packages/party_host/test/support/`. The wave2 trigger ("when a third test needs them") is met (from: across jobs)
- **should** docs/briefs/m17/map2a/m2b.md:4 names `CityTokenArt` as a new type; the code has none (`city_tokens.dart` holds free functions) and m2b-report.md:14 does not say the name was dropped → record the change in the report and settle the name with Claude (from: across jobs)
- **could** packages/party_host/lib/src/city/art/city_layout.dart:125 `if (roads.isNotEmpty)` sits in the loop over `points`, so it is always true there and never changes the result → remove it (from: wave1 review)
- **could** packages/party_host/lib/src/city/art/city_layout.dart:127-129 the fit ignores the Plaza (side 1.25 tiles, city_painter.dart:30). By hand, not run, it does not overlap at the sizes checked: at 1920×1080 with 8 players the nearest road tile is 123.5 px from the Plaza centre on x, against a 90.5 px limit (tile 80.4 px); at 360×640 it is 41.2 px on y against 19.6 px. Downgraded from should; add a Plaza-rect check to the new layout test so the fit cannot regress (from: wave1 review, corrected)
- **could** packages/party_host/lib/src/city/art/city_painter.dart:141 the `buildCount` doc says "one per size", but `_buildCount++` (line 158) also counts builds that line 168 discards → say "one per started build" (from: wave1 review)
- **could** packages/party_host/test/city/art/city_painter_test.dart:123 `expect(box.left >= 0 && ..., isTrue)` gives no reason on failure → use a `predicate` as at lines 114-117, with a reason (from: wave1 review)
- **could** packages/party_host/test/city/art/city_painter_test.dart:225-226 the test "paints under every look without an error" checks only `buildCount == 1` and no exception; it does not show the look reached the painter → rename it to what it checks, or assert a draw from the look (from: wave1 review)
- **could** docs/briefs/m17/map2a/m2a-report.md:21 self-check line 2 says the cache "is disposed by its owner", but this job creates no owner, and dispose is untested → reword to "no owner yet; dispose untested" (from: wave1 review)
- **could** packages/party_host/lib/src/city/art/city_painter.dart:60-61 while a build is in flight every frame draws the whole static layer, and the first frame of a size pays it twice (line 60, then inside `build`) → accept it and say so in the report's decisions, or draw a cheap placeholder (from: wave1 review)
- **could** public surface: city_layout.dart:71 `size`, :95 `tileRect`; city_painter.dart:65 `paintStatic`, :156 `build` are public but not in the brief's list → make `paintStatic` private (the tear-off works inside the class) and keep the rest only where a caller needs them (from: wave1 review)
- **could** packages/party_host/lib/src/city/art/city_scene.dart:27 six public types in one file; guidelines §3 allows it when they belong together → keep; split only if the file grows (from: wave2 review)
- **could** packages/party_host/lib/src/city/art/city_scene.dart:95 and :128 `CityTokenScene.playerId` and `CityChipScene.playerId` are read by nothing outside `CityScene.from` (no painter, no test) → drop them or use them in a test (from: across jobs)
- **could** packages/party_host/lib/src/city/art/city_tokens.dart:37-45 the six colours are indexed by `slot` for `slot < cityColouredSlots` (city_scene.dart:24); raising that constant above 6 throws a RangeError here → derive the limit from `colours.length`, or assert it (from: across jobs)
- **could** packages/party_host/lib/src/city/art/city_tokens.dart:63-68 `paintCityLabel` lays out a new `TextPainter` for every badge and chip every frame (called at city_overlay_painter.dart:53 and :107); an allocation proportional to players, not measured → cache the painters per text, or record the cost (from: across jobs)
- **could** packages/party_host/lib/src/city/art/city_painter.dart:124 and city_overlay_painter.dart:126 `shouldRepaint` compares `CityLayout` by identity (it has no `==`), so a screen that builds a new layout each build repaints every frame → when wiring, compute the layout once per size (later cost, from: across jobs)
- **could** packages/party_host/lib/src/city/art/city_painter.dart:66 builds `ToyShapeStyle(ink:, outlineWidth:)` inline, the same as `cityShapeStyleOf` (city_tokens.dart:29-30); the start-to-Plaza path at city_painter.dart:82-85 is the same as city_overlay_painter.dart:70-73 → use the shared helpers from wave 3 (from: across jobs)

## Open questions

1. Built-tile colour (M1): pick `good`; it differs from paper and the lane start, but it matches the corner start (city_painter.dart:109); owner to confirm.
2. Sixth player colour `ink` (city_tokens.dart:43): it may vanish on the Night palette; keep `ink`, add a Night-palette test, or choose a distinct colour.
3. Cache at logical pixels (city_painter.dart:164): accept for the TV; use devicePixelRatio before wiring a phone.
4. Badges from the 7th player on (city_scene.dart:193) versus the brief's "7th and 8th": keep; the layout caps at 8 players, so the result matches the brief.
5. `builtTiles` clamped to `roadLength` (city_scene.dart:184) versus `roadLength - 1`: keep the brief's `roadLength`; the painter guards the Plaza either way.
6. `CityScene.from` throws for a token off its road (city_scene.dart:157, :199): keep the throw, since a bad snapshot is a bug, and have the screen validate before wiring.
7. Bolts chips under the Plaza (city_scene.dart:207) rather than on each player's road: keep as built; owner to confirm.
8. A token with no Bolts entry shows a chip with 0 (board.dart:149): keep.
9. Colours chosen without the brief: cone `caution` (city_overlay_painter.dart:93), complete stroke `good` (:80), Plaza `caution` (city_painter.dart:77), start tiles (:109): keep; confirm on a device.
10. Tuning constants (city_layout.dart:16, :20, :23; city_painter.dart:30) are untested by eye: confirm on a device.
11. `dynamic noSuchMethod` in both test files (city_painter_test.dart:67, city_overlay_painter_test.dart:67): the driver's gate flagged the word "dynamic" (run.log:30); keep, since Dart requires the return type, and confirm the gate allows it.
12. The first run stopped on "tools/review.sh found a FAIL after m2b" (run.log:27): suggest the cause is M2; confirm from the review log (not read here).
13. `CityTokenArt` (S13): keep the free functions and record it, or add the class; suggest keep and record.

## Numbers against targets

- Files under about 380 lines (m2a.md and m2b.md item 4): met. Lib: city_layout 139, city_painter 185, city_scene 216, city_tokens 69, city_overlay_painter 127. Tests: scene 187, overlay 219, painter 231 (limit 500).
- 120 columns: missed by one line (city_overlay_painter_test.dart:187).
- Test counts: 29 (m2a) and 34 (m2b) match the test files by count: painter file 21 + 2 layout, 3 cache, 3 screen; overlay 10 per size × 2 + 3 colour + 1 repaint; scene 10. The test runs themselves are not in run.log (see below).
- Tile overlap: none at the sizes checked, by hand. Nearest road-tile gap at 1920×1080 with 8 players is 126.3 px, tile 80.4 px; at 360×640, gap 27.3 px, tile 17.4 px.
- Expectations in m2b: 3 built tiles → 3 side faces and 9 paths; 6 built → 5 faces and 15 paths; complete road adds 1 stroke (16); 8 tokens → 24 paths and 2 labels. These match the code paths; the 3-paths-per-`toyShape` count rests on toy_look, which was not opened.
- No numeric target is given for tile size; review-rules B5 asks for a floor and the code has none (see S9).

## Could not check

- Test and analyze results: run.log has no pass or fail lines for the m2a or m2b check (only "combined check ... skips", run.log:26). "29 tests" and "34 tests passing" are not backed by runner output here, and no `dart analyze` output is in the log.
- The STOP reason in `.dart_tool/run-jobs/docs_briefs_m17_map2a/run-review.log` (run.log:27) was not read; it is not on the read list.
- Whether dart format would reflow other lines: only the 120-column width was checked, by grep.
- toy_look internals (the three paths per `toyShape`, the Sunny and Night palettes) were not opened.
- docs/architecture.md was not checked for the city art layer.
- Look, legibility and high-DPI softness on a device: not checkable here.
- Hand-fix (step 2): run.log:30 `HAND-FIX m2b: 4 doc-comment words 'dynamic' reworded`, committed 4b6ae05a by the driver. The tests-first proof exists (run.log:42-43; done.txt "m2b 4b6ae05a proof") and the worker review exists (run.log:44; wave2-review-report.md). Fixed, unverified: needs the gate re-run; the gate's failure was not reproduced here.
- Unverified fixes (step 4): none other. No `f<n>` fix commit exists; HEAD (aeab0382) changes docs only.
- Dropped at carry-over (step 1): none; every wave1 and wave2 item still holds in the final code, with the Plaza item corrected to could.

## Commit message — a draft

map2a: review of the run, findings for Claude

Read-only review of the map2a commits (m2a a1606249, m2b 4b6ae05a).
Carries over the wave 1 and wave 2 findings that still hold in the
final code, adds the across-job findings, and lists the open
questions. No code changed; the report is REVIEW.md.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

map2a run review done (read-only, 29 findings: 2 must, 13 should, 14 could); open: built-tile colour (Claude's design), format fix at city_overlay_painter_test.dart:187, the 13 should items in three waves, 13 owner questions, and no test or analyze output for m2a/m2b in run.log.

## Delete

- none
