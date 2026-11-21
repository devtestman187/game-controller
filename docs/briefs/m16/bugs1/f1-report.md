# M16 bugs1 f1 — the award popover height follows the look's button height

## Summary

**Fixed.** The height is now `awardExplanationFixedPx` (159 = 207 − 48) plus `look.sizes.buttonHeight`, read
at build time: 207 in the menu look, 223 in the TV look, so the TV's OK button is wholly inside the box.
`scrollBody: true` stays as a guard.

Test counts: `award_explanation_tv_test.dart` 5 (one per device, each over all 12 awards) +
`award_explanation_size_test.dart` 5 → 10 passed together; `night_start_frame_test.dart` +
`night_screens_test.dart` → 43 passed; `tools/check.sh format analyze host` → PASS (format needed one pass on
the new file after writing, then clean). Tests first: the new file failed on the old code at all five devices
with `maxScrollExtent` 16.0 and the OK button 16 px below the card.

Decisions:

1. `awardExplanationHeightPx` kept its name and became a function of the look; the fixed part is the new const
   `awardExplanationFixedPx` (one number, not a computation). Both are exported for a screen that asks.
2. Each test file pins its look's height as its own literal (`207.0`, `223.0`), not via the lib function, so a
   wrong constant fails a test instead of agreeing with it.
3. "No scrolling needed" is checked two ways in both files: the guard scroll's `maxScrollExtent` is 0, and the
   OK button's rect lies inside the card's rect.
4. The new file duplicates the existing file's small scaffolding (device cases, tile, `_expectInside`) rather
   than moving it into `test/support/`: one file per look, no shared helper changed for one job.
5. `scrollBody: true` kept, as the brief says; the tests prove it is a guard that never moves.

## Computed values

- Fixed part: 207 − 48 = **159** px (header band, 24 px padding above and below the body, one line of 22 px
  text, the 24 px gap; the header's ink line is painted inside its box, so the 3 vs 4 px outline adds nothing).
- TV height: 159 + 64 = **223** px; menu height: 159 + 48 = **207** px. 223 leaves 540 − 223 = 317 px of the
  frame's height to spare, so no award scrolls at any of the five devices.
- Old code's scroll: `maxScrollExtent` **16.0** at 640x360, 852x393, 1024x768, 1280x800 and 1920x1080
  (measured by the test, not arithmetic).

## Self-check (review-rules part A)

1. Host setups: the TV look is the new test; the menu look (phone host, PC, "Play on this phone") is the old
   test; "Show on this device" and a joined phone draw no popover (the pad), so not affected —
   `award_explanation_tv_test.dart`, `award_explanation_size_test.dart`.
2. Kept state: none added; the popover starts on the "i" and ends on OK, a tap outside or Escape, and both tests
   tap OK and expect the card gone — `award_explanation_size_test.dart:148`.
3. Combining with other states: the popover is a dialog over the night start card and owns no pause, timer or
   input; pause, away players and the results cannot coexist with it (it closes before the night moves on) —
   `night_start_frame_test.dart:240-257`.
4. Stayed in the job's folder: only `award_tile.dart`, the two test files, `b033-report.md` and this report.
5. Stopped rather than overstepped: nothing needed outside `allow:`.

## Hand-over

`tools/check.sh format analyze host` passes; `tools/review.sh` reports 0 fail, 0 note. `award_tile.dart` is 164
lines. `b033-report.md`'s status row gained one line naming this fix; nothing else there was rewritten. The
review's other shoulds (the live-stats order flake, the stale night start comment, the mixed wave commits) are
other jobs' and are untouched.

## Commit message

M16 bugs1 f1: the award popover height follows the look's button

The 207 px explanation height was measured with the menu look's 48 px OK button, but the TV look gives every
button 64 px: the same card needs 223 px, and the OK button sat 16 px below the box behind the guard scroll.
The height is now the 159 px fixed part plus `look.sizes.buttonHeight`, read at build time (207 menu, 223 TV).
The existing size test pins the menu look's 207 and no scrolling; the new `award_explanation_tv_test.dart`
opens every award's popover in the TV look at the five frame sizes and checks one equal box, the title, line
and OK button inside it, and a guard scroll that never moves.

## Status row

M16 bugs1 f1: done — the award popover is 159 px plus the look's button (207 on a menu, 223 on the TV), tested in both looks over all twelve awards; open: the review's other shoulds (the live-stats order flake, the stale night start comment, the mixed wave commits).

## Delete

- none
