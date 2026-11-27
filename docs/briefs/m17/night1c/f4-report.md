## Summary

Job f4 (night1c): the controller lives through the last round's ceremony, the host ring is drawn only inside the host
frame, and the dead bumper guard is gone.

Files changed:
- `night_flow_provider.dart`: the select keys on null / `isEndedEarly`, not `isOver`, so the last round keeps the
  controller. A night loaded after its last round still returns null (a fresh controller would replay it).
- `night_flow_provider_test.dart`: last-round test expects the controller alive and `next()` to apply NightCeremony
  then NightEnded; new tests for a loaded finished night (null) and a new night after a finished one (fresh); the
  ended-night test uses the fake scheduler.
- `player_badge.dart`: ring only when `HostFrameInfo.maybeOf(context) != null`; outside it, players 7 and 8 are plain.
- `player_badge_ring_test.dart`: new test, outside the frame, player 7 has no PlayerBadgeRing (both looks).
- `night_scoreboard_screen.dart`: deleted the dead `nightBumperRoundReady` line and reworded the dartdoc.

Tests-first (before the lib change): the last-round test failed (`Expected: true, Actual: <false>`) and the
outside-frame test failed. Both pass now.

Checks: `tools/mine.sh` ran 26 party_host tests, all OK; analyze clean; format applied.

Computed values: 3 rounds of 3 points; events end `[NightCeremony(), NightEnded()]`, stage `NightStage.ended`;
`PlayerBadge(number: 7)` default size 32 gives a ToyBadge of diameter 32 and no ring; end() drops the pause from 1
waiting to 0.

Self-check (review-rules part A):
1. Setups: TV and PC ring in frame (`player_badge_ring_test`, both looks); phone outside frame (outside-frame test).
   The controller_app PlayerBadge tests were not run.
2. Kept state: starts with the night, ends when cleared or ended early (`ending the night disposes...`, ended-early
   test); a new night gets a fresh controller.
3. Combinations (pause, host away, Get ready, dropped link, results, leaving): unchanged here, not tested here.
4. Stayed in allow: yes; `night_round_hook_test.dart` names no `nightBumperRoundReady`, so it is unchanged.
5. Stop: none.
6. Looks: ring and outside-frame tests run in both looks via `forEachLook`.

Decisions:
- Loaded finished night: null (the brief's literal "null or isEndedEarly" would replay it).

## Hand-over

- Five files as in the Summary; nothing staged or committed.
- Not run: controller_app tests (host_chip_test, identity_phone_test, lobby_alignment_test) that pin PlayerBadge.
- Not run: `tools/check.sh` (the script runs it).

## Questions

1. The phone's badge for players 7 and 8 is now plain. Confirm the owner accepts that (brief's choice); suggested yes.
2. A night loaded after its last round shows no ceremony or end. Separate job? Suggested yes.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

night1c f4: keep the night's controller through the last round's ceremony

The provider dropped the controller once the last round was recorded, so the ceremony and end never ran.
It now keeps the controller until the night is cleared or ends early; a night loaded after its last round still
has none. The host ring is drawn only inside the host frame, so the phone app shows players 7 and 8 plain.
The dead bumper guard in the scoreboard's startRound is removed. Tests: last round, loaded finished night,
fresh controller after a finished one, and the badge outside the frame.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

night1c f4 done: ceremony and end run after the last round; host ring only in the host frame; dead bumper guard removed. Open: controller_app PlayerBadge tests not run here; a night loaded after its last round shows no end.

## Delete

- none
