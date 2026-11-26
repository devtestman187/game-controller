# n1b report

tests-first: exempt, the consumer is new and its test feeds a whole night.

## Files
- packages/party_host/lib/src/night/night_captions.dart: new, `captionFor` exhaustive switch over NightEvent, private reason and last-round helpers.
- packages/party_host/test/night_captions_test.dart: new, 4 tests (full night, 14 kinds, avatar id only, last round and double).

## Checks
tools/mine.sh: format, analyze and 4 party_host tests ok.

## Events the flow could not express
None. All 14 kinds are legal in the walk. Note: NightHowTo has no lastRound fact, so its caption cannot say "last round".

## Caption list (full night)
1. Tonight: 3 rounds
2. Avatar a1 joined at round 0
3. How to play round 1
4. Round 1 skipped: the host chose it
5. Round 1 starts
6. Round 1 paused
7. Round 1 resumed
8. Round 1 is over
9. Avatar a1 left at round 1: a player left
10. Scoreboard after round 1
11. How to play round 2
12. Round 2 starts
13. Round 2 rerolled: time ran out
14. Round 2 is over
15. Scoreboard after round 2
16. How to play round 3
17. Round 3 is the last round: doubled points
18. Round 3 starts (last round)
19. Round 3 is over (last round)
20. Scoreboard after round 3 (last round)
21. The ceremony begins
22. The night is over

## Questions
None.

## Commit message
Add stub captionFor for NightEvent (night1a n1b)

captionFor turns each NightEvent into a plain caption from facts only
(rounds, last round, doubled points, avatar ids, reason phrases).
The test folds a full 3-round night through NightFlow and checks the
exact captions. Thumby (P4) replaces the stub.

## Status row
n1b: stub captionFor and full-night caption test done; Thumby voice, UI and wiring open.

## Delete
- none
