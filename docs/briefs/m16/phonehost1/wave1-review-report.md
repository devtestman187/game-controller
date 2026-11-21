# Wave 1 review (S1, S9a) — findings only

## Summary

Verdict: **small fixes**.

0 must, 2 should, 4 could. I ran `packages/party_host/test/host_frame_test.dart` (16 pass),
`packages/toy_look/test/toy_type_test.dart` (7 pass) and `packages/puzzle_game/test/tablet_board_png_test.dart`
(1 pass, `git status docs/design` empty after it); `dart format` reports those four files unchanged. Both jobs
did what their briefs asked, stayed in `allow:` and made the tests they were told to make.

- `_frameMedia` keeps the device's `textScaler`, so a phone host with a large system font grows every frame text
  while the layout stays 960x540: the first screen S2 builds to the 20 px floor overflows.
- The new doc comment in `tablet_board_png_test.dart:16` claims a guard "the other picture tests use"; no other
  picture test has it (the S9a report itself says so) — the next worker will copy a pattern that isn't there.
- At a zero device size `HostFrame` divides by a zero scale: `frame` becomes NaN and `SizedBox` asserts.

## Findings

- **should** packages/party_host/lib/src/ui/host_frame.dart:63 `_frameMedia` copies the device's `textScaler` into the frame, so an accessibility font scale on the phone host enlarges all frame text inside a fixed 960x540 layout and screens sized to the 20 px floor overflow, while the brief's "every device draws the same layout" no longer holds → pin `textScaler: TextScaler.noScaling` in `_frameMedia` (or state in its doc comment why the device's scale is kept, as a decision).
- **should** packages/puzzle_game/test/tablet_board_png_test.dart:16 the doc comment says "the same guard the other picture tests use", which is false: no other picture test in `packages/` has an `UPDATE_PNG` guard (the worker's own report says so), only the `PHONE_FIT` tests have that pattern → say "the guard `party_host`'s `PHONE_FIT` tests use" or drop the parenthetical.
- **could** packages/party_host/lib/src/ui/host_frame.dart:43 a device size of zero (a desktop window minimised, before the first layout) makes `scale` 0 and `frame` NaN, and the `SizedBox` at :48 then asserts on a non-finite size → return `const SizedBox.shrink()` when `size.isEmpty` before computing the scale.
- **could** packages/party_host/test/host_frame_test.dart:242 this focus test only asserts that the focus node changes, which a pass-through builder also does, so it tells nothing about the transform at s = 2 → also assert the moved button's painted rect is its frame rect times 2 (`tester.getRect`), which fails if the frame's scale is wrong.
- **could** packages/puzzle_game/test/tablet_board_png_test.dart:96 the write branch is never executed by any run, so "writes when asked" is untested and a broken path or flag spelling would only show on the day someone refreshes the PNG → exercise it once with `UPDATE_PNG` set against a temp path, or add a one-line note that the branch is manual-only.
- **could** packages/party_host/test/host_frame_test.dart:151 `_ignore` declares `_Seen seen` and never uses it, which the guidelines' leftovers rule rules out → `void _ignore(_Seen _) {}`.

## Decisions to confirm

- `ToyType.frameSmall` is a static beside `ToyType.frame` (packages/toy_look/lib/src/toy_type.dart:156) while DESIGN section 5 writes "small 20" as part of the frame set; S2 must remember the pairing, and a `small` field on the set would make it impossible to forget — the brief allowed either, so this is the owner's call.
- `_frameMedia` divides `padding`/`viewPadding`/`viewInsets` by `s` (host_frame.dart:66), which the brief did not ask for; it changes what every `SafeArea` does the moment the frame is wired, so it is worth one line in the design note.
- The phone-app wiring the report describes (s1-report.md:47-55) would scale the controller's pad screens too, since one `MaterialApp` draws both; a gate provider or a nested app is a design choice, not a one-line wiring.
- `ThumbySlot`'s `ValueKey` over the spot (host_frame.dart:169) invents M17's reset behaviour now; harmless today, but M17 should be told it exists.
- The ring is 4 frame px, so 8 device px at s = 2 (s1-report.md:62), while DESIGN section 5 says "focus ring size ... unaffected"; one of the two has to change, and S2 should own it.

## Could not check

- `tools/review.sh` and the full `host` suite: not run, so the report's "0 fail" and the one-off `live_stats_share_test` flake are unverified.
- The `UPDATE_PNG=1` write branch of the tablet-board test: not run (it writes outside this job's `allow:`).
- `HostFocusRing` drawing inside the frame: never run anywhere; the worker says so in its report and I did not add a check.
- A real Windows/desktop minimise (the zero-size case above): reasoned from the code, not reproduced.
- Whether a system font scale on a real phone actually overflows S2's screens: no device, and the screens do not exist yet.

## Commit message

Add the wave1 review of S1's host frame and S9a's PNG guard

- S1 and S9a meet their briefs and stay in `allow:`; only findings, no code change.
- Two shoulds: the frame keeps the device's text scale, and a new doc
  comment claims a picture-test guard that no other picture test has.
- Four coulds: zero-size NaN, a focus test a pass-through builder would
  also pass, an untested write branch, one unused parameter.
- Decisions for the owner: `frameSmall` beside the frame set, scaled
  insets, the phone-app wiring gate, the Thumby key and the ring on the TV.

## Status row

Wave 1 reviewed: S1 (HostFrame/HostFrameInfo/ThumbySlot/hostFrameBuilder, ToyType.frame + frameSmall, unwired) and S9a (tablet-board PNG guarded by UPDATE_PNG) are done and pass their tests; open — 2 shoulds and 4 coulds from this review, the phone-app wiring gate (S1b/S2), S2's screens and S9's phone_fit matrix.

## Delete

- none
