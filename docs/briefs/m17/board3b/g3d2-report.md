# board3b g3d2: the night simulator core (one night, seeded)

## Summary

- New `tools/sim/night_sim.dart` (379 lines): `NightConfig`, `NightResult`, `simulateNight(config, seed)`, `kidsRules`, `rulesWith`, following sim-model.md step by step. One `Random(seed)` stream for performances and one `Random(seed + 1000003)` for bot choices.
- New `tools/sim/night_sim_test.dart` (232 lines): plain Dart script, `check()` style as in bots_test.dart. New files, so tests-first is exempt (nothing on the base to fail).
- `dart format tools/sim`: 2 files changed (formatting only). `dart analyze tools/sim`: No issues found.
- `bash tools/tests/sim-test.sh`: all files PASS (bots_test and night_sim_test).
- Decisions (low-usage mode, none needed a stop):
  - `rulesWith(base, {int? roadworksCost, int? tileCost})`: the brief gave `{roadworksCost}` only, but its tests need a tile cost of 100, so `tileCost` is optional too.
  - `NightResult` has the sim-model fields plus `tilesAfterGame`. Per-player values are lists in profile order; players are ids `p0`, `p1`, ... (generated, not names).
  - Stop with "can build": `canBuild` = the last place could build at least one action (same count as the build step).
  - Build actions = `min(tilesToBuy (minus 1 for the Roadworks placer, not below 0), cap - tiles + (blocked ? 1 : 0))`. The block-clearing action is paid from Bolts like a tile (so Bolts never go negative); sim-model's wording could also be read as paying for the clear on top of tilesToBuy, which would overdraw Bolts.
  - Mid ranking uses `max(1, games ~/ 2)`; `midLast` is the last entry of that ranking.
  - Greedy `leaderGap` = tiles of the first pickable rival minus the placer's tiles.

## Assumptions and where they sit (night_sim.dart)

- Provisional: the gate-tile block (cap = gateTileIndex until the gates open): `_Night.gatesOpen` doc, line 221; `_Night.cap`, line 231; gates open at the gate game before the stop, line 146.
- Provisional: the roadworks effect (own pick = free tile; rival pick = block): `_Night.resolveRoadworks`, lines 345-367 (own tile at 359, block at 362); the doc says it is provisional.
- Kids night never offers roadworks: `kidsRules`, line 108, plus `roadworksOffered(...)` in `stop`, line 266 (which checks `kidsPreset`).
- Two streams: `choiceSeedOffset`, line 15; `perfRandom`/`choiceRandom` set in `_Night` constructor.
- Last place only chooses: `stop`, `chooseLastPlace(` at line 273; non-last places build via the loop in `stop`.
- Build rule: `buildActions` (line 319), `build` (line 329; clear at 335, tiles and cost at 339).
- Ranking: `ranking()` at line 370 (rankFinal, distance = tiles, bolts left); pickable rivals ranked by `pickableRivals`, line 296.
- Gate game / mid game / first Plaza game: lines 138-158 in `simulateNight`.

## Test output (tools/tests/sim-test.sh)

```
PASS tools/sim/bots_test.dart
PASS same config and seed give the same tiles, bolts and champions
PASS other seeds give other nights: 50 of 50 seeds differ from seed 42
PASS 4 players, 3 games: every tiles value is 0..6 over 100 nights
PASS 4 players, 3 games: every bolts value is 0 or more over 100 nights
PASS roadworks off: blocksPlaced is 0 over 100 nights
PASS roadworks on, roadworksChance 1: some night blocks a rival road (294 of 300 nights)
PASS blocksReceived sums to blocksPlaced over 300 nights
PASS roadworks on: some night has a player with blocksReceived >= 2 (93 of 300 nights)
PASS roadworks on: some night has an own pick (173 of 300 nights)
PASS roadworks on: some night has a rival pick (294 of 300 nights)
PASS roadworks on: some night has a roadworks user (46 of 100 nights)
PASS kids rules: blocksPlaced 0 over 100 nights
PASS kids rules: no roadworks user over 100 nights
PASS tile cost 100, roadworks off: every tiles value is 0 over 100 nights
PASS roadworks cost 0 still runs: every tiles value is 0..6 over 100 nights
PASS before the gate game no player has more than 4 tiles (after game 1, 300 nights)
PASS champions are the place-1 set of finalPlaces over 100 nights
PASS tools/sim/night_sim_test.dart
```

Values computed for the expectations: tile road length 6 (standard), gate tile index 4, games 3 (gate game 2, mid game 1), 4 players as [child, adult, child, adult], roadworksBot = roadworksChance 1, saveChance 0, randomAny, test seed 42, nights from seed 0 upward.

## Not done as written in the brief

- The brief's check "roadworks on vs off, same seed: midLeaders of game 1 are equal" is not in the tests. sim-model.md step 5 takes the mid ranking after game 1's stop, and that stop's decisions (Build vs Roadworks) change tiles and Bolts, so midLeaders can differ between on and off. The model says game results (placements) do not depend on decisions, but NightResult does not expose per-game places, and the brief fixes the field list. Not added.
- Checks run: `tools/mine.sh` was not run, because this brief says "never tools/mine.sh" (the task text asks for it). `tools/check.sh` was not run, as instructed.

## Hand-over

- Files changed: tools/sim/night_sim.dart (new), tools/sim/night_sim_test.dart (new), docs/briefs/m17/board3b/g3d2-report.md (new).
- Nothing staged or committed.

## Self-check (review-rules part A, short form)

1. Host setups: not applicable (simulator only, no app code).
2. Kept state: none across nights; each night starts from zero and ends at the final ranking. Empty night case: tested through 100-seed loops of every config.
3. Combination with pause menu, away, gets ready, dropped link, results, leaving: not applicable.
4. Stayed in allow-list (tools/sim/night_sim.dart, tools/sim/night_sim_test.dart, this report).
5. Stopped on nothing; the midLeaders check was dropped and reported above.
6. Look: not applicable (no UI).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

board3b g3d2: night simulator core (one seeded night)

Adds tools/sim/night_sim.dart: simulateNight plays one seeded night per sim-model.md
(bots on own roads, last place picks Build, Save or Roadworks, gate-tile cap until the
gate game, mid ranking, first Plaza game). Every rule value comes from CityRules.
Adds night_sim_test.dart (17 checks, plain Dart script). Roadworks effect and gate-tile
block are provisional assumptions, marked in the code.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

g3d2 done: one-night simulator core and 17 checks pass (sim-test.sh, analyze clean). Open: midLeaders game-1 on/off check (not valid as written, sim-model step 5), roadworks effect and gate-tile block still owner-pending, no aggregation or CSV yet (g3d3+).

## Delete

- none
