# n8c report: coach marks overlay

## Files
- `controller_app/lib/src/home/coach_marks.dart` (new): `CoachStep`, `CoachMarks`. Dimmed scrim with a rounded hole (evenOdd path), hint box (ToyCard, ink text) with an up/down arrow, Skip button.
- `controller_app/test/coach_marks_test.dart` (new): 17 tests.

## Behaviour
- The anchor rect is read after layout (post-frame) and converted to the widget's own coordinates. It is re-read on every build; a rotation or text-scale change rebuilds through `MediaQuery.sizeOf` and `LayoutBuilder`.
- A step whose anchor has no render box is skipped. If none is left, `onDone` is called once. `onDone` and `onSkip` are guarded to run once in total.
- The box goes below the hole, or above it when below has no room. It is clamped inside a 16 dp screen margin and is at most 360 dp wide.
- Skip and the box's minimum height are `max(48, look button height)` (48 menu, 64 TV). Text is never scaled down.
- With no room on either side (568x320 TV look), the box overlaps the hole's edge and the arrow is dropped. The arrow lay on the text and took its taps; found by the test.

## Test values
- 568x320 TV look, step 2: box Rect(156.8, 169, 411.3, 304), text rect (172.8, 185, 395.3, 216). Box height 135 against 124 dp of room below and 76 dp above, so the arrow is dropped.
- 568x320 TV look, step 1: box Rect(16, 68, 248.3, 203).
- Hole padding 8 dp, scrim alpha 0.6, arrow 24x12 dp (chosen, not derived).

## Tests-first
The test file is new and exercises a new type, so it could not fail on older code. It was written together with the widget.

## Questions / suggestions
1. In the TV look at 568x320 the box covers the bottom of the lit anchor for the middle step. Fine for Home's anchors, which sit near the top; say if you want Skip beside the text to save height.
2. A tap on the scrim advances, as the brief says. An accidental tap outside the box therefore also advances.

## Commit message
coach_marks: pure CoachMarks overlay widget with CoachStep

New CoachMarks widget: dimmed screen with a hole at the current anchor,
a hint box with an arrow (below the anchor, or above it), tap to advance,
Skip. A step with no render box is skipped. Skip and the tap area are at
least 48 dp. Tested at four phone sizes and 1.3x text in the menu and TV
looks.

## Status row
n8c: CoachMarks/CoachStep overlay widget done and tested (menu + TV looks, 4 sizes, 1.3x); not yet wired into Home (saved flag, routing and consent are open).

## Delete
- none
