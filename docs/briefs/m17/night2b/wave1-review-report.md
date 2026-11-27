# night2b wave1 review: d2w and d2f

## Summary

Verdict: needs Claude.
Counts: must 1, should 5, could 3.
1. controller_app/test/choices_vote_test.dart passes on the old code (run.log:14, :34), and the d2f brief's reason for exempting it does not hold.
2. settleVote counts a repeated offered variant twice in a tie (packages/party_host/lib/src/night/vote_round.dart:68), so a tie can be settled 2/3 for one game.
3. The played list is cleared on night end only if the notifier was already built (packages/party_host/lib/src/night/night_pick_provider.dart:34), so a stale list can survive into the next night.

## Findings

- **must** controller_app/test/choices_vote_test.dart:89 The file is new but the runner recorded it passing on the old code (run.log:14, :34); the brief's exemption says it "cannot compile on the base", which run.log contradicts, so it proves no change in d2f → Claude decides: keep it as a pin and say so in the report, or add an assertion that fails on the base.
- **should** packages/party_host/lib/src/night/vote_round.dart:68 The leaders list loops over `offered`, so a variant offered twice counts twice in a tie: offered [A, A, B] with one vote each gives A 2/3 and byChance true → loop over the distinct variants (e.g. `offered.toSet()`) and add a test for a repeated offer.
- **should** packages/party_host/lib/src/night/night_pick_provider.dart:34 The listen that clears the list is registered in build, so a restored night that ends before anything reads nightPickProvider keeps its saved list, and the next night loads it at line 32 → clear the saved list in build when partyNightProvider is null (d2w-report.md:74).
- **should** packages/party_host/lib/src/text/variant_text.dart:9 The map names are copied into lib, and the drift test that guarded them was removed by hand (run.log:22), so nothing keeps `mapNames` equal to test_game's arenaMapNames → Claude decides: export arenaMapNames from test_game (outside allow) or restore a test that compares them.
- **should** docs/briefs/m17/night2b/d2f-report.md:8 The report says variant_text_test has 5 tests and that a test guards the copy (line 15), and it counts 17 party_host tests; the file now has 4 tests (variant_text_test.dart:7, :17, :25, :33) and the touched count is 16 → correct the report.
- **should** packages/party_host/lib/src/night/vote_round.dart:24 A pool of 4 with the last played game offers only 3, while the d2f brief says the whole pool for 4 or fewer, and the d2f report does not list this choice → Claude confirms it and lists it, or the code offers the whole pool.
- **should** packages/party_host/test/night_pick_test.dart:109 The director test uses one seed (Random(1)) and asserts only that the second pick differs from the first, so it can pass with the played-list rule removed → loop over seeds (e.g. 0 to 19) and assert every second pick differs from the first.
- **could** packages/party_host/test/night_pick_test.dart:89 The opening test uses the default difficultyMin (easy) only, so a director that always opens at easy passes → add a case with difficultyMin above easy.
- **could** packages/party_host/lib/src/night/vote_round.dart:73 With one offered game and nobody voting, byChance is false, though the brief says nobody voting is byChance true → Claude decides which reading is right and documents it.
- **could** controller_app/test/choices_vote_test.dart:27 `_pumpRound` is 41 lines, over the about-40 guideline → split the look setup into a named helper.

## Decisions to confirm

- d2f: the phone test is kept as exempt, and the exemption's reason is wrong (see the first finding).
- d2f: `voteDuration` (vote_round.dart:10) has no caller in this wave, and the phone test hard-codes 5000 ms and "5 s" (choices_vote_test.dart:22, :128), so a change to the constant would not be caught.
- d2f: `mapNames` (variant_text.dart:11) is a copy of test_game's list, kept on purpose.
- d2w: Kids keeps the picker at host (night_settings.dart:49-53), so the director is not used by Kids until the host changes it (d2w-report.md:78).
- d2w: `load()` removes a save that is not JSON or not a list (night_played_store.dart:25-27); a read that writes, listed as decision 2.

## Could not check

- No analyze or test run: read-only, and no base run was possible. The "analyze clean" and "tests pass" claims come from the reports and run.log only. run.log has no re-run of tools/review.sh after the hand-fix (run.log:20-34).
- Whether the d2w tests fail without their rules: judged by reading only.
- The review-rules text was judged from the worker extract, not the full file.
- Pause, reconnect and host-away combinations: nothing reads the pick or the vote yet (d2x), so there is nothing to check.
- Whether NightDirector.pick, ShufflePicker.next, partyNightProvider.end and the test helpers have the signatures the code uses: not opened.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 night2b wave1 review: report on d2w and d2f

Read-only review of the d2w and d2f commits against the coding guidelines, the review rules and their briefs.
Records the findings: one must (a new phone test passes on the old code), five should, three could.
Changes no code. Claude decides the open points listed in the report.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2b wave1 review: done: report on d2w and d2f (1 must, 5 should, 3 could); open: the must on choices_vote_test, the settleVote tie with a repeated offer, the stale played list on a restored night, the map-name copy, and the report corrections.

## Delete

- none
