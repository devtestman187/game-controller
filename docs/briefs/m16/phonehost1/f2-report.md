# M16 phonehost1 f2 — the scaffold claims the safe area once; the chip in the header

## Summary

Fix batch B, findings 3 and 6 (and the `could` at `host_frame_screen_test.dart:178`, the title's left).

- `HostFrameScreen` now wraps its column in a `SafeArea` inside the scaffold's body, so one scaffold claims the
  frame's MediaQuery padding once for every screen built on it. The header starts under a notch and the footer
  stops above a home bar; the 64 and 84 px stay the content's heights and the insets add room outside them, taken
  from the body (the only flexing child). With zero padding every rect is exactly what it was.
- New `packages/party_host/test/host_frame_screen_safe_area_test.dart` (9 tests) was written first and failed on
  the old code for the right reason ("Expected: 30.0 (±1e-9) Actual: <0.0>" on the header's top at 852x393 with a
  30 px notch). It covers the notched phone at 852x393 and 640x360, the same two sizes with zero padding, and the
  48 px `RoundSegment` inside the 64 px header at all five sizes, with the title's left at `hostFrameGutterPx`.
- `host_frame_screen_test.dart` needed no change: with zero insets `SafeArea` inserts an `EdgeInsets.zero` padding
  and the frame's rects are unchanged; all 39 tests of the two frame files pass untouched.
- `s2-report.md`'s claim (:65) now names the file that asserts the chip's fit, and its open question 1 records the
  answer f2 gives.
- `tools/check.sh format analyze host` passes; `tools/review.sh` reports 0 fail, 0 note.

## Files changed

1. `packages/party_host/lib/src/ui/host_frame_screen.dart` (144 lines) — the scaffold's body is
   `SafeArea(child: Column(...))`; the class doc says how the insets are claimed and that zero insets change
   nothing. No constant added: the insets come from the frame's MediaQuery, not from this file.
2. `packages/party_host/test/host_frame_screen_safe_area_test.dart` (new, 222 lines) — copies
   `host_frame_screen_test.dart`'s five-device table and `_pumpFrame` helper (as s2 did: `test/support/` is outside
   `allow:`), adds an optional `FakeViewPadding` to the helper, and the three test groups below.
3. `docs/briefs/m16/phonehost1/s2-report.md` — the chip claim and open question 1, as above.
4. `docs/briefs/m16/phonehost1/f2-report.md` — this report.

`packages/party_host/test/host_frame_screen_test.dart` is in `allow:` but unchanged.

## How the insets are applied

`HostFrame` already provides `device.padding / scale` as the frame's MediaQuery padding
(`host_frame.dart:66`). `HostFrameScreen` is the one scaffold every S2+ screen is built on, so the `SafeArea`
sits there, inside `Scaffold.body` (the other host screens claim it the same way, e.g.
`night_start_screen.dart:91`, `best_times_screen.dart:35`):

```
Scaffold(body: SafeArea(child: Column(header, Expanded(body), footer)))
```

`SafeArea` defaults are kept (`minimum: EdgeInsets.zero`, no `maintainBottomViewPadding`), so:

- the column, and with it the 64 px header and 84 px footer, is inset by the frame's padding on all four sides;
- the header and footer keep their 64/84 content heights; the body (the only `Expanded`) gives up the room, so
  nothing overflows and no screen has to know about the insets;
- `SafeArea` removes the claimed padding from its child's MediaQuery, so a screen inside cannot claim it twice;
- with no insets (TV, PC, tablet, a phone in portrait without a cutout) the padding is zero and every rect is
  the one S2's tests assert — which is why those tests needed no change.

## Computed test values (what the new tests assert)

Safe area, device padding 30/20/40/40 (top/bottom/left/right), device px:

| device | s | insets in frame px | header (device) | footer (device) | body (frame px) |
| --- | --- | --- | --- | --- | --- |
| 640x360 | 2/3 | 45 / 30 / 60 / 60 | top 30, left 40, right 600, h 42.667 | bottom 340, h 56 | 840 x 317 |
| 852x393 | 131/180 = .72778 | 41.221374 / 27.480916 / 54.961832 (x2) | top 30, left 40, right 812, h 46.578 | bottom 373, h 61.133 (top 311.867) | 1060.763359 x 323.297710 |

The body's height is `540 - 64 - 84 - topInset - bottomInset` (640x360: 540 - 148 - 75 = 317;
852x393: 540 - 148 - 68.702290 = 323.297710); its width is the frame less the left and right insets
(960 - 120 = 840; 1170.687023 - 109.923664 = 1060.763359).

Zero padding, the same two sizes: header top 0, left 0, right the device width, 64 x s high (42.667 / 46.578);
footer bottom the device height (360 / 393), 84 x s high (56 / 61.133); body 960 x 392 and 1170.687023 x 392.

Chip in the header, zero padding, all five sizes (frame px x s):

| device | header height (device) | `roundChipHeightPx` (device) | chip's top minus header's top | title's left |
| --- | --- | --- | --- | --- |
| 640x360 | 42.667 | 32 | 5.333 | 16 |
| 852x393 | 46.578 | 34.933 | 5.822 | 17.467 |
| 1024x768 | 68.267 | 51.2 | 8.533 | 25.6 |
| 1280x800 | 85.333 | 64 | 10.667 | 32 |
| 1920x1080 | 128 | 96 | 16 | 48 |

i.e. `(64 - roundChipHeightPx) / 2 = 8` frame px above and below the chip at every size, and the title at
`hostFrameGutterPx = 24` frame px from the frame's left. The chip's own layout height is read as
`roundChipHeightPx` (48) too, so the constant cannot drift from the widget unnoticed.

## Decisions

- **`SafeArea` rather than an explicit `Padding`.** It is the idiom the other host screens use, it strips the
  padding from the child's MediaQuery (so nothing claims it twice), and it keeps the file without a new constant.
- **The insets add room outside 64/84; the body gives the room up.** The brief says the heights stay 64/84 for
  the content; the alternative (shrinking the header/footer) would put the chip under the notch.
- **The chip test runs with zero padding.** Its subject is the chip's fit, not the insets; the safe-area tests
  already show the title's offset shifting with the inset, and a zero-padding run pins the S2 rects.
- **The five-device table and `_pumpFrame` are copied, not shared.** `test/support/` is outside `allow:` (the same
  call s2 made and reported); a later slice that needs it a third time should move it.

## Self-check (review-rules part A)

1. **Every host setup** — the widget is the same on every host and the insets come from the frame, not the host
   type: on a TV/PC/tablet they are zero and the rects are exactly S2's (`host_frame_screen_test.dart`, 23 tests,
   unchanged and green), while a notched phone host keeps its header and footer on screen
   ("852x393, a phone in landscape: a notched phone draws the header and footer inside its safe area"). A joined
   phone does not use the frame yet; a phone or host one build older draws the same widget, and nothing on the
   wire changed.
2. **When kept state starts and ends** — nothing is held, timed or counted: `SafeArea` reads the MediaQuery once
   per build, and the tests mount the screen afresh each time ("640x360, a small phone: without a safe area the
   header and footer take the frame's edges").
3. **How a new state combines with the others** — no pause, away, wait or block is added; the only new thing is
   layout room, which combines with nothing ("640x360, a small phone: a notched phone draws the header and footer
   inside its safe area").
4. **Stay in the job's folder** — `git status` shows only the three allowed paths I changed plus this report;
   `run.log` and `tv_test_app/windows/flutter/generated_plugin*` were touched by the tooling, not by me.
5. **Stop rather than overstep** — nothing outside `allow:` was needed; `host_frame.dart` was read only (finding 1
   and the look's `ToyType.frame` wiring are job A's), and the questions below are questions, not changes.

## Questions

1. Should S3/S4's screens stop wrapping their own `SafeArea` once they move onto `HostFrameScreen`? Claiming the
   insets twice on the same edge gives zero room the second time (`SafeArea` strips the padding), so today it is
   harmless, but a screen that keeps its own `SafeArea` inside the scaffold is dead code worth removing when it
   is rewritten.
2. `SafeArea` drops the bottom inset while the keyboard is up (`viewInsets.bottom > 0`). The frame divides
   `viewInsets` too, so a screen that ever shows a text field on a phone host will move its footer up by the
   keyboard — is that wanted for a host screen, or should the scaffold keep the bottom padding fixed to the home
   bar?

## Suggestions

- Move the five-device `_Case`/`_pumpFrame` pair into `test/support/` when a third test file needs it (now three:
  `host_frame_test.dart`, `host_frame_screen_test.dart`, this one).
- Finding 6's other half (a title too long for the room the chip leaves is ellipsised) is still only drawn, not
  tested at a header with a real chip; a one-line test could assert `didExceedMaxLines` for an over-long title.

## Hand-over

Both findings are fixed and covered by tests that failed first. Ready for the next wave: job A (host_frame.dart,
`ToyType.frame`, the scaler) still owns findings 1 and 2, and finding 3's sibling — the frame's look type — is A's,
not this job's. Nothing waits on this report.

## Commit message

```
Claim the safe-area insets once in HostFrameScreen

HostFrameScreen wraps its column in a SafeArea, so a notched phone
host keeps its 64 px header under the cutout and its 84 px footer
above the home bar; the insets add room outside those heights and
the body gives it up. Zero insets leave every rect as before.

Adds host_frame_screen_safe_area_test.dart: the notched and
unnotched rects at 852x393 and 640x360, and the 48 px RoundSegment
inside the 64 px header at the five sizes (REVIEW findings 3, 6).
s2-report.md now names the test that asserts the chip's fit.
```

## Status row

F2 done: HostFrameScreen claims the safe area once (REVIEW 3) and the 48 px chip inside the 64 px header is asserted at five sizes (REVIEW 6); s2-report's claim corrected. Open: host_frame.dart's look type and text scaler (REVIEW 1-2, job A), S3-S6, S8, the phone-app wiring gate.

## Delete

- none
