# M16 phonehost1 S1 — HostFrame scaler, HostFrameInfo, ToyType.frame (foundation)

## Summary

- Added `packages/party_host/lib/src/ui/host_frame.dart`: `HostFrame` (the one scaler), `HostFrameInfo`
  (inherited, `of`/`maybeOf`, scale/frame/extraW/extraH/thumbySpot), `ThumbySpot` (side/strip/corner),
  `ThumbySlot` (empty until M17) and `hostFrameBuilder(context, child)` for `MaterialApp.builder`; exported from
  `party_host.dart`. **Not wired into either app.**
- Added `ToyType.frame` (title 40, button 28, clock = title, body 22) and `ToyType.frameSmall` (20, the floor) in
  `packages/toy_look`. `ToyType.tv` and `ToyType.phone` are untouched.
- Tests first: `packages/party_host/test/host_frame_test.dart` (16 tests) failed on the old code (`HostFrame` was
  unknown), then passed; `packages/toy_look/test/toy_type_test.dart` grew from 5 to 7 tests.
- Checks: `tools/check.sh format analyze look host` → PASS format, analyze, look (135 tests), host (every time but
  once). One full host run failed on `live_stats_share_test` (the order of two IDs), which passes alone and in the
  full runs before and after it; see Suggestions. `tools/review.sh` → 0 fail, 0 note.
- Computed values the tests assert (s = min(W/960, H/540), frame = device/s):
  - 640x360: s 0.6666666666666666, frame 960x540, extra (0, 0) → corner.
  - 852x393: s 0.7277777777777777, frame 1170.6870229007634 x 540, extraW 210.68702290076344 → side.
  - 1024x768: s 1.0666666666666667, frame 960x720, extraH 180 → strip.
  - 1280x800: s 1.3333333333333333, frame 960x600, extraH 60 → corner.
  - 1920x1080: s 2, frame 960x540, extra (0, 0) → corner.
  - Hit test at 640x360: a button at frame (100, 50) 200x60 is drawn at device (66.667, 33.333) 133.333x40; a tap at
    device (133.33, 53.33) fires it once, a tap at (466.67, 266.67) does not.
  - Safe area at 1920x1080 (s 2): device padding top 40, left 60 reads as 20 and 30 frame px inside the frame.
  - Type: `ToyType.frame` 40 / 28 / 40 / 22, `clock` is the same object as `title`; `ToyType.frameSmall` 20.

## Decisions

1. All the new host types live in one file, as the brief names them, although the guidelines prefer one public type
   per file: they only make sense together and the file is 158 lines.
2. `FittedBox` over a `SizedBox` of exactly the frame size, default `BoxFit.contain`. The frame has the device's shape,
   so contain fills it exactly (`W/frameW` and `H/frameH` are both `s`); a rounding difference is fitted, never
   stretched. Hit tests go through `RenderFittedBox`'s transform (tested).
3. `MediaQuery` inside the frame: `size` = the frame, `devicePixelRatio` = 1, and `padding`/`viewPadding`/
   `viewInsets` divided by `s`. The last part is not in the brief: without it a phone's notch would be under-reserved
   inside the frame (40 device px would cover only 26.7 device px). One test covers it.
4. `extraW`/`extraH` are getters computed from `frame` (clamped at 0), so they can never disagree with it; the spot
   rule is the design's 120 frame px. Nothing else is stored, so `updateShouldNotify` compares scale and frame only.
5. `ToyType.frameSmall` is a documented static beside `ToyType.frame` rather than a `small` field: a field would need
   a value on `tv` and `phone`, and the brief keeps both unchanged (the existing size tests still guard their values).
6. `ThumbySlot` is a zero-size box whose key follows the spot, so M17's character starts afresh when he moves between
   a side, a strip and the corner (a rotation or a window resize).
7. `hostFrameBuilder` takes `Widget?` and falls back to an empty box, because `MaterialApp.builder`'s child is nullable.

## Wiring the main session must add (not done here)

- TV, `tv_test_app/lib/main.dart:89`:
  `builder: (context, child) => hostFrameBuilder(context, ControllerMenus(child: child!)),`
- Phone, `controller_app/lib/main.dart:102` — **needs a decision first**: that one `MaterialApp` draws both the pad
  screens and the host mode (host screens are pushed on its navigator, `connect_panels.dart:114`), so the root-builder
  line
  `builder: (context, child) => party.hostFrameBuilder(context, party.HostFocusScope(child: child ?? const SizedBox.shrink())),`
  would scale the controller's pad screens too, which DESIGN risk 5 says must stay as they are. Either the builder
  asks a provider whether this phone is hosting (a gate, the way `HostFocusScope` is a gate), or the host mode gets a
  nested app. Both are more than one line, so S2 (or a small S1b) should choose.

## The focus ring

- `HostFocusRing` was not drawn in these tests: it needs `ToyLookScope` and a look, which is the apps' setup, not the
  frame's. What I did check of focus: at 1920x1080 two `TextButton`s still take and move the focus with arrow keys
  (`sendKeyEvent`) through the transform.
- What the frame does to the ring: it is a uniform scale, so `ToySizes.focusRing` of 4 frame px is drawn at 4s device
  px: 2.67 device px at 640x360, 4 px at 1024x768, 8 px at 1920x1080 (today the TV draws it at 4). It reads as the
  same ring relative to the screen, but twice as thick in device pixels on the TV — DESIGN risk 5 asks for a visual
  look there, and S2 should take it.

## Self-check (review-rules part A)

1. **Every host setup** — no app uses the frame yet and it reads no provider, so the TV/Windows host, a phone "Play on
   this phone", a phone "Show on this device" and a joined phone all get the same widget; the five device tests
   include the TV (`1920x1080, the TV: the screen is laid out at the frame, not the device`).
2. **When kept state starts and ends** — the frame keeps none (stateless, recomputed from `MediaQuery` every build) and
   `ThumbySlot` reserves nothing, so nothing starts or ends and hiding Thumby changes nothing yet
   (`the Thumby slot draws nothing and reserves no room until M17`).
3. **How a new state combines** — it adds no pause/away/wait state; the only effects are a transform and a
   `MediaQuery` override, shown not to block input or focus (`a tap at a device pixel lands on the button drawn under
   it`, `at 1920x1080 a pad press moves the focus to the next button`).
4. **Stay in the job's folder** — only files in `allow:` changed (git status: `party_host.dart`, `toy_type.dart`,
   `toy_type_test.dart`, the two new files). `tv_test_app/windows/flutter/generated_plugin*` show as modified with an
   empty diff (line endings only); I did not edit them.
5. **Stop rather than overstep** — nothing outside `allow:` was needed; the phone-app wiring conflict above is
   reported, not acted on.

## Suggestions

- `live_stats_share_test` ("a phone that said no is left out of the upload…") failed once in a full host run with the
  two IDs in the other order, and passes alone and in the full runs before and after. It looks like state shared
  between tests; worth a look before the host suite is trusted in CI.
- S2 will want the stage width (`frame` less the gutter) and the Thumby sizes (side 240, strip 180, head sizes) next to
  `HostFrameInfo`; today only the 120 px spot threshold lives here.

## Hand-over

- S1 is complete and unwired. The main session adds the TV wiring line, decides the phone-app gate, then S2 builds
  `HostScreen`/`ScoreRow` inside the frame. Nothing in `controller_app` or `tv_test_app` changed in this job.

## Commit message

Add the host frame scaler, its info and the frame type (M16 S1)

- HostFrame lays the host's screens out in a 960x540 design frame scaled by
  s = min(W/960, H/540), with MediaQuery size, ratio 1 and scaled insets inside.
- HostFrameInfo gives scale, frame, extraW, extraH and the Thumby spot
  (side/strip/corner); ThumbySlot is empty until M17 and reserves nothing.
- hostFrameBuilder is the MaterialApp.builder helper; no app wires it yet.
- ToyType.frame (40/28/40/22) and ToyType.frameSmall (20) for the frame; the
  TV and phone type sets are unchanged.
- Tests at 640x360, 852x393, 1024x768, 1280x800 and 1920x1080, plus a tap
  through the transform, focus at s = 2, insets and the empty Thumby slot.

## Status row

S1 done: HostFrame/HostFrameInfo/ThumbySpot/ThumbySlot/hostFrameBuilder (tested, not wired) and ToyType.frame + frameSmall. Open: app wiring (TV line ready, phone-app gate needs a decision), S2 screens.

## Delete

- none
