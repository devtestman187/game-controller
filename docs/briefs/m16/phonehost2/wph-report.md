# wph — the phone app's host screens in HostFrame, its pad outside it

## Summary

- Added `controller_app/lib/src/host/host_frame_gate.dart`: `HostFrameGate` paints the look's background in the strip
  the phone bar covers (key `hostFrameBarStrip`) and gives `party.HostFrame` a `MediaQuery` sized to the room below the
  bar (no insets), so the host's screens are scaled in that room and nothing above is.
- `host_games.dart` (42 lines) wraps its Navigator in the gate: the host's whole subtree is in the frame, while the
  bar, the round strip and the pad stay in the device's pixels.
- Tests first: new `controller_app/test/host_frame_wiring_test.dart` (5 tests). Against the old `host_games.dart` the two
  frame tests fail ("Found 0 widgets with type HostFrameInfo that are ancestors of GamesScreen"); the pad test and the
  two no-frame tests pass, as they must.
- Asserted values (s = min(W/960, (H - 52)/540), frame = W/s x 540): 852x393 s **0.6314814814814815**, frame
  **1349.2082111436952 x 540**, rect **(0, 52)-(852, 393)**, header 64 s = **40.41481481481481** px at y 52; 640x360 s
  **0.5703703703703704**, frame **1122.0779220779221 x 540**, rect **(0, 52)-(640, 360)**; the strip is (0, 0)-(W, 52)
  in `look.colors.background`.
- The pad, measured before and after (852x393, a solo round): `faceButtons` **(510, 60)-(827, 377)**,
  `dpad` **(25, 60)-(342, 377)**, Start **(378, 202.5)-(474, 246.5)**; no `HostFrameInfo` ancestor, same rects asserted.
- Suite: baseline 534 pass / 2 skip / 4 fail → now **543 pass / 2 skip / 0 fail**. `host_menu_fit_test`'s picker-scroll
  failure (no frame yet) now passes unchanged; the other three were pinned old layouts from S8p and are rewritten.
- Four more pinned the pre-frame layout after wiring and are rewritten: picker/join/puzzle rects in `host_mode_test`,
  the round's "whole screen" in `host_title_bar_test`, and `expectRoomBelowTheBar` (old screens keep 52 frame px of bar
  room inside the frame). No test was deleted; each rewrite keeps its rule.
- Measured, **not fixed** (step 4): the in-game board's pad clearance is wrong by the scale (numbers below).
- Checks: `tools/check.sh format analyze phone` → PASS format, analyze, phone; `tools/review.sh` → 0 fail, 0 note.

## What changed

- `host_frame_gate.dart` (61 lines): a `LayoutBuilder` gives the room below the bar to a `Column`; the top
  `topBarHeightPx` is a `SizedBox` painting `look.colors.background`, and the rest is a `MediaQuery` (size = the room,
  `padding`/`viewPadding` zero) around `party.HostFrame`. With no look above, nothing is painted there and the sky
  shows as before. When the room is empty or negative the frame draws nothing (`HostFrame` also refuses an empty
  size).
- `host_games.dart`: `HostFrameGate(child: Navigator(...))`; nothing else moved, the route name, the observer and
  `gamesRouteName` are as they were.
- Tests: `host_frame_wiring_test.dart` (5), `host_mode_test.dart` (rects, 4 lines), `host_title_bar_test.dart` (the
  picker's header, the old menus' padding scope, the round's frame rect, `expectRoomBelowTheBar`).

## Decisions and deviations

1. **The frame's MediaQuery is the room the gate lays it in**, not the raw screen less the bar. The gate sits inside
   the controller's `SafeArea` (controller_screen.dart:218), so its box is the safe area; using the raw screen would
   make `HostFrame`'s box a different shape from its media on a notched phone and the drawn scale would no longer be
   `HostFrameInfo.scale`. At the two test sizes (no insets) it is exactly the brief's formula. The media's
   `padding`/`viewPadding` are zero, not just `padding.top`: the outer `SafeArea` already claimed every inset, and
   `HostFrameScreen`'s own `SafeArea` would otherwise claim them a second time inside the frame. Reported as a
   question below.
2. **No look, no strip.** The brief says fill the strip with the look's background; a transparent literal colour would
   be a magic value, so without a `ToyLookScope` the strip paints nothing (the sky shows through the bar, as before the
   gate). Both apps always have a look above.
3. **The gate is a widget, not a provider check**, because `HostGames` only exists on the hosting route; there is
   nothing to gate on and no provider read was needed.
4. **Sizes inside the frame are frame px, rects are device px.** `tester.getSize` on a frame screen returns its frame
   size (the level list is 432 = 540 - 52 - 56), while `tester.getRect` returns the drawn rect (432 x s = 272.8); the
   rewritten tests say which they mean.
5. **Old screens keep their bar room inside the frame.** `HostScreen` still reads `hostBarHeightProvider` (52) and
   `MediaQuery.padding.top` in frame px, so the level list and join screen put their title bar at 52 + 52 s = **84.84**
   device px at 852x393 (was 52). It is the old layout the brief leaves for S8/S9; the tests pin the new number and
   the question is below.

## The board's pad clearance (step 4, measured, no fix)

At 852x393 inside the frame (frame 1349.208 x 540, s 0.63148148), `puzzle_screen.dart:318-331` reads
`hostPadProvider` with the frame-sized box (1349.208 x 540) and `pxPerMm` = `phonePxPerMm` =
6.299212598425197 (a device figure), mode dpad. Its rects, in frame px, are:

| arm | frame-px rect the board keeps clear of | drawn on the device (x s + y 52) | the pad's real device rect |
| --- | --- | --- | --- |
| up | (138.946, 182.646)-(255.006, 353.323) | (87.7, 167.3)-(161.0, 275.1) | (129.6, 60.0)-(237.4, 218.5) |
| down | (138.946, 353.323)-(255.006, 524.0) | (87.7, 275.1)-(161.0, 382.9) | (129.6, 218.5)-(237.4, 377.0) |
| left | (26.299, 295.323)-(196.976, 411.384) | (16.6, 238.5)-(124.4, 311.8) | (25.0, 164.6)-(183.5, 272.4) |
| right | (196.976, 295.323)-(367.653, 411.384) | (124.4, 238.5)-(232.2, 311.8) | (183.5, 164.6)-(342.0, 272.4) |

- The clearance is **wrong by the scale**: the thumb box is 341.35 frame px = 215.6 device px against the pad's 317
  device px, i.e. 68% of it; the clear area's top is y 167.3 against the pad's 60 and its right edge x 232.2 against
  342. A board may be laid under the pad's upper arm and outer third.
- Cause: `hostPadProvider` answers in device px (`mm x pxPerMm`, joined_view.dart:26-46) and is applied to a box that
  is now frame px; `HostFrame` scales its own insets, not these. The in-frame pad layout also subtracts the 52-px bar
  as 52 frame px = 32.8 device px against the pad's 52.
- This is a finding for the main session (the brief asks for it, not a fix). The simplest fix shape: the puzzle screen
  (or the provider) divides the rects and `pxPerMm` by `HostFrameInfo.scale` when it is inside a frame.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup** — TV/PC host: `controller_app` only, `tv_test_app` untouched, no route, key or message
   changed. "Play on this phone": `host_frame_wiring_test` "a 'Play on this phone' round keeps its pad exactly where
   it was" (pad rects and no frame ancestor). "Show on this device": `host_mode_test` "'Show on this device' shows the
   game alone" and `host_title_bar_test` "'Show on this device' loses the picker's back arrow too". A joined phone:
   "a joined phone is not in the frame". One build older: no protocol message, key or route changed, so the same
   screens are found.
2. **When kept state starts and ends** — the gate holds nothing (stateless; the size is read each build), starts no
   timer and owns no listener; the wiring test mounts and disposes a host (`soloRound` + `host.dispose`) with no
   pending timer, and `host_mode_test` does the same through the frame.
3. **How a new state combines** — the frame adds no pause, hide, wait or input block: it is a scale and a
   `MediaQuery`. A full solo Shape Race round runs through it (`host_frame_wiring_test`'s pad test, `host_mode_test`'s
   solo round); the away/waiting overlays sit above the stack as before (`sleep`-free suite: 543 green).
4. **Stay in the job's folder** — six files changed, all in `allow:` (`host_frame_gate.dart` new, `host_games.dart`,
   `host_frame_wiring_test.dart` new, `host_mode_test.dart`, `host_title_bar_test.dart`, this report). The suite itself
   rewrites the six `site/shots/*.png` on every run (site_shots.dart:336); see Suggestions.
5. **Stop rather than overstep** — nothing outside `allow:` was needed. The two things I would have changed elsewhere
   (the media/inset choice and the board's pad clearance) are reported, not acted on.

## Hand-over

- Where the numbers are: `HostFrameGate`'s doc comment (scale for 852x393 and 640x360) and
  `host_frame_wiring_test.dart`'s `frameAt`; the pad's recorded rects are in that test with their values.
- Open: the in-game pad clearance (step 4) — needs a fix job in `party_host`/`controller_app` (scale the rects by
  `HostFrameInfo.scale`).
- Open: the old-layout screens (level list, join, puzzle results) still leave `hostBarHeightProvider` (52) of frame px
  above their title bar inside the frame, now on top of the bar's own 52 device px; 84.84 device px at 852x393.
  S9's move of those screens, or a gate that zeroes the provider inside the frame, would settle it.
- Open: a notched phone host gets the frame from the safe area (no insets inside it); whether the strip should also
  cover the device's top inset, the frame's media decision in "Decisions" 1.

## Questions

1. Is "the frame's media is the safe area less the bar, insets zero" the intended reading of decision (Nov 20)? It is
   the brief's formula at the test sizes and the only one that keeps `HostFrameInfo.scale` equal to the drawn scale on
   a notched phone.
2. Should `hostBarHeightProvider` be zero inside the frame until the old screens move (a gate override), or is 84.84 px
   acceptable for S9's screens?
3. The six rewritten `site/shots` PNGs: I could not restore them without a git command, and the suite rewrites them on
   every run — the runner should discard them.

## Commit message

Draw the phone host's screens in HostFrame below the bar

- Add HostFrameGate: the look's background in the bar's strip, then HostFrame over a MediaQuery sized to the room
  below the bar, so the frame's scale is min(W/960, (H - 52)/540) (0.63148 at 852x393, 0.57037 at 640x360).
- HostGames wraps its Navigator in the gate: the host's whole subtree is scaled, while the bar, round strip and pad
  stay in device pixels (rects unchanged: faceButtons (510,60)-(827,377), dpad (25,60)-(342,377)).
- New host_frame_wiring_test (frame info, rect and strip at two sizes; no frame on a joined phone or Connect; the pad
  outside it); host_mode_test, host_title_bar_test rewritten from the pre-frame layout to the frame's.
- Measured, not fixed: the in-game board's pad clearance is computed in device px and applied in frame px, so it is
  0.63148 of the pad and misses its top arm.

## Status row

wph done: the phone host's screens are in HostFrame under the bar (HostFrameGate, 5 new tests, 543 green) and the pad's layout is proven unchanged. Open: the board's pad clearance is wrong by the frame's scale (measured, fix job), the old screens double the bar inset inside the frame, the six site/shots PNGs the suite rewrote need discarding.

## Delete

- none
