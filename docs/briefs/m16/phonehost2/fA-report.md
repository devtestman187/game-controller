# fA report — the score card takes the stage width

## Summary

The must finding is fixed: `_Scoreboard` gave `_ScoreCard` to an `Align` with a loose width, so `ToyCard`'s
`IntrinsicWidth` sized the card to a row (~380–430 of the 912 px stage). The card is now given the body's width
with `LayoutBuilder` + `SizedBox(width: constraints.maxWidth)`, as the reveal does, under the same top-centre
`Align`; the confetti branch is untouched. Nothing else in `lib/` changed.

Tests first: the new `night_scoreboard_card_test.dart` has 20 tests (5 sizes × 4 and 6 players × between rounds and
final scores). On the old code all 20 failed at the card width; after the fix all 20 pass. The frame test and the
robo test still pass, and `tools/check.sh format analyze host` passes (after one `dart format` of the new file).

The two frame-test coulds (its five-device loop draws the final scores only at 640x360; the delta test never reads
the `+n` size) are covered by the new file at every size, so the frame test itself is left unchanged — see Q1.

Measured card and bar widths, new code (p1's bar, frame px):

| device | frame width | card width | bar, between rounds | bar, final scores |
| --- | --- | --- | --- | --- |
| 640x360 | 960 | 912.0 | 444.6 | 490.05 |
| 852x393 | 1170.6870229007634 | 1122.6870229007634 | 655.287029004279 | 700.7370259525212 |
| 1024x768 | 960 | 912.0 | 444.6 | 490.05 |
| 1280x800 | 960 | 912.0 | 444.6 | 490.05 |
| 1920x1080 | 960 | 912.0 | 444.6 | 490.05 |

Card width = frame width − 2 × `hostFrameGutterPx` (24): 960 − 48 = 912; 1170.6870229007634 − 48 =
1122.6870229007634. Every bar is over the brief's 300 px at 960; the test asserts the 300 px line only at a 960 px
stage and asserts the card width at all five. The final scores keep the winner's 68 px row, the others' 52 px, and
the one-button footer (Back to games) on screen and hit-testable at every size. The `+n` text's `fontSize` is
`ToyType.frameSmall.fontSize` = 20.0.

## Questions

1. The two frame-test coulds (its five-device loop draws the final scores only at 640x360; the delta test never
   reads the `+n` size) are now covered by the new file at every size, so `night_scoreboard_frame_test.dart` is
   unchanged and its loop still pumps `rounds: 1`. Should a later job tighten that loop (or drop it as duplicated),
   or is the new file enough?
2. REVIEW's fix job A also grouped the bare-places could at `_medalOf` (`1`/`2`/`3`, and `row.place == 1`), but the
   brief's title and `do:` name only the must and the two coulds, so it is unchanged. Confirm it belongs elsewhere.

## Self-check

Review-rules part A, one line each with the test that shows it:

1. Every host setup: the card is drawn from the frame's body box, not the device, so the TV, a PC, a phone host on either role and a joined phone all get the same 912 (or 1170.687) px card; no host-type code was touched — `night_scoreboard_card_test`, five devices.
2. Kept state: nothing held, timed or cached was added; the card is a pure build from `night.rows(players)` — `night_scoreboard_card_test` between rounds and on the final scores.
3. Combining states: no new state; the away dim, Robo's full row, the crown, the confetti and the last-round banner draw as before — `night_scoreboard_frame_test` (leaver/Robo, final scores, banner).
4. Stay in the job's folder: only `night_scoreboard_widgets.dart`, the new `night_scoreboard_card_test.dart` and this report changed.
5. Stop rather than overstep: nothing was needed outside `allow:`; no contradiction was found in the brief.

## Hand-over

- The must is fixed and measured in tests; a pixel/device look at the wider card (REVIEW said the fix needs one) was
  not possible here (no app or device run).
- The frame test still pumps `rounds: 1` in its five-device loop and its delta test still asserts only the `+n`
  text; the new file covers both rules at all five sizes, so they can be tightened or left as duplication.
- The bare-places could at `_medalOf` (1/2/3) is unchanged: the brief's title and `do:` list only the must and the
  two coulds.

## Commit message

Give the night score card the stage width and test it at five sizes

_Scoreboard wrapped the card in an Align with a loose width, so ToyCard's IntrinsicWidth sized it to a row.
It now gets the body's width via LayoutBuilder + SizedBox, top-aligned, confetti unchanged.
New night_scoreboard_card_test: 20 tests over 5 sizes, 4 and 6 players, between rounds and final scores.
It asserts card = frame − 2 × hostFrameGutterPx (912; 1122.687 at 852x393), a bar over 300 px at 960,
the winner's 68 px row, the one-button footer on screen at each size, and the "+n" at ToyType.frameSmall (20).
Old code failed all 20 at the card width; host suite, analyze and format pass.

## Status row

fA done: the score card fills the stage at all five sizes, with the "+n" style and final-scores coverage in a new test file; open: the frame test's five-device loop still draws the final scores only at 640x360 (now duplicated by the new file), and the bare-places could in `_medalOf`.

## Delete

- none
