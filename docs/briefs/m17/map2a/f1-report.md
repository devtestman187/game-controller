# map2a f1 — report

## Summary

- **Built-tile colour (M1):** `_paintBuiltTiles` now paints built tiles in `look.colors.star`, not `look.colors.paper` (`city_overlay_painter.dart:65`).
- **Colour test first:** a new test reads each built tile's side-face paint and checks it equals the star shade and differs from the paper shade. Run before the fix, it failed in all four cases (2 sizes × 2 looks).
- **Both looks (A6):** the layer tests and the `cityTokenColour` tests now run for the menu look and the TV look (`HostLook.values` from `test/support/all_looks.dart`).
- **Over-long line (M2):** the 187-column line is wrapped the way `dart format` wants it. `dart format --set-exit-if-changed` reports 0 changed on both files.
- **Tests:** `tools/mine.sh` ends `OK 51 tests packages/party_host`. The analyzer is clean on both files.
- **Not checked here:** `tools/check.sh` was not run, as the brief says.

Decisions:
1. **Colour is `star`, not `good`.** The brief names `star`; REVIEW.md line 58 suggested `good` and left it to the owner. I followed the brief. See question 1.
2. **Test file rewritten whole.** Every layer test needed the look passed in, so I rewrote the file from the read copy instead of making 20 small edits. Test names and expected values are unchanged apart from the new test and the look loop.
3. **Look helper.** `pumpHostLook` in `all_looks.dart` mounts a widget and needs a `WidgetTester`, so a canvas painter test can't use it. I used the `HostLook` enum from that file and mapped `tv` to `ToyLook.build(palette: ToyPalette.sunny, tv: look == HostLook.tv)`. See question 2.
4. **Colours compared as ARGB ints.** The first version compared `Paint.color` with `toyShadeOf(...)` directly and failed on identical-looking values. `Paint` keeps 8 bits a channel and `toyShadeOf` returns full-precision floats, so the test compares `toARGB32()`.

## Files changed

- `packages/party_host/lib/src/city/art/city_overlay_painter.dart`: line 65, `look.colors.paper` → `look.colors.star` in `_paintBuiltTiles`. Nothing else.
- `packages/party_host/test/city/art/city_overlay_painter_test.dart`: rewritten whole. Adds the built-tile colour test. Adds `_CountingCanvas.roundRectPaints` (records each `drawRRect` paint). Loops the layer tests and the `cityTokenColour` tests over `HostLook.values`. Wraps the over-long line. `_paint` takes a `look` (required).
- `docs/briefs/m17/map2a/f1-report.md`: this report.

## Checks

- **Colour test first (before the lib fix):** `tools/mine.sh` → FAILED, 4 cases: "a built tile is painted in the star colour…" for {1920×1080, 360×640} × {menu, TV}. Actual shade (0.74, 0.7139, 0.6587) is the paper shade; expected (0.74, 0.6094, 0.1828) is the star shade.
- **After the lib fix, first run:** `tools/mine.sh` → FAILED, the same 4 cases. Values printed identical to 4 decimals. Cause: `Paint.color` is 8-bit per channel. Fixed by comparing `toARGB32()`.
- **After the comparison fix:** `tools/mine.sh` → `OK 51 tests packages/party_host`, `RESULT: ok`.
- **Format:** `dart format --output=none --set-exit-if-changed` on both files → `Formatted 2 files (0 changed)`.
- **Analyze:** `dart analyze` on both files → `No issues found!`.
- **Long lines and debug leftovers:** grep for lines over 120 columns, `BISECT`, `print(`, `TODO` in both files → no matches.

Colour values used (`packages/toy_look/lib/src/toy_colors.dart`): sunny `star` 0xFFFFD23F, sunny `paper` 0xFFFFF6E3. The night palette has the same two values, so the colour check holds in both looks.

## Self-check (review-rules part A)

1. **Host setups:** the painter is shared by all hosts and is not host-specific. Covered by the built-tile test at both sizes (TV and phone) in both looks. Not a host-setup test.
2. **Kept state:** none added. `shouldRepaint` test (still menu look) shows a new scene repaints and the same scene doesn't.
3. **Combination with other states:** none; painter-only change, no new state.
4. **Stayed in allow:** yes, three files only: the lib painter, its test, and this report.
5. **Stop rather than overstep:** nothing blocked. Did not touch `city_scene.dart` or `city_painter.dart`.
6. **Every look:** the layer tests and the built-tile colour test run at 1920×1080 and 360×640 in both menu and TV looks. No fixed pixel heights.

## Hand-over

- Built tiles now show as built (star). The unbuilt road keeps paper.
- The TV look is the sunny palette with `tv: true`. This matches how the TV host builds it only if `toyTvProvider` also uses sunny; I did not check that (question 2).

## Questions

1. Is `star` right for built tiles, or should it be `good` as REVIEW.md suggested? The job followed the brief (`star`). Changing it is a one-line edit plus a test name.
2. Should the TV look in painter tests come from the same source as `toyTvProvider` rather than `ToyLook.build(..., tv: true)`? I did not confirm they match.
3. The top face of a built tile is not asserted: `toyShape` draws it through a path with no readable colour. Only the side face is checked. Is that enough?
4. `shouldRepaint` still uses the menu look only. Extend it to both looks if you want the same coverage.

## Suggestions

- If `toyShape` ever exposes its paint, assert the top face colour too.

## Commit message — a draft

Built tiles use the star colour, not the unbuilt paper

Built tiles in the city overlay were painted with the paper colour of
unbuilt road tiles, so a built tile looked unbuilt (REVIEW M1). They now
use star. The overlay tests run the layer and token-colour checks in the
menu and TV looks, add a built-tile colour check, and the over-long test
line is wrapped (REVIEW M2, A6).

## Status row

map2a f1: built tiles now use star (M1); overlay tests cover both looks and the built-tile colour, 51 tests pass, line wrapped (M2). Open: confirm star vs good (question 1); top face colour not asserted.

## Delete

- none
