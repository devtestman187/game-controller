# M16 phonehost2 wtv — the TV app wears HostFrame

## Summary

The TV app's one `MaterialApp.builder` is now `hostFrameBuilder(context, ControllerMenus(child: child!))`, so every
TV screen, dialog and overlay is laid out in the host's 960x540 frame and scaled to the device (owner's decision,
Nov 20: one layout everywhere). At 1920x1080 the home screen's size in frame px is **960x540** (s = 2), drawn at
1920x1080 device px. `HomeScreen.wideWidth`/`wideHeight` still gate the wide/narrow layout, but inside the frame the
frame is never narrower than 960 nor shorter than 540, so the TV now always draws the wide home: the stacked, scrolling
narrow home is no longer reachable from the app. The frame also hands its screens `ToyType.frame`, so the TV's title
and clock text is 40 frame px instead of the TV type's 56 (body 22 and buttons 28 are unchanged).

Tests first: `test/host_frame_wiring_test.dart` failed on the old code at four of its six tests (the three device
sizes had no `HostFrameInfo`, the consent dialog found none); the tap and d-pad tests already held and still do.

Computed values
- 1920x1080: s = min(1920/960, 1080/540) = 2; frame 960x540.
- 1280x720: s = 1280/960 = 1.3333333333333333; frame 960x540.
- 1024x768: s = 1024/960 = 1.0666666666666667; frame 960x720.
- 700x500 (the old narrow test): s = 700/960 = 0.7291666666666666; frame 960x685.7142857142857 (spare height).

## Files changed

- `tv_test_app/lib/main.dart` — the builder line and its import (already imported through `party_host`); the comment
  above it says the frame is what draws every screen.
- `tv_test_app/test/host_frame_wiring_test.dart` (new) — the six brief tests: the home in the frame at 1920x1080,
  1280x720 and 1024x768 (scale, frame, MediaQuery size and 1:1 pixel ratio at the home), a tap through the frame,
  the d-pad between two header buttons at 1920x1080, and the first-launch consent dialog inside the frame.
- `tv_test_app/test/home_look_test.dart` — the panel title and the pairing code compare their type with a new
  `frameLook` (`tvLook.withType(ToyType.frame)`), because the frame hands the screens that type. Only the clock's size
  differs (56 -> 40 frame px); the palette and `ToySizes` are unchanged.
- `tv_test_app/test/tv_fit_test.dart` — the "narrow home scrolls" test is rewritten: at 700x500 the frame is
  960x685.7 and the home is the wide layout (controllers beside the pairing panel, the log under it), so the test now
  asserts the frame and the side-by-side layout instead of the stacking and scrolling that no longer happens. Its
  measurements are frame px (`tester.getSize`, `HostFrameInfo.frame`). The unused `material.dart` import went, and a
  named tolerance replaced the bare 1e-9. The 1280x720 test is unchanged: its rects are device px but the frame
  fills the screen, so the same check holds scaled.

## Which TV tests changed, and why

- `home_look_test`: the frame's `ToyType.frame` (clock/title 40) replaces the TV type's 56. The assertion still
  compares against the look the screen actually reads; nothing was loosened.
- `tv_fit_test` 700x500: the rule it checked ("a small window stacks and scrolls") no longer applies once the frame is
  the one layout everywhere; it is rewritten to the new layout and named here, as COMMON.md asks. Nothing is skipped
  or weakened: it now proves the wide layout at a small window and the frame's math.
- `host_frame_wiring_test`: new, tests first.

## Self-check (review-rules.md part A, items 1-5)

1. Every host setup: not affected — this changes the TV shell only; the phone host and the joined phones draw the same
   frames. `host_frame_wiring_test` covers the TV at three sizes; `host_away_tv_test` still passes.
2. Kept state: nothing new is held; the frame is computed from the device size on each build and `HostFrameInfo`
   rebuilds on a resize (packages/party_host tests), and hiding the app still reports host away
   (`host_away_tv_test`).
3. Combining with other states: no new pause, hide or blocking state. The first-launch dialog (a route) is drawn in
   the frame, tested by `a dialog opened over the home is in the frame too`; the away state is untouched.
4. Stay in the job's folder: only `tv_test_app/lib/main.dart`, `tv_test_app/test/` and this report were written
   (`git diff --stat`).
5. Stop rather than overstep: nothing outside `allow:` was needed; no design decision was mine to make.

## Notes and questions

- The night/palette route observer and the `ToyLookScope` above the app are unchanged; the frame only re-wraps the look
  with `ToyType.frame` below itself, as S1 designed.
- Suggestion: the `TV` type (`ToyType.tv`) is now only used by tests and by any screen outside the frame; if every TV
  screen ends up inside the frame, `toyTvProvider` may become redundant. Not acted on.
- Suggestion: `home_screen_test`'s "fits a small laptop window without overflow" (600x800) now exercises a 960x1280
  portrait frame; it passes, but a later job may want that comment to say so.

## Hand-over

- The TV line is wired and tested. The phone app's gate is still open (s1-report: `controller_app/lib/main.dart:102`
  needs a decision between a hosting gate and a nested app) and was not part of this job.
- The frame scales the focus ring (owner's decision: a later job measures it).
- Next natural steps: measure the focus ring at 1080p, then the phone host's gate.

## Commit message

```
Wire the TV app into HostFrame

The TV's MaterialApp.builder now wraps the navigator in hostFrameBuilder, so
every TV screen, dialog and overlay is laid out in the host's 960x540 frame
and scaled to the device (owner: one layout everywhere, s = 2 at 1920x1080).
The frame hands its screens ToyType.frame, so the TV's clock and title draw at
40 frame px. Tests first: host_frame_wiring_test covers three sizes, a tap, the
d-pad and a dialog in the frame. A small window now draws the wide home in a
960x685.7 frame, and tv_fit_test's narrow-scroll case is rewritten to that.
```

## Status row

M16 phonehost2 wtv: TV app wired to HostFrame and tested (three sizes, tap, d-pad, dialog); phone host gate still
open, focus-ring measurement later.

## Delete

- none
