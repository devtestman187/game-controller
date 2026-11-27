# City Rush night simulator: the model (provisional bot model, owner Nov 26 road rules)
Every rule value is read from `CityRules` (packages/party_host/lib/src/city/rules.dart); no literal of a rule value in tools/sim/. Import it by relative path (`../../packages/party_host/lib/src/city/rules.dart`, `.../stubs.dart`); both are pure Dart.

## Setup
- n players (4 or 8), each with a BotProfile (tools/sim/bots.dart). Each player has an OWN road of `roadLength` tiles (no shared tiles, no drafting). State per player: `tiles` built (0..roadLength; the Plaza is reached when tiles == roadLength), `bolts`, `blocked` (bool).
- `games` games in a night (3 or 5); a stop (shop) follows every game. `gateGame = (games + 1) ~/ 2` (3 -> game 2, 5 -> game 3). Until the gates open a road can be built only up to `gateTileIndex` tiles (assumption: the gate tile itself is blocked); at the stop of the gate game the gates open before anyone builds, then the cap is `roadLength`.
- A kids night uses a copy of the rules with `kidsPreset: true` (helper `kidsRules(base)` copying every field); no roadworks there whatever the flag says.
- Roadworks is a simulator flag `roadworks` (on/off). On: provisional effect below. Off: last place may only Build or Save.

## One game
1. Each player draws `performance` from its profile; sort players by performance, best first; call `StubRoundPlacing().placeRound(sortedIds)` to get places 1..n (never tied).
2. Bolts += `placementBolts(place, isLastGame: game == games, rules)`.
3. If game == gateGame, gates open.
4. Stop:
   a. Only the last place (place n) has a choice. Roadworks is available when the flag is on, `roadworksOffered(place: n, lowestPlace: n, rules)`, bolts >= `roadworksPrice`, and a target exists. Target: rank everyone now with `rankFinal` (reachedPlaza, distanceTiles = tiles, boltsLeft = bolts), skip the last-place player, take the best-ranked (list order breaks ties) whose tiles < roadLength, who is not blocked and who can still build (tiles < current cap). The profile calls `chooseLastPlace(random, canBuild:, roadworksAvailable:)`.
   b. Roadworks chosen: the player pays `roadworksPrice`, does not build or save, and `blocked` is set on the target (at most one block per road per stop). The block lands BEFORE the builds of this stop.
   c. Save chosen: bolts += `saveBonus`, no build.
   d. Everyone else (and last place when it chose Build) builds, best place first: actions = `tilesToBuy(bolts, rules)` limited to (cap - tiles) plus 1 when blocked. If blocked, the first action clears the block (costs `tileCost` Bolts, no tile) and `blocked` becomes false; each other action lays one tile (`tileBuildCost(1, tileCost)`).
5. Record the stop; after the stop of game `games ~/ 2` (at least 1) record the mid leaders = players with place 1 in `rankFinal`.

## Result of a night (class NightResult)
games, tiles (list), bolts (list), finalPlaces (`rankFinal`, place 1 = champion set, ties share), champions (set of ids), midLeaders (set), firstPlazaGame (int or null: first game whose stop leaves any player with tiles == roadLength), blocksPlaced (int), leaderReachedPlaza (any champion has tiles == roadLength). Ranking happens only after the last stop; an early arrival does not end the night.

## Metrics (per cell, over N nights; night k uses `Random(seed + k)`)
- tileSpread: mean of (max tiles - min tiles) at the end.
- comebackRate: share of nights whose champion set is disjoint from midLeaders.
- leaderPlazaRate: share of nights with leaderReachedPlaza; anyPlazaRate: share with firstPlazaGame != null.
- meanFirstPlazaGame: mean firstPlazaGame over nights that have one (empty when none).
- meanBlocks: mean blocksPlaced. Night length in games is the config's `games` (fixed, the night never ends early).
