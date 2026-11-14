# M14 cleanup1 c1 — review of the screen job

## Summary

`clean` — must 0, should 0, could 2.

- Both brief items are done as written: `_stageBody` takes `NightState?`, and `_game` is guarded with a local
  returning `const SizedBox.shrink()`, matching the old `_field()` (55aa6a1^ game_screen.dart:357-360).
- The report's type correction is right: `partyNightProvider` is `NotifierProvider<PartyNight, NightState?>`
  (party_night.dart:112), `NightState` is night_state.dart:83, and the new import matches three other screens.
- Re-run here: format PASS, `dart analyze` PASS, `flutter test` in party_host PASS (402 tests; the report's 399
  was taken before c3's `sound_loop_protect_test.dart` landed in the same commit).
- The only code finding: `_result!` at `game_screen.dart:354`, pre-existing and outside this brief's scope.

## Findings

- **could** packages/party_host/lib/src/ui/game_screen.dart:354 `_result!` has no proof on the line before it
  (guidelines §2 type escapes); the arm and the `_stage == _Stage.results` check prove it only indirectly → in a
  later job guard it with the same local-and-return shape used here for `_game` (the brief scoped only `_game`).
- **could** docs/briefs/m14/cleanup1/c1-screen-report.md:21 the size claim "`_stageBody` about 34 lines" is 38
  lines by count (`game_screen.dart:329-366`), inside the limit either way → correct the figure if Claude quotes it.

## Decisions to confirm

1. The brief names `PartyNight?` from `party_night.dart`; the worker used `NightState?` from `night_state.dart`.
   The code is right and the brief's parenthetical is wrong — accept, and fix the brief wording next time.
2. The `switch` went from an expression to a statement. A `return` inside the arm needs it, `analyze` finds no
   exhaustiveness gap, and the waiting arm's widget is unchanged — safe.
3. The guard returns for the whole playing/results arm, so a null `_game` in the results stage now also drops
   `ArenaResults`, where the old `_field()` dropped only the field. Unreachable today (the results stage is entered
   only from `_finished`, after `_start`/`_again` set `_game`), and the brief prescribed it — but the report does
   not say so.
4. No test proves the guard; the brief exempted it and the path needs an unset `_game` in a playing stage the screen
   cannot enter. Accept unless Claude wants a comment on the guard or a test seam.

## Could not check

- The range 09071cb..3fcbb8c is a single commit holding c1's `game_screen.dart` change plus c2's and c3's reports
  and `sound_loop_protect_test.dart`, so the diff cannot show that c1 alone touched no other code; the 402-test
  total above is HEAD's tree, not c1's.
- `run-findings.md`'s one entry (puzzle_game's `board_cache_state_test` passes on the old code) concerns another
  job, not this one.

## Commit message

```
Review c1-screen: typing and the null guard match the brief

The stage body now takes NightState?, the type partyNightProvider holds,
and guards _game with a local before GameField, as the old _field() did.
Both brief items check out; sizes, imports and the two listed decisions
hold. The one finding is the pre-existing _result! beside the new guard,
left out of this brief's scope. Format, analyze and the 402-test host
suite pass here.
```

## Status row

M14 cleanup1 c1 review: `clean`, two coulds (`_result!` at game_screen.dart:354, a size figure in the c1 report) left to Claude; c2 and c3 reviews open.

## Delete

- none
