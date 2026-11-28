# Review of wave 3 (glow1 f1): pinning the golden glow's two handovers

Reviewed commit 5a38c50c (`git diff c9bcb46f..5a38c50c`): 3 files, 185 insertions, 0 deletions. No lib file changed, as f1 required.
Read: f1.md, f1-report.md, golden_match_snapshot_test.dart, golden_match_painter_test.dart, review-rules.md, coding-guidelines.md, match.dart:320-340, match_painter.dart:125-152 and 236-245, golden_slot_test.dart:1-60, golden_glow_paint_test.dart:1-80, support/match_helpers.dart:34-96, golden_slot.dart:37, puzzle.dart:19, split_layout.dart:250-260. `run-findings.md` does not exist, so there are no run findings to check.

## Summary

verdict: small fixes
counts: must 0 · should 3 · could 2
1. `golden_match_painter_test.dart:88-91`: the "repaints when only its golden differs" test is decided by the `identical(old.s, s)` check alone, so it would stay green with golden removed from the handover.
2. `golden_match_painter_test.dart:49-62, 68-86`: the pixel tests compare whole half-frames, not target 0's slot, so a glow drawn on the wrong target still passes (the brief asked for the slot's pixels).
3. `f1-report.md:34`: the report has no review-rules part A self-check lines.

## Findings

- **should** packages/puzzle_game/test/golden_match_painter_test.dart:88 The test named "repaints when only its snapshot's golden slot differs" compares two new `MatchSnapshot` objects, and `MatchPainter.shouldRepaint` (match_painter.dart:236-237) returns true on `!identical(old.s, s)` before it reads anything else, so the assertion holds even if golden never reaches the painter → rename the test to what it checks (a new snapshot repaints) and drop the golden claim, or state in its reason that golden is not what is tested.
- **should** packages/puzzle_game/test/golden_match_painter_test.dart:49 `differsInHalf` compares whole half-frames of the board area, so a glow drawn on any other target in that half (say target 3 instead of 0) passes both pixel tests at :68-86 → compute target 0's rectangle in the frame from `SplitLayout.leftBox`/`rightBox` and the 4 px-per-field-unit scale (`box.width / fieldSize.width`, puzzle.dart:19), and compare only that rectangle; this stays inside the allowed file.
- **should** docs/briefs/m17/glow1/f1-report.md:34 The report has no part A self-check (host setups, kept state, combination with pause/away/Get ready/drop/results/leave, folder, stop, looks), which guidelines §11 requires; the job is test-only, so each line can say "not affected" with its test → add one line per part A item under a `## Self-check` heading.
- **could** packages/puzzle_game/test/golden_match_painter_test.dart:16-45 `emptyMatch`, `paint` and `window` repeat `emptyBoard`, `paint` and `box` in golden_glow_paint_test.dart:12-39, and the snapshot test repeats `race()` from golden_slot_test.dart:16-20 → move the shared builders into a `test/support` file in a job whose allow list includes it; not needed for this job.
- **could** packages/puzzle_game/test/golden_match_painter_test.dart:12 The comment on `window` ("4 px a field unit") describes a scale the file never uses; the number is right (640/160 = 4) → drop the scale part of the comment, or use the scale in the fix above.

## Decisions to confirm

- Half-frame pixel check instead of the target's slot rectangle (f1-report.md:24-28): this is weaker than brief item 2, and the worker did not widen `allow:`. Claude should decide whether the fix above goes in as a follow-up job.
- The `shouldRepaint` case (f1-report.md:29-31): the worker's own note says golden only matters through `identical`; the test name still claims more. Claude should decide whether to keep the case as a plain "new snapshot repaints" check.
- No change to the lib: the brief's "tests-first: exempt" holds, since the lib already passes the golden to the painter (match_painter.dart:148, golden: s.golden) and the snapshot (match.dart:338).

## Could not check

- The `tools/mine.sh` result (f1-report.md:13: 6 tests OK). I did not run tests or analysis; the pass/fail claim is the worker's.
- That the left board's box lies within x 0..319 and the right within x 320..639 at 640 x 360 (split_layout.dart:256). I did not compute the layout, so "left half" and "right half" are assumed to match the boards.
- The glow on the other looks (only `sunny` is used in the painter test); not a rule breach for a glow with no sized widget, but untested.
- Values I checked by reading (not run): `begin` steps once at 0.016 s before `drive` (support/match_helpers.dart:43), so the frame times are 190 × 0.05 + 0.016 = 9.516 s and 210 × 0.05 + 0.016 = 10.516 s. Both sit either side of `GoldenSlot.firstDelayS` = 10.0 s (golden_slot.dart:37). The worker's "10.5 s" and "9.5 s" are the rounded values.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs(m17): wave 3 review of glow1 f1 (findings only)

Reviews the f1 tests (commit 5a38c50c) against the rules and the brief.
Finds no must. Three should: a shouldRepaint test that cannot fail on
golden, pixel checks on whole half-frames rather than target 0's slot,
and no part A self-check in f1-report.md. No code or test changed here.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

glow1 wave 3 review of f1: done, 0 must / 3 should / 2 could. Open: rewrite the shouldRepaint test to check what it names; pin the painter tests to target 0's slot rectangle; add the part A self-check to f1-report.md.

## Delete

- none
