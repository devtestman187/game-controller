## Summary

Verdict: **small fixes**. Counts: must 0, should 3, could 4.

Top three:
1. The test named "measures the first race puzzle, one labelled line each" asserts nothing, so it cannot fail.
2. The proposed rule says the strip sits left of Start; it sits right of Start (strip x 686 and 512, Start x 482 and 337).
3. The rule's "about 61 px floor height" is not printed by the test, so the number has no output behind it.

Checked and correct: the floor formula matches camera.dart:248; the strip (tray right + mirrorGapPx 8) matches the table; the Start rect is last in stick mode (joined_view.dart:69-75); the report's gap and overlap values recompute from its own table.

## Findings

- **should** controller_app/test/mirror_proof_test.dart:139 The first test per box has no `expect`, so no output can fail it; it only prints → add `expect` for the pad and right rects inside the box and for `mirror == null || mirror.rect` inside the box, as the second test does.
- **should** docs/briefs/m16/m165/b3-report.md:39 "a strip mirror sits left of Start's x range" is wrong: the strip is x 686–956 and 512–667, Start is x 482–548 and 337–393, so the strip is right of Start → say "right of Start's x range; it does not meet Start".
- **should** docs/briefs/m16/m165/b3-report.md:36 "about 61 px floor height" is not printed by mirror_proof_test.dart (lines 123–127 print the width only) → print the board's floor height in the test (board height × floorScale) and quote the printed value (derived by hand: 308.2 / 4.972 × 0.990 ≈ 61.4).
- **could** controller_app/test/mirror_proof_test.dart:105 `right.last` as Start relies on list order (joined_view.dart:71-75); a reorder silently moves the measurement → add `expect(right, hasLength(3))` before it, or match the rect by its size.
- **could** controller_app/test/mirror_proof_test.dart:81 `measure()` runs about 51 lines, above the ~40-line guideline → move the `stdout.writeln` block (lines 110–130) into a named helper.
- **could** controller_app/test/mirror_proof_test.dart:148 the pad and right rects do not depend on the puzzle, but the loop recomputes them for each of the 18 puzzles → hoist lines 148–149 above the loop.
- **could** controller_app/test/mirror_proof_test.dart:23 `loadPuzzles` and `raceText` are copies of mirror_pad_test.dart:29-43; `raceText` repeats the HUD string 'You 0/$n · Right 0/$n', which drifts if the game's text changes → share them in test/support (suggestion, not a violation; the brief said copy).

## Decisions to confirm

- Start/Pause is the last rect of `rightPadRects` (list order), not "the one nearest the top right" as the brief says; the nearest one is the face buttons (706.5,118.6). Disclosed in the report and in the test comment at line 103-104; it depends on list order.
- The strip's free height is measured from the box's top edge, not below `topBarHeightPx` (rightPadRects shifts by that bar at joined_view.dart:61-63). If the top bar is game area, the 118.6 px and 108.0 px figures overstate the room. Disclosed as the report's question 1.
- The Start/board overlap (gap 0.0 px in both boxes) is accepted as the B-044 design; the proposed rule keeps it.

## Could not check

- I did not run `flutter test`, `mine.sh` or `dart analyze`; the printed numbers and the counts "14 of 18", "3 of 18", "18 of 18" are not re-derived from a run. Only the formulas and the table's own arithmetic were checked by hand.
- The 4-test pass claim and the "no new lint" claim come from the worker; not re-checked.
- run-findings.md has no entries for b3 (grep for b3, B-042 and "passes on the old" found none), so no run evidence exists for the test.
- Checked against the worker extract of the guidelines and review rules, not the full docs/coding-guidelines.md and docs/review-rules.md.
- Whether the strip's "under the floor" fallback works as the rule says was checked only by reading camera.dart:236-285, not by a run.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m165 review: wave 5 (b3) B-042 proof test reviewed

Read-only review of b3 (mirror_proof_test.dart, b3-report.md) against the guidelines and its brief.
Three should findings: the first test asserts nothing; the report puts the strip left of Start
(it is right of it); the report's floor height is not printed by the test. Fixes are not made here.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

wave5 b3 review: done (wave5-review-report.md, verdict small fixes: 3 should, 4 could); open: fix the 3 should findings in b3, and the owner's choice of Start rect (list order vs nearest top right).

## Delete

- none
