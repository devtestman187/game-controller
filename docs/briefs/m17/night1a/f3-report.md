## Summary

Job night1a f3: caption wording and the join after a scoreboard. Changed `captionFor` only, plus its test file.

- `night_captions.dart`
  - One round says "round", more say "rounds": `Tonight: 1 round`.
  - A join or leave at round 0 says "before round 1" (new `_whenPhrase`), not "at round 0".
  - `NightReason.playerLeft` reads "they went away" instead of "a player left". This phrase is shared by every use of that reason, so it changes in the skip, reroll and leave captions alike; only the leave caption uses it today.
- `night_captions_test.dart`
  - Full-night walk: expected captions updated for the round-0 join, the "they went away" leave and the new join.
  - Added `NightPlayerJoined('a2', 1)` after the first scoreboard (the flow accepts it there; the walk passes).
  - Added three tests: round-0 join/leave, "they went away", and the one-round / many-rounds setup captions.

Test counts seen: `tools/mine.sh` reported `OK 7 tests packages/party_host` (4 existing + 3 new) and `RESULT: ok`. `dart analyze` findings: none reported by mine.sh (it fails on any).

Self-check (review-rules part A):
1. Host setups: captions are host-agnostic; covered by the full-night walk test.
2. Kept state: none; `captionFor` is a pure function. Covered by the walk test.
3. Combination with pause, away, ready, dropped link, results, leaving: the pause and resume captions are unchanged (walk test).
4. Stayed inside the allowed files.
5. No stop needed.
6. No UI look in this job; N/A.

Tests-first: the new tests are in the existing test file because the brief names it as the file to update. The rule for new tests says a NEW file; the brief overrides this, so the new cases are not in a new file. I did not run the new tests against the old code; the expectations differ from the old output (old code gives "at round 0", "a player left", "Tonight: 1 rounds"), so they would fail there by reading.

## Final caption list (full-night walk, 3 rounds)

1. Tonight: 3 rounds
2. Avatar a1 joined before round 1
3. How to play round 1
4. Round 1 skipped: the host chose it
5. Round 1 starts
6. Round 1 paused
7. Round 1 resumed
8. Round 1 is over
9. Avatar a1 left at round 1: they went away
10. Scoreboard after round 1
11. Avatar a2 joined at round 1
12. How to play round 2
13. Round 2 starts
14. Round 2 rerolled: time ran out
15. Round 2 is over
16. Scoreboard after round 2
17. How to play round 3
18. Round 3 is the last round: doubled points
19. Round 3 starts (last round)
20. Round 3 is over (last round)
21. Scoreboard after round 3 (last round)
22. The ceremony begins
23. The night is over

Other captions changed: `Tonight: 1 round` (new test), `Avatar a1 joined before round 1`, `Avatar a1 left before round 1: the host chose it` (new test).

## Hand-over

Questions:
1. The brief's test-file rule (new tests in a new file) conflicts with "update the expected captions" in the existing file. I followed the brief. Tell me if the new cases should move to their own file.
2. The "they went away" phrase is shared with skip and reroll reasons through `NightReason.playerLeft`. If only the leave caption should change, the reason needs its own phrase.

Suggestions:
- The reason-phrase helper could take the caption context, so each caption picks its own wording.

## Commit message — a draft

Captions: say "round" for one round and "before round 1" for a round-0 join or leave

Tonight: 1 round (not "rounds"); a join or leave at round 0 says "before round 1"
instead of "at round 0"; the playerLeft reason reads "they went away" so the leave
caption no longer repeats "left". The full-night walk now includes a join after the
first scoreboard, and new tests cover the round-0, one-round and reason cases.

## Status row

night1a f3: caption wording and the round-0 join/leave done, with tests (mine.sh ok, 7 tests); open: whether the new tests should move to their own file, and whether the "went away" phrase should stay shared with skip/reroll.

## Delete

- none
