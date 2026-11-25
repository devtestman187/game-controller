# c4 report: pad top bar overflow at 568x320 in the TV look

## Summary

Owner question, no file changed. At 568x320 in the TV look the pad top bar row overflows by 12 px (controller_top_bar.dart:89). Options in the Options section: A narrower segment padding, B scroll or overflow menu, C declare unsupported and keep the test exception. The test exception stays.

Status: stopped, owner question. No file changed (the test is back as it was).

## Measurement
- With the knownTopBarOverflow exception removed, `connect_narrow_test` "568x320 in the TV look" fails:
  `A RenderFlex overflowed by 12 pixels on the right`, the Row at controller_top_bar.dart:89 (`_ControllerTopBar`).
- That Row: constraints 0<=w<=548 (568 - 12 - 8 (left 12, right 8)), height 48.
- Non-flexible children: SizedBox 8 + BarModes + Settings 48 + Diagnostics 48 = 560, so BarModes is about 456 dp wide.
  The Expanded chip/ping part already gets 0 dp, so it cannot give up more room. (Inferred from the 12 px; I
  did not print the child widths.)
- At 568 the `compact` branch of `_ModePicker` (width < 680) has already dropped the mode icons.

## Why nothing changed
Every fix I see breaks the brief's stop rule:
1. Remove the 8 dp gap: recovers 8, still 4 dp short, and the chip is already 0 dp wide.
2. Smaller segment padding or text in `_ModePicker` below ~600 dp: changes the look's sizes and the drawn
   segments at 568 (the 667 case is left alone only with a new width threshold, a new magic number).
3. Shrinking the 48 dp buttons, hiding a control or dropping a label: forbidden.

## Options for the owner
A. Accept a narrower segment padding for bars under a named width (about 600 dp) in the TV look.
B. Let the pad bar scroll horizontally, or wrap Settings/Diagnostics into one overflow menu under that width.
C. Declare 568x320 in the TV look unsupported and keep the test exception (the state today).
Note: even after any fix the connection chip has 0 dp at 568, so the bar has no visible connection chip there.

## Questions
1. Which option, A, B or C?

## Commit message
c4: report the 568x320 TV-look top bar overflow as an owner question

No code changed. The pad's top bar overflows 12 px at 568x320 in the TV look
because BarModes (about 456 dp) plus the gap and two 48 dp buttons need 560 of
548 dp, with the chip already at 0 dp. Every fix shrinks a target, hides a
control or changes a look's sizes. Measurement and options are in the report.

## Status row
c4: not fixed, stopped as an owner question (12 px at 568x320 TV look; BarModes needs 456 dp, chip already 0 dp); open: pick option A, B or C.

## Delete
- none
