job: night1a e0a — the Arena race sets roundResult with placing, shaped like the Bumper Round's
stop: no change to the Bumper Round, scoring rules or party_host; the race's play, timing and snapshot stay as they are
read: docs/briefs/templates/COMMON.md · packages/test_game/lib/src/arena.dart:100-135,165-222 (the race, _result) · packages/test_game/lib/src/arena_bumper.dart:200-250 (the result's shape) · packages/game_kit/lib/src/round_result.dart:1-60,74-115 · packages/test_game/test/arena_bumper_test.dart:160-200 (how a result is tested) · plan, quoted: "e0a: Arena race sets roundResult with placing, in the same shape as the Bumper Round. New test, fails on old code (null result)"
changes: raceResultPlacing
model: haiku
turns: 35
expected-min: 25
do:
1 In _RaceGame._updatePlayer, where a player reaches the goal, set `_result = RoundResult(game: arenaGame, winners: {p.id}, draw: false, points: const {}, stats: {every player: {'place': n}}, lines: {every player: RoundLine(outcome: win for the winner, loss for the others)})`. Placing: the winner is 1; the others are 2, 3... by straight-line distance from their position to the goal rect centre, nearest first, ties by player id. Points stay empty on purpose (the night's scoring turns placing into points later, n1d): say so in a comment. Set `_result = null` in `_newRound`. Update the stale doc on `roundResult` (arena.dart:~126-133): the race sets it too, when someone reaches the goal.
2 grep how ArenaView and the session use roundResult to finish a round (arena_view.dart:140-150): if a race round in a night now finishes on this result, say so in the report; do not change that code.
3 Tests: NEW packages/test_game/test/arena_race_result_test.dart (use the existing maps helper in the test support folder and the way arena_test.dart drives a race to the goal): null before the goal; after the goal the winner is the only winner, place 1, the others placed by distance (set positions so the order is known), outcomes win and loss, points empty, game 'arena'; null again once the break ends and the next round starts. The first test fails on old code. Also run the existing test_game arena tests.
4 Report: what you found at step 2.
5 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/test_game/lib/src/arena.dart · packages/test_game/test/arena_race_result_test.dart · packages/test_game/test/arena_test.dart
check: format analyze test_game
report: docs/briefs/m17/night1a/e0a-report.md
