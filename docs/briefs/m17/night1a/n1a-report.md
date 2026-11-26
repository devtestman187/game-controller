# night1a (n1a) report: NightFlow state type and NightEvent contract

## Summary

STATUS: done. Pure Dart, no UI, not wired into party_night.dart or night_state.dart.

Files changed (the two allowed, plus this report):
- `packages/party_host/lib/src/night/night_flow.dart` (new, 309 lines): `NightReason`, `NightStage`, `sealed class NightEvent`
  with the 14 final subclasses (facts only, `==`, `hashCode`, `toString` on the base), and `final class NightFlow`
  (`start`, `stage`, `round`, `rounds`, `paused`, `isLastRound`, `apply`).
- `packages/party_host/test/night_flow_test.dart` (new, 189 lines): 14 tests, written first.
- `docs/briefs/m17/night1a/n1a-report.md` (this file).

Tests-first evidence: before `night_flow.dart` existed, `flutter test` on the new file failed to compile
("Couldn't find constructor 'NightRoundEnded'" and no library). The first `tools/mine.sh` run then failed 2 of the
14 tests because my own test helper stopped at roundEnd; I fixed the helper, not the flow.

Checks run:
- `tools/mine.sh` (first run): FAILED, 2 tests (my helper; fixed).
- `tools/mine.sh` (after fix): `RESULT: ok: 2 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`, `OK 14 tests packages/party_host`.
- `dart analyze` on the two files: no findings (inside mine.sh's analyze of packages/party_host).

## Test values computed

- 3-round walk: setup -> howTo(1) -> round(1, lastRound false) -> roundEnd -> scoreboard(1) -> howTo(2) -> round(2)
  -> scoreboard(2) -> howTo(3) -> round(3, lastRound true) -> scoreboard(3) -> ceremony -> ended. Pause/resume in
  round 1 toggles `paused` true then false.
- Illegal, each returns null: skip at scoreboard(1); pause at setup and at scoreboard; second pause; resume when not
  paused; NightRoundStarted(1, false) from setup; NightHowTo(2) from setup; NightHowTo(3) from scoreboard(1);
  NightRoundStarted(2, false) in howTo(1); NightRoundEnded(2, false) in round 1; NightRoundStarted(1, true) in a
  3-round night; NightCeremony at scoreboard(1); NightLastRoundDoubled(2) in round 2 of 3; NightSetup(5) on a 3-round
  flow; every event after ended (5 events).
- Joined/left: legal at setup (round 0), howTo (1), roundEnd (1), scoreboard (1); illegal in round (1) and for a
  wrong round (2 in roundEnd).
- Equality: NightRoundStarted(1, true) == itself, hashCode equal, != NightRoundStarted(1, false); NightRoundEnded(1,
  true) != NightScoreboard(1, true) (class is part of ==).
- toString: all 14 events checked for 'nick' (case-insensitive): none found.

## Transition table (one line per stage; "same" = state unchanged)

- setup: NightSetup (same, rounds must equal the flow's); NightPlayerJoined / NightPlayerLeft (same, round 0); NightHowTo(1) -> howTo.
- howTo: NightRoundStarted(round, lastRound) -> round; NightRoundSkipped / NightRoundRerolled (same); NightLastRoundDoubled (same, last round only); join / leave (same).
- round: NightPaused -> round, paused; NightResumed -> round, not paused; NightRoundEnded(round, lastRound) -> roundEnd (clears pause); skip / reroll / doubled (same).
- roundEnd: NightScoreboard(round, lastRound) -> scoreboard; join / leave (same).
- scoreboard: NightHowTo(round + 1) -> howTo when round < rounds; NightCeremony -> ceremony when last round; join / leave (same).
- ceremony: NightEnded -> ended.
- ended: nothing (every event returns null).

## Decisions

- NightSetup is legal only at setup, round 0, with rounds equal to the flow's, and changes nothing. There is no flag that stops a second NightSetup.
- NightEnded is legal only from ceremony. Nothing in the brief ends a night early (no players, host away); see question 4.
- A round can end while paused (NightRoundEnded clears the pause). Brief said nothing; chosen so a timer or time-up cannot get stuck.
- Skip, reroll and the doubled announcement are not blocked by a pause. Brief said nothing about pause for them.
- Join and leave require the event's round to equal the flow's round, so a stale round number is illegal.
- `toString` prints the facts map (e.g. `NightRoundStarted{round: 1, lastRound: true}`); the `==` and `hashCode` are on the base class, not repeated in each of the 14 subclasses (fewer lines, same behaviour).
- `NightFlow` has a private constructor; only `start` builds a new flow, so a bad stage cannot be made from outside.

## Self-check (docs/review-rules.md part A)

1. Host setups: not applicable (pure Dart, no host UI). The 3-round walk test covers the flow for every host type alike.
2. Kept state: starts at `NightFlow.start` (setup, round 0); ends at `ended`; an ended flow refuses everything (test "ended accepts no event at all").
3. Combinations: pause with round end (decision above); skip / reroll during pause (decision above); host away, player away, "Get ready", dropped link: not modelled here; join / leave only between rounds (test "a join or leave is legal between rounds..."); results / leaving: scoreboard then ceremony then ended (walk test).
4. Files: only the three in the brief's allow list plus this report.
5. Stop: none needed.
6. Looks: no UI in this job; no widget, no size, no look.

Not read: `docs/briefs/m17/night1a/probe-n1a.patch` (named under `probe:`, not in `read:`). The probe was not applied or checked.

## Hand-over

- `night_flow.dart` is not imported by any other file yet; wiring is a later job.
- The brief asks for "about 270 lines at most"; the file is 309 lines. Under the 380 limit, so not split. Trimming docs would bring it under 270 if wanted.

## Questions

1. Should a second NightSetup be illegal? It needs a flag (or a new stage) to know it has already happened; I did not add one.
2. Should a night be able to end early (no players left, host away, link dropped)? Only NightEnded from ceremony exists; NightReason.noPlayers has no event to use it.
3. Should a round be allowed to end while paused (time-up during a pause), or must the host resume first?
4. Should skip, reroll and the doubled announcement be blocked during a pause?

## Commit message — a draft

party_host: NightFlow stage machine and NightEvent contract (night1a)

Adds the pure Dart NightFlow state type and the sealed NightEvent contract for a night's transitions:
setup, how-to, round start and end, scoreboard, ceremony and ended, plus the last-round doubled
announcement, skip, reroll, pause, resume, and player joined or left between rounds.

Events carry facts only (round numbers, last-round flag, avatar ids, reason codes), never nicknames.
apply() returns the next flow, or null for an event that is not legal now; ended accepts nothing.
Not wired into party_night.dart or night_state.dart yet; no UI.

Tests are in test/night_flow_test.dart (14, written first; they failed to compile before the library existed).

## Status row

M17 night1a: NightFlow stage machine and 14 NightEvent facts done in party_host (pure Dart, tests green, not wired); open: wiring into party_night, the four questions in n1a-report.md (second setup, early end, pause and round end, pause and skip).

## Delete

- none
