# n1g report: host controls on the night controller

## Summary

- Added the pause seam (`NightPausable`, `addPausable`, `removePausable`, `isPaused`), `pause()` and `resume()`, `skip()` and `reroll()` (both legal in the how-to card and the round, paused or not), and roster handling (`rosterChanged`) to `NightFlowController`. No change to NightFlow, NightEvent, the pause rules or the protocol.
- `skip` and `reroll` do not use a round: the round number and stage stay put, and at a how-to card the card's timer starts again for a full `pacing.howTo`.
- A round that ends while paused resumes its pausables with no event. Dispose clears the pausables without calling them.
- Joins and leaves: the first `rosterChanged` only records the roster. Later calls emit at once between rounds; during a round they are queued and emitted right after `NightRoundEnded`, once. Leaves use `NightReason.playerLeft`. Avatar id is `character.id`, else `player<number>`; nicknames never reach the events.
- `nightFlowControllerProvider` reads the roster once at build and then listens to `gamePlayersProvider`.
- `tools/mine.sh`: format OK, analyze OK for packages/party_host, 40 tests OK. Tests first was exempt (see the brief); the new tests did not compile before the methods existed.

Files changed (all inside `allow:`):

- `packages/party_host/lib/src/night/night_flow_controller.dart` (207 → 326 lines): NightPausable, the pause/skip/reroll/roster methods, `_armHowTo` (split out of `_howTo`, so skip and reroll can re-arm without emitting NightHowTo again), `_replace`, `_rosterEvent`, `_emitQueued`.
- `packages/party_host/lib/src/night/night_flow_provider.dart` (27 → 30 lines): imports `../providers.dart`; reads the roster at build and listens to `gamePlayersProvider`.
- `packages/party_host/test/night_controls_test.dart` (new, 379 lines): 17 tests on pause, resume, skip, reroll, roster, pausables and dispose. Its fake scheduler is a copy of the one in night_flow_controller_test.dart (the original is private to that file); the `asked` list is left out.
- `packages/party_host/test/night_roster_wiring_test.dart` (new, 21 lines): one test, a player who joins after the controller exists produces `NightPlayerJoined('player1', 0)` in `controller.events`.
- `docs/briefs/m17/night1c/n1g-report.md` (this file).

Not mine: `docs/briefs/m17/night1c/DRIVER-NOTES.md` and `run.log` were already modified in the working tree at the start. I did not touch them.

## Computed values (the test expectations)

Default pacing: setup 3 s, howTo 6 s, results 6 s, scoreboard 8 s.
- Round 1 starts at 3 + 6 = 9 s after `begin()`; the test helper `_toRound` moves the clock 9 s.
- Round 1 scoreboard: roundEnded at 9 s, then results 6 s, so scoreboard at 15 s.
- Skip at the how-to card at 5 s (begin → 3 s, then 2 s): the old timer (due 9 s) is cancelled, so nothing starts at 10 s; the round starts at 5 + 6 = 11 s.
- 3-round night with one skip at 3 s: NightRoundStarted for rounds 1, 2, 3; NightHowTo for 1, 2, 3; three NightRoundEnded; ends.
- Queued leave: emitted after NightRoundEnded(1, false) and before NightScoreboard(1, false) at 9 + 6 = 15 s.

## Self-check (review-rules part A)

1. Host setups: no UI. The controller is shared by every host; the phone-join path is covered by night_roster_wiring_test.dart ("a player who joins after the controller exists…").
2. Kept state: the pausable list is built by addPausable/removePausable and cleared by dispose; the queue is filled in a round and emptied by roundEnded or dispose. Tests: "after dispose the pausables are dropped without being called", "a removed pausable is not paused, but the controller still pauses", "a roster change after the night has ended emits nothing".
3. Combinations: pause at how-to/scoreboard (returns false, pauses nothing); round ends while paused (resumes, no pause left); skip and reroll while paused (accepted, still paused); a leave during the how-to wait (emitted, timer kept); a leave in a round (queued, once). Host away, "Get ready" and the pause menu are UI-level and are not in this batch.
4. Stayed inside `allow:`: yes, see the file list.
5. Nothing stopped.
6. Looks: no UI in this job.

## Hand-over

- The night controller is ready for ChoiceRound to join with `addPausable`; no screen or button calls pause/skip/reroll yet (a later batch does).
- Analyzer and tests: `tools/mine.sh` OK (format, analyze, 40 tests). I did not run `tools/check.sh`.

## Questions

1. A pausable added during a pause is not paused. Should `addPausable` pause it when the night is already paused, or is that for ChoiceRound to handle? I did not add it.
2. A how-to card that waits for `startNow` (a host start, with no timer) gets a timer when skip or reroll re-arms it. The brief asks for this; confirm it is wanted for that card.
3. Queued joins and leaves use the round number at the time they arrived, which is the round in play. A join that arrives during a round is shown as the round's join, not the next one's; confirm.

## Commit message — a draft

Night controller: host pause, skip, reroll and roster events

- NightFlowController gets pause and resume (emit NightPaused/NightResumed, call NightPausable on each), skip and reroll (no round used; at a how-to card the card's timer starts again)
- A round that ends while paused resumes its pausables with no event
- rosterChanged emits NightPlayerJoined/Left between rounds and queues them during a round, emitted once after NightRoundEnded
- The provider feeds the roster from gamePlayersProvider once at build, then on change
- Tests: night_controls_test.dart (fake scheduler), night_roster_wiring_test.dart (provider join)

## Status row

n1g: done — pause/resume seam (NightPausable), skip/reroll without using a round, roster join/leave events (queued in a round), provider wiring; tests OK. Open: no screen or button yet; ChoiceRound adds its pausable later; a pausable added mid-pause is not paused (question 1).

## Delete

- none
