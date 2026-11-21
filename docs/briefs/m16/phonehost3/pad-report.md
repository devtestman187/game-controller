# M16 phonehost3 pad: the board's pad clearance in the frame

## Summary

- Cause confirmed (wph-report, step 4): `hostPadProvider` answers in device px (rects and `pxPerMm`), and the
  puzzle screen applied that answer to a box that is now frame px. At 852x393 a framed board was asked about
  1349.21x540 device px and received rects drawn 52 px too high and a small fraction of the pad's real size.
- Fix: a new pure helper, `puzzle_pad_scale.dart`, reads `HostFrameInfo.maybeOf`; above a frame it asks the pad
  about the device-sized box (`box x s`), maps each rect back to frame px (`/ s`) and returns `pxPerMm / s`. With no
  frame above (the TV, "Show on this device") it returns the pad's answer unchanged.
- `puzzle_screen.dart` calls it in the existing `LayoutBuilder`; 375 lines (was 372). The new file is 30 lines.
- Tests first: `puzzle_pad_clearance_test.dart` (3) and `pad_clearance_frame_test.dart` (1). The framed pair failed
  before the fix for the bug's reason (the pad was asked for `1349.2082111436948` instead of 852); all four pass now.
- Checks: `format` PASS, `analyze` PASS, `host` PASS (the full `party_host` suite). `phone`: 545 pass, 1 fail
  — `mirror_pad_test.dart` "the host phone's own round gets this phone's pad rects and density, as a joined phone
  does", which pins the old device-px answer and is **outside `allow:`** (question 1).
- Found while checking the numbers: the fix as briefed is still 52 device px too low vertically, because
  `leftPadRects` adds the phone's 52 px bar for a box that now sits below that bar (question 2).

## What changed

- `packages/party_host/lib/src/ui/puzzle_pad_scale.dart` (new, 30 lines): `PadClearance` (the rects and px per mm the
  board keeps clear of) and `padClearanceFor(context, pad, boardBox)`. A frame above means the pad is asked about
  `boardBox * scale` and its rects and density are divided by the scale; no frame means the answer is passed on as
  it is. `Rect` has no `/`, so a private `_frames(rect, scale)` divides the four edges.
- `packages/party_host/lib/src/ui/puzzle_screen.dart`: the `LayoutBuilder` builds `padClearanceFor(context,
  ref.watch(hostPadProvider), box.biggest)` and passes `pad.rects` / `pad.pxPerMm`; the comment says why the pad's
  device measure and the board's frame px are converted.
- `packages/party_host/test/puzzle_pad_clearance_test.dart` (new): a phones round under `HostFrame` with a fake
  `hostPadProvider` returning the pad's real device rects (up and left arms), at 852x393 and 640x360 (the harness
  gets the room the gate leaves, 852x341 and 640x308); plus the same round with no frame, unchanged.
- `controller_app/test/pad_clearance_frame_test.dart` (new): the real gate and the real `hostPadProvider` at
  852x393; the board's rects are the pad's device rects for the 852x341 device box, divided by the scale.
- `controller_app/test/host_frame_wiring_test.dart` (allowed, unchanged): its "Play on this phone" test measures the
  pad the controller draws above the navigator, in device px, so it neither breaks nor gains anything here.

## Computed values

### Before and after at 852x393 (s = 341/540 = 0.63148148, frame 1349.2078 x 540)

The four arms, in the frame px the board is laid out in:

| arm | before (wph-report) | after (device rect / s) |
| --- | --- | --- |
| up | (138.946, 182.646)-(255.006, 353.323) | (205.232, 95.015)-(375.941, 346.012) |
| down | (138.946, 353.323)-(255.006, 524.0) | (205.232, 346.012)-(375.941, 597.009) |
| left | (26.299, 295.323)-(196.976, 411.384) | (39.589, 260.657)-(290.587, 431.367) |
| right | (196.976, 295.323)-(367.653, 411.384) | (290.587, 260.657)-(541.584, 431.367) |

`pxPerMm`: 6.299212598425197 before, 9.975292678 after (= `phonePxPerMm / s`).

The pad's up arm, device px: (129.6, 60.0)-(237.4, 218.5); the after rect starts at frame 95.015, i.e. device
52 + 95.015 x 0.63148 = 112.0 — see question 2.

### Test values

- 852x393: pad asked 852x341 (was 1349.2082111436948 x 540); board rects as the table's after column; pxPerMm
  9.975292678.
- 640x360 (s = 308/540 = 0.57037037, frame 1122.078 x 540): pad asked 640x308; up arm (227.221, 105.195)-
  (416.221, 383.279); pxPerMm 11.0440740.
- No frame (960x540): pad asked 960x540, rects unchanged, pxPerMm 6.299212598425197.
- Under the real gate at 852x393: frame scale 0.63148148, device box 852x341, 4 rects returned, pxPerMm
  9.975292678.

## Questions and suggestions

1. **`mirror_pad_test.dart` now fails and is outside `allow:`.** Its test "the host phone's own round gets this
   phone's pad rects and density, as a joined phone does" expects `view.pxPerMm == phonePxPerMm` and
   `view.padRects == leftPadRects(box)` for the framed round (actual pxPerMm 9.975292677858082). It pins the
   behaviour this job changes. The smallest edit that follows the new rule:
   ```dart
   final s = tester.widget<party.HostFrameInfo>(find.byType(party.HostFrameInfo).first).scale;
   final device = Size(box.width * s, box.height * s);
   Rect frames(Rect r) => Rect.fromLTRB(r.left / s, r.top / s, r.right / s, r.bottom / s);
   expect(view.pxPerMm, phonePxPerMm / s);
   expect(view.padRects, [for (final r in leftPadRects(device, mode: PadMode.dpad, mm: phonePxPerMm)) frames(r)]);
   ```
   Please add the file to `allow:` or approve the edit.
2. **The bar's 52 px are still in the wrong place.** `leftPadRects` subtracts `topBarHeightPx` from its box and
   shifts the arms down by 52 because the board it was written for filled the safe area behind the bar. The box the
   fix hands it (the frame x s) is the room *below* the bar, so the answer comes back 52 device px low: the after
   rect's top is device 112.0 against the pad's arm at 60.0. The brief's rule (divide by s) is what I implemented;
   the board now clears too much above the pad and, more importantly, misses the pad's top 52 px. Options for the
   owner: subtract the bar in the mapping (`(y - topBarHeightPx) / s`) or make the provider's rects frame-relative.
   Which one is right is a design decision, so I did neither.
3. Suggestion: a `Rect` division helper would fit in `game_kit` or a shared place; both the lib helper and the two
   tests carry four lines of it today.
4. Suggestion for the check runner: `phone` is the suite that catches this job's side effects; `host` alone would
   have gone green.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup** — TV and "Show on this device": no frame, panel unchanged (`puzzle_pad_clearance_test`
   "a board with no frame above gets the pad's rects and density as they are"; `puzzle_screen_test` "the TV has no
   pad over the game..."). "Play on this phone": scaled under the frame (`pad_clearance_frame_test` and the two
   framed cases). A joined phone is not changed (`joined_view.dart` untouched); one build older sees no protocol,
   key or route change.
2. **When kept state starts and ends** — nothing is held: `padClearanceFor` is pure, the frame is read with
   `HostFrameInfo.maybeOf` (a dependency, so a resize rebuilds), and no timer, listener or cache is added.
   `pad_clearance_frame_test` disposes its host (`tester.runAsync(host.dispose)`); the party_host tests run a fake
   service and leave no timer.
3. **How a new state combines** — nothing pauses, hides or blocks input; only the rects and density the board is
   given change. A full solo round runs through the gate in `pad_clearance_frame_test` (`soloRound`).
4. **Stay in the job's folder** — four files changed, all in `allow:` (`puzzle_screen.dart`, `puzzle_pad_scale.dart`,
   `puzzle_pad_clearance_test.dart`, `pad_clearance_frame_test.dart`) and this report. Nothing outside it was written.
5. **Stop rather than overstep** — stopped at the `mirror_pad_test.dart` failure (question 1) instead of editing a
   file outside `allow:`, and at the 52 px bar offset (question 2) instead of choosing a design.

## Hand-over

The fix is in and green on `format`, `analyze` and `host`. Before the `phone` suite is green, someone must own the
`mirror_pad_test.dart` pin (question 1); after that, question 2 decides whether the clearance needs the bar removed
as well. Neither is inside this job's files.

## Commit message

```
Scale the host pad's clearances into the host frame

hostPadProvider answers in device px, but a board inside HostFrame draws in
frame px, so a framed round kept clear of the wrong place (M16 phonehost3 pad).
puzzle_pad_scale.dart asks the pad about the device-sized box and divides its
rects and pxPerMm by the frame's scale; with no frame above it passes the
answer on unchanged. Tests cover 852x393, 640x360 and the unframed board, plus
the real gate in the phone app.
```

## Status row

| pad | done: board clearances and px/mm scaled into the frame, tested at 852x393, 640x360 and unframed; open: `mirror_pad_test.dart` pins the old device px (outside allow:) and the 52 px bar offset (question 2) |

## Delete

- none
