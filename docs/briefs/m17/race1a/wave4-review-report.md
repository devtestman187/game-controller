# wave4 review of f2 (race1a): report

## Summary

Verdict: needs Claude
Counts: must 1, should 3, could 1
1. must: the new screen test passes on the old code (run.log:105); only the brief's exemption allows it.
2. should: the report has no self-check (review-rules part A) at all.
3. should: the Easy screen test does not assert that players 1 and 2 are seated.

## Findings

- **must** packages/party_host/test/join_cap_screen_test.dart:48 The rule "a new test that passes on the old code is a must" applies: run.log:105 records the file passing on the old code, and the brief exempted it from tests-first. The worker's cap-replaced-by-2 run (f2-report.md:16) fails only the Medium test; Easy (line 66) and default (line 76) pass with that mutation by design, so only one of three tests is shown to fail without the change → Claude decides: accept the exemption with that mutation evidence written to run-findings.md, or ask for a test that fails on the base.
- **should** packages/party_host/test/join_cap_screen_test.dart:71 The Easy test checks only P3 left and P4 right; P1 and P2 are never asserted seated, so a screen that drops players 1 and 2 still passes → assert P1 on left and P2 on right (the four-seat count the deleted test pinned).
- **should** docs/briefs/m17/race1a/f2-report.md:1 The report has no self-check lines (review-rules A1 to A6; guidelines §11 asks for one line each with its test, "not affected" allowed) → add A1 to A6, one line each, with the test or "not affected".
- **should** docs/briefs/m17/race1a/f2-report.md:1 The report has no Summary block in its first 40 lines, as run-findings.md:4 records → add a Summary block at the top.
- **could** packages/party_host/test/join_cap_screen_test.dart:81 The default test checks P1 left and P4 right only; P2 and P3 are not asserted → assert P2 on right and P3 on left.

Checked and true: the join_cap_test.dart deletions leave `_fill` and `_count` in use (lines 7, 17); `maxPerSideFor(Level.easy, 4)` = 2 and `(Level.medium, 4)` = 4 still asserted at per_side_rule_test.dart:6 and :22; the Medium placement (odd left, even right, P9 refused) follows sideForNewPlayer (join_screen.dart:74-81, a tie goes left); a right player pressing left while left is full is refused (join_screen.dart:246-247); the test file and the changed lines are under 120 columns; `PuzzleChoice(level:)` is the constructor used (puzzle_choice.dart:5).

## Decisions to confirm

- The screen test exemption (see the must above). The brief allowed it because the wiring works on the base; the review rule does not allow an exemption by itself.
- Brief item 1 asks that "a fifth press of the same side key does not move the player". No test does that. The Medium test checks a right-side player pressing left while left is full (line 59), which is the worker's Question 1. Confirm that this is the check you wanted.
- The deleted tests asserted fill counts of 4 and 8. The Medium test covers 8 only through P8 on the right (line 57). The Easy fill count of 4 is not counted (see the should above). Confirm whether a count is wanted.

## Could not check

- Test results: I did not run the tests. The runner's evidence in run.log covers the exemption (line 105) but not the pass or fail of each test; the worker's `tools/mine.sh` pass and the cap-replaced-by-2 run are not in run.log, so they are unconfirmed.
- Display names "P8 Phone 8", "P2 Phone 2" and "P1 iPhone 3F1C" in the new test: the phoneInfo helper was not located, so I could not trace how the names are built.
- The per_side_rule_test.dart test names still say "wanted" (worker suggestion). Not read line by line; not a finding.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

No commit: this is a read-only review. No code or document was changed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

race1a wave4 review of f2 done: 1 must (screen test passes on the old code; exemption for Claude to decide), 3 should, 1 could. Open: Claude's call on the exemption; P1/P2 and P2/P3 seat assertions; f2 self-check and Summary block.

## Delete

- none
