# City Rush night simulator v2: the model (owner Nov 27, board3c)
Supersedes board3b/sim-model.md for the rules named here; the performance and decision streams are unchanged. Shipping rule values come from `CityRules` (copied, never edited); rules under test are in `tools/sim/sim_rules.dart` (`SimRules`, `RoadworksVariant`, `RoadVariant`).

## Setup
- 2-8 players, one OWN road each (no shared tiles), 5 games per night (nightRoundCap = 5), a stop after every game. Tile cost, road length from a `RoadVariant`: V0 6 tiles at 3 Bolts, V1 5 at 3, V2 6 at 2, V3 5 at 2 (V3 is beyond the brief, only to size the 8-player gap).
- Per game: performances, places 1..n, Bolts by `placementBolts` (5/3/2/1, places 5-8 = 1 Bolt placeholder, x2 in the last game). At most 3 Builds per stop. Save +2 (last place only). Ranking only at the end: Plaza, distance, Bolts left, shared.
- Streams per night: performances `Random(seed)`, last-place decisions `seed+1000003`, gate pick `seed+2000003`. So the games of a night never depend on a decision and the gate never changes another decision's draws. The paired runs below rely on this.

## Targeted gate (no fixed tile-4 gates)
- The winner of the gate game (game 3 of 5) picks one rival; no pick = nobody gated. The gate goes on the rival's next unbuilt tile. Pickable: a rival with an unbuilt tile and no gate. Kids nights: no gate.
- Adult bots gate the best rival (rank by tiles, then Bolts), which is the leader, or the nearest rival when the bot leads (the best rival is the nearest one then); child bots pick a random rival; adults make no pick 10% of nights, children 30% (guesses).
- ASSUMPTIONS (not owner rules, flags in `SimRules`): the gate is placed at the gate game's stop BEFORE that stop's Builds; opening it is the gated player's first Build action, costs one tile's Bolts and lays no tile (`gateOpeningCostsBolts`); a Roadworks crew cannot lay a tile while the next tile is gated (`gateBlocksRoadworks`).
- One gate game per 5-game night, so one gate per night: a road is never gated twice (the multi-gate column is 0 by construction).

## Roadworks (own road only, last place only, never kids)
- Offered to the last place (the sim has no ties; the real rule gives it to every tied last). The user's next tile on their own road is laid at once with no tile cost. The pick is made before the stop's Builds.
- R1: 1 Bolt, replaces one Build. R2: free, replaces one Build. R3: free, on top of the normal Builds (the free tile is not counted against the 3-Build cap).
- Choice per bot: Roadworks with `roadworksChance` (adult 50%, child 10%) when offered; else Save with `saveChance` (adult 40%, child 10%) or Build. A sensitivity set has every adult bot always send a crew (`rw_always`).

## Metrics (per cell, 5000 nights, night k uses seed 17+k; CSV: docs/briefs/m17/city/sim-results-v2.csv)
- plaza_rate: the winner (a champion) reached the Plaza. mid_last_not_last_rate: the player last after game 2 finishes not last. mid_leader_win_rate: the first leader after game 2 wins.
- rw_better/same/worse: over Roadworks users, final place versus the same night (same seed) with Roadworks off. gated_*: the gated player's final place versus the same night with no gate; gated_mean_place_change = place with gate - place without (positive = worse). multi_gate_rate: a road gated twice.
- Not in the CSV (so marked "not measured" in the report): the midpoint-last player's own Roadworks use, ties for last, human pick behaviour, late joiners, the 10 s timer.
