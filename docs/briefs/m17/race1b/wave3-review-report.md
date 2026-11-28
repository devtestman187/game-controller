## Summary

Verdict: small fixes
Counts: must 2, should 6, could 2
1. present_wiring_test.dart:91: the "no present draws none" test compares two identical frames, so it cannot fail, and it passes on the old code.
2. present_match_test.dart:54: the "no present on Off, Wild, one board" test passes on the old code, since no present existed there.
3. match_painter.dart:193: the phone path draws the present with no test at any phone size.

## Findings

- **must** packages/puzzle_game/test/present_wiring_test.dart:91 The test "a frame with no present draws none" calls `changed(..., null)`, so both frames come from `frame(puzzle)` with no present; it asserts 0 whatever is drawn, and it passes on the old code → delete it (the two held-by tests already compare with a no-present frame).
- **must** packages/puzzle_game/test/present_match_test.dart:54 The test "no present on Off, on Wild, or on one board" passes on the old code (no present was ever set, so null everywhere) and can never show a present that should not be there → add a positive in the same test (a present is out on Little with Lively at the same time) so it fails on the old code.
- **should** docs/briefs/m17/race1b/r3c-report.md:21 Self-check 1 says host setups are "covered by present_match_test", but that file drives PuzzleMatch only; no host setup (TV or PC host, phone modes, joined phone, older peer) is tested → say host setups are "not tested" here, or add the host-level test.
- **should** docs/briefs/m17/race1b/r3c-report.md:23 Self-check 3 says pause, host away and dropped link were "not touched", but the present is a new timed state, and rule A3 asks for each pair to be named and tested (pause menu, host away, Get ready, dropped link, results, leaving); only results is named → list each pair as "not tested" with its reason, or test it.
- **should** packages/puzzle_game/lib/src/match_painter.dart:193 The phone path passes `present: s.present` and no test covers it (f1-report.md:24 says so); rule A1 covers phone host setups → add a phone-size case to present_wiring_test.dart.
- **should** packages/puzzle_game/test/present_wiring_test.dart:14 The wiring test runs one window size (640x360, `box`) and one look (`sunny`, :63 and :74) → add the night look and a phone-size window (rule A6).
- **should** packages/puzzle_game/lib/src/match.dart:172 The job grew match.dart from 309 to 328 lines, past the brief's 14-line cap; the worker kept the growth and said so (r3c-report.md:30) → Claude to accept it, or ask for the trim.
- **should** docs/PRD-v2.md:764 The PRD still says "On Party a placed piece it knocks loose…", but the code now knocks on Wild only; the job touched no PRD → update that line in a docs job (owner Q4), or record it as a known gap.
- **could** packages/puzzle_game/test/present_match_test.dart:43 The test name says "on Little and Party, Calm and Lively", but the loop pairs Little with Lively and Party with Calm → rename it to state the pairs, or split the loop.
- **could** packages/puzzle_game/test/present_wiring_test.dart:22 The `for (var i ...)` loop uses the index only as a count, and `i` is never read in the body → build the piece list from a named count.

## Decisions to confirm

- Wild-only knock (owner Q4, cat_chaos.dart:281): Calm and Lively now have no knock, and the PRD (PRD-v2.md:764) still says Party. Confirm the PRD should follow in a docs job.
- match.dart:172-185: the 19-line growth past the 14-line cap was kept by the worker. Confirm it is accepted.
- puzzle_painter.dart:156: `side: s.side ?? PuzzleSide.left` draws a holder-less board as the left board. No present reaches such a board today (one-board matches never hold one), but the fallback is not in the report. Confirm, or make the no-side case explicit.
- cat_review_test.dart: the expected starts moved from 3 to 4 on Wild (a 2 minute round). cat_tuning_test shows the same 4-visit plan for Wild. Confirm Wild's plan is meant to differ from Lively's.
- view.dart's single-board PuzzleView passes no present (per the f1 brief). Confirm; the match screens are the only ones that show it.
- match.dart:227-230: the snap loop has no `_result == null` gate, unlike the lines below it. It is harmless only if `end()` clears the holder (see Could not check).

## Could not check

- present_rules.dart:109-126 was not read in full: whether `end()` clears the holder, so that a snap after the result does nothing (onSnap returns early when holder is null, present_rules.dart:75).
- Pause, host away and dropped link (rule A3): whether the host stops calling `PuzzleMatch.update` during a pause. The present's clock depends on that, and the call sites are outside this diff.
- Per-test "fails on the old code": run.log:48-49 records the two new files as failing on the old code at file level only. I did not run the tests (this job is read-only), and I did not check each test on the old code.
- Rules: I read the worker extract, the headings and rules B1-B9 and A1-A6 from docs/review-rules.md, and not the full docs/coding-guidelines.md text.
- Function length of PuzzlePainter.paint (puzzle_painter.dart) was not measured. match.dart update() is about 27 lines (match.dart:208-234), within the limit.
- r3c's "Calm knock at 40.858 s on the base" and f1's pixel-count claims were not re-run; the r3c report gives no pixel counts for f1.
