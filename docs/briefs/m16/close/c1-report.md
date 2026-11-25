# c1 report: ArenaBoardOptions for ArenaHud and ArenaBoard

## Summary

Refactor only, no visual or behaviour change. `ArenaBoardOptions` (ownId, round, rounds, showHud) now carries the four values that ArenaHud and ArenaBoard took one by one, which brings both constructors to 5 parameters (key not counted).

Files changed:
- `packages/test_game/lib/src/arena_board_options.dart`: new. `const` value object, dartdoc on the class and every field; the field docs moved from ArenaBoard and ArenaHud (the "Round N of M" rule, "(you)", the strip's space staying).
- `packages/test_game/lib/test_game.dart`: exports `arena_board_options.dart` after `arena.dart`.
- `packages/test_game/lib/src/arena_hud_widgets.dart`: ArenaHud takes snapshot, roster, characters, oneLine, options (default `const ArenaBoardOptions()`). `_RoundRow` takes `options` instead of `round`/`rounds`; `ownId` is read as `options.ownId`. 351 lines (was 364).
- `packages/test_game/lib/src/arena_view_widgets.dart`: ArenaBoard takes snapshot, roster, characters, options, onResize. It passes `options` to ArenaHud and reads `options.showHud` for the Visibility. 192 lines (was 206).
- `packages/test_game/lib/src/arena_module.dart`: `options: ArenaBoardOptions(ownId: view.playerId)`.
- `packages/test_game/lib/src/arena_view.dart`: `options: ArenaBoardOptions(showHud: widget.showHud, round: widget.round, rounds: widget.rounds)`. ArenaView's own fields are unchanged.
- `packages/test_game/test/arena_hud_map_test.dart`: ArenaHud gets `options: const ArenaBoardOptions(round: 1, rounds: 3)`.
- `packages/test_game/test/arena_hud_round_test.dart`: ArenaHud gets `options: ArenaBoardOptions(round: round, rounds: rounds)`.
- `packages/test_game/test/arena_hud_test.dart`: ArenaBoard gets `options: ArenaBoardOptions(ownId: ownId)`.

Not changed: `arena_hud_coins_test.dart` and `arena_identity_test.dart`. They pass neither removed parameter (only snapshot, roster and, for identity, characters), so they compile and pass as they are. Nothing was deleted or weakened.

Decisions:
- `oneLine` stays a direct ArenaHud field, as the brief's list says; ArenaBoard still computes it from the box height.
- ArenaHud receives the whole options object, though it ignores `showHud`. This keeps the constructor the brief asks for.
- The `_RoundRow` private widget takes `options` too, so its constructor drops from 5 fields to 3.

## Checks

- `tools/mine.sh`: format, analyze and tests for packages/test_game. Output: `RESULT: ok: 9 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`, and `OK 259 tests packages/test_game`. The format step reformatted 9 files, which is `dart format` at 120 columns. A second run was not needed, since the first run was clean.
- Tests-first: exempt, as a refactor. The existing tests, moved to the new constructors, are the proof. Their expectations were not edited.
- Self-check (review-rules part A):
  1. Host setups: TV and phone paths both build ArenaBoard through ArenaView/ArenaModule; covered by the arena_hud_test and arena_identity_test widget tests (259 passed).
  2. No kept state is added; nothing starts or ends.
  3. No new state combines with the pause menu, the host away, a dropped link, the results or leaving; the change is constructor plumbing only.
  4. Stayed inside the allow list.
  5. Nothing stopped.
  6. Looks: the HUD look tests (arena_hud_map_test, arena_hud_round_test, arena_hud_test) pass in both looks and at the sizes they already run.

## Hand-over

Refactor complete. Analyze and the package's 259 tests pass under `tools/mine.sh`. I did not run `tools/check.sh`; that is the runner's job.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m16 close c1: ArenaBoardOptions for ArenaHud and ArenaBoard

Adds ArenaBoardOptions (ownId, round, rounds, showHud) as a const value
object and passes it to ArenaHud and ArenaBoard in place of their four
separate parameters, so both constructors take at most 5 parameters.
No visual or behaviour change. The HUD tests move to the new constructors
unchanged in what they expect.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 close c1: done: ArenaBoardOptions value object; ArenaHud and ArenaBoard take it (5 params each); callers and HUD tests moved, 259 pass. Open: nothing in c1.

## Delete

- none
