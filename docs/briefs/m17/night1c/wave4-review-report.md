# night1c wave 4 review (f3)

## Summary

Verdict: small fixes. Counts: 0 must, 3 should, 4 could.
Top three:
1. `night_scoreboard_screen.dart:86` the Bumper check reads `!nightBumperRoundReady`, which is `const true` (`party_night.dart:21`), so the branch is dead and untested.
2. `night_scoreboard_screen.dart:95` is 121 columns, one over the 120-column limit.
3. The base-run proof the brief asks for (items 1 and 2 fail on base) was not done; the worker's reasoning only.

## Findings

- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:86 `!nightBumperRoundReady` is dead while `nightBumperRoundReady` is `const true` (party_night.dart:21), and no test can reach it → remove the branch and its words at lines 80-81 until the flag can be false, or raise it with Claude (see Decisions).
- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:95 the dartdoc line is 121 columns, over the 120-column limit → rewrap the sentence "which holds only once…" onto a new `///` line.
- **should** packages/party_host/test/puzzle_pick_test.dart:150 and packages/party_host/test/night_round_hook_test.dart:108 the brief requires items 1 and 2 to fail on the base code, and the report says the base run was not done ("not run") → run both on base (with `tools/mine.sh` or the runner's base check) and record the result; if either passes on base it becomes a must.
- **could** packages/party_host/lib/src/ui/puzzle_pick.dart:226 the three lines (`ref.read(nightFlowControllerProvider)`, `roundEnded()`, `next()`) are copied from packages/party_host/lib/src/ui/game_screen.dart:268 → one shared helper, if Claude wants one place for the night's round-end call.
- **could** packages/party_host/lib/src/ui/puzzle_screen.dart:379 the file is 379 lines, one under the 380 limit, and the import was added in this job → the next job that touches it must split it first (the worker says this too).
- **could** packages/party_host/test/night_round_hook_test.dart:128 the dialog test checks only the stage after the timer fires; it does not check what happens once the dialog closes → add the footer-start check now, or record it as open in the status row.

## Decisions to confirm

- The Bumper guard is variant-specific (`night_scoreboard_screen.dart:86`), not the brief's literal gate. Safe: the footer never gates Shape Race. But the brief's "unless nightBumperRoundReady" is a different rule, and the guideline's dead-branch rule applies while the flag is const.
- After `startRound` returns false, the controller does not re-arm its timer (`night_flow_controller.dart:265-270`, a file this job may not change), so the night waits at the how-to card until a host press. Confirm this is wanted.
- The new tests sit in existing files (`puzzle_pick_test.dart`, `night_round_hook_test.dart`, `night_controls_test.dart`). The guideline says new tests go in a NEW file; the brief named the existing files. Confirm which rule wins.
- The puzzle Next calls `roundEnded()` then `next()` before `recordRound`, the same order as `game_screen.dart:268-273`. Consistent, including the last round (reveal path).

## Could not check

- Fail-on-base for items 1 and 2: not run (read-only job; no checkout allowed to me). Reasoning only.
- Test results (`OK 29 tests`, `RESULT: ok`) were not re-run here; they are the worker's claim.
- Item 4 expectations (`[1,2,3,4,5]`, five ends, `replaced == [(1,false),(2,true),(3,false),(3,true)]`) were checked by reading `night_controls_test.dart:266-294` and the helpers, not by running them.
- Phone-host and joined-phone behaviour of the puzzle Next and the route check: no test, not checked on device.
- Helpers used by the new puzzle test (`lockEveryPiece`, `endRound`, `navigated`, `openNight`, `pickShapeRaceRound`) exist in the test support files; compile not run.
