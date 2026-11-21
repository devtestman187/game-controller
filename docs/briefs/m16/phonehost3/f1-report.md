# M16 phonehost3 f1: a framed board's pad clearance (review findings 2, 4, 6)

## Summary

- Cause confirmed by a test that failed for the bug's reason: the framed board's
  box is the room below the bar (852x341 device px at 852x393), while
  `leftPadRects` lays the pad out for a whole screen, takes the bar off that box
  again and shifts the rects down by the bar. At 852x393 the board was told its
  Up arm starts 60 device px (95.02 frame px) into the board where it is drawn at
  8 (12.67), and its D-pad was 265 device px against the drawn 317.
- Fix (one file, `host_overrides.dart`): the pad callback now answers in the
  board's own box: `leftPadRects(Size(box.width, box.height + topBarHeightPx))`,
  each rect shifted by `Offset(0, -topBarHeightPx)`. `leftPadRects`, joined
  phones and `padClearanceFor`'s division by the frame scale are unchanged.
- Tests first: new `controller_app/test/pad_clearance_screen_test.dart` (a real
  solo round at 852x393 and 640x360) compares the board's `padRects` with the
  D-pad the screen DRAWS (found by its key, cut by `dpadArms`), moved up by the
  bar and divided by `s`. It failed before the fix at both sizes (852x393: 12.67
  expected, 95.02 actual; 640x360: 76.27 expected, 121.85 actual).
- `pad_clearance_frame_test.dart` and `mirror_pad_test.dart` now expect the same
  truth; neither derives the expected value from `pad.rects` any more, so a wrong
  mapping fails them (the old mapping is 52 device px off at 852x393).
- Finding 6: `puzzle_screen.dart` is 372 lines again (was 375): its two
  device-px/frame-px comment lines moved into `puzzle_pad_scale.dart`'s doc, and
  the pad comment above it lost one line.
- No change to `packages/party_host/test/puzzle_pad_clearance_test.dart`: it
  fakes the pad and its contract (the board's device box, the room below the bar)
  is the one the fix keeps. It still passes.

## Computed values (device px unless said otherwise)

- 852x393: `s = min(852/960, 341/540) = 0.63148148`, board 1349.21x540 frame px.
  Drawn D-pad square (25,60)-(342,377), 317 device px (as drawn; `padLayout`'s
  square of the 852x341 room). In the board's own box: Up arm
  (129.61,8)-(237.39,166.5) = frame (205.25,12.67)-(375.93,263.67); Left arm
  (25,112.61)-(183.5,220.39) = frame (39.59,178.33)-(290.59,349.01).
  Before the fix: Up arm top 60 device px (95.02 frame), D-pad 265 device px.
- 640x360: `s = min(640/960, 308/540) = 0.57037037`, board 1122.1x540 frame px.
  Drawn D-pad square (24,43.5)-(237,256.5), 213 device px. In the board's own
  box: Up arm (94.29,43.5)-(166.71,150) = frame (165.31,76.27)-(292.28,262.99).
  Before the fix: Up arm top 69.5 device px (121.85 frame): 26 device px too low,
  not 52, because the pad was laid out in the smaller room and its square
  centred higher. The D-pad's size at this size was already 213.
- The measured D-pad matches `host_frame_wiring_test.dart:96`'s recorded
  (25,60,342,377) at 852x393, which pins the "as drawn" figures.

## Self-check (review-rules part A, 1-5)

1. Every host setup: the TV/PC host and "Show on this device" pass no rects
   (unchanged); a joined phone keeps `leftPadRects`' whole-screen contract
   (`mirror_pad_test`'s joined-phone group); "Play on this phone" is the fix
   (`pad_clearance_screen_test` at both sizes, `pad_clearance_frame_test`); an
   older build sees no protocol change.
2. Kept state: nothing is held, timed or cached here; the rects are computed on
   each read from the mode and stick settings (`host_overrides.dart:72-79`).
3. New state combinations: none added; no pause, card or phase reads this
   (`pad_clearance_screen_test` runs a round from "Get ready" into play).
4. Stay in the folder: only the eight files in `allow:` were written; `git
   status` shows no other file of mine.
5. Stop rather than overstep: no file outside `allow:` was needed and the brief
   matched the code; the only ambiguity (2 lines moved still left 373 > 372) was
   settled by condensing the pad comment.

## Hand-over

- Findings 2, 4 and 6 are done, and finding 1 with them: `mirror_pad_test.dart`'s
  working-tree edit is re-pinned to the corrected mapping in this job's files, so
  committing this diff also commits that edit (its rule is kept: the host's own
  round gets this phone's pad rects and density).
- Still open from the run's review, not mine: finding 3 (arena footer 480 budget),
  findings 5, 9-15 (shared button width, night/teams items), and the device check
  of the 52 px mapping.
- Suggestion (not done): if a later job gives `HostPad.rects` a box contract in
  a doc test, say explicitly "the box is the board's own box, below the bar";
  `_hostPadRects`' doc has the reason today.

## Commit message

Fix the framed board's pad clearance, 52 device px too low

A board under HostFrame keeps clear of a pad that is not where it is
drawn: the phone's pad answer is laid out for a whole screen, so
leftPadRects took the bar off the room below the bar again and shifted
the arms down by it (Up arm at 60 device px where it is drawn at 8, and
a 265 px D-pad against the drawn 317 at 852x393). The pad override now
answers in the board's own box. The pad tests compare with the D-pad the
screen draws, not with the pad's own answer, and mirror_pad_test's
uncommitted fix is re-pinned to the corrected mapping.

## Status row

| M16 phonehost3 f1 | done: a framed board keeps clear of the pad's drawn arms at 852x393 and 640x360, pad tests expect the drawn layout, puzzle_screen.dart 372 lines; open: the arena footer budget, shared measured button width, the night/teams items, a device check |

## Delete

- none
