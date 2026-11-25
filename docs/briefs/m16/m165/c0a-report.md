# m165 c0a report: hudRects through the draw chain (B-044, contract 1 of 2)

## Summary

- Added `hudRects` (`List<Rect> = const []`) beside every `padRects` on the draw chain, down to `PuzzleCamera.hudPlace`. Nothing uses it yet: `hudPlace` takes the list and ignores it, as the brief says. `place()`, the mirror and the board fit are unchanged.
- `MatchPainter.shouldRepaint` compares `hudRects` with `listEquals`, so a change to the list repaints.
- Tests first: the new `hud_rects_plumbing_test.dart` failed to compile before the lib change (`The named parameter 'hudRects' isn't defined`, two errors from `mine.sh`), then passed after it.
- Decision: the `hudRects` dartdoc on `MatchPainter`, `MatchView` and `PuzzlePlayView` is the brief's wording, "controls the HUD keeps clear of, which the board and the mirror may go under (B-044)". On `hudPlace` it also says "not used yet, so the placement ignores them", as the brief asks.
- Decision: `phone_hud.dart` passes `hudRects` only to the `hudPlace` call in the no-mirror branch. The mirror branch takes `mirror?.hud` from `mirrorPlace`, which still calls `hudPlace` without `hudRects`. Since `hudPlace` ignores the list, the output is the same either way.
- Decision: `puzzle_module.dart` (which builds the `padRects` for the views) is not in `allow:`, so it does not pass `hudRects`. The default `const []` applies to every host until b1 wires it.

### Tests seen in this job

- `tools/mine.sh` before the lib change: format, analyze and the new test file failed to compile (2 `undefined_named_parameter` errors).
- `tools/mine.sh` after the change: `OK 14 tests packages/puzzle_game`, `RESULT: ok: 6 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`. Run again after the last edit, same result.
- `flutter test` on the four named files, run from `packages/puzzle_game`: `All tests passed!`, 20 tests (mirror_place_test, portrait_hud_test, match_view_whole_if_no_mirror_test, hud_rects_plumbing_test).
- Computed values in the new test: `hudPlace` with `hudControl` (0, 0, 10, 10) and without any `hudRects` gives the same rect and form on the race text (`raceText(boat)`) at `iphone` (852 x 393), `sideLeft`. The exact rect is not written in the test: it compares the two results. `shouldRepaint` is false for equal lists and true for `[hudControl]` against `const []`.

## Self-check (review-rules part A)

1. Host setups: no behaviour change; every host gets the default `const []`. Shown by the four named files passing (20 tests).
2. Kept state: none added. Nothing starts or ends.
3. Combinations with pause, away, get ready, dropped link, results, leaving: `hudRects` is ignored by the placement, so none change. Not tested beyond the existing suites.
4. Stayed in allow: yes. Files changed are listed below; no other file was edited.
5. Stopped rather than overstepped: `puzzle_module.dart` needs `hudRects` wired, and it is outside `allow:`. Not edited; see Questions.
6. Looks: no drawing changed; no fixed pixel size added. The four named files cover the tablet and phone sizes they already test.

## Files changed

- `packages/puzzle_game/lib/src/camera.dart`: `hudPlace` gets `List<Rect> hudRects = const []` and a doc line. Ignored for now.
- `packages/puzzle_game/lib/src/match_painter.dart`: `hudRects` constructor parameter, field with dartdoc, and a `listEquals` check in `shouldRepaint`.
- `packages/puzzle_game/lib/src/match_view.dart`: `hudRects` parameter and field; passed to `MatchPainter`.
- `packages/puzzle_game/lib/src/play_view.dart`: `hudRects` parameter and field; passed to `MatchView`.
- `packages/puzzle_game/lib/src/phone_hud.dart`: `hudRects` passed to the `PuzzleCamera.hudPlace` call (no-mirror branch).
- `packages/puzzle_game/test/hud_rects_plumbing_test.dart` (new): two tests, one for `shouldRepaint`, one for `hudPlace` with and without `hudRects`.
- `docs/briefs/m16/m165/c0a-report.md` (this file).

Line counts of the touched lib files: camera.dart 359, phone_hud.dart 233, match_painter.dart 241, match_view.dart 220, play_view.dart 224 (all under 380).

## Hand-over

Next job b1 can read `hudRects` in `hudPlace` and pass the list from `puzzle_module.dart` (or the hosts) once that file is in its allow list.

## Questions

1. `hudPlace` now has 8 parameters (the brief's shape). The coding guidelines allow at most 5 and suggest a value object. Keep as is for c0a, or should b1 bundle `padRects`, `hudRects` and `split` into one object?
2. `puzzle_module.dart` (lines 148-150) builds the `padRects` the views get. Should b1 also pass `hudRects` there?
3. `mine.sh` and plain `flutter test packages/puzzle_game/test/x.dart` from the repo root fail with `Cannot open file, path = 'puzzles/boat.json'`: the tests read `puzzles/` relative to the package directory. Running from `packages/puzzle_game` works. Suggest `tools/mine.sh` or the brief's commands say which directory to run from.

## Commit message — a draft

Subject: puzzle_game: pass hudRects through the draw chain to hudPlace (B-044)

Add an optional `hudRects` list (controls only the HUD must clear) beside every
`padRects` on the draw chain: PuzzlePlayView, MatchView, MatchPainter, phoneHud and
PuzzleCamera.hudPlace. hudPlace accepts it and ignores it for now; place(), the mirror
and the board fit are unchanged. MatchPainter.shouldRepaint compares it. Tests first:
hud_rects_plumbing_test checks the repaint rule and that hudPlace is unchanged by it.

## Status row

m165 c0a (B-044 contract 1 of 2): `hudRects` now reaches `PuzzleCamera.hudPlace` through PuzzlePlayView, MatchView, MatchPainter and phoneHud; hudPlace ignores it. Open: b1 uses it for the HUD clearance and wires it from puzzle_module.dart.

## Delete

- none
