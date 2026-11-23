# M16 bugs3 b038 — report

## Summary

Shape Race on a joined phone now leaves the top 52 px clear for the controller's top bar. `ShapeRaceViewer.build` wraps its `MatchView` in a 52 px top `Padding` and shifts the pad rects up by 52 when `target == LayoutTarget.phones`. A screen match is unchanged. Tests were written first and failed on the old lib; they pass now.

Files changed:
- `packages/puzzle_game/lib/src/puzzle_module.dart` (198 lines): new `phoneBarClearPx = 52.0` constant with its reason, documented as joined-phone only. `ShapeRaceViewer.build` now shifts the pad rects and pads the match when the target is phones; screen is untouched.
- `packages/puzzle_game/test/puzzle_module_bar_test.dart` (new, 124 lines): one test, run at 852 x 393 and 393 x 852 for the phones viewer, plus a screen match at 852 x 393.
- `packages/puzzle_game/test/puzzle_module_test.dart`: the existing pad expectation for the phones viewer moved from `Rect(24, 250, 120, 120)` to `Rect(24, 198, 120, 120)`, the same pad shifted up by 52. This is the only pinned position that moved.

Decisions:
- The constant lives in `puzzle_game` as a number, not an import of `controller_app`'s `topBarHeightPx`, because the package does not depend on the app. The doc comment names the source.
- The screen viewer path is unchanged. It is selected by `onPhone`, so the screen match keeps the top of its box.
- The new test file duplicates the small `servePuzzles` and `house` helpers from `puzzle_module_test.dart`, because `test/support/` is outside `allow:`.
- The view is resized per box with `tester.view.physicalSize`. The default 800 x 600 test surface clamped the 852-high box to 600 and gave a false height.

## Self-check (review-rules part A)

1. Host setups: a TV or PC host (screen target) is covered by the screen case in `puzzle_module_bar_test.dart`. A phone on "Play on this phone" and "Show on this device" draw `PuzzleScreen`, not this viewer, so the change does not reach them (no test). A joined phone is covered by the phones case. A peer one build older is not covered (no test; see Questions).
2. Kept state: none added. The padding is built on each `build` from the constant.
3. Pause menu, host away, player away, "Get ready", dropped link, results, leaving: this is a layout offset only; no state is added. Not separately tested.
4. Files stayed inside `allow:`; the new test file is the one new file.
5. Nothing stopped. No file outside `allow:` was needed.
6. Looks: the test covers two sizes (852 x 393 and 393 x 852) and checks the match height is the box minus 52, so no fixed pixel height is used. The menu and TV looks are not drawn in this test.

## Computed test values

- Phones bar: `phoneBarClearPx = 52.0` (4 + 48, from `topBarHeightPx`).
- Pad given: `Rect.fromLTWH(24, 250, 120, 120)`; expected after the shift: `Rect.fromLTWH(24, 198, 120, 120)` (250 - 52 = 198).
- 852 x 393 box: match top 52, match height 393 - 52 = 341.
- 393 x 852 box: match top 52, match height 852 - 52 = 800.
- Screen 852 x 393 box: match top 0, height 393, pad unchanged.

## Checks

- `tools/mine.sh`: first run FAILED as expected (new tests failed on the old lib: height expectation and the missing MatchView). After the lib fix and the test-setup fix (resize per box, one test): OK 2 tests. After the pad expectation in `puzzle_module_test.dart`: OK 6 tests, puzzle_game analyzed, formatted.
- Not run: the controller_app tests named in the brief (`tablet_board_test`, `portrait_hud_test`, `puzzle_size_test`). `mine.sh` runs only touched tests, and I did not touch those files. They build `SplitLayout` directly and do not construct `ShapeRaceViewer` (grep of `controller_app/test` shows no `ShapeRaceViewer` or `shapeRaceModule` use in those three), so I expect no movement, but this is unverified.
- Not run: `camera_test`. It is in `packages/puzzle_game`, and `mine.sh` did not touch it. The camera code is unchanged, so no movement is expected, but this is unverified.

## Hand-over

- Expected, not verified: the host phone and the TV are unchanged by construction.
- `tools/mine.sh` printed `churn: reverted 22 generated file(s)`. After that run, `git status` shows only this job's three files. The working tree at the start had modified files under `docs/design/` and `site/shots/` and `tv_test_app/windows/flutter/`. Those changes are no longer in the working tree. See Questions.

## Commit message — a draft

```
puzzle: leave the top bar's 52 px clear in Shape Race on a joined phone

The controller's top bar covers the top 52 px of a joined phone, which hid
the time and rounds over the shapes. ShapeRaceViewer now pads its match
52 px down and shifts the pad rects up by the same amount, only for a
phones target. The host phone draws PuzzleScreen and is unchanged.
```

## Status row

b038 done: Shape Race on a joined phone leaves the top 52 px clear; the viewer pads its match and shifts the pad rects (tests in puzzle_module_bar_test.dart). Open: controller_app tablet_board/portrait_hud/puzzle_size and camera_test were not run; the churn revert in mine.sh removed uncommitted docs/design, site/shots and tv_test_app changes from the working tree.

## Delete

- none

## Questions

1. `tools/mine.sh` reverted 22 generated files, and the working tree had uncommitted changes in them (`docs/design/*.png`, `site/shots/*.png`, `tv_test_app/windows/flutter/*`). Were those changes wanted? If so, they need restoring from wherever they were kept; I did not run any git command that changes anything.
2. The controller_app tests named in the brief were not run. Should the runner run them, or should I touch one of them so `mine.sh` picks it up?
3. Suggestion: a peer one build older (Shape Race with no pad shift) would now draw a match under a bar it did not expect. Is a version check needed, or does the protocol already gate this?
