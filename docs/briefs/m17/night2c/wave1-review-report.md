# night2c wave 1 review: v1a (Vote engine) and t1 (agent-cost)

## Summary
small fixes
- Counts: 1 must, 6 should, 8 could.
- must: v1a's report has no review-rules part A self-check (A1 to A6), which guidelines §11 requires.
- should: the default `voteStarterProvider` rules (no real phone → null) and the real round's own 5 s close are untested.
- should: the v1a pick test passes even if the vote were ignored (its starter returns null, so the pick is random).

## Findings
- **must** docs/briefs/m17/night2c/v1a-report.md:1 The report has no part A self-check (A1 to A6), only Files, Checks, Values, Questions and the closing blocks; guidelines §11 and review-rules A require it → add the six one-line answers, each with its test (for example A1: the `closeNow` and `done` tests in night_vote_test.dart:277 and :287).
- **should** packages/party_host/lib/src/night/night_vote.dart:78 The default `voteStarterProvider` (host must be a `ServerGameHost`; `local` and `simulated` players excluded; null when none is left) has no test; every vote test overrides it → add a test that reads the default provider with only local or simulated players and expects null.
- **should** packages/party_host/test/night_vote_test.dart:277 The `ServerVoteHandle` tests only call `closeNow()`; the path that matters in play, the round closing by its own timer (`ChoiceRound` `_endTimer` → `close()` → `changes` → `done`, choice_round.dart:85, :163, :178), is not tested with a real round → add a test that lets the round's timer fire (fake clock or a short injected duration) and checks `done` completes with the outcomes.
- **should** packages/party_host/test/night_pick_test.dart:215 The "vote picker plays the game its settled vote chose" test uses a starter that returns null, so the pick is a random one; it can pass with `takeResult` ignored when the seeded random happens to match → use a fake starter whose handle closes with votes for a known game (as night_vote_test.dart:105 does) and assert that game.
- **should** tools/tests/agent-cost-test.sh:172 `agents-off-unchanged` only checks that `driver:` and `rows sum` are absent; brief t1 item 1 asks for byte-identical output without the flag, and a changed row or total would pass → compare the no-flag output with a stored expected text, or with the output of the base tool.
- **should** tools/agent_cost.py:243 `main()` runs from line 243 to the end (about 113 lines; the guideline is about 40) and this job added lines to it (`owners`, `driver`, the accumulation at 286 to 300) → move the per-owner and driver accumulation into a named helper in a follow-up job (Claude decides).
- **should** tools/agent_cost.py:240 `gap / 60` puts a bare 60 in the code; guidelines allow only 0, 1, -1 and 2 bare → name it (`_SECONDS_PER_MIN = 60`) with a one-line comment.
- **could** packages/party_host/lib/src/night/night_vote.dart:64 `ServerVoteHandle.dispose()` before the round closes never completes `done`, so the `await handle.done` in `NightVoteNotifier.run` (night_vote.dart:164) never returns; it is held memory, not a timer (the case is the open question 3 in v1a-report.md:21) → complete `done` with an empty map in `dispose`, or note it in the dartdoc.
- **could** packages/party_host/lib/src/night/night_vote.dart:19 One file holds five public types (`VoteHandle`, `VoteStarter`, `ServerVoteHandle`, `NightVoteState`, `NightVoteNotifier`); guidelines §3 asks for one public type per file unless they are small and only make sense together → move `ServerVoteHandle` (the ChoiceRound wiring, lines 33–74) to its own file.
- **could** docs/briefs/m17/night2c/v1a-report.md:6 The report says "10 tests"; night_vote_test.dart has 11 (`test(` at lines 92, 105, 122, 137, 152, 169, 179, 201, 277, 287, and the countdown `testWidgets` at 189) → correct the count.
- **could** packages/party_host/test/night_vote_test.dart:215 The `setup()` helper in the `ServerVoteHandle` group is about 60 lines (215 to 275); guidelines say functions about 40 → move the server and phone start-up into a top-level helper in `support/`.
- **could** packages/party_host/test/night_vote_test.dart:92 The name says "the default pool of 7", but the file never asserts the pool size; the 7 is only in the report → assert it, or drop it from the name.
- **could** tools/agent_cost.py:292 `"headless" if c["sub"] else "main"` works because `sub` is True, False or the string "head" (set at line 127), but the three cases are not named → write them as explicit comparisons.
- **could** docs/driver-kit.md:129 The text says "any wait over about 55 min", but the tool prints only the longest wait in minutes (t1 decision 4) → say "the longest wait (min)", so the doc matches the output.
- **could** docs/briefs/m17/night2c/run-findings.md:1 It records that v1a's report has no Summary block; no rule in the brief or the guidelines I read requires one → decide whether the worker report template needs it; no change to the code.

## Decisions to confirm
- v1a `NightVoteNotifier.run` (night_vote.dart:145–167): a new round's `run` disposes an open vote of another round without settling it; in v1b this is safe only if the previous round always calls `takeResult` first. Why: the brief does not say what happens to the old vote.
- v1a `_votePick` (night_pick_provider.dart:102–108): with no vote run, the random pick is drawn from `voteOffer()` (at most 4 cards), not the whole pool. Why: it follows the brief, but it means the pick is random among the cards the phones would have seen.
- v1a `voteStarterProvider` (night_vote.dart:85): the host's own player is excluded; a TV host with no joined phone gets no vote. Why: intended by the brief, and it means no vote on a single-device night.
- v1a one-game case (night_vote.dart:154): with one offered game no round starts and the result is random, byChance true, votes 0. Why: the brief says "result at once"; the result reads as a random pick, not a vote.
- t1 decision 1 (headless row), 2 (driver line only with `--agents`), 3 (4 decimals), 4 (longest wait always printed, threshold left to the reader), 5 (`--since <time>` in the docs). Why: each departs from or extends the brief, and the owner should see the list.

## Could not check
- v1a `tools/mine.sh` result (OK, 72 tests) and the v1a `flutter analyze`: not rerun in this review.
- t1 "8 of 10 new cases FAIL on the base": no base run was done here.
- `ChoiceOutcome` equality used by the `expect` calls in night_vote_test.dart:283 and :292: not read.
- The t1 claim that `tools/mine.sh` formatted party_host files outside the allow list: the commit range touches only allowed files (10 files in the diff stat), so no violation is visible; the formatting claim is unverified.
- I ran `bash tools/tests/agent-cost-test.sh` once: 31 PASS, 0 FAIL. I did not check whether it removes its temp folder.

## Commit message — none
This job changes no file (read-only review); no commit.

## Status row
- night2c wave 1 review: v1a and t1 reviewed; open: v1a self-check missing from its report (must), default vote starter and timer close untested, pick test can pass without the vote, agent-cost no-flag check not byte-exact, `main()` length; nothing changed.

## Delete
- none
