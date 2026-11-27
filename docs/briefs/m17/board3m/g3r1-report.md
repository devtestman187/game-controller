# board3m g3r1 report: CityRules to the owner's final rules

## Summary

Done except one item, which is blocked: `gateTileIndex` is kept (not deleted), because `packages/party_host/test/city/board_test.dart` (outside `allow:`) reads `CityRules.standard.gateTileIndex` in four places. Removing the field would break that file's compile. The rest of the job is in place: the new fields, `forPlayers`, the gate functions, `roadworksOffered` with `nextTileGated`, `roadworksPrice` and `roadworksCost` removed, the tests, and `cityRulesWith`.

Checks run in this job:
- `flutter test packages/party_host/test/city/rules_test.dart packages/party_host/test/city/roadworks_offer_test.dart`: `All tests passed!` (the last line of output).
- `bash tools/tests/sim-test.sh`: all PASS, 0 FAIL.
- `dart format` on the four files: formatted.
- `dart analyze` on the four files: No issues found (after one info fixed).
- `tools/mine.sh`: `OK 75 tests packages/party_host`, `RESULT: ok`.

## Files changed

- `packages/party_host/lib/src/city/rules.dart` (186 → 255 lines): removed `roadworksCost` and `roadworksPrice`; added `tileCostLargeNight` (2), `largeNightFrom` (5), `nightGames` (5), `gateGame` (3), `gatePickSeconds` (10) with doc comments; `tileCost` (3) doc says 2-4 players; `buildCap` doc says at most 3 Builds per stop; `kidsPreset` doc now covers gates; added typedef `GateRoad`; added `CityRules.forPlayers`, `gateOffered`, `gateTargets`, `gateOpenCost`; `roadworksOffered` gained `nextTileGated = false`. `gateTileIndex` kept (see Blocked).
- `packages/party_host/test/city/rules_test.dart` (now 377 lines): new `forPlayers`, `gate` and `buildCap` tests; roadworks group removed (its tests moved to the roadworks file); every `gateTileIndex` use replaced by `roadLength - 2` (or `roadLength - 3` for `gateTileIndex - 1`); the kids night is a local `kidsNight` copy.
- `packages/party_host/test/city/roadworks_offer_test.dart` (54 lines): kids copy updated to the new constructor; two new `nextTileGated` tests.
- `tools/sim/sim_rules.dart`: `cityRulesWith` drops `roadworksCost`, copies the five new fields from base; `gateTileIndex` still copied.

## Signatures and tests

- `CityRules forPlayers(int players)`: tests `forPlayers` group: "a night of 2 players costs 3 Bolts a tile" (3), "4 players" (3), "5 players costs 2" (2), "8 players costs 2" (2), "rejects a night of 0 players", "rejects a night of 9 players, more than two per corner" (both ArgumentError), "keeps every other field and the kids flag".
- `bool gateOffered({required int game, required int gatesPlaced, required CityRules rules})`: "a gate is offered in the gate game when no gate is placed yet" (game 3, gatesPlaced 0: true), "no gate is offered in any other game of the night" (games 1, 2, 4, 5: false), "no second gate ..." (gatesPlaced 1: false), "a kids night offers no gate, even in the gate game" (false).
- `List<String> gateTargets({required String winnerId, required List<GateRoad> roads, required CityRules rules})`: "the gate winner picks from the rivals in the order given, never the winner" (roads b, a, c with winner a gives ['b', 'c']), "a road with every tile built is not a gate target" (roads a, b(6 = roadLength), c(5) with winner a gives ['c']).
- `int gateOpenCost({required CityRules rules})`: "opening a gate costs one tile's Bolts" (3), "on a 6 player night opening a gate costs 2 Bolts" (2).
- `bool roadworksOffered({..., bool nextTileGated = false})`: "last place is offered roadworks when the next tile is not gated" (true), "roadworks are not offered while the next tile is gated, last place included" (false).
- Kept: "the gate tile is on the road, before the Plaza" (now `roadLength - 2` = 4, within 0 to 4), "a night plays 5 games" (5), "the gate game is one of the games of the night" (3 within 1 to 5).

## Blocked

- `gateTileIndex` cannot be removed inside `allow:`. `packages/party_host/test/city/board_test.dart` lines 26, 90, 93, 168 use `CityRules.standard.gateTileIndex`. To finish: allow that file (replace those uses with a value from `roadLength`, or move the gate tile to the board code), then delete `gateTileIndex` from `rules.dart` (field, constructor argument, standard value 4), `sim_rules.dart` line 125, and the `gateTileIndex:` line in the kids copy in `roadworks_offer_test.dart`.

## Decisions

- `forPlayers` is documented as call-on-base: a copy keeps the tile cost it was given, so calling it on a copy would not restore the standard cost.
- `forPlayers(1)` is allowed (tile cost 3); the brief said only 0 and 9 throw.
- `gateOffered` checks `gatesPlaced == 0` exactly (one gate per night).
- `gateTargets` excludes a road with `tilesBuilt >= roadLength`; it does not look at whether the rival's next tile is already gated (the brief does not say).

## Self-check (docs/review-rules.md part A)

1. Host setups: N/A for this job (pure rules; no host UI or adapter). Covered by the sim tests (`tools/tests/sim-test.sh`, all PASS).
2. Kept state: none added; the functions are pure. Tested by the "no gate" cases above (`gatesPlaced 0` / kids).
3. Combinations: the gate and roadworks interplay is tested by "roadworks are not offered while the next tile is gated, last place included".
4. Folder and allow: only the four `allow:` files changed.
5. Stop rather than overstep: `board_test.dart` (see Blocked).
6. Looks: N/A (no UI).

## Commit message — a draft

```
m17 board3m g3r1: CityRules to the owner's final rules

Tile cost is 3 Bolts for 2-4 players and 2 for 5-8 (forPlayers).
Adds the gate game rules (gateOffered, gateTargets, gateOpenCost),
the night fields (nightGames, gateGame, gatePickSeconds) and
roadworksOffered's nextTileGated. Removes roadworksCost and
roadworksPrice (roadworks are free now). gateTileIndex is kept
until board_test.dart is allowed to change.
```

## Status row

board3m g3r1: CityRules final rules (tile cost by players, gate game functions, roadworks not offered while gated, roadworks free) done and tested (rules, roadworks, sim PASS); open: gateTileIndex removal waits on board_test.dart (outside allow).

## Delete

- none

## Hand-over

- Open question for the owner or runner: allow `board_test.dart` (or say how the board should find the gate tile) so `gateTileIndex` can go.
- The brief says "never tools/mine.sh" in its stop line, but the invocation asked for `tools/mine.sh`; I ran it once and it passed. Flagged in case the brief is right.
