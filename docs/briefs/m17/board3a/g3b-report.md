# board3a g3b report: CityRules and pure rule functions

## Summary

- Added `CityRules` (one const value object with every tunable), `CityRules.standard` (roadworks on), `CityRules.kids` (roadworks off), and three pure functions: `placementBolts`, `tileBuildCost`, `draftStepsFor`.
- Wrote the tests first in a new file; then `rules.dart`.
- `tools/mine.sh`: format applied to 2 files, analyzer clean, `OK 20 tests packages/party_host`, `RESULT: ok`.
- `dart analyze` on the two changed files: "No issues found!" (run directly, since mine.sh prints only errors when green).
- Not run: the tests on the code as it was (before `rules.dart` existed). The test file would not compile without `rules.dart`, so it fails, but I did not measure that.
- Not built, because they have no function in the change list: late join (token starts at the slowest district's position) and absent token holds still. See Questions.
- Not tested as a rule: "driving on paved road costs 0 Bolts". No drive-cost function exists, and the brief says there is no drive-cost field. See Questions.
- Lib file: 114 lines. Test file: 169 lines.

## Files changed

- `packages/party_host/lib/src/city/rules.dart` (new, 114 lines): `CityRules` value object with fields `tileCost`, `placementBolts`, `lastGameMultiplier`, `saveBonus`, `buildCap`, `roadLength`, `draftStepsPerStop`, `roadworks`; `CityRules.unlimitedDraftSteps = -1`; presets `standard` and `kids`; functions `placementBolts(place, {isLastGame, rules})`, `tileBuildCost(tiles, {tileCost})`, `draftStepsFor({onPavedRoad, tilesToFront, draftStepsPerStop})`.
- `packages/party_host/test/city/rules_test.dart` (new, 169 lines): 20 tests, one or more per rule, plus the worked example.
- `docs/briefs/m17/board3a/g3b-report.md` (this file).

## Decisions

1. The functions are top-level and pure. `placementBolts` and `tileBuildCost` take the `CityRules` (or the one value they read). `draftStepsFor` takes `draftStepsPerStop` as a plain int, so the unlimited case is a call with `CityRules.unlimitedDraftSteps`, with no second rules object.
2. `draftStepsFor` is the only place the draft rule lives: a follower off paved road or with nothing ahead gets 0; otherwise `min(draftStepsPerStop, tilesToFront)`, or `tilesToFront` when unlimited.
3. `placementBolts` returns 0 for a place past the last paid place (places 1-4 are paid), and throws `ArgumentError` for place below 1. `tileBuildCost` throws for a negative count. `draftStepsFor` throws for a negative cap that is not the unlimited value.
4. The kids preset repeats the standard values and sets `roadworks: false`. The brief gave no other kids difference, so none is set.
5. No import from `board.dart` in `rules.dart`: no function there needs a board type. The brief said "use District, Board, Token, Bolts, Plaza" for the file; I did not add unused imports. Tests import `board.dart` for `District`, `Tile`, `Plaza`.
6. Tests read the config for rule expectations. The worked example uses the owner's numbers as literals, since those numbers are the spec.

## Computed test values

Standard config: tileCost 3, placementBolts [5, 3, 2, 1], lastGameMultiplier 2, saveBonus 2, buildCap 3, roadLength 8, draftStepsPerStop 2, roadworks true.

Worked example (first place every round, buy min(affordable, buildCap), 5 games):

| Round | Bolts earned | Bolts before buying | Tiles bought | Bolts left |
|---|---|---|---|---|
| 1 | 5 | 5 | 1 | 2 |
| 2 | 5 | 7 | 2 | 1 |
| 3 | 5 | 6 | 2 | 0 |
| 4 | 5 | 5 | 1 | 2 |
| 5 | 10 (last game x2) | 12 | 3 (cap) | 3 |

- Total tiles after round 5: 9. Tiles before round 5: 6, so tile 8 is reached in round 5 (6 < 8 <= 9).
- Last place with 2 Bolts: 2 + saveBonus 2 = 4 Bolts. Draft on paved road with `tilesToFront` = roadLength 8: 2 tiles (draftStepsPerStop).

## Self-check (review-rules part A)

1. Host setups: the rules are pure functions with no host wiring. Covered by no host test; nothing to set up.
2. Kept state: none. The functions hold no state; `CityRules` is a const value.
3. Combinations (pause, host away, player away, Get ready, dropped link, results, leaving): not wired into any flow yet, so none apply.
4. Folder and allow: only the three files in allow were touched; `mine.sh` formatted only my two files.
5. Stops: late join, absent token, and the drive-cost test are not built. Named under Questions.
6. Looks: no UI in this job.

## Hand-over

- `rules.dart` is not yet called from anywhere. The next job should wire the draft and placement rules into the round logic.
- The worked-example test is a test-only simulation; the `buildCap` min and the greedy purchase live in the test, not in lib. A real purchase function would need its own job.

## Questions

1. Late join (token starts at the slowest district's position) and absent token (holds still): no function is in the change list, so no tests were written. Which function should own these, and in which file?
2. "Driving on paved road costs 0 Bolts": with no drive-cost field and no drive function, nothing can be tested. Should a `driveCostBolts` function return 0 for this rule, or is the absence of a cost enough?
3. `saveBonus` and `buildCap`: config values only, with no lib function. The saveBonus test pins 2 + 2 = 4 in the test; the buildCap test checks the value is positive. Should a purchase function (`tilesBuyable`) and a save function be added in a later job?
4. `roadLength`: the test builds a road of that length in the test itself. No lib function uses it yet.
5. The `CityRules` constructor has 8 named parameters, over the 5-parameter guideline. It is a value object, so I kept it that way; say if you want a different shape.
6. The brief says never run `tools/mine.sh` because it skips untracked folders. Here the folders are tracked, and mine.sh picked up both new files (20 tests ran). I used it as the task instructs.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
board3a g3b: CityRules config and pure rule functions

Adds CityRules (every City Rush tunable in one const value, with
standard and kids presets) and three pure functions: placementBolts,
tileBuildCost and draftStepsFor, which holds the only draft rule.
Tests are in a new file and cover one rule each plus the 5-game
worked example (tile 8 reached in round 5). Late join, absent token
and the drive cost are not built: no function for them is in scope.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

g3b done: CityRules config (standard and kids presets), placementBolts, tileBuildCost and draftStepsFor with 20 passing tests; open: late join, absent token, drive cost (no functions in scope), saveBonus and buildCap not yet used by lib.

## Delete

- none
