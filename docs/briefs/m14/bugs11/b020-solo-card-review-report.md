# M14 bugs11 b020-solo-card: review

Job: `docs/briefs/m14/bugs11/b020-solo-card-review.md`. Read-only: this report is the only file I changed. Change reviewed: `d187a5b`'s parent `b8638dd..f11c4b1` (10 files, +203/−72).

## Summary

**Verdict: small fixes.** 0 must, 1 should, 3 could.
The fix itself is sound and matches the brief: `_alone`, its `when` branch and `SoloRoundStart` are gone, the card always shows, `skipsLobby` is Shape Race's alone, the design doc and the old pin are updated, and the new test file is red on the old code for the bug's reason.
Most important: (1) the one-player night on a phone that plays here is the setup whose behaviour changed (a Ready tap now starts the round) and no test covers it — the report's A1 line cites a two-player test; (2) the test named "on Surprise me" never checks the map the round actually plays; (3) a wording slip in the `_startBumperRound` comment.
Checked myself: `flutter test test/solo_arena_card_test.dart test/solo_skip_test.dart` 7 passed; `flutter test test/night_round_test.dart` 16 passed.

## Findings

- **should** packages/party_host/test/arena_touch_ready_test.dart:110 the report's review-rules A1 line for "a phone on Play on this phone" cites this test, but its setup joins a second phone (line 56), so a one-player night on a playing phone host — where the round used to start itself and now waits for the own player's Ready tap — has no test → add one test to `solo_arena_card_test.dart` with `ownPhoneOverrides('p1')`, one player, a night's Bumper Round: `arenaReady` is up, one tap starts the round, or say in A1 that this setup is covered by reasoning and not by a test.
- **could** packages/party_host/test/solo_arena_card_test.dart:52 the test named "on Surprise me" proves it only by the absent `chosenMap-pinball` key, and line 61 never reads `arenaSnapshot(tester).mapId`, so a start that played the saved 'pinball' anyway would still pass → also assert `arenaSnapshot(tester).mapId`, `isNot('pinball')` after `roundStarted` (the run logs "Block Castle", the night's unused map).
- **could** packages/party_host/test/solo_arena_card_test.dart:17 `openNightBumperCard` restates test 1's setup (lines 34-42) and is used by test 2 only → give it the `setMap` case as a parameter and let test 1 use it, or inline it into test 2.
- **could** packages/party_host/lib/src/ui/night_start_screen.dart:74 "as Shape Race's join screen does for two" reads as exactly two, while that join screen shows for two or more → say "for two or more".

## Decisions to confirm

- **The night's card keeps Bumper alone.** B-020's row asks for the map *and* the game type; this job answers the map and leaves the mode to the owner's open question ("show both modes in a solo night?"). Worth putting to the owner as a yes/no, not only as a note.
- **"Surprise me" proven by absence.** The card has no key for the chosen Surprise-me tile, so the test shows the absence of a chosen map. That is the weakest part of the new file (finding 2); confirm whether the round's map must be asserted or the current proof stands.
- **`SoloRoundStart` deleted, not parked.** Correct per guidelines §2, but if `b020-next-map` or a later job meant to reuse it, it is gone.

## Could not check

- The red run: I cannot check out `b8638dd` (no git state changes allowed), so "1 failed on the old code" rests on the report and on `docs/briefs/m14/bugs11/run.log:6` ("finished: result 4"); reasoning agrees — `_alone` hid the card, so test 1's first `findsOneWidget` on `arenaWaitingCard` must fail there.
- `tools/review.sh`'s "0 fail, 1 note": not re-run (the working tree carries unrelated changes, so it would diff those too), and neither were the full `tools/check.sh host`/`phone` counts (465/475).
- `run.log:7` records that this job dropped `site/shots/*.png` as churn outside its list; from here I cannot tell whether the job's own commands wrote them or a shared tool did.

## Commit message

M14 bugs11: review of b020-solo-card

Reviewed b8638dd..f11c4b1 against the guidelines, the review
rules and the brief: the fix, the doc change and the rewritten pin
are right, and the new file is red on the old code for the bug's
reason. One should (a one-player night on a playing phone host
has no test) and three coulds (the Surprise-me assertion reads
only the card, a one-use helper, a wording slip in a comment).

## Status row

M14 b020 (solo Arena card): reviewed — small fixes: add a one-player night test on a phone that plays here, assert the round's map in the Surprise-me test, tighten one comment; open: those fixes, the owner's answer on showing both modes in a solo night, and the Next-map button (b020-next-map).

## Delete

- none
