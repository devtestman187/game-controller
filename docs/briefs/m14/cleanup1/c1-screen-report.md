# M14 cleanup1 c1 — type and guard the game screen's stage body: report

## Summary

- **Item 1 — done, with one correction.** `_stageBody` takes the provider's state type instead of `Object?`.
  `partyNightProvider` is `NotifierProvider<PartyNight, NightState?>` (`party_night.dart:112`), so the type is
  `NightState?`, declared in `../night/night_state.dart:83` (not `PartyNight?` in `party_night.dart`). The new
  import is `../night/night_state.dart`, as `night_reveal_screen.dart` and `night_scoreboard_screen.dart` do.
  `night != null` reads unchanged; `GameScreen`'s behaviour is the same.
- **Item 2 — done.** The playing/results arm now reads `final game = _game; if (game == null) return const
  SizedBox.shrink();` before building the `Stack`, and `GameField` gets `game: game` — no `!`.
- **Decisions**
  - Used `NightState?` from `night_state.dart`: it is "the type `partyNightProvider` holds", which the brief's
    parenthetical names but mislabels; anything else would not typecheck against `build()`'s `night`.
  - Changed the `switch` from an expression to a statement: a return inside the playing/results arm needs a
    statement, and a `when game == null` guard would not promote `game` in the next case, so `game!` would return.
  - Left `_result!` in `ArenaResults` untouched: the brief covers only `_game`, and the results arm's guard is
    `_stage == _Stage.results`, which the `_finished` transition sets together with `_result`.
- **No test added.** The brief exempts this as a pure typing and null-guard clean-up of a path the screen cannot
  reach with no game; no computed test values.
- **Sizes:** `game_screen.dart` 370 lines (was 365); `_stageBody` about 34 lines. Both inside the limits.
- **Checks:** `tools/check.sh format analyze host` — format PASS, analyze PASS, host PASS (399 tests, 103 s).

### Self-check (docs/review-rules.md part A)

1. **Every host setup** — not affected: the same `GameField`/`ArenaResults` get the same values on a TV host, a
   phone host, a joined phone and an older build; proven by `game_screen_test.dart` and the 399 host tests.
2. **When kept state starts and ends** — not affected: no state is held, timed or counted; the guard reads the
   existing `_game`/`_stage` fields only.
3. **How a new state combines with the others** — not affected: the guard adds no state and owns no pause; it
   returns an empty widget only in the impossible case where a stage outruns `_start`/`_again` setting `_game`.
4. **Stay in the job's folder** — done: the only code file changed is `packages/party_host/lib/src/ui/game_screen.dart`,
   inside `allow:`; this report is the only other file.
5. **Stop rather than overstep** — one mismatch reported as a decision (the brief's `PartyNight?`/`party_night.dart`
   naming); the rest was done as written, no file outside `allow:` touched.

## Files changed

- `packages/party_host/lib/src/ui/game_screen.dart` — added the `../night/night_state.dart` import; `_stageBody`
  takes `NightState?` and is a `switch` statement whose playing/results arm guards `_game` with a local and returns
  `const SizedBox.shrink()` when it is null, passing the promoted local to `GameField`.

## Checks

- `tools/check.sh format analyze host`: format PASS (6 s), analyze PASS (17 s), host PASS (399 tests, 103 s),
  all checks passed in 126 s.

## Questions / suggestions

1. The brief's step 1 names `PartyNight?` from `party_night.dart`, but the provider holds `NightState?` from
   `night_state.dart`; a future brief should name the state type, not the notifier's class.
2. `ArenaResults(result: _result!)` keeps a `!` whose proof is the `_stage` value; if a later job hardens this
   screen, the same local-guard shape (`final result = _result; if (result == null) …`) would remove it.

## Commit message

```
Type the game screen's stage body and restore its null guard

_stageBody took Object? and passed _game! to GameField. It now takes
NightState?, the type partyNightProvider holds, and guards _game with a
local: with no game in the playing or results stage it returns an empty
box, as the old _field() did, and GameField gets a promoted non-null
value. The switch becomes a statement so the arm can return. No
behaviour change otherwise; party_host's 399 tests pass.
```

## Status row

M14 cleanup1 c1: `_stageBody` typed `NightState?` and `_game` guarded (no `!`); checks pass; c2 (awards reveal) still open.

## Delete

- none
