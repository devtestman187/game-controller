## Summary

Verdict: needs Claude (the built-tile colour is a design call; the rest are small fixes).
Counts: must 2 · should 6 · could 2.
Top three:
1. Built tiles are painted in the same paper colour as every unbuilt road tile on the static map, so a built tile is invisible (city_overlay_painter.dart:65).
2. A changed test line is 121+ columns, so the report's "format clean" claim is wrong (city_overlay_painter_test.dart:187).
3. The late-joiner scene test is named after `lateJoinTilePosition` but never calls it (city_scene_test.dart:153).

## Findings

- **must** packages/party_host/lib/src/city/art/city_overlay_painter.dart:65 built tiles are painted in `look.colors.paper`, the colour the static map gives every road tile (city_painter.dart:109), so a built tile looks like an unbuilt one → paint built tiles in a distinct look colour (e.g. `good` or `focus`), name it in the report, and add a painter test that checks the colour.
- **must** packages/party_host/test/city/art/city_overlay_painter_test.dart:187 the line is over 120 columns, so `dart format` rewrites it and the report's "5 files formatted" claim is false → wrap the set literal as dart format would, and re-run the format check.
- **should** packages/party_host/test/city/art/city_scene_test.dart:153 the test says the late joiner starts on `lateJoinTilePosition`, but it types `tilePosition: 1` and never calls the function → build the position with `lateJoinTilePosition([3, 1, 4])` (the rule at rules.dart:207 returns 1) so the test checks the rule.
- **should** packages/party_host/test/city/art/city_overlay_painter_test.dart:151 the eight-player test repeats the badge rule (`slot < cityColouredSlots ? null : slot + 1`) that is under test in city_scene.dart:193, so it checks a copy → take the badges from `CityScene.from` in that test, or assert only the label count.
- **should** packages/party_host/test/city/art/city_overlay_painter_test.dart:41 `_look()` builds only the menu look (`tv: false`); the TV look and the all-looks helper (test/support/all_looks.dart) are never used, so review-rules A6 is not met → run the colour and layer tests under the TV look too, through the all-looks helper.
- **should** packages/party_host/lib/src/city/art/city_overlay_painter.dart:111 `_paintSlab` repeats `CityPainter._paintTile` line for line (city_painter.dart:114-120) → move one shared tile-drawing function into a file both can use, when city_painter.dart may be touched; do not leave two copies.
- **should** packages/party_host/lib/src/city/art/city_scene.dart:80 public booleans are named as states (`complete`, `open` at :119, `roadworks` at :55, `roadworksCone` at :174), against guidelines §4 → rename to `isComplete`, `isOpen`, `hasRoadworks`, `hasRoadworksCone`.
- **should** docs/briefs/m17/map2a/m2b-report.md:31 the report has no answers to review-rules part A (the six self-check lines for host setups, kept state, combinations, folder, stopping and looks); the job is "stateless", so "not affected" lines were needed → add them to the report with the test that shows each one.
- **could** packages/party_host/lib/src/city/art/city_scene.dart:27 six public types in one file; guidelines §3 allows that only when they make sense together, which they do, so a split is optional → keep, or move the token, chip and gate parts to a second file if the file grows.
- **could** packages/party_host/test/city/art/city_overlay_painter_test.dart:20 `_boardFor` and `_CountingCanvas` (test line 59) repeat city_painter_test.dart:59 and the board builder → move them to a shared test support file when a third test needs them.

## Decisions to confirm

- Sixth colour is `look.colors.ink` (city_tokens.dart:43): the tests check only the Sunny palette; the worker says ink may vanish on the Night palette. Confirm or pick a distinct colour, and test the Night palette.
- Badges are given to every slot from 6 on, so players 9 and up get badges 9 and up (city_scene.dart:193); the brief named only the 7th and 8th. Confirm the maximum player count.
- Built tiles are not coloured at all today (see the first must); the colour to use is a design choice.
- Cone colour `caution` (city_overlay_painter.dart:93) and complete-road stroke `good` (:80) are chosen here; the brief names neither.
- `CityScene.from` throws for a token or gate off its road (city_scene.dart:149), as the worker's question 4 asks; a bad snapshot then crashes the frame. Confirm that a throw is wanted.
- Chips show 0 for a player with a token and no Bolts entry (Bolts.of, board.dart); confirm that is wanted rather than no chip.

## Could not check

- The test run and analyzer output were not read here (the runner's `tools/mine.sh` result was not provided); the count of 34 matches the tests in the two files (scene 10; painter 10 per size × 2, colour 3, shouldRepaint 1).
- Whether `toyShape` draws exactly 3 paths (shadow, body, outline) was taken from the worker's report, not from toy_look's source.
- Whether docs/architecture.md describes the city art layer was not checked; the job touched no doc except its own report.
- Nothing in the five files imports `night/`, and no TODO, print or ignore comment was found (grep); the layer and size rules were read by eye.

## Commit message — a draft

none: this review changes no code, so there is nothing to commit.

## Status row

map2a m2b review: done, verdict needs Claude; open: built-tile colour (must), format fix at the painter test line 187 (must), the should items and the six decisions above.

## Delete

- none
