# night1c f3 report

## Summary

What changed:
- Item 1 (puzzle Next reports to the controller): `puzzle_pick.dart` `_next` now calls `roundEnded()` then `next()` on `nightFlowControllerProvider`, before `recordRound`, copied from `game_screen.dart` `_next`. `puzzle_screen.dart` gets the import `../night/night_flow_provider.dart`. New test in `puzzle_pick_test.dart`: a night's Shape Race round, after Next, leaves the controller at `NightStage.scoreboard`, round 1.
- Item 2 (startRound gate): `night_scoreboard_screen.dart` `startRound` returns false unless the screen is mounted, its route is current (`ModalRoute.of(context)?.isCurrent`), and, for the Bumper Round, `nightBumperRoundReady`. New test in `night_round_hook_test.dart`: a route pushed over the scoreboard when the how-to timer fires opens no game, and the controller stays at the how-to card, round 2.
- Item 3: `replaceRound` dartdoc extended with the "skipped or rerolled game gives nobody points" line. Body still empty.
- Item 4: new test in `night_controls_test.dart`, "a night of 5 rounds plays 5 rounds after skips and rerolls", using the file's own helpers. Exempt from tests-first (pins behaviour that already holds).

Test counts seen: `tools/mine.sh` printed `OK 29 tests packages/party_host` and `RESULT: ok: 6 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`. `dart analyze` on the six changed files: `No issues found!`

Computed values for the item 4 expectations (round-by-round, from the controller's own pacing):
- Skip at round 1's how-to card: `replaced` gets `(1, false)`; round 1 then starts after one full `howTo`.
- Round 1 ends, then `results + scoreboard + howTo` elapses: round 2 starts. Reroll in play: `replaced` gets `(2, true)`, round stays 2.
- Round 2 ends, same elapse: round 3 starts. Skip in play `(3, false)`, reroll in play `(3, true)`.
- `_play` finishes rounds 3 to 5. Expected `NightRoundStarted` rounds `[1, 2, 3, 4, 5]`, five `NightRoundEnded`, `replaced == [(1,false),(2,true),(3,false),(3,true)]`, stage `ended`. The test passed under `tools/mine.sh`.

Fail-on-base reasoning (not run; see Questions):
- Item 1 test: on base `_next` never calls `roundEnded`/`next`, so the stage stays `round` after Next; the `scoreboard` expectation fails.
- Item 2 test: on base `startRound` has no route check, so `GameScreen` opens under the dialog; `findsNothing` fails.

Decisions:
- The Bumper check is variant-specific (`variant == bumperRound && !nightBumperRoundReady`), not a blanket check. A blanket check would also block Shape Race, which the footer never gates.
- The new tests sit in the existing files the brief names, because the allow list has no new file.

Self-check (docs/review-rules.md part A):
1. Host setups: TV host only. Puzzle test uses `pumpHost` default (TV). Phone host, joined phone, and older peer are not covered by these tests.
2. Kept state: the night controller starts at round 1 and ends at `ended`; `night_controls_test.dart` "a night of 5 rounds..." shows the 5-round start/end.
3. Combination with pause, host away, player away, "Get ready", dropped link, results, leaving: pause with skip/reroll is covered by the existing "skip and reroll while paused" test; the dialog case is covered by the new hook test. Host away, dropped link, leaving mid-round are not covered by new tests.
4. Stayed in the allow list: yes, six files, no others touched.
5. Stop rather than overstep: nothing needed stopping.
6. Looks: no visual change (no widget or layout edits); menu and TV look not separately rendered.

## Hand-over

- `puzzle_screen.dart` is 379 lines, one under the 380 limit. The next change there must split it.
- `replaceRound` still has an empty body; a skip or reroll screen is for a later batch.
- The Bumper guard cannot be exercised by a test while `nightBumperRoundReady` is a `const true`.

## Questions

1. The brief says new tests go in a NEW file, but item 1 and item 2 name existing files and the allow list has no new file. I put them in the existing files. Is that accepted?
2. I did not run the new tests against the base code (no git stash or checkout allowed). The runner must prove they fail on base; my reasoning above says they do.
3. Should the Bumper guard block only the Bumper variant (as written) or every variant, as the brief's literal "unless nightBumperRoundReady" could be read?
4. The puzzle test covers the TV host only. Does a phone-host Shape Race Next need its own test?

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
party_host: puzzle Next ends its night round; startRound checks route

Shape Race's Next now calls roundEnded and next on the night controller,
as the bumper round's Next does, so the scoreboard follows the round.
The scoreboard's startRound opens a game only when its route is current
and, for the Bumper Round, the bumper is ready, so a dialog on top of
the scoreboard keeps the how-to card waiting. replaceRound's dartdoc says
a skipped or rerolled game gives nobody points only once it closes the
old screen. A test pins a 5-round night with skips and rerolls.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

m17 night1c f3: done: puzzle Next reports to the night controller; startRound checks route and Bumper readiness; 5-round night with skip/reroll pinned. Open: replaceRound still empty (skip/reroll screen later); phone-host Next and base-run proof not done here.

## Delete

- none
