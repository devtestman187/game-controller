# b1h report: the HUD keeps clear of the right-hand controls (B-044)

## Summary

- Done: the clock area (HUD) now keeps clear of the right hand's controls (face buttons, Start, and the right stick or its zone in stick mode). The board and the mirror still fit to the left hand's rects only (`padRects`).
- New `rightPadRects` (joined_view.dart), next to `leftPadRects`; passed as `FrameView.hudRects`.
- `HostPad.hudRects` returns the same rects moved into the host's room (`_hostHudRects`); "Show on this device" still gives none.
- `PuzzleCamera.hudPlace` uses `hudRects`: a side-form candidate that meets a control (inflated by `mirrorGapPx`) is rejected like one that does not fit; `_hudUnder` moves right of a control it meets, as it does for pads; the corner fallback is unchanged.
- `mirrorPlace` and `match_view.dart` pass `hudRects` to `hudPlace` only, never to `place()`.
- Tests first: two new files failed before the change (`rightPadRects` undefined; the HUD test's overlap check failed on the old code with `Rect.fromLTRB(0.0, 1917.2, 862.6, 2100.9)` overlapping the control).
- Checks: `tools/mine.sh` OK (56 tests controller_app, 4 tests puzzle_game, format and analyze clean on the changed packages).
- Test counts seen: right_pad_rects_test 18 PASS; hud_place_right_controls_test 3 PASS; mirror_pad_test + pad_clearance_frame_test + pad_clearance_screen_test + portrait_hud_test (controller_app) 14 PASS; camera_test + portrait_hud_test + mirror_place_test + hud_rects_plumbing_test (puzzle_game) 31 PASS in one run.
- Decisions: see below. Questions: see the end.

## Files changed

- `controller_app/lib/src/ui/joined_view.dart`: `rightPadRects(Size, {mode, mm, sticks})`: dpad and gyro give face buttons and Start; sticks give face buttons, right stick (its zone when floating) and Start; all in the screen's px with the bar shift. Passed as `hudRects:` on the `FrameView`.
- `controller_app/lib/src/host/host_overrides.dart`: `HostPad.hudRects` returns `_hostHudRects(...)` when sharing the view (the room's rects moved up by the bar, like `_hostPadRects`); otherwise empty, as before.
- `packages/puzzle_game/lib/src/camera.dart`: `hudPlace` checks side-form candidates against `hudRects` (inflated by `mirrorGapPx`); the under-world search gets `[...padRects, ...hudRects]`; the dartdoc says the board and mirror are not fitted to them. `mirrorPlace` gains `hudRects` (named, default empty), passed to both `hudPlace` calls. New private helper `_meetsControls`.
- `packages/puzzle_game/lib/src/camera_fit.dart`: `_hudUnder` takes `controls` (pads and right-hand controls); the clear check uses `_meetsControls`; dartdoc updated.
- `packages/puzzle_game/lib/src/match_view.dart`: the `mirrorPlace` call passes `hudRects: widget.hudRects`.
- `controller_app/test/right_pad_rects_test.dart` (new): for dpad, fixed sticks, floating sticks and gyro, at 1640x2360 and 852x393: the rect count (2, 3, 3, 2), all rects inside the box, the Start rect present, no overlap with `leftPadRects`. Host: "Play on this phone" gives `pad.hudRects(room)` equal to `rightPadRects` for the room plus the bar, moved up by the bar; "Show on this device" gives none.
- `packages/puzzle_game/test/hud_place_right_controls_test.dart` (new): at 1640x2360 portrait with `house` (whole camera): (1) a control far off the area leaves the area unchanged; (2) a control over the area's own spot: the area moves clear of it and its `mirrorGapPx` air; (3) a strip over the left half of the band: the area keeps clear.
- `docs/briefs/m16/m165/b1h-report.md`: this file.

Not changed (outside `allow:`): `packages/puzzle_game/test/hud_rects_plumbing_test.dart` has a stale test name, see questions.

## Computed values (house, 1640x2360 portrait, whole camera, `PuzzleCamera.hudPlace`)

- No controls: `Rect.fromLTRB(0.0, 1917.2, 862.6, 2100.9)`, `oneLine`.
- Control = that same rect: `Rect.fromLTRB(870.6, 1917.2, 1339.7, 2199.3)`, `twoLines`. Left = 862.6 + `mirrorGapPx` 8.0.
- Strip `Rect.fromLTWH(0, 1917.2, 820, 183.7)` (left half of the band): area `Rect.fromLTRB(828.0, 1917.2, 1297.0, 2199.3)`; left = 820 + 8.

## Self-check (review-rules part A)

1. Host setups: "Play on this phone" (right_pad_rects_test, host group); "Show on this device" (same file, empty). TV/PC host: untouched, default empty rects. A joined phone: `rightPadRects` at both sizes, but the `FrameView` call itself has no widget test. A peer one build older: not tested; `FrameView.hudRects` already existed in game_kit.
2. Kept state: none added. `rightPadRects` and `_hostHudRects` are pure, computed each build from mode, mm and sticks.
3. Combinations with the pause menu, host away, player away, "Get ready", dropped link, results and leaving: not tested. The HUD rects are recomputed on each build, so they follow the same frame as the pad rects; unverified on a device.
4. Only files in `allow:` changed.
5. Stopped on: `hud_rects_plumbing_test.dart` (outside allow).
6. Looks: the rects are tested at 1640x2360 (portrait) and 852x393 (landscape); the menu and TV looks are not separately tested. No fixed pixel height added.

## Hand-over

- `tools/mine.sh`: OK. `dart analyze` on the changed packages: no findings after the fixes.
- Not run: `tools/check.sh` (the runner runs it).
- Stop line: the brief's `stop:` says "after the two parts below"; I read that as the whole `do:` list (steps 1-4), and did all four.

## Questions

1. The mirror's gap path (`camera.dart`, `mirrorPlace`) places the mirror under `hud.rect`. When `hudRects` move the HUD down, the mirror moves too, and `mirrorPlace` can return null (then `match_view` uses the whole camera). The brief says the mirror is not fitted to `hudRects`. Should the gap path ignore the HUD's new position, or is this indirect effect accepted?
2. `hud_rects_plumbing_test.dart` has the test "the HUD placement ignores hudRects for now". It still passes (its control is in the corner, far from the area), but the name is now false. It is not in `allow:`; rename it in a later job?
3. `PuzzleCamera.place` takes no `hudRects`, so the brief's "place gets the same scale with and without hudRects" has nothing to vary. I did not write that check; the board is not moved by the change, by construction.
4. `mirrorPlace` now has 9 parameters (the limit is 5; it was already over). Should a value object carry the pad and HUD rects?
5. Suggestion: a joined-phone widget test for `JoinedView` with the stick and floating modes, to pin the `FrameView.hudRects` call itself.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m165 b1h: the HUD keeps clear of the right-hand controls (B-044)

The clock area now keeps clear of the right hand's face buttons, Start and
right stick (or its zone), passed as hudRects from the app: rightPadRects for a
joined phone, HostPad.hudRects for a phone that hosts its own round. The board
and the mirror still fit to the left hand's pad rects only. hudPlace rejects a
candidate that meets a control (inflated by mirrorGapPx) and _hudUnder moves
right of one, as it does for pads; the corner fallback is unchanged.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

B-044 (b1h): the clock area keeps clear of the right-hand controls on phones and tablets (done, mine.sh OK); open: a device check of the joined and host screens, the mirror's gap-path position when the clock area moves (question 1).

## Delete

- none
