# City Rush night simulator: the model (provisional bot model, owner Nov 26 road rules, owner Nov 27 roadworks "A, one, A")
Every rule value is read from `CityRules` (packages/party_host/lib/src/city/rules.dart); no literal of a rule value in tools/sim/. Import it by relative path (`../../packages/party_host/lib/src/city/rules.dart`, `.../stubs.dart`); both are pure Dart.

## Setup
- n players (3, 4 or 8), each with a BotProfile (tools/sim/bots.dart). Each player has an OWN road of `roadLength` tiles (no shared tiles, no drafting). State per player: `tiles` built (0..roadLength; the Plaza is reached when tiles == roadLength), `bolts`, `blocked` (bool).
- `games` games in a night (3 or 5); a stop (shop) follows every game. `gateGame = (games + 1) ~/ 2` (3 -> game 2, 5 -> game 3). Until the gates open a road can be built only up to `gateTileIndex` tiles (assumption: the gate tile itself is blocked); at the stop of the gate game the gates open before anyone builds; then the cap is `roadLength`. "cap" below = that current limit.
- A kids night uses a copy of the rules with `kidsPreset: true` (helper `kidsRules(base)` copying every field); no roadworks there whatever the flag says. A helper `rulesWith(base, {roadworksCost})` (new copy of every field) lets a cell try a roadworks price of 0.
- Two random streams per night: `perfRandom = Random(seed)` for game performances only, `choiceRandom = Random(seed + 1000003)` for every bot decision. So the game results of a night do not depend on any decision (the paired runs below rely on this).
- Roadworks is a simulator flag `roadworks` (on/off). Off: last place may only Build or Save.

## One game
1. Each player draws `performance(perfRandom)`; sort best first; `StubRoundPlacing().placeRound(sortedIds)` gives places 1..n (never tied here; the real rule gives roadworks to every player tied for last).
2. Bolts += `placementBolts(place, isLastGame: game == games, rules)`.
3. If game == gateGame, gates open.
4. Stop. Only the last place (place n) has a choice: Build, Save or Roadworks.
   a. Roadworks is available when the flag is on, `roadworksOffered(place: n, lowestPlace: n, rules)`, bolts >= `roadworksPrice`, and at least one road is pickable. Pickable: the player's OWN road when it is not blocked and tiles < cap; a RIVAL's road when its tiles < roadLength (a complete road cannot be picked), it is not blocked (one block per road) and tiles < cap. `rivals` = the pickable rivals ranked best first with `rankFinal` (reachedPlaza, distanceTiles = tiles, boltsLeft = bolts; list order breaks ties). The profile decides with `chooseLastPlace(choiceRandom, canBuild:, roadworksAvailable:)`.
   b. Roadworks chosen: pay `roadworksPrice`; the placer's Build count this stop drops by ONE (it replaces one Build). The pick is `profile.chooseRoadworksTarget(choiceRandom, self:, rivals:, ownAvailable:, leaderGap:)` with leaderGap = tiles of the best pickable rival minus the placer's tiles (0 without rivals). OWN road picked: a road crew lays the placer's next tile now, no tile cost (the crew replaces the one Build; tiles += 1). A RIVAL picked: its `blocked` becomes true. Record ownPicks or rivalPicks, `blocksReceived[target]++` for a block, and the placer in `roadworksUsers`. These resolve BEFORE the builds of this stop.
   c. Save chosen: bolts += `saveBonus`, no build.
   d. Everyone builds (the roadworks placer too, one fewer Build; a Save player does not), best place first: actions = `tilesToBuy(bolts, rules)` (minus 1 for the roadworks placer, not below 0) limited to (cap - tiles) plus 1 when blocked. If blocked, the first action clears the block (costs `tileCost`, no tile) and `blocked` becomes false; each other action lays one tile (`tileBuildCost(1, tileCost)`).
5. Record the stop; after the stop of game `games ~/ 2` (at least 1) record the mid ranking: midLeaders = players with place 1 in `rankFinal`, midLast = the last entry of that ranked list.

## Result of a night (class NightResult)
games, tiles, bolts (lists), tilesAfterGame (list of lists), finalPlaces (`rankFinal`, place 1 = champion set, ties share), champions, midLeaders, midLast (an id), firstPlazaGame (int or null: first game whose stop leaves any player with tiles == roadLength), blocksPlaced, blocksReceived (per player), ownPicks, rivalPicks, roadworksUsers (set of ids), leaderReachedPlaza (any champion has tiles == roadLength). Ranking happens only after the last stop; an early arrival does not end the night.

## Metrics (per cell, over N nights; night k uses seed + k)
- tileSpread: mean of (max tiles - min tiles) at the end.
- comebackRate: share of nights whose champion set is disjoint from midLeaders. midLeaderWinRate: share of nights where the first midLeader is in champions. midLastRecoversRate: share of nights where the midLast player's final place is better than the worst final place (finishes not last).
- leaderPlazaRate: share of nights with leaderReachedPlaza; anyPlazaRate: share with firstPlazaGame != null. meanFirstPlazaGame: mean over nights that have one (null when none).
- meanBlocks: mean blocksPlaced. multiHitRate: share of nights where some player has blocksReceived >= 2. ownPickShare: ownPicks / (ownPicks + rivalPicks) over the cell (null when none).
- roadworksBeatsBuild (only for a roadworks-on cell): each night is also run with the flag off (same seed, same game results); for every player in `roadworksUsers`, compare the final place on vs off: share better, same, worse (three numbers, over those player-nights; null when none). This answers "how often Roadworks beats Build for last place".
- Night length in games is the config's `games` (fixed).
