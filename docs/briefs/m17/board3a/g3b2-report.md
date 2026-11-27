# board3a g3b2 — CityRules rework and board type changes

## Summary

- Pure Dart rules and data; no UI, no host service, no import from `night/`.
- Tests first, then the lib. Final check: `tools/mine.sh` → format OK, analyze OK, `OK 44 tests packages/party_host`.
- `board.dart`: `Token` gains `roadId`; `Gate` is now `Gate({roadId, tileIndex, kind})` with no open state of its own; `Board` takes `gates` and holds one shared `gatesOpen` flag set by `openAllGates()`; `District` gains `laneOf` (null = corner road).
- `rules.dart`: one `CityRules.standard` (roadLength 6, tileCost 3, buildCap 3, saveBonus 2, roadworksCost 1, gateTileIndex 4, placementBolts 5/3/2/1 then 1 for places 5-8, last game x2). New functions `tilesToBuy`, `driveCost`, `lateJoinTilePosition`, `rankFinal` (with typedef `FinalStanding`). Removed `draftStepsFor`, `draftStepsPerStop`, the `kids` preset and the `roadworks` flag.
- Board validation: a gate must stand on a road on the board and on a tile before the Plaza (`ArgumentError` otherwise).
- Worked examples, computed by hand and asserted in `rules_test.dart`:
  - Bolts 5,5,5,5 per game: tiles after each game 1, 3, 5, 6; the road (6 tiles) is complete after game 4.
  - Bolts 5,3,5,3: after game 1 bolts 2, tiles 1; after game 2 bolts 2, tiles 2; after game 3 bolts 1, tiles 4; after game 4 bolts 1, tiles 5. So 5 tiles and 1 Bolt before the last game.
- Test count: 44 in `party_host` (18 in `board_test.dart`, 26 in `rules_test.dart`).

## Decisions

1. `CityRules` keeps one instance, `standard`. I dropped the `kids` preset and the `roadworks` boolean, since `roadworksCost` now carries that meaning. No code outside `city/` referenced them.
2. `driveCost`: 0 on a built road, `roadworksCost` on a road not built yet. The brief only says "driving on built road costs 0"; the other branch is my reading.
3. `tilesToBuy` is a lib function (greedy: min of affordable and `buildCap`). The brief's change list did not name it, but item 4 describes it as a rule, so the test uses the lib function rather than a copy.
4. `lateJoinTilePosition` returns the smallest tile position, or 0 with nobody on the board.
5. `rankFinal` takes a record typedef `FinalStanding` (`playerId`, `reachedPlaza`, `distanceTiles`, `boltsLeft`) and returns ids, first place first. Ties keep the input order.
6. Gate tile is index 4 (0-based), so on a 6-tile road it is the fifth tile, with the Plaza at index 5.
7. Lanes: the tests build four corner roads (`cog-hill`, `candy-harbour`, `pepper-park`, `lantern-ridge`) and four lanes with `laneOf` set and tile ids prefixed by the lane id. The builder lives in the test. No lib builder was in the allow list.
8. Corner names appear only as ids in the test file, not in lib.
9. `RoadworksBlock` is unchanged; `Bolts` is unchanged.

## Owner-pending placeholders

- `CityRules.standard.placementBolts` places 5-8 = 1 Bolt each (flagged in the doc comment in `rules.dart`).
- Team-game payouts: the brief names them as placeholders, but it gives no field or value for them, so I did not add any.

## Not tested directly

- "Early arrival does not end the night": there is no function for it. The 5,5,5,5 example shows the arrival after game 4, but the night continuing is not asserted.
- "Each player has own road progress": covered by `Token.roadId` in the type; not tested as a rule.

## Hand-over

- Self-check (review-rules part A):
  1. Host setups: N/A, no host UI in this job.
  2. Kept state: `gatesOpen` starts false (board test "starts with every gate closed"); only `openAllGates()` sets it; no reset exists in this job.
  3. Combinations with pause, host away, "Get ready", dropped link, results, leaving: N/A, nothing is wired to a caller yet.
  4. Stayed in `allow:` — yes; `git status` shows only the four lib/test files plus this report.
  5. Stops: none.
  6. Looks: N/A.
- Conflict in the brief: it says "never tools/mine.sh" and "dart analyze and flutter test by explicit path", but the task says to check with `tools/mine.sh`. I followed the task and ran `tools/mine.sh` only.
- The brief's "shared-road test" was not in `rules_test.dart` before my edit (the old file had no such test). I kept the board tile-uniqueness tests, since they guard the shared-tile rule.
- The first `mine.sh` run reported one analyzer info (a non-const `Gate` in a `const` list) and one failing test (my own mistake: two equal distances in the `rankFinal` test). Both fixed; the second run is green.

## Commit message

```
city: CityRules rework with own road progress, lanes and gates

Rework the City Rush rules for the owner's final model: four corner roads
(roadLength 6, gate on tile 4, no toll), one greedy build up to buildCap,
own road progress and own payments, and lanes for players 5-8 with tile ids
prefixed by the lane id.

Board: Token carries roadId; Gate is roadId + tileIndex + kind with one shared
gatesOpen flag set by openAllGates(); District gains laneOf; gates are
validated against the roads.
Rules: tilesToBuy, driveCost, lateJoinTilePosition and rankFinal added;
draft rules and the kids preset removed. Places 5-8 and team payouts are
owner-pending placeholders.
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row

g3b2 done: CityRules rework (roadLength 6, gate tile 4, tilesToBuy, driveCost, lateJoin, rankFinal) and board types (Token roadId, Gate, District laneOf, shared gatesOpen), 44 tests green. Open: owner-pending places 5-8 and team payouts; no lib builder for the real board; the `kids` preset is dropped (question for the owner); "early arrival does not end the night" has no direct test.

## Delete

- none
