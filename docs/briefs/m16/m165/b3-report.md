## Summary

- Changed: `controller_app/test/mirror_proof_test.dart` (new). It measures the top-right strip for the first
  puzzle in the index (`house`) at 956x440 and 667x375, in sticks + D-pad mode with fixed sticks, and checks
  across all 18 puzzles that the pad and right-hand rects lie inside the box. No lib change.
- Tests: `tools/mine.sh` OK, 4 tests pass (format, analyze, test). `flutter test test/mirror_proof_test.dart`
  run once more to read the printed lines (mine.sh hides stdout): All tests passed.
- Decision: "Start/Pause" is the last rect `rightPadRects` returns in stick mode (face buttons, right stick,
  Start). The brief's "nearest the top right" picks the face-buttons square instead, so I used the list order.
- Decision: the strip's free height is measured from the box's top edge down to the first right-hand rect in
  the strip's x range. The top bar is not subtracted (question 1).
- Decision: the test asserts only the rects inside the box and that `mirrorPlace` returns; the numbers are printed.

### Measured (`house`, the first puzzle; all values px unless marked mm)

| Box | Tray right | Board on screen | Pad rects (left) | Right-hand rects | Mirror (current) |
|---|---|---|---|---|---|
| 956x440 | 678.0 | 328.8,121.8 298.3x308.2 | 16.0,118.6 184.1x184.1 · 290.0,310.7 42.6x62.6 · 290.0,373.4 42.6x62.6 · 248.7,352.1 62.6x42.6 · 311.3,352.1 62.6x42.6 | 706.5,118.6 233.5x233.5 (face buttons) · 582.0,288.7 147.3x147.3 (right stick) · 482.0,198.0 66.0x40.0 (Start) | 208.1,145.3 77.2x79.8, scale 1.287, hud 8.0,61.6 183.9x75.7 two lines |
| 667x375 | 504.0 | 206.4,103.8 254.2x262.7 | 16.0,108.0 151.3x151.3 · 196.7,267.3 35.3x51.8 · 196.7,319.2 35.3x51.8 · 162.5,301.5 51.8x35.3 · 214.3,301.5 51.8x35.3 | 496.1,108.0 154.9x154.9 (face buttons) · 400.8,250.0 121.0x121.0 (right stick) · 337.5,173.8 55.3x40.0 (Start) | null |

| Box | Strip (x; width px = mm) | Strip height above right rects | Floor: smallest piece | Mirror width at floor | Start overlaps board, gap |
|---|---|---|---|---|---|
| 956x440 | 686.0..956.0; 270.0 = 42.9 mm | 118.6 | 14.0 units, drawn 69.6 px at scale 4.972 | 59.4 px = 9.4 mm; strip fits: yes | yes, 0.0 px |
| 667x375 | 512.0..667.0; 155.0 = 24.6 mm | 108.0 | 14.0 units, drawn 59.3 px at scale 4.237 | 59.4 px = 9.4 mm; strip fits: yes | yes, 0.0 px |

All puzzles: 956x440 mirror placed (current code) 14 of 18, strip width ≥ floor 18 of 18; 667x375 mirror placed
3 of 18, strip width ≥ floor 18 of 18. Floor scale 0.99 px per unit at the smallest piece of 14 units.
Mirror max scale = world scale × mirrorFraction (0.259): 1.287 at 956x440.

### Proposed fit rule for a top-right mirror (5 lines)

1. Try the top-right strip first: x from the tray's right edge + `mirrorGapPx` to the box's right edge, y from 0 down to
   the top of the first right-hand rect in that x range minus `mirrorGapPx`.
2. Take the largest scale up to `mirrorFraction` that fits that strip; it must clear the tray, the board's top, and
   the face buttons. At the floor, the numbers fit both boxes for `house` (strip 270 and 155 px wide vs. 59.4 px
   floor width; 118.6 and 108.0 px tall vs. about 61 px floor height).
3. If the strip is under the floor in width or height, do not place it there; fall back to today's `mirrorPlace`
   (top-left corner, then the gap under the clock). The current code path stays unchanged.
4. Start/Pause: a strip mirror sits left of Start's x range in both boxes (Start is at x 482–548 and 337–393, and
   the strip starts at 686 and 512), so it needs no room from Start. Start overlaps the board in both boxes by
   design (B-044 lets the board and mirror meet right-hand controls); the rule must not change that.
5. Left open: whether the strip may use the top bar's band (question 1) and whether the mirror's clock area sits
   beside it or under it (the current `hudPlace` rules).

## Self-check (review-rules part A)

1. Host setups: measurement only; both boxes are the phone's landscape boxes in sticks + D-pad mode. Tested by
   "measures the first race puzzle" (956x440 and 667x375). Not run on a TV or PC host.
2. Kept state: none; the test builds its layout and draws nothing. Test: both tests create no state.
3. Combinations with pause, host away, "Get ready", links, results: not measured. Not applicable to a measurement.
4. Folder and allow: two files only (the new test and this report); no other file was edited by this job.
5. Stop: none needed.
6. Looks: no look changed; the numbers are for the menu and TV boxes the brief names.

## Hand-over

- `tests-first: exempt measurement test: it pins numbers that already hold on the base` (from the brief). The test
  passes on the base code because it only measures.
- Question 1: the strip height is measured from the box's top edge. `topBarHeightPx` is not subtracted, so the
  real free height may be smaller if the top bar is not game area. Which is it?
- Question 2: the proof uses one puzzle for the detailed lines (`house`) and counts across all 18. Other puzzles
  have other smallest pieces; say if the owner wants a per-puzzle table.
- Question 3: the brief asked for `flutter test` to print the lines. I ran it once directly after `tools/mine.sh`
  (which hides stdout) for the numbers only; `tools/mine.sh` was the check.
- Question 4: Start is overlapped by the board in both boxes (gap 0.0 px). This is the current design, not a bug,
  per the B-044 comment; please confirm it stays.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m165 b3: measure the mirror's top-right strip against the floor (B-042)

Adds mirror_proof_test.dart, which prints the numbers the owner needs for a mirror at the top
right: the tray's right edge, the left and right-hand pad rects, the current mirror placement,
the strip width and height against the 2.2 mm piece floor, and the Start rect against the board.
Measurement only; no lib change. Numbers for `house` at 956x440 and 667x375 are in the report.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

B-042 numbers: done (controller_app/test/mirror_proof_test.dart, measured at 956x440 and 667x375; strip fits the floor in both); open: the owner's fit rule, whether the strip may use the top bar, and Start/board overlap confirmed.

## Delete

- none
