# City Rush simulator v2 (board3c, Nov 27)

Data: sim-results-v2.csv (364 cells x 5000 nights, seed 17). Every per-cell table is in sim-tables-v2.md. Model: ../board3c/sim-model-v2.md. Rule flags: tools/sim/sim_rules.dart. CityRules (shipping code) is untouched.

## Rules simulated
- 2-8 players, 5 games.
- Targeted gate: the game-3 winner picks one rival. Adult bots pick the best rival (the leader, or the nearest rival behind when they lead). Child bots pick at random. No-pick is 10% for adults and 30% for children. The gate goes on the rival's next unbuilt tile, and their next Build only opens it.
- Roadworks: own road only, last place only, never Kids. R1 = 1 Bolt and replaces a Build; R2 = free and replaces a Build; R3 = free, on top of the Builds.
- Roads: V0 = 6 tiles at 3 Bolts; V1 = 5 at 3; V2 = 6 at 2; V3 = 5 at 2.

## Assumptions the rules do not settle (flags in sim_rules.dart)
1. The gate goes on before the Builds at the gate game's stop.
2. Opening a gate uses one Build and costs one tile's Bolts; no tile is laid.
3. A Roadworks crew cannot lay a tile while the user's next tile is gated.
4. There is one gate game per night, so "gated 2+ times" is 0 by construction.
5. For a leading adult, "nearest rival ahead" is read as the nearest rival behind.
6. Places 5-8 get 1 Bolt (2 in the doubled last game), a placeholder.
7. Bot odds are guesses, and the simulator has no ties for last.

## Headline (5 games, gate on, V0; the bar is 90%)

| Players | Bots | Plaza V0, Roadworks off ; R1 | Smallest road change that meets 9 of 10 | Best Roadworks |
|---|---|---|---|---|
| 2 | adult / mixed | 99.8 / 100.0 ; 100 / 100 | none (V0) | R2 |
| 3 | adult / mixed | 100 / 100 ; 100 / 100 | none (V0) | R2 |
| 4 | adult / mixed | 98.6 / 99.6 ; 98.8 / 99.5 | none (V0) | R2 |
| 5 | adult / mixed | 87.0 / 92.0 ; 89.3 / 91.0 | V1 or V2 (both 100%) | R2 |
| 6 | adult / mixed | 71.5 / 76.6 ; 73.0 / 74.5 | V1 (99.8 / 99.7) or V2 (100) | R2 |
| 7 | adult / mixed | 58.4 / 62.5 ; 60.2 / 61.5 | V1 (98.2 / 98.3) or V2 (100) | R2 |
| 8 | adult / mixed | 46.1 / 49.2 ; 49.8 / 51.0 | V1 (95.2 / 95.5) or V2 (100) | R2 |

## Key findings
- **Gate cost:** the gate lowers the V0 Plaza rate by 5-10 points at 5-8 players. Adult bots with no gate on V0 reach it 93.6 / 80.8 / 68.6 / 55.6% at 5 / 6 / 7 / 8 players.
- **V1 vs V2:**
  - V1 reaches the first Plaza late: game 4.89 of 5 at 8 players, 95%.
  - V2 reaches it earlier: game 4.24, a spread of 2.75 tiles, 100%.
  - V3 is too easy: a spread of 0.5 tiles at 5 players.
- **The gated player:**
  - The gated player ends +0.36 places worse on average at 2 players, +0.43 at 4, +0.58 at 5 and +0.97 at 8 (adult, V2).
  - 36% of them finish worse at 2-4 players, 59% at 8.
  - The gate lowers the midpoint leader's win rate: adult V0, 4 players 42.9 -> 37.2; 8 players 31.0 -> 23.0.
  - It lifts last-at-midpoint finishing not-last: 4 players 58.3 -> 65.1; 2 players 31.6 -> 43.1.
- **Roadworks user, better/same/worse against the same seed without it:**
  - R1 leaves the user worse off as often as better off in 13 of 42 cells, nearly every V2 cell: V2 adult 4 players 10/78/12; 8 players 22/53/25.
  - R2 (4 players 16/78/6; 8 players 29/60/11) and R3 (17/77/6; 35/54/11): worse is under half of better in all 42 cells.
- **Roadworks is not a catch-up tool for the player trailing at the midpoint.** Last-at-midpoint finishing not-last moves 0 to -2.5 points with any variant. The last place of a single game is rarely the player trailing overall (no CSV column backs this).
- **Mid-night leader win %, V2/R2, adult/mixed:** 2 players 63.5 / 77.6; 4 players 39.6 / 45.5; 8 players 26.5 / 30.1.
- **Not measured:** human behaviour, ties for last, the 10 s pick, late joiners, and places 5-8 beyond the placeholder.

## Owner questions (from the driver)
1. 5-8 players: V1 (5 tiles) or V2 (2 Bolts a tile)?
2. Roadworks: R2 or R3?
3. Confirm assumptions 1-3.
4. Should a longer night get a second gate game?
