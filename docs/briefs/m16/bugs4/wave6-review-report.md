# M16 bugs4 wave 6 review: np2 (read-only)

## Summary

- Verdict: **small fixes**
- Counts: 2 must, 3 should, 2 could
- must: the tie test at `controller_app/test/result_card_night_test.dart:228` asserts a tied-phone case it never runs (it uses player 3, who is not tied).
- must: three new tests (lines 246, 259, 270) pass on the code as it was before np2, which the review rules count as a must.
- should: no fail-first evidence for the card tests. The file cannot compile against the old code, so no behaviour failure was ever seen (report Question 3 says so).

## Findings

- **must** controller_app/test/result_card_night_test.dart:228 The test is named "…and the tied phone says 'You won the night!'", but it runs player 3 (Sam, line 235, not tied) and asserts only `nightWinner('Mia and Dad')`; the tied-phone branch at result_night.dart:111 is never exercised, and report computed value (c) claims a check that does not exist → add a case with player 1 (Mia, tied) expecting `PhoneText.youWonNight`, or rename the test to what it checks.
- **must** controller_app/test/result_card_night_test.dart:246 Tests (d) "not the last round changes nothing" (246), "before any result shows no card" (259) and the size/palette test (270, which asserts only no exception and the card and waiting line in the screen) all pass on the code before np2, so under the review rules they are musts; (270) is the one the brief wants to fail on old code → keep (d) and the no-result test as guards and say so in the report, and make (270) also assert `resultAward-fast` and `resultNightWinner` inside the screen, which fail on old code.
- **should** controller_app/test/result_card_night_test.dart:175 No run showed the new tests failing for their behaviour: the file references `PhoneText.awardsHeading`, `awardNotWon` and `awardLine`, which do not exist before np2, so the whole file fails to compile on the old code (report Question 3; run.log:103-106 has only "result 4" for np2) → run the new card tests once against the pre-lib code and record which fail and why.
- **should** controller_app/lib/src/ui/result_night.dart:141 `maxLines: 1, overflow: TextOverflow.ellipsis` on the award line: with several winners joined by " and " the "(+3)" points can be cut off, and the report does not list this as a decision → let the award line wrap (no `maxLines`) or cut names rather than points, list the choice, and test a long winners list at 568x320.
- **should** controller_app/lib/src/ui/result_night.dart:27 Review rule A3 asks for the pairs that can co-occur with the night's end (pause menu, host away, player away, "Get ready", dropped link, leaving); the report says only "not tested" and gives no combination table → add the table to the report with "not tested" per pair, and test "dropped link clears the night's end" if np1 does not already cover it.
- **could** controller_app/lib/src/ui/result_night.dart:41 A message with no awards and no standings makes `night != null`, so "Awards coming…" disappears and nothing replaces it → treat an empty message as no message (`end.awards.isNotEmpty || end.standings.isNotEmpty`), or state the behaviour in the report.
- **could** controller_app/lib/src/ui/result_night.dart:136 All unmatched winner IDs collapse into "Not won tonight", so a protocol mismatch looks like a real unclaimed award; the report lists this as a decision but not as a risk → keep it, but mention in the report that a mismatch is silent.

## Decisions to confirm

- Tie with this phone's player among the top: "You won the night!" (result_night.dart:111) drops the co-winners' names; the brief asked for it, but owner should confirm (report Question 1).
- Award line punctuation `'$name: $winners (+$points)'` (phone_text.dart:233): the brief named parts only; confirm the format.
- Unmatched winner IDs are dropped silently (result_night.dart:136): hides a bad message as "Not won tonight".
- Heading and standings blocks show only when non-empty (result_night.dart:79, 85).
- Award-line truncation with an ellipsis (result_night.dart:141) is made but not listed in the report's decisions.
- Own-winner check uses the player number (result_night.dart:111), as the existing own-row bold does.

## Could not check

- The `tools/mine.sh` and `flutter test` results in np2-report.md: run.log records only "result 4 (38 turns)" for np2 (run.log:103), no test output. I ran no tests (read-only job).
- Rendered widths at 568x320, 667x375 and 852x393: text truncation and fit were not rendered.
- A peer one build older (review rule A1): np2 adds no message; the `night_end` message is np1's, and I did not check how an older phone handles it.
- run-findings.md does not exist, so no "passes on the old code" entries to check.
- Docs: only np2-report.md was touched; `Awards coming` appears in briefs only, no product doc states the card's behaviour.

## Commit message

wave6 review: np2 findings (read-only)

Review of np2 (the joined phone's night's end card) against the coding
guidelines, review rules and brief. Report only; no code changed.
Two musts: the tied-phone test at result_card_night_test.dart:228 does not
run the tied player, and tests at lines 246, 259 and 270 pass on the old code.
Open: fail-first evidence for the card tests, award-line truncation,
review rule A3 combinations.

## Status row

wave6 review: np2 reviewed, verdict small fixes (2 must, 3 should, 2 could). Open: fix the tie test (result_card_night_test.dart:228), strengthen the size test, record fail-first runs, decide award-line truncation and the tie wording.

## Delete

- none
