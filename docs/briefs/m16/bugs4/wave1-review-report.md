# Wave 1 review: b040awards and b040fit

## Summary

Verdict: needs Claude
Counts: must 2 · should 3 · could 3
1. must: round_results_test.dart:72 passes on the old code (the report says so); Claude decides whether to keep it as a labelled guard.
2. must: b040fit-report.md:64-66 mine.sh reverted about 22 files that were already modified in the worktree; their content may be lost.
3. should: the awards test's red was a compile error and the fit test's red was the missing key, so neither overflow nor the old standings order was seen failing.

## Findings

- **must** packages/party_host/test/round_results_test.dart:72 the test "a round one of three of a night carries no award points" passes on the old code, and the awards report says so by design → Claude accepts it as a named regression guard, or drops it; the rule makes it a must either way.
- **must** docs/briefs/m16/bugs4/b040fit-report.md:64-66 `tools/mine.sh` reverted "22 generated files" that were already modified before the job, and the report does not say whether their content was kept → Claude checks whether those files' pre-run content still exists, and makes mine.sh revert only files the job itself changed.
- **should** controller_app/test/result_card_fit_test.dart:93 the fit test's only observed red on the old code was the missing `Key('resultCard')` lookup (b040fit-report.md:18), so the overflow at 568x320 was never seen failing → on the old code, add the key only and record the `resultWaiting` rect that fails.
- **should** packages/party_host/test/round_results_test.dart:41 the awards test's red was a compile error (`withAwards` undefined, b040awards-report.md:41), not an assertion → on the old lib, the assertion at line 63 should fail with order `['Mia', 'Ben']` and points `[9, 7]`; record that.
- **should** docs/protocol.md:285 the `standings` field says `pts` and "in total order" but not that a night's last round now includes the awards, nor that an early-ended night does not; docs/design/party-night.md:206 has the same gap → add one sentence to each saying so.
- **could** controller_app/lib/src/ui/result_card.dart:44-45 the comment says a card that is too big "keeps its text proportions", but below about 436 px of room the SizedBox at line 49 narrows and the text re-wraps → reword the comment to say it scales only when taller than the room, or accept as is.
- **could** packages/party_host/test/round_results_test.dart:63 the reason 'Ben 7 + 3, Mia 6 + 3' reads as if Mia got +3; she got none (her 9 is 6 + 3 of rounds) → reword to 'Ben 4 + 3 rounds + 3 award; Mia 9 rounds, no award'.
- **could** docs/briefs/m16/bugs4/b040fit-report.md:40 the self-check says the m14 and phone_fit tests "still pass" but phone_fit_test was not run (the report's own line 40 and Checks section say so) → say "not run".

## Decisions to confirm

- Early-ended night (round_results.dart:21-23): the phone's standings for the last recorded round still omit the awards the host's final scores include. The brief accepted this; Claude or the owner confirms, since closing it needs the awards sent with the result (a protocol change).
- Guard test (round_results_test.dart:72) passes on the old code by design; confirm it is kept.
- Fit width shrink (result_card.dart:49): below about 436 px of room the card narrows and its text re-wraps. The brief said "keep the 420 px width"; confirm this behaviour is wanted.
- Test 1's last round uses zero points, so Comeback is out of the expected result (round_results_test.dart:41). Chosen by the worker; it is a fair choice, listed for the record.

## Could not check

- No tests were run: this is a read-only review. Test results are the reports' claims, except where the runner log (run.log) says otherwise.
- Whether the old code fails the fit test on overflow (result_card_fit_test.dart:93-99) and the awards assertion at round_results_test.dart:63.
- Whether the 22 files reverted by mine.sh had content that is now lost.
- Whether `room.maxWidth` below 16 px makes `SizedBox(width:)` negative and assert (result_card.dart:49). Not checked by running.
- "At 852x393 with 2 rows the scale is 1": the fit report prints no number for it, so it is unverified.
- Whether the fit test's setup matches m14_phone_test "a result end keeps the last frame", as the brief asked: not compared line by line.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

This review changes no code, so it has no commit of its own. Draft for committing this report only:

```
bugs4 wave 1 review: findings on the B-040 awards and fit jobs

Reviews b040awards (c1d6d559) and b040fit (001b77e0) against their briefs,
the coding guidelines and the review rules. Writes findings only; no code
or document is changed. Open: a passing guard test (round_results_test.dart:72),
mine.sh reverting 22 modified files, and two tests whose red was not seen
for the right reason. Decisions for Claude are in the report.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

B-040 wave 1 review: done, report written (2 must, 3 should, 3 could). Open: mine.sh churn revert of ~22 modified files (check for lost content); guard test round_results_test.dart:72 passes on old code (keep or drop); fit and awards reds not seen for the right reason; early-end awards gap (protocol).

## Delete

- none
