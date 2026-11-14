# b012a-measure — the time a player moves against the time they place (B-012a)

## Summary

- **Built:** per player per round, `placeS` counts the time holding a piece within
  `positionTolerance` of a free outline it could fill (angle ignored), once per step in `_turn`;
  `moveS = the side's clock − placeS`, so the two add up to the round clock exactly. Both go into
  `player_result` and so into `puzzle` `gameStats` (count/mean/max), with no recorder change.
- **Numbers that matter:** 60 steps of 1/60 s holding away give `moveS` 1.0 s; 30 steps of 1/60 s over
  the outline give `placeS` 0.5 s; a race side finishing at 40 s (799 + 1 steps of 0.05 s) has
  `moveS + placeS` = 40.0 s; 11 frames of 100 ms report `moveS` 1.1 s, `placeS` 0.0 s; means of 72 s
  moving and 24 s placing print as `75%`.
- **Level tag:** `_endTags` writes `level_easy|medium|hard`, `RoundTag.level` names it, and "By game
  and feature" prints a `level <name>` row between the map rows and Robo's.
- **Report table:** new "By player: moving and placing" (`report_players.dart`): session, player,
  rounds, moving s, placing s, moving share (mean moving / mean of both), after "By game and feature".
- **Decisions:** `moveS` is the clock minus `placeS` because the per-step hook that sees an
  empty-handed player is `puzzle_tick.dart`, outside `allow:`; `placeS` counts in `_turn`, which runs
  once per carrier per step with `dt` (`_carrySmall` has none). One decimal, like `rotatingS`.
- **Blocked, needs files outside `allow:`:** (1) `puzzle_session_test.dart` pins two whole tag lists
  (`:203`, `:218`); adding `'level_easy'` to both fixes them. (2) The environment denies edits to
  `docs/PRD-v2.md`, so the line-203 note is **not** written.
- **Not done:** nothing else. The table shows means per session, not per level: the summary keeps no
  `player_result` per round, so the level rows do that comparison.
- **On a device:** play a Medium puzzle, check the summary's `puzzle` `gameStats` for `moveS`/`placeS`
  and the report's new table; "most of it moving" should read as a share well over 50%.
- **Checks:** `tools/check.sh format analyze puzzle metrics` — format PASS, analyze PASS, metrics PASS
  (111 tests), puzzle FAIL (420 passed, 2 failed: the two tag-list tests above). The new tests would
  fail on the old code (no `moveS`/`placeS` key, no `level_` tag, no `movingPlacingTable`).

## Self-check (review-rules part A)

1. **Every host setup:** no host-specific code; the numbers are per player in the rules, so TV, PC, phone
   host, joined phone and one build older all report them. Not affected by host type; `player_result` is
   additive, so an older reader ignores the two keys. Test: `puzzle_measure_test` "the round reports each
   player's moving and placing time, and its level" (MemoryGameHost, one player).
2. **When kept state starts and ends:** `placeS` starts at 0 when the player joins (`PuzzlePlayer`) and
   only grows while the round is playing and the player holds a piece; it stops at the result because
   `PuzzleGame.update` returns before `_turnAll` once the phase is not playing, and it is written once,
   in the report that is written once (`PuzzleReport.write`). Nothing runs with no round. Test: "a snap
   adds no time to either number" shows placing stops when the piece leaves the player's hands; the
   session test shows one `player_result`.
3. **How a new state combines with the others:** none — the change adds two counters and a tag, no
   pause, wait or input state. A paused round steps nothing, so neither number moves. Test: not
   separately tested (no new state); the fields are inert while `phase != playing` (`puzzle_measure_test`
   snap test).
4. **Stay in the job's folder:** every file I wrote is in `allow:` (see Blocked for the two I did not
   touch).
5. **Stop rather than overstep:** stopped at the two files outside `allow:` and the denied PRD path
   (Blocked); did not edit either.

## Files changed

- `packages/puzzle_game/lib/src/puzzle_player.dart` — `placeS` (seconds placing) and
  `moveS(clockS) = clockS - placeS`, both documented.
- `packages/puzzle_game/lib/src/puzzle_carry.dart` — `_isPlacing` (a held piece within the drop's
  position tolerance of a free outline it is a twin of) and the one-line accrual at the top of `_turn`,
  which runs once per carrier per step with `dt`.
- `packages/puzzle_game/lib/src/puzzle_report.dart` — `moveS` and `placeS` in each `player_result`, to
  one decimal like `rotatingS`.
- `packages/puzzle_game/lib/src/puzzle_session.dart` — `_endTags` writes `level_<level>` first.
- `packages/puzzle_game/test/puzzle_measure_test.dart` — 6 tests (below).
- `packages/metrics/lib/src/report_games.dart` — `RoundTag.level`, a `level` row group (keys
  renumbered: map 1, level 2, robo 3, chaos 4, night 5), rows and docs.
- `packages/metrics/lib/src/report_players.dart` — new `movingPlacingTable`.
- `packages/metrics/lib/src/report_table.dart` — the table is printed in `report()` after "By game and
  feature".
- `packages/metrics/lib/metrics.dart` — exports `report_players.dart`.
- `packages/metrics/test/report_players_test.dart` — 4 tests.
- `packages/metrics/test/report_games_test.dart` — 1 test for the level rows.
- `docs/PRD-v2.md` — **not changed** (denied, see Blocked).

## Computed test values

- 60 steps × 1/60 s = 1.0 s moving (`placeS` 0, nothing within the tolerance).
- 30 steps × 1/60 s = 0.5 s placing; moving unchanged over those steps.
- Empty-handed: 60 steps of 1/60 s add 1.0 s of moving.
- Snap: placing keeps the 30 steps plus the drop step's 1/60 s (≈ 0.5167 s) and then stops; the 60 steps
  after it add 1.0 s of moving.
- Race: 799 steps of 0.05 s = 39.95 s, the 800th finishes the side at 40.0 s; `moveS + placeS` = 40.0 s
  (asserted `closeTo(40, 1e-9)`; the report would round each to a tenth).
- Session: 10 frames of 100 ms = 1.0 s, the finish frame 1.1 s; `moveS` 1.1, `placeS` 0.0.
- Share: 72 / (72 + 24) = 0.75 → `75%`; means 0 and 0 → `-`.
- Level rows: 60 s = 1.0 min, 120 s = 2.0 min; rows print `puzzle`, `map playroom`, `level hard`,
  `level medium`, `robo easy` in that order.

## Decisions (low-usage mode)

- `moveS` derived from the side's clock: the per-step hook for a player with empty hands is in
  `puzzle_tick.dart`, outside `allow:`, and the subtraction is the same number, exact, and keeps the sum
  property the design asks for.
- `placeS` counted in `_turn`: `_carrySmall` has no `dt`, and `_turn` is called once per carrier per step.
- The near test ignores the angle (the design says the angle may still be wrong) and ignores filled
  outlines (a filled outline is not one the piece could fill).
- Level rows sit between maps and Robo's level, because a level is compared the way a map is.
- The per-player table does not group across sessions: a row is one player in one session, which is what
  the summary's `gameStats` are.
- One decimal for both seconds, matching `rotatingS`; a reader can therefore see a sum up to 0.1 s off
  the clock, while the rules keep the exact value.

## Questions

1. `packages/puzzle_game/test/puzzle_session_test.dart` needs `'level_easy'` added to two expected tag
   lists (`:203`, `:218`). It is outside this job's `allow:`.
2. `docs/PRD-v2.md` line 203 could not be edited (permission settings deny that path for both Edit and
   Bash). Wanted text: "time moving against time placing each piece (seconds a player, measured since
   B-012a)" in place of "time carrying each piece".
3. A player who drops and rejoins mid-round gets a fresh `PuzzlePlayer`, so their `moveS` includes the
   time before the drop (the side's clock continues). Worth a decision if the away/rejoin flow matters
   for these numbers.
4. The recorder path (`session_recorder.dart:108-116` maps any numeric `player_result` key) is not
   covered by a test in this job: `party_host` tests are outside `allow:`. The puzzle side is tested
   (both keys are numbers in `player_result`) and the metrics side is tested (both keys land in the
   table), but not the middle.

## Commit message

Measure the puzzle's time spent moving against time spent placing

Add moveS and placeS to each player's player_result, so they arrive as
puzzle gameStats and the report can compare moving with placing.
placeS counts steps holding a piece near an outline it could fill; moveS is
the side's clock minus placeS, so the two add up to the round clock.
Tag Shape Race rounds with their level and give the report a level row.
Add the "By player: moving and placing" report table with the moving share.
Not in this commit (outside allow): the two tag lists in puzzle_session_test
and the PRD line-203 note.

## Status row

| M14 bugs6 b012a | B-012a built ([b012a-measure-report.md](b012a-measure-report.md)): `moveS`/`placeS` per player in `player_result` → `gameStats`, `level_*` round tag with a report row, and the "By player: moving and placing" table; new tests in `puzzle_measure_test` and `report_players_test`, metrics 111 pass. Stopped: `puzzle_session_test`'s two exact tag lists need `level_easy` (outside allow) so puzzle has 2 failing tests, and the PRD line-203 note is blocked by permissions. Open: those two edits, then b012b |

## Delete

- none
