# n8c report: coach marks overlay

## Files
- `controller_app/lib/src/home/coach_marks.dart` (new): `CoachStep`, `CoachMarks`. Dimmed scrim with a rounded hole (evenOdd path), hint box (ToyCard, ink text) with an up/down arrow, Skip button.
- `controller_app/test/coach_marks_test.dart` (new): 17 tests at n8c; 22 after the f1 fixes (see `f1-report.md`).

## Behaviour
- The anchor rect is read after layout (post-frame) and converted to the widget's own coordinates. It is re-read after each build of the overlay and on each layout change of the overlay (the `LayoutBuilder` builder schedules the read; f1). An anchor that moves while `CoachMarks` is not rebuilt is **not** re-read: that case is open (f1-report.md).
- A rotation or text-scale change rebuilds through `MediaQuery.sizeOf` and the layout change.
- A step whose anchor has no render box is skipped. If none is left, `onDone` is called once. `onDone` and `onSkip` are guarded to run once in total.
- The box goes below the hole, or above it when below has no room. It is clamped inside a 16 dp screen margin and is at most 360 dp wide.
- Skip and the box's minimum height are `max(48, look button height)` (48 menu, 64 TV). Text is never scaled down.
- With no room on either side (568x320 TV look), the box overlaps the hole's edge and the arrow is dropped. The arrow lay on the text and took its taps; found by the test.

## Test values
- 568x320 TV look, step 2: box Rect(156.8, 169, 411.3, 304), text rect (172.8, 185, 395.3, 216). Box height 135 against 100 dp of room below and 100 dp above, so the arrow is dropped. Room below = 320 − 16 − 192 − 12 = 100; room above = 128 − 16 − 12 = 100; the hole is 128–192 dp (anchor 136–184 inflated by 8, coach_marks.dart:149).
- 568x320 TV look, step 1: box Rect(16, 68, 248.3, 203).
- Hole padding 8 dp, scrim alpha 0.6, arrow 24x12 dp (chosen, not derived).

## Tests-first
**Not done for n8c.** The test file was written together with the widget, so the tests were not seen to fail before the code existed, and the claim that the file "could not fail on older code" is not a check. The f1 job added tests (a) to (d); the brief marked them exempt (they pin behaviour that was already correct). On the base code (a), (b), (c) and the first (d) test passed; the Skip test was first written with a wrong finder and fixed before the lib change, so its pass is measured only with item 1 applied (item 1 does not touch the once-only guard). The one re-read test (anchor moved by the host) was run on the base code and failed (box top 68, expected 108), as the brief expected; after the f1 layout re-read it still fails. See `f1-report.md`.

## Part A self-check (docs/review-rules.md, items 1-6)
1. Host setups: not applicable. `CoachMarks` is not wired into any host (n8c stop; it is still unwired). Test: `pumpMarks` mounts it on a plain `Scaffold` host in every group.
2. Kept state: `_index`, `_anchor` and `_isFinished` start at mount (0, null, false) and end at unmount; with no step that has an anchor, `onDone` is called once. Tests: "marks with no step that has an anchor call onDone once"; "unmounting the marks before the anchor is read calls neither onDone nor onSkip" (f1).
3. Combination with pause menu, host away, player away, "Get ready", dropped link, results, leaving: not applicable; the overlay has none of these states and is not wired. No test.
4. Stays in folder and inside allow: only `coach_marks.dart`, `coach_marks_test.dart` and the two reports changed (`git status`).
5. Stop rather than overstep: the anchor that moves while the marks are not rebuilt is not re-read. The LayoutBuilder re-read does not cover it, and the fix needs a design choice (a per-frame read, or a listener on the anchor's render box). Stopped and reported in f1-report.md; no test for it is committed. Test: the failing run is recorded in f1-report.md.
6. Every look: the menu look and the TV look, both in every group: "at 568x320 in the TV look every step keeps the box inside and Skip 48x48" and the 320x640 / 375x667 / 640x360 variants, plus the 1.3x text scale tests. The box has no fixed pixel height: its minimum height is `max(48, look button height)`.

## Check results
- `flash-n8c.log` is not in this worktree, so the n8c format and analyze results cannot be cited here; they are not verified in this job.
- For the f1 changes, `tools/mine.sh` on `controller_app`: format ok (2 files formatted by the script), `dart analyze` no findings, 22 tests OK.

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
