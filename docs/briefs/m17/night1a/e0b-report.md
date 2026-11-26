# night1a e0b report: the champion chain as a pure Champion type

## Summary

Added the champion chain as a pure Dart type, with no wiring into night state, the scoreboard or the ceremony.

- `packages/party_host/lib/src/night/champion.dart` (new, pure Dart):
  - `enum ChampionStep { points, plazaDistance, bolts, lastGamePlace, shared }`, with `higherWins` (points and bolts true; plazaDistance, lastGamePlace and shared false).
  - `final class ChampionEntry` (`const`): `id`, `points`, `plazaDistance?`, `bolts?`, `lastGamePlace?`. A null on a step loses to any number on that step.
  - `final class ChampionChain`: constructor `ChampionChain(List<ChampionStep> steps)`, statics `quickNight = [points, shared]` and `cityRush = [plazaDistance, bolts, shared]`, and `Set<String> champions(Iterable<ChampionEntry>)`.
- `packages/party_host/test/champion_test.dart` (new): 13 tests, one per step plus the asserts and the scoreboard pin.

Decisions:
1. **Constructor is not `const`.** Dart cannot check a list's length or contents in a constant expression; `mine.sh` failed with `invalid_constant` and `const_eval_property_access` when I tried. The checks are now body asserts in a non-const constructor, which run in debug builds. The brief asked for `const`, so this is a deviation.
2. **Test entries use `const ChampionEntry(...)` where the value is constant,** and the chain in the added-step test is a `final`.
3. **Null handling in `champions`:** a step keeps the entries with the best non-null value. If every entry is null on that step, all of them stay, so nobody is better than anybody on that step.
4. **Empty input** returns an empty set, and the loop stops as soon as one entry is left.
5. **Not exported from `party_host.dart`.** The test imports `package:party_host/src/night/champion.dart`, the same way `coverage_all_test.dart` imports other night src files. Export is a wiring decision for a later job.
6. **`probe-e0b.patch` was not applied.** It is a stub that would overwrite `champion.dart`; the real file replaces it.
7. **The pin test uses `threeAwards`** because `NightState.start` asserts exactly three awards per night. The pin compares `quickNight` against `rows()` place 1 using each row's `total`, so the award points do not change the comparison.

Computed test values:
- Quick night single leader: a=5, b=3 → {a}.
- Points tie: a=5, b=5, c=1 → {a, b}.
- City Rush: plazaDistance 10 vs 4 → {b}; plaza 4 tie with bolts 1 vs 3 → {b}; plaza 4 tie with bolts 2 vs 2 → {a, b}.
- Null plazaDistance: a null vs b 7 → {b}; all null, bolts 1 vs 2 → {b}.
- Added last-game step `[points, lastGamePlace, shared]`: a (5, 2), b (5, 1), c (3, 1) → {b}.
- Empty input → empty.
- Asserts: `[]`, `[shared, points]` and `[points, shared, shared]` each throw `AssertionError`.
- Pin: 3 players, one round of points p1=5, p2=5, p3=2. `rows()` place 1 = {p1, p2}; `quickNight.champions` = {p1, p2}.

## Checks

- `tools/mine.sh`: OK. Format: 4 files formatted. Analyze: packages/party_host and packages/test_game clean. Tests: party_host 13 pass; test_game 4 pass.
- I did not run the tests against the code as it was. The new test file did not exist before, and the runner is the one that proves the tests fail on the old code.

## Hand-over

- Files changed: `packages/party_host/lib/src/night/champion.dart` (new), `packages/party_host/test/champion_test.dart` (new), `docs/briefs/m17/night1a/e0b-report.md` (this report).
- Open for a later job: wiring into `night_state.dart`, the scoreboard and the ceremony, and the Plaza and Bolts data sources. Nothing here calls them.

## Commit message — a draft

```
Add the champion chain as a pure Champion type (night1a e0b)

Quick night and City Rush decide their champion through ordered
tie-break steps ending in shared. ChampionChain holds the steps and
champions() returns the set left level. Nothing calls it yet.
Constructor checks shared-last are asserts, not const, because Dart
cannot check list contents in a constant expression.
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row

Done: champion chain as a pure type (ChampionStep, ChampionEntry, ChampionChain with quickNight and cityRush), 13 tests incl. the rows() place-1 pin. Open: not wired into night state, scoreboard or ceremony; Plaza and Bolts sources not built; not exported from party_host.dart.

## Delete

- none
