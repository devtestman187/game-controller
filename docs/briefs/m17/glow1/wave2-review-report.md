# glow1 wave 2 review: job g2 (commit d3889601, feat(glow1): pulse the golden slot's glow on an empty target)

## Summary

Verdict: **small fixes**
Counts: must 0 · should 2 · could 2
1. No test would fail if the golden wiring were removed: `match_painter.dart:148`, `:199` and `match_view.dart:219` are untested.
2. The brief asked for a doc line on each new constant; `slot_paint.dart:21-27` has one block for four.
3. Self-check 3 says "not tested" where the code answers it: results clear the glow at `golden_slot.dart:71`.
4. The brief's 0 vs 600 ms pulse check cannot differ on a 1200 ms sine; the worker tested 0 vs 300 ms instead (see Decisions).

## Findings

- **should** packages/puzzle_game/lib/src/match_painter.dart:148 The golden wiring (`golden: s.golden` here and at `:199`, plus `match_view.dart:219`) has no test: the four tests in `golden_glow_paint_test.dart` build `PuzzlePainter` directly, so deleting any of the three lines leaves all green → add a test that builds `MatchPainter` from a split snapshot with `golden` set and checks target 0 glows on both boards.
- **should** packages/puzzle_game/lib/src/slot_paint.dart:21 The brief asked for "constants named at the top of the file with a doc line each", but `_goldenGlowPx`, `_goldenGlowMinAlpha`, `_goldenGlowMaxAlpha` and `_goldenPulseMs` share one block comment (lines 21-23) → give the alpha bounds and the pulse period their own `///` line each, saying why.
- **could** docs/briefs/m17/glow1/g2-report.md:24 Self-check 3 says "not tested" for the results state, but `golden_slot.dart:71` clears the slot when `enabled` is false, which is the case once a result is in → write "cleared at results by golden_slot.dart:71; pause and Get ready not checked".
- **could** packages/puzzle_game/test/golden_glow_paint_test.dart:36 Every test paints the Sunny look only (`look: sunny`), and the glow colour is the look's `star` → add one test that paints the same board in Night, or state the gap in the report.

## Decisions to confirm

- Pulse test: the brief's 0 vs 600 ms check is impossible with `sin` over 1200 ms (alpha 0.55 at 0 ms, 0.75 at 300 ms, 0.55 at 600 ms, which I recomputed from `slot_paint.dart:40-43`). The worker changed the test to 0 vs 300 ms instead of stopping. Accept it and correct the brief's wording.
- Placement: the glow is drawn after Easy's tint and the ready fill, not directly after the recess as the brief said (`slot_paint.dart:58-65`). It sits above the tint; confirm that is the look wanted.
- Split screen: both boards glow the same target index, as `golden_slot.dart:29` describes. Confirm this is intended.
- Test 2 uses the farthest target, not target 1, because the neighbour's blur moved target 0 by 0.00059 in L (worker's figure). Exact-equality checks will break if the blur radius grows; accept or loosen.
- `puzzle_painter.dart` is 378 of 380 lines, within the limit; the next change to it must split it first.
- Tests-first: the new file "fails on the old code" only as a compile error (no `golden` parameter; `run.log:44`). That is the exemption the brief allows; no behaviour test was seen failing on the base.

## Could not check

- `tools/mine.sh` results (`OK 16 tests`, format, analyze): not run (read-only job). `run.log` has no test count.
- `pieceMean` and `capture` in `test/support/` were not read, so "target 0's piece area" (test) and "the slot centre" (brief) are not confirmed to be the same region.
- Night look contrast of the star glow, and what `nowMs` does during pause, Get ready and a dropped link: not read or run.
- `docs/briefs/m17/glow1/run-findings.md` does not exist; the only runner evidence is `run.log`.

## Commit message — a draft

review(glow1): review of wave 2 job g2 (golden glow)

Read-only review of d3889601 against the g2 brief, the coding guidelines and the
review rules. Findings are in wave2-review-report.md; no code changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

glow1 wave 2 review of g2 (d3889601): small fixes, 2 should and 2 could; open: golden wiring has no test, slot_paint.dart constants lack their own doc lines, self-check 3 and the Night look not covered.

## Delete

- none
