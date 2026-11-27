# night2c wave 3 review (v1b, v1c, f1)

## Summary
Verdict: small fixes
Counts: must 1, should 4, could 2
1. must: night_pick_test.dart:256 is not shown to fail without takeResult (the f1 worker did not run it against the old code, and the fallback can land on the same card).
2. should: a settled vote stays in state, so the strip on the last round's scoreboard shows an old "wins!" line (night_scoreboard_screen.dart:148).
3. should: the VoteHandle.done doc (night_vote.dart:20) no longer says that dispose completes it.

## Findings
- **must** packages/party_host/test/night_pick_test.dart:256 The vote-pick test passes if the fallback draw happens to pick the same card, because the test was never run against code that ignores takeResult (f1-report.md "Questions"), so it is not proven to fail. → Temporarily make `_votePick` ignore takeResult, run the test, and confirm it fails; if it passes, pick a vote that the fallback draw cannot produce (or assert the fallback is not used).
- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:148 The strip shows whenever nightVoteProvider is non-null, and nothing clears a settled vote: takeResult (night_vote.dart:172-178) leaves the state, and _startVote (night_scoreboard_screen.dart:81-86) returns without a vote on the last round. So the last round's scoreboard shows the previous vote's "<game> wins!" line; night_vote_screen_test.dart:254-263 misses it because it starts from a fresh state. → In _startVote, call `ref.read(nightVoteProvider.notifier).cancel()` before each early return, and add a test: a vote run for round 2 of 3, then the round-3 scoreboard shows no strip.
- **should** packages/party_host/lib/src/night/night_vote.dart:20 The doc of VoteHandle.done says it completes "when the round closes, by its timer or by closeNow", but dispose now completes it too (night_vote.dart:67). → Add "or when the handle is disposed, with an empty map" to that doc line.
- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:193 Review-rule A3 pairs are not tested: an open vote while "End the party night?" is answered Yes (the listener at night_vote.dart:137-139 cancels it, but no test shows the timer stops), and an open vote with a dropped or away phone on the scoreboard. v1c-report.md self-check 1 and 3 say these are not covered. → Add one scoreboard test for the End-night path (state null, no timer left), and state the other pairs as "not tested" in the report.
- **should** docs/briefs/m17/night2c/v1b-report.md:1 and docs/briefs/m17/night2c/f1-report.md:1 Neither report has the part-A self-check (the six host and state lines), which review-rules A requires in every job's report. → The workers add the self-check section, one line per item with the test that shows it ("not affected" is an answer).
- **could** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:79 The doc comment line runs past 120 columns (the grep for 121+ characters matches it). → Rewrap the comment at 120.
- **could** packages/party_host/lib/src/text/night_setup_text.dart:37 `pickerVoteHelp` hard-codes "5 seconds", while the duration is `voteDuration` in vote_round.dart:10; a change to the duration would leave the help line wrong. → Keep the text, but name the constant in its doc comment, or add a test that checks the text against `voteDuration.inSeconds`.

## Decisions to confirm
- night_scoreboard_screen.dart:170-172 The host's Next on a scoreboard calls startNow, and then pickFor → takeResult closes an open vote at once. So a Next tap within the 5 s cuts the phones' vote short (the auto path waits 8 s, scoreboard pacing in night_flow_controller.dart:44, so it always finishes). Owner said "Vote 5 s". Confirm: a Next tap should close the vote early, or should it wait for the vote?
- night_start_screen.dart:126-129 With the vote picker, every start-card press runs a new round-1 vote, and Back returns to the card with nothing started (v1c-report.md Question 2). Confirm this is wanted.

## Could not check
- Nothing was run: no tests, no analyze, no mutation check (the workers' "84 tests" and "36 tests" claims are unverified here).
- Whether the picker-row fit tests (night_labels_fit_test, phone_fit_matrix_test) pass with five rows (v1b): not run.
- Layout inside the strip beyond the overflow check (night_vote_screen_test.dart:282-298) was not measured.
- Phone setups "Play on this phone" and "Show on this device" were traced only through the starter's null path (night_vote.dart:80-103), not run.
- No doc under docs/ was changed by this wave; PRD and plan wording about the Vote picker was not checked.
- run.log notes that v1b's usage row covers only its last resume, so its turn count is unknown.

## Commit message — a draft
night2c wave3 review: report on v1b, v1c, f1

Read-only review of the three wave 3 jobs against the guidelines, the review
rules and their briefs. Findings: the vote-pick test is not shown to fail on
the old code; a settled vote's strip stays on the last round's scoreboard;
the VoteHandle.done doc misses the dispose completion; the End-night and
away-phone pairs are untested; v1b and f1 reports lack the self-check.
No code or other document changed.

## Status row
wave3 review (v1b v1c f1): verdict small fixes (1 must, 4 should, 2 could); open: the vote-pick test proof, the stale strip on the last scoreboard, the VoteHandle doc, the untested pairs, the two missing self-checks.

## Delete
- none
