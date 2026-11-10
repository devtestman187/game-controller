job: M14 g2: split arena.dart (487 lines, the one size FAIL) so the Bumper Round can share the marbles' movement (docs/design/party-night.md sections 7 and 13, wave 1)
pub: no
stop: after it.
read: docs/design/party-night.md (sections 2 N10, 7, 13) · docs/briefs/m14/scan-m14-refresh-report.md (section 3) · packages/test_game/lib/src/arena.dart, arena_session.dart, arena_snapshot.dart, arena_moments.dart, arena_painter.dart · packages/test_game/lib/test_game.dart · packages/test_game/test · docs/project-notes.md (the size rule) · docs/coding-guidelines.md · docs/review-rules.md

The Bumper Round (G9, job b1) adds contacts, coins and a clock to the Arena, on the same marbles, walls and hazards as today's race. `arena.dart` is 487 lines, over the 400 limit, so it is split first, by moving code, with no change in behaviour. Claude's design:
1. **Three parts by content:**
   - **the events**: `GameEvent`, `GameEventCause`, the input type and anything the session and screen read of an event;
   - **the field and the marbles**: the constants, walls, hazards and goal, `ArenaPlayer`, and the movement every mode shares: a marble's step from its input (`_updatePlayer`'s movement and dash), `_move` with its sub-steps, `_resolve` against walls, `_checkHazards`. Make them callable by a second mode without copying: functions or a small class that take the field, the player, the input and `dt` and return the events. Keep the rules' current order of operations exactly;
   - **the race**: `ArenaGame` with `ArenaPhase`, the goal, the winner, the round break and `_newRound`, calling the shared movement.
2. Public names stay as they are (`ArenaGame`, `ArenaPlayer`, `GameEvent`, …) and `test_game.dart` exports the same API, so the session, the snapshot, the painters and every test compile unchanged.
3. Each file under 300 lines if it can be done without contortion; `arena.dart` itself under 400 in any case.

tests (each failing first, if any): the job is a move, so the proof is that **every existing arena, host and tv test passes unchanged**. Add one test only if a moved function gains a public seam (the shared movement called on its own gives the same result as through `ArenaGame.update` for one fixed input sequence).

in the report: the files and their line counts; what moved where; the shared movement's signature; test counts before and after (identical); `tools/review.sh` showing the size FAIL gone.
self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · a move is a move: no renames, no rewrites inside moved code, no change in the order of operations · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch packages/puzzle_game, packages/party_host, packages/game_kit or assets (other jobs are working there)
allow: docs/briefs/m14/g2-arena-split-report.md · packages/test_game/lib · packages/test_game/test
check: format analyze arena host tv
report: docs/briefs/m14/g2-arena-split-report.md
