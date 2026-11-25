# c0b report: hudRects plumbing (B-044, contract 2 of 2)

tests-first: the lib edits were made in the same pass as the tests, so I did not run the tests red first (deviation).

## Files changed
- game_kit/lib/src/game_module.dart: `ViewContext.hudRects` (record field, dartdoc).
- game_kit/lib/src/frame_view.dart: `FrameView.hudRects` (default `const []`), handed to the viewer.
- puzzle_game/lib/src/puzzle_module.dart: `MatchView.hudRects`, shifted up by `phoneBarClearPx` on phones like `padRects`.
- party_host/lib/src/providers.dart: `HostPad.hudRects` (function of the box); default `(_) => const []`.
- party_host/lib/src/ui/puzzle_pad_scale.dart: `PadClearance.hudRects`; `padClearanceFor` divides them by the frame scale like `rects` (one device box for both).
- party_host/lib/src/ui/puzzle_screen.dart: passes `pad.hudRects` to `PuzzlePlayView`.
- controller_app/lib/src/host/host_overrides.dart: `hudRects` empty in both records.
- Tests: frame_view_test (new case: passes through, defaults empty), puzzle_module_test (phones: shifted by 52 px; screen: unshifted), puzzle_pad_clearance_test (divided by scale at 852x393 and 640x360; unchanged with no frame), plus record literals in puzzle_screen_test, puzzle_module_bar_test, worker_identity_test, arena_phone_identity_test.
- camera_test, mirror_pad_test, pad_clearance_frame_test: no record literals; no change needed. joined_view.dart: nothing passed (default).

## Computed values
- Phone shift: HUD rect (10,100,80,40) -> (10,48,80,40) (minus 52).
- Clearance: `_hudDevice` (300,8,560,56) expected as device/s, s = 0.63148148 at room 852x341 and 0.57037037 at 640x300 (the test computes s).

## Checks
tools/mine.sh: format (14 files), analyze 5 packages, tests OK (controller_app, game_kit, party_host, puzzle_game, test_game).

## Questions
none.

## Commit message
m165 c0b: carry hudRects from the app to puzzle_game

ViewContext, FrameView and HostPad gain hudRects; PuzzleModule hands
them to MatchView (shifted by phoneBarClearPx on a phone, like padRects),
and padClearanceFor divides them by the frame scale like rects. Both apps
pass an empty list; job b1 fills them.

## Status row
c0b: hudRects plumbed viewer and host path to puzzle_game (apps pass none); open: b1 fills the apps' lists.

## Delete
- none
