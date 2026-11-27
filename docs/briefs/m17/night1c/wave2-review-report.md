# Wave 2 review: n1g, n1i, n1j (read-only)

## Summary

- Verdict: **needs Claude**
- Counts: must 1 · should 2 · could 7
- 1. (must) The three champion tests pass on the old code, so nothing guards the `championsAmong` wiring (run.log:55).
- 2. (should) Shape Race and puzzle rounds never call `roundEnded()`/`next()`: puzzle_pick `_next` is unhooked, so the controller stays in `round` after the footer's Shape Race pick.
- 3. (should) The controller's auto-start (`startRound`) opens a game without checking the scoreboard is the top route.

## Findings

- **must** packages/party_host/test/night_scoreboard_champions_test.dart:93 The three tests assert crowns that `row.place == 1` also gives, and the runner logged them as passing on the old code (docs/briefs/m17/night1c/run.log:55, exempted by n1j's brief) → Claude to confirm the exemption, or accept that the wiring has no failing test.
- **should** packages/party_host/lib/src/ui/puzzle_pick.dart:222 `_next` records the round but never calls `roundEnded()`/`next()` (game_screen.dart:268-270 does), so after a Shape Race or puzzle round the controller stays in `round`, and the next footer `startNow()` (night_scoreboard_screen.dart:148) does nothing → add the two calls once puzzle_screen.dart's import is allowed (n1i question 1).
- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:82 `startRound` checks only `mounted`, so a how-to timer that fires while a dialog or another route is on top pushes a game over it; no test covers this pair → return false unless `ModalRoute.of(context)?.isCurrent` is true, and add a test with a dialog open.
- **could** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:82 `startRound` does not check `nightBumperRoundReady`, which the footer checks at line 144; the constant is `true` today (party_night.dart:21) → add the same gate to `startRound` when the flag can change.
- **could** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:95 `replaceRound` is an empty override, so an accepted skip or reroll (night_flow_controller.dart:273-279) replaces no game; no UI calls skip or reroll yet → leave a dartdoc line saying so, or raise it in the next batch.
- **could** packages/party_host/test/night_controls_test.dart:10 `_FakeTimer` and `_FakeScheduler` are copied from night_flow_controller_test.dart (n1g report says so) → move both into one test support file.
- **could** packages/party_host/test/night_scoreboard_champions_test.dart:34 `_NightInFrame` and `_pumpFinalScores` repeat night_scoreboard_card_test.dart (n1j report, question 2) → move them into a shared support helper.
- **could** packages/party_host/lib/src/night/night_flow_controller.dart:135 `begin()` returns at once when any event exists, so a join recorded before it skips NightSetup silently; `startNow` checks `isEmpty` first, so this is latent → guard on the flow's stage and round, not on `_events`.
- **could** packages/party_host/lib/src/night/night_flow_controller.dart:259 `_howTo` always arms a timer, so the n1g report's question 2 (a how-to card "with no timer") does not happen → answer question 2 as "not reachable" in the report.
- **could** packages/party_host/lib/src/night/night_flow_controller.dart:326 The file is 326 lines, above the guideline's "about 300" and under the 380 limit → split the roster handling into its own file in a later batch.

## Decisions to confirm

- n1i (night_scoreboard_screen.dart:95): `replaceRound` is a stub, which the brief asked for; it is safe only while no screen calls skip or reroll.
- n1i (night_start_screen.dart:95): `startNow()` from the start card emits round 1's how-to card and the round at once, so the start card's how-to wait is skipped. The brief's wording allows this, but confirm it is wanted.
- n1g (night_flow_controller.dart:213-225): a queued join or leave takes the round number when it arrived, as n1g's question 3 says; confirm.
- n1g (night_flow_controller.dart:185): a pausable added during a pause is not paused (n1g question 1); ChoiceRound must handle it.
- n1i (night_scoreboard_screen.dart:82): the hook lives on the scoreboard state, not a class (allowed); Shape Race and puzzle rounds are left open (see the second should).

## Could not check

- I ran no tests or analyzer (read-only job); the report's counts (40, 72, 44 tests) are unverified beyond what run.log shows.
- n1i's claim that its four tests "fail on the code as it was" is unproven: the file cannot compile on the base, so that is a compile failure, not a behaviour failure.
- night_flow.dart apply rules for skip and reroll (lines 218-290) were read only in part; I did not confirm the stage after a skip in `round`.
- docs/architecture.md and docs/decisions.md were not checked for the night controller; no job touched them.
- The UI looks (menu and TV) were not checked: n1i and n1j changed no layout, so the all-looks rule was not tested.

## Commit message — a draft

None: this is a read-only review; nothing is committed from this job.

## Status row

wave2-review: done — n1g, n1i, n1j reviewed (1 must, 2 should, 7 could); open: champion test exemption, Shape Race/puzzle round end (puzzle_pick), top-route check on the auto-start.

## Delete

- none
