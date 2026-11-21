# b033 — every award "i" popover is the same size (B-033)

## Summary

The award's "i" popover (`_AwardExplanation` in `award_tile.dart`) is now one fixed box, 480 x 207 frame px, for
all twelve awards at all five frame sizes, instead of a card that grew to the width of its own line. The test
`award_explanation_size_test.dart` opens every `NightAward`'s "i" at 640x360, 852x393, 1024x768, 1280x800 and
1920x1080, and checks the box is the same width and height for all twelve, that the title, the line and the OK
button sit inside it, that no text is under 20 frame px, and that nothing overflows.

Measured box size per frame size (frame px, all twelve awards equal):

| device | frame | box |
| --- | --- | --- |
| 640x360, a small phone | 960x540 | 480.0 x 207.0 |
| 852x393, a phone in landscape | 1170.687x540 | 480.0 x 207.0 |
| 1024x768, a tablet | 960x720 | 480.0 x 207.0 |
| 1280x800, a laptop | 960x600 | 480.0 x 207.0 |
| 1920x1080, the TV | 960x540 | 480.0 x 207.0 |

- Old code, measured by the same test at 640x360: heights were already 207.0 for every award, but widths ran from
  177.6 (Big Bopper) to 369.4 (Try Again), so the box was as wide as its line. The test therefore fails on the old
  code's width, not its height; "each popover has the height of its own line" does not show, because every line
  fits one line at the card's intrinsic width. At 480 the content width is 432, still one line for all.
- 207 is the tallest card the old code laid out: header band, 24 px padding twice, one 22 px line, the 24 px gap
  and the 48 px OK button; it is now `awardExplanationHeightPx`. No frame cap was needed (207 is 333 px short of
  the shortest frame, 540); `scrollBody: true` is the safety net for a longer line one day.
- Only `award_tile.dart` changed in `lib/`: `ConstrainedBox(maxWidth:)` became `SizedBox(width:, height:)`, the new
  constant, and a `scrollBody: true` on the card. The tile row, the reveal cards and the award texts are untouched.
- Test counts: the new file has 5 tests (one per frame size, 12 awards each), all passing. Run together with the
  four tests the brief names (`night_start_frame_test`, `night_start_noscroll_test`, `night_screens_test`,
  `night_awards_test`): 74 tests, all passing. `tools/check.sh host` (the whole package) passed.

### Decisions

- **A constant height (207) rather than a runtime text measurement.** Every line fits one line at the fixed width,
  so the tallest content is the same for all twelve and a measured constant is exact; it also keeps the build free
  of `TextPainter` work in a dialog. The test holds it to the rule (same height for all, content inside).
- **Width fixed to the existing `awardExplanationWidthPx` (480)** rather than a new value: "width as now".
- **No frame-height cap.** The cap applies only when the longest line needs more than the frame at 640x360; it does
  not (207 in 540). If it ever does, `scrollBody` lets the body scroll while the box stays equal, and the test's
  "OK button inside the box" check would flag it.
- **The test mounts one award tile alone instead of the night start screen**, so all twelve awards are checked; a
  seed only draws three. It uses `pumpHost(framed: true)`, the same frame builder both host apps install.

### Self-check (review-rules.md part A, items 1–5)

1. **Every host setup.** One dialog in the shared frame, so TV/PC, "Play on this phone" and "Show on this device"
   draw the same box; tested at all five device sizes by `award_explanation_size_test.dart`. A joined phone and an
   older build see no protocol or host-state change: not affected.
2. **Kept state.** The box is kept state only while open: it starts on the "i" tap and ends on OK, Escape or a tap
   outside; no timer or cache (`night_start_frame_test.dart`, the "i" opens its explanation test).
3. **How it combines.** The explanation is a dialog route over the night start; it touches no pause, away, "Get
   ready", results or leaving state, and the route behaved the same before, only the box size changed: not
   affected (`night_start_frame_test.dart`).
4. **Stay in the folder.** Only `docs/briefs/m16/bugs1/b033-report.md`, `packages/party_host/lib/src/ui/award_tile.dart`
   and the new `packages/party_host/test/award_explanation_size_test.dart` were written.
5. **Stop rather than overstep.** Nothing needed outside `allow:`; the brief's cap path was not needed and is
   reported above rather than coded.

## Hand-over

`tools/check.sh format analyze host` passes; `tools/review.sh` reports 0 fail, 0 note. The test file, run from
`packages/party_host` (the look fonts are read relative to the package), passes. Running it from the repository
root fails in `setUpAll` because of that font path — the same as the package's other frame tests.

## Commit message

B-033: one size for every award's "i" explanation box

The award explanation was a card as wide as its own line (177.6 to 369.4 frame px), so the popover changed shape
from award to award. It is now a fixed 480 x 207 frame px box for all twelve awards: SizedBox replaces the
max-width constraint, the height is a documented constant (header, paddings, one line, gap, OK button), and the
card body scrolls only if a future line needs more. New award_explanation_size_test opens every award's "i" at
the five frame sizes and checks equal width and height, the text and OK inside, a 20 px type floor and no
overflow.

## Status row

M16 bugs1 B-033: done — every award's "i" popover is the same 480 x 207 frame px box at all five frame sizes, with
a test over all twelve awards; open: nothing.

Fixed by f1: the TV look's popover is 223 px (the 159 px fixed part plus the look's 64 px OK button), so its OK
button is wholly inside the box there too; `award_explanation_tv_test.dart` checks all twelve awards at the five
frame sizes.

## Delete

- none
