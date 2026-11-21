# M16 phonehost1 f1 — the frame keeps its own text and its own type (REVIEW.md findings 1, 2, 9)

## Summary

- Finding 1: `_frameMedia` now sets `textScaler: TextScaler.noScaling`, so a phone host with the system text at
  2x draws the frame at its frame sizes instead of overflowing the fixed 960x540 layout.
- Finding 9: `HostFrame.build` returns `const SizedBox.shrink()` when the device's size is empty, before the
  scale is computed (old code: `BoxConstraints has NaN values`).
- Finding 2: `HostFrame` wraps its child in a `ToyLookScope` whose look is the scope's look with
  `ToyType.frame` - the palette, colours, sizes and shaders are kept. The look's type is now the frame's inside
  the frame and the phone's outside it.
- New toy_look API (documented, minimal): `ToyLook.withType(ToyType type)` and `ToyLookScope.maybeOf(context)`.
  `ToyLook.build`'s `tv` flag, `ToyLookScope.of` and every caller are unchanged (`of` now calls `maybeOf` and keeps
  its assert).
- With no `ToyLookScope` above it, the frame leaves the child as it is: the frame draws the host's screens but
  does not choose a palette, so `host_frame_test.dart` (which mounts the frame with no scope) is unchanged and
  still passes.
- Tests first: `packages/party_host/test/host_frame_look_test.dart` is new, and its four brief tests failed on the
  old code. The fifth (a TV-shaped look inside the frame) was added for self-check A1 after the fix and passes.
- `host_frame_test.dart` was not changed; `host_frame_screen_test.dart` was not changed and still passes (23
  tests). It holds a TV-shaped look, whose 28 px button and 22 px body are the frame's too, and the screen builds
  its title from `ToyType.frame` directly, so the frame's new type changes none of its values.
- Checks: `tools/check.sh format analyze look host` PASS on the second run (look 137 tests, host all green). The
  first host run hit the known flake `live_stats_share_test` (two IDs in the other order), the same one s1
  reported; it passes alone and in the full run after it. `tools/review.sh` -> 0 fail, 0 note.
- `host_frame.dart` is 182 lines.

Computed values the new tests assert:

- 640x360: s = 640/960 = 2/3 = 0.6666666666666666, frame 960x540. A `ToyButton` label is 28 frame px
  (`ToyType.frame.button`) = 18.666... device px (18.7); the phone's type would be 18 frame px = 12 dp.
- 1920x1080: s = 2, so the frame's 40 px title is 80 device px; a TV-shaped look reads the frame's type too.
- Text scale: the platform's `textScaleFactorTestValue = 2` reads as `TextScaler.linear(2)` outside the frame
  (`scale(10) == 20`) and as `TextScaler.noScaling` inside it.
- Zero size: the frame is 0x0, builds no child, and throws nothing.

## Files changed

- `packages/party_host/lib/src/ui/host_frame.dart`: the empty-size guard, `textScaler: TextScaler.noScaling` in
  `_frameMedia`, the new `_frameLook` wrapper, the toy_look import, and the class and `_frameMedia` doc comments.
- `packages/toy_look/lib/src/toy_look.dart`: `ToyLook.withType`.
- `packages/toy_look/lib/src/toy_look_scope.dart`: `ToyLookScope.maybeOf`, and `of` built on it.
- `packages/toy_look/test/toy_look_test.dart`: two tests, for `withType` and for `maybeOf` (8 -> 10 tests).
- `packages/party_host/test/host_frame_look_test.dart`: new, 5 tests.

## Decisions

1. `withType` on `ToyLook` rather than a `type:` parameter on `ToyLook.build`: `build` takes `ToyShaders`, not the
   `FragmentProgram`s a built look holds, so a widget that has the look cannot rebuild it with its shaders.
   `withType` keeps every field and changes one, and `look.withType(look.type)` equals `look`, so nothing below
   the frame's scope rebuilds for a same-type rebuild.
2. `ToyLookScope.maybeOf` was added because the frame cannot call `of`: it is mounted with no look above it in
   `host_frame_test.dart` and in any test of the frame alone. `of`'s behaviour (assert, then the look) is
   unchanged.
3. A frame with no look above it passes the child through rather than inventing a look: a test or a screen that
   drew with no look must keep failing the way it did, not silently get Sunny.
4. The frame changes the look's type only, not its sizes, colours or shaders: DESIGN section 5 says the host picks
   `frame` for its type, and the sizes stay the device's (`ToySizes.menu` on a phone, `ToySizes.tv` on the TV).
5. The empty-size case returns before `MediaQuery`, `HostFrameInfo` and the look wrapper, so a zero-size frame
   builds no child at all: there is no layout to give it.

## Self-check (review-rules part A)

1. **Every host setup** - TV/PC host: a TV-shaped look inside the frame reads `ToyType.frame` and its 40 px title
   ("a TV look inside the frame reads the frame's type too"). Phone host: same at 640x360 ("a phone look draws as
   the frame's type inside the frame and stays the phone's outside"). "Show on this device" and a joined phone
   never enter the frame, so the scope's own look is what they read (the same test asserts the look outside is
   unchanged). Older build: no protocol, saved-file or wiring change, and neither app wires the frame yet.
2. **When kept state starts and ends** - nothing is held, timed or counted: `HostFrame` is still a
   `StatelessWidget` that reads the device's media query and the look on each build, and the two look tests read
   both through the widgets inside the frame ("a phone look draws as the frame's type inside the frame", "the
   frame drops the device's text scale").
3. **How a new state combines with the others** - no pause, away, wait or input state is added. The frame wraps
   the pause menu, the away card and the results the same way it wraps a screen, so their look and text scale are
   the frame's and nothing else changes; no other state owner is touched.
4. **Stay in the job's folder** - `git status` shows only the four allowed Dart files and this report; `run.log`
   and `tv_test_app/windows/flutter/generated_plugin*` were touched by the tooling, not by me.
5. **Stop rather than overstep** - no file outside `allow:` was needed; `host_frame_screen.dart` (f2's, safe
   area), `host_frame_screen_test.dart` and `host_frame_test.dart` were read only. The open points below are
   questions, not changes.

## Open questions

1. **The theme inside the frame.** `controller_app` makes `toyTheme(look)` from the phone's look above the
   `MaterialApp`, so `ToyLookScope.of` sees the frame's type but built-in Material text (dialogs, snackbars)
   keeps the phone's. Should a later slice build the theme from the frame's look inside the frame?
2. **TV titles get smaller.** The TV app's look is `ToyType.tv` (title 56); inside the frame its titles become 40,
   which is the design's one set for every host ("one set serves every host, the TV included"). Worth confirming
   with the owner when the TV app is wired.
3. **Sizes in the frame.** The look's `sizes` stay the device's (menu: 48 px button height). Should the frame set
   its own `ToySizes` (Thumby's edge, hit targets) or is the phone's menu set the frame's set too?

## Suggestions

- When `HostFrame` is wired into an app without a `ToyLookScope` above it, nothing warns: the screens would draw
  the phone's 18 px buttons under the 20 px floor silently. A debug-mode assert in `_frameLook` would catch it.
- `host_frame_screen_test.dart:83` draws the screen with a TV look, so its 40 px title assertion only passes
  because the screen builds its title from `ToyType.frame` itself; its look's button and body sizes equal the
  frame's, so the frame's type is invisible to that file. A footer test with a phone-shaped look (as f1's third
  test does through `ToyButton`) would show the difference.

## Hand-over

- f1 is done: the frame keeps the device's insets divided by `s`, drops its text scale, hands its screens the
  frame's type, and takes an empty device as an empty frame.
- f2 still owns the safe area in `host_frame_screen.dart`; nothing here claims insets in the frame or adds a
  `SafeArea`.
- Neither app wires `HostFrame` yet. When the phone's gate lands (s1's open question), every host screen gets the
  no-scaling text and the frame's type at once, with no screen changing.

## Commit message

```
HostFrame: no device text scale, ToyType.frame inside, empty size safe

The frame copied the device's textScaler, so a phone with large system text
overflowed its fixed 960x540 layout; _frameMedia now sets
TextScaler.noScaling (REVIEW finding 1).

HostFrame also wraps its child in a ToyLookScope whose look is the one above
it with ToyType.frame, which DESIGN section 5 asks for (finding 2), and an
empty device size now returns SizedBox.shrink instead of a NaN layout
(finding 9).

toy_look gains ToyLook.withType and ToyLookScope.maybeOf; ToyLook.build,
ToyLookScope.of and every caller are unchanged. New host_frame_look_test.dart.
```

## Status row

phonehost1 f1 done: HostFrame drops the device's text scale, provides ToyType.frame (ToyLook.withType /
ToyLookScope.maybeOf) and builds an empty frame at an empty size; new host_frame_look_test.dart (5) green, host
and look suites green. Open: f2's safe area, the phone-app wiring gate, the theme and sizes questions above,
S3-S6, S8, S9's matrix and TV check.

## Delete

- none
