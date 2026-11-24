# Review of wave 2 (b040win): report

## Summary

Verdict: small fixes. Counts: 2 must, 2 should, 3 could.
- The new test "no winner line before the night's last round" passes on the old code, so it does not prove the line (a must under the review rules).
- The job's report says mine.sh's churn step left the three tv_test_app generated files "no longer modified"; `git status` still lists them as M, so that claim is wrong.
- The winner line is measured at 568x320 only, not at the card's other landscape sizes (852x393 is the suite's default).

## Findings

- **must** controller_app/test/result_card_night_test.dart:102 The test "no winner line before the night's last round" only asserts absence (findsNothing) and the card's presence, so it passes on the old card, which never showed the line (the job's own report: 4 failures before the change, this test not among them) → add a same-test assertion that the line shows on round 3 of 3, so the test fails without the change.
- **must** docs/briefs/m16/bugs4/b040win-report.md:39 Question 1 says the three tv_test_app generated files are "no longer shown as modified"; `git status` shows `M` for generated_plugin_registrant.cc, generated_plugin_registrant.h and generated_plugins.cmake → correct the sentence to say they are still modified and that the runner logged their drop (docs/briefs/m16/bugs4/run.log:18).
- **should** docs/briefs/m16/bugs4/b040win-report.md:47 Hand-over says "six tests" in result_card_night_test.dart; the file has five `testWidgets` (lines 66, 78, 89, 102, 113) → change to "five tests".
- **should** controller_app/test/result_card_night_test.dart:113 The winner-line fit test runs only at 568x320; the card's other landscape size 852x393 (the suite default, line 36) is not checked, although review rule 6 asks for every look → add 852x393 to the palette loop, or record in the report why it is left out.
- **could** controller_app/test/result_card_night_test.dart:75 and :86 and packages/party_host/test/phone_text_test.dart:22-23 Tests assert a constant against the same literal it was written with, which pins the copy but checks no behaviour → keep the pin, and drop the duplicate expect at :75 and :86 since the widget assertion already covers the text.
- **could** packages/party_host/lib/src/text/phone_text.dart:220 `nightWinner` is followed directly by `waitingForNext` with no blank line, so the new block breaks the static-const layout → add a blank line after line 220.
- **could** controller_app/lib/src/ui/result_card.dart:121 `ToySizes.space12` above the winner line is a spacing choice that the brief does not give and the report does not list → list it under Decisions in the report, or reuse the points line's `space8`.

## Decisions to confirm

- Tie rule: every top scorer is named, in standings order, and a tied phone sees "You won the night!" (b040win-report.md Decisions). Confirm this is the owner's intent for ties.
- Winner line keyed on `round == of` from the host's ViewResult (result_card.dart:144). This treats the card's round as the night's last round; confirm the host never sends `round == of` for a stopped or abandoned night.
- Spacing `ToySizes.space12` above the winner line (result_card.dart:121) is not in the brief and not in the report's Decisions.

## Could not check

- Whether mine.sh's churn step really reverted the three tv_test_app files: the tree shows them modified now, and run.log:18 logs the drop; I cannot tell which state is current without changing git state, which I may not do.
- The winner line's behaviour when the night ends early (the host's `of` value at that point): the host code is outside this job's diff.
- The test run itself: I did not run the suites (read-only review); the failing-first claim rests on the report and run.log.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

review: wave2 b040win (B-040 winner line)

Review only, no code changed. Found: the "no winner line" test passes on
the old card (must), the report's churn claim about the three tv_test_app
files is wrong (must), the test count is five not six, and the winner
line is not checked at 852x393. Fixes are listed in the findings.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- wave2 review of b040win: done (small fixes: 2 must, 2 should, 3 could). Open: the must and should fixes in b040win's tests and report; the owner's check of the three tv_test_app generated files.

## Delete

- none
