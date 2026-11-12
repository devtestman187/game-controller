# Review of c1-big-cat (read-only)

## Summary

`small fixes` — 1 must, 6 should, 3 could.
- A paw is left floating: in `leave` its tip returns to a shoulder fixed under the head's *rest* place while the head slides
  out of the board, so the last ~0.5 s of every visit draws a paw on the board with no head (`cat_pose.dart:51`).
- The swat is not tested: the paint test compares pixels only inside the head's box, so the paw and the burst could draw
  nothing and it would pass — while the report says "the head and the burst change pixels".
- The design doc still describes the old cat: `docs/design/party-night.md:69` and `:211` say the warning shows "a paw at the
  edge", and no test covers the `phones` world the phone host actually draws though self-check 1 says one does.
- Also: no test for the new reduced-motion path; the head can hide the piece it warns about; the self-check's pause claim.

## Findings

- **must** packages/puzzle_game/lib/src/cat_pose.dart:51 in `leave` the tip lerps back to `shoulder` (line 46), which is the head's rest place and does not move, while the head's peek falls to 0 by 60 % of the state and the clip hides it above `field.board.top`, so every visit ends with ~0.5 s of a paw drawn on the board's top band with no head → make the paw's return follow the peeked head (add the peek offset to the shoulder, or draw no paw once the head's bottom is above the board's top edge).
- **should** packages/puzzle_game/test/cat_swat_test.dart:130 the paint test counts changed pixels only inside `head` (x 46–66, y 13–31.4 on the one board, the same box in the warning and the bat frame), so `paintCatPaw` and `paintCatSwat` could draw nothing and the test would still pass, and the report's "the head and the burst change pixels in Sunny and in Night" is not what it checks → also count changed pixels in a box round `pose.aim`, where the paw and the burst are.
- **should** docs/design/party-night.md:69 §5 still says the warning is "a paw at the edge of that side", which the new drawing no longer does (only the head is drawn in the warning, `cat_pose.dart:48`), and line 211 repeats "the cat's warning (paw, shadow)" → rewrite both to the head-and-paw visit in the same commit (`docs/design` is in `allow:`).
- **should** packages/puzzle_game/test/cat_peek_test.dart:82 the split-screen case builds `SplitLayout.of(puzzle, 1)`, whose default target is `LayoutTarget.screen` (`split_layout.dart:128`), so no test covers the `phones` world (tray above the board, cropped board) that the phone host draws and the owner tests on, though self-check 1 says the tests cover `LayoutTarget.phones` → add a phones-target case for the head's size, place and clamp, or correct the self-check.
- **should** packages/puzzle_game/lib/src/cat_paint.dart:41 the new reduced-motion branch (head at rest, no paw, no burst, and nothing during the leave) has no test — the two effects-off cases are the old warning and leave checks (`cat_paint_test.dart:81`, `:87`), neither of which says what is *not* drawn — so a regression there would pass the suite → add a widget test that a walk or bat frame with `effects: false` differs from the plain frame only inside the head's box.
- **should** packages/puzzle_game/lib/src/cat_pose.dart:38 the head hangs wholly from the board's top edge (bottom at y 31.4, a quarter of the board's height) and is drawn after the pieces (`cat_paint.dart:50`), so a target piece in that band is hidden, shadow and all, for the whole visit (~4.3 s of warning, walk, bat and the head's leave) → keep the head's bottom above `aim.dy`, or record that covering a high piece is intended before the device test.
- **should** packages/puzzle_game/lib/src/view.dart:164 the self-check's "a pause stops the clock … nothing catches up" is false: `_clock` is a `Stopwatch` started at the widget and never stopped (`PuzzlePlayView` passes no clock, `play_view.dart:174`), so after a pause `CatMoments.progress` (`cat_moments.dart:35`) jumps by the pause's length and the slide-in and the reach are skipped → reword the self-check, or reset `CatMoments` when the pause ends.
- **could** packages/puzzle_game/lib/src/cat_head.dart:49 the pupil is drawn at the full `pose.gaze` (1.2 units) and with its radius (1.0) reaches 2.2 against an eye of radius 2.0, so it pokes 0.2 units past the white at the strongest gaze → clamp the gaze to `_eyeRadiusShare - _catPupilShare * _eyeRadiusShare` and tighten `cat_peek_test.dart:119` to the eye's radius.
- **could** packages/puzzle_game/test/cat_paint_test.dart:76 the test still says "draws its paw and its shadow in the warning", but the warning pose has no tip (`cat_pose.dart:48`) and at the share 0 a fresh `MatchView`'s `CatMoments` gives, the head is hidden too, so it now only sees the shadow → rename it to what it checks.
- **could** docs/briefs/m14/bugs1/c1-big-cat-report.md:16 the Summary says "7 in `packages/puzzle_game/lib`", but 11 files changed there (its own list names 10 and leaves out `cat_view.dart`, where `CatRules.spanMs` was added) → correct the count and add `cat_view`.

## Decisions to confirm

- Decision 1 / Question 1: the head sits wholly inside the board area, not over its top edge; the owner asked for it "poking out from the top of the screen", so the rest position is what to look at on the TV, and it is also why finding 6 (a covered piece) can happen.
- Decision 2: exactly a quarter of the board area's width (20 units) and 0.92 of that tall — the owner said "quite small", so confirm the size on a phone host as well as a TV.
- Decision 9: reduced motion drops the burst as well as the stretch; the brief's item 3 only asks to drop the stretch animation, so the burst's removal is the worker's call.
- Decision 6: `CatPose` and `CatMoments` are exported from the package's main library so the tests can reach them — a public surface given to test helpers; fine, but it is permanent.
- Decision 7: the paw and the burst are not clipped to the board, so they draw over the sky between the board and the tray; intended for tray pieces, worth seeing on a phone.

## Could not check

- That each new test fails on the code as it was (read-only job, no second checkout): `cat_peek_test` and `cat_swat_test` use `CatPose`/`CatMoments`, which did not exist before.
- The look on a real phone, TV and mirror (no device); the mirror draws the cat (`mirror_painter.dart:100`) but no test asserts that its size reads.
- `cat_pictures_test` itself (it rewrites `docs/design`, outside this job's allow list); the four committed PNGs are 640 × 360 (read from their headers) and show the head and the mid-swat in both looks.

## Commit message

```
Review: c1 big cat, findings only

Read-only review of 415dd0e against the coding guidelines, the review
rules and the brief. The head, the paw, the burst and the four pictures
match the brief and the suites pass; the findings are in the report: the
paw is drawn on the board with no head at the end of the leave, the
swat's pixels are never tested although the report says they are,
party-night.md still describes the warning's paw at the edge, and no test
covers the phones layout or the reduced-motion path.
```

## Status row

`c1 big cat: reviewed (small fixes) — big head-and-paw cat for sunny and night, split screen, the mirror and reduced motion, four pictures saved, rules and snapshot bytes unchanged (cat_peek 6, cat_swat 3, cat_paint 2 tests pass; analyse and format clean); open: the leave's floating paw (must), a test for the swat's pixels, the phones layout and the reduced-motion path, the party-night.md §5 wording, and whether the head may cover its target piece.`

## Delete

- none
