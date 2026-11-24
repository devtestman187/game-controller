# Run review: bugs4 (B-040 awards, fit, winner line)

## Summary

Verdict: **needs Claude's design**. The owner's Nov 24 answer (Q8, `docs/briefs/m16/plan789/QUESTIONS.md:50`) asks for a new capability-gated awards message to joined phones; the run built computed standings and no message. The other findings are one fix batch plus two decisions.

Counts: **must 5 · should 7 · could 8** (20 findings).

The five that matter most:
1. Design: no awards message and no "Awards coming…" state exist (grep of `packages/protocol/lib` and `controller_app/lib`: no match). The run's `round_results.dart:24` computes the awards on the phone's projection instead.
2. Guard tests pass on the old code: `round_results_test.dart:72` and `result_card_night_test.dart:102`. G9 says new tests fail on the code as it was.
3. The awards test was red only by compile error (`round_results_test.dart:42`); `run.log` logs no tests-first line for b040awards.
4. `mine.sh` reverted 22 files outside the job's allow list (`run.log:9`, `run.log:11`); whether their pre-run content survived is unknown.
5. The fit test's red may be the missing key, not the overflow (`result_card_fit_test.dart:90`).

Questions only the owner can answer: Open questions 1, 4, 5, 7 and 11.

Batches (no shared files within a wave): W1 phone `result_card_night_test.dart` (M4, S2, C2); W1 phone `result_card.dart` + `result_card_fit_test.dart` (S1, S3, C4); W1 host `round_results_test.dart` (M2, C1; M3 after Claude's decision); W1 docs (S4; S5, C8; S6, C7). Wave 2: S7, C5, C6, C3. Not a fix job: M1 (design), M5 (runner).

## Findings

- **must** docs/briefs/m16/plan789/QUESTIONS.md:50 and packages/party_host/lib/src/night/round_results.dart:24 — the owner's Nov 24 answer asks for a capability-gated awards message sent at the reveal's end and an "Awards coming…" state on the phone; the run sends no message and the state does not exist → Claude decides whether B-040 is reworked to Q8 before m16.3 (a design change, not a fix batch) (from: across jobs; b040awards, b040win)
- **must** packages/party_host/test/round_results_test.dart:42 — the awards test failed before the change only as a compile error (`withAwards` undefined), and `run.log` has no tests-first line for b040awards → re-run on the old lib with only the method stubbed and record the assertion; the old code gives order `['Mia', 'Ben']`, points `[9, 7]` (from: b040awards)
- **must** packages/party_host/test/round_results_test.dart:72 — "a round one of three of a night carries no award points" passes on the old code, which G9 forbids for new tests → Claude keeps it as a named guard with a stated exemption, or drops it (from: b040awards; wave1)
- **must** controller_app/test/result_card_night_test.dart:102 — "no winner line before the night's last round…" asserts only absence and the card's presence, so it passes on the old card (it is not among the 4 logged failures) → add an assertion in the same test that the line shows on round 3 of 3 (from: b040win; wave2) [phone]
- **must** docs/briefs/m16/bugs4/run.log:9 — `mine.sh` reverted 22 files outside the job's allow list (docs/design and site/shots PNGs, tv_test_app generated files); the fit report does not say whether their pre-run content survived (`b040fit-report.md:64-66`) → owner checks those files; `mine.sh` reverts only files the job itself changed (from: b040fit; runner)
- **should** controller_app/test/result_card_fit_test.dart:90 — the only old-code red recorded was the missing `Key('resultCard')` lookup (`b040fit-report.md:17-19`), so the overflow was never seen failing → on the old code add only the key and record the `resultWaiting` rect that fails (from: b040fit; wave1) [phone]
- **should** controller_app/test/result_card_night_test.dart:117 — the winner-line fit test runs only at 568x320; 667x375 and 852x393 are not checked → add both sizes to the loop, as the fit test does (from: b040win; wave2) [phone]
- **should** controller_app/lib/src/ui/result_card.dart:44-45 — the comment says a card too big "keeps its text proportions", but below about 436 px of room the `SizedBox` at line 49 narrows and the text re-wraps, so the brief's "keep 420 px" is missed there → reword the comment, or Claude decides the width rule (from: b040fit; wave1) [phone]
- **should** docs/protocol.md:285 and docs/design/party-night.md:206 — the `standings` text does not say that a night's last round now includes the awards, or that an early-ended night does not → one sentence in each (from: b040awards; wave1)
- **should** docs/briefs/m16/bugs4/b040win-report.md:39 — says the three tv_test_app generated files are "no longer shown as modified"; the tree still lists them as M, and `run.log:18` logs only the drop → correct the sentence (from: b040win; wave2)
- **should** docs/briefs/m16/bugs4/b040fit-report.md:45-46 — the self-check says the menu and TV looks are both covered "through the two palettes", but the test sets no TV look (review-rules A6) → correct the claim, or state that the TV look does not apply to the phone card (from: b040fit) [phone]
- **should** controller_app/test/result_card_night_test.dart:46-59 — the six-standing fixture and the palette loop (`:113-135`) repeat `result_card_fit_test.dart:16-65` and `:72-102`, written in two jobs → move both into one shared test support file in one job (from: across jobs) [phone]
- **could** packages/party_host/test/round_results_test.dart:63 — the reason `'Ben 7 + 3, Mia 6 + 3'` reads as if Mia got +3; her 9 is rounds only → reword to `'Ben 4 + 3 rounds + 3 award; Mia 9 rounds, no award'` (from: b040awards; wave1)
- **could** controller_app/test/result_card_night_test.dart:75 and :86 — `expect(PhoneText.x, 'literal')` repeats the constant's own literal and checks no behaviour (the same pin is in `phone_text_test.dart:22-23`) → keep the pin in `phone_text_test.dart`, drop the two duplicates (from: b040win; wave2) [phone]
- **could** packages/party_host/lib/src/text/phone_text.dart:221 — no blank line between `nightWinner` and `waitingForNext` → add one (from: b040win; wave2)
- **could** controller_app/lib/src/ui/result_card.dart:121 — `ToySizes.space12` above the winner line is not in the brief or the report's decisions → reuse `space8` as the points line does, or list it under Decisions (from: b040win; wave2) [phone]
- **could** controller_app/lib/src/ui/result_card.dart:148 — no test covers a tie of three or more; six phones tied at 0 give a long line and the whole card then shrinks → add a three-way tie case to the night test (from: across jobs; review-rules B9) [phone]
- **could** controller_app/lib/src/ui/result_card.dart:297 — the file grew from 261 to 297 lines over two jobs, at the guideline's 300; the next card change breaks it → split `_StandingRow` and the night lines into their own file in the job that next touches the card (from: across jobs) [phone]
- **could** docs/briefs/m16/bugs4/b040fit-report.md:40 — says phone_fit_test "still pass", but its own Checks section says it was not run → say "not run" (from: b040fit; wave1)
- **could** docs/briefs/m16/bugs4/b040win-report.md:47 — says "six tests" in result_card_night_test.dart; the file has five `testWidgets` (lines 66, 78, 89, 102, 113) → "five tests" (from: b040win; wave2)

## Open questions

1. Q8 (`plan789/QUESTIONS.md:50`) versus the run: rework B-040 to the awards message, or keep the phone-computed route for the last round? → Suggested: rework to Q8 before m16.3; the computed route cannot cover early ends.
2. Early-ended night: the phone's standings lack the awards (`round_results.dart:22-24`) → Suggested: accept; no winner line shows there because round < of.
3. Tie rule: every top scorer is named in standings order, and a tied phone says "You won the night!" → Suggested: keep.
4. Are the three tv_test_app generated files meant to be committed? → Suggested: restore them to HEAD after the owner checks the diff; they are build output.
5. Keep the guard at `round_results_test.dart:72` (M3)? → Suggested: keep it, labelled, with a G9 exemption reason.
6. Below 436 px of room, keep the narrowing or hold 420 px? → Suggested: keep the narrowing and correct the comment; FittedBox still handles height.
7. Did the 22 files reverted by `mine.sh` lose pre-run content? → Suggested: owner compares them with the pre-run state before the next commit.
8. Test the winner line at 667x375 and 852x393 (wave2 question 2)? → Suggested: yes.
9. New tests in existing files: the worker extract says "New tests in a NEW file", `docs/coding-guidelines.md` §9 does not, and the awards and win briefs put tests in existing files → Suggested: keep the briefs' choice and make the extract and the guideline say the same.
10. Does the TV look apply to the phone's result card? → Suggested: no; say "not affected" in the self-check.
11. Did the runner's combined check cover `phone`, and did it pass? `run.log:13` and `:20` show no result → Suggested: read its output before merging; the fit and win briefs require `check: phone`.
12. Keep the spacing `ToySizes.space12` above the winner line? → Suggested: keep it and list it under Decisions.

## Numbers against targets

- Fit (brief item 1): the waiting line at 568x320 sat at y 341, 58 px off the screen. After the change the test asserts `bottom <= 320` but prints no rect, so the margin is unknown; not measured again. Missed: nothing shown; unverified.
- Fit width (brief item 2, "keep the 420 px width"): missed for any room narrower than 436 px (card width = room − 16). The test's narrowest room is 552 px, so the test does not reach the miss.
- Fit scale "at 852x393 with 2 rows the scale is 1" (brief item 2): not reported by the job; unverified.
- Awards: expected last-round totals Ben 10 (4 + 3 rounds + 3 award) and Mia 9 (6 + 3 rounds, no award). The old code gives Mia 9, Ben 7, so the test's assertion would change order.
- Sizes against the guideline (about 300 lines; build under 60): `result_card.dart` 297 lines (was 261; at target); `ResultCard.build` about 50 lines; `night_state.dart` 343 lines (under 380); `phone_text.dart` 251; tests 100, 137 and 103 lines (under 500).
- Checks: none run (read-only); the reports' numbers are not re-checked.

## Could not check

- Pre-run content of the 22 reverted files and the state of the 3 tv_test_app files: the snapshot lists the 3 as M; the reports disagree.
- Whether the old code fails the fit test on overflow, and the awards assertion: taken from the reports and `run.log`, not re-run.
- Whether the combined `phone` check passed (`run.log:13`, `:20` give no result).
- `room.maxWidth` below 16 px would make the `SizedBox` width negative and assert (`result_card.dart:49`); not run.
- Host paths other than the phone's card, for the `viewResultsFor` change: read only, not run.
- Device checks at any size: none done.
- The "(G4)" tag in the new `withAwards()` doc comment: I did not find what G4 refers to in the docs I read.
- `pubspec.lock`: the status snapshot lists no change to it.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
bugs4 run review: findings on B-040 awards, fit and winner line

Reviews the run's commits (15d4384..2330d358) as one change against the
coding guidelines and review rules. Adds the review report only; no code
or other document is changed. Open: the owner's Nov 24 awards decision
(Q8) is not built; a guard test passes on the old code; mine.sh reverted
22 files outside the job's allow list. Findings and batches are in the
report.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

B-040 run review: done, report written (5 must, 7 should, 8 could). Open: owner's Nov 24 awards decision (Q8: capability-gated awards message, "Awards coming…") not built, needs Claude's design; guard tests round_results_test.dart:72 and result_card_night_test.dart:102 pass on old code; awards red was a compile error; mine.sh reverted 22 files (owner to check); fit and winner line not checked on device.

## Delete

- none
