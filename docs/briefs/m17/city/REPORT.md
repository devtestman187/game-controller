# City Rush night simulation: bot-tuned, PROVISIONAL (board3b, Nov 27)
Bots are guesses (tools/sim/bots.dart), not measured players. Every number below says what the model does, not what kids will do. Re-run with `dart run tools/sim/run_sim.dart --nights 5000 --seed 17` (about 4 s); raw rows in sim-results.csv (36 cells: adult, mixed and kids bots x 3/4/8 players x 3/5 games x Roadworks off/on, plus Roadworks free).

## Model (docs/briefs/m17/board3b/sim-model.md)
Owner Nov 26 road rules (own 6-tile road per player, tile 3 Bolts, at most 3 Builds a stop, Save +2, placement 5/3/2/1 with the last game x2, places 5-8 = 1 Bolt placeholder, gate at tile 4 opened by a mid-night game, ranking only at the end) read from CityRules. Owner Nov 27 Roadworks ("A, one, A"): last place only, 1 Bolt, replaces ONE Build, then picks a road: own = a crew lays your next tile now; rival = block on its next unbuilt tile, cleared by that player's next Build (3 Bolts); one block per road; never on Kids nights. Pick policy: adult = greedy (crew own road unless the best rival leads by 2+ tiles, then block that rival); child = random among own road and the pickable rivals. The simulator keeps an on/off flag. Mixed = adult, child, adult, child... Round results are noisy performances sorted into places through the stub RoundPlacing (no ties in the sim; the real rule gives Roadworks to every tied last place).
Assumptions to confirm: the gate tile itself cannot be built before the gates open; Roadworks resolves before the stop's Builds; the Save/Roadworks choice exists only for last place; non-last players always build as much as they can pay.

## Headline (mixed bots, 5000 nights per row)
Columns: tile spread = mean (best - worst tiles at the end); comeback = champion not among the midpoint leaders (ties at the midpoint inflate it); mid-leader win = midpoint leader wins; recovers = last at the midpoint finishes not last; Plaza = the night's winner reached the Plaza; own = share of Roadworks picks on the placer's own road; multi-hit = nights where one player is blocked 2+ times (all nights); beats/same/worse = the Roadworks user's final place against the same night without Roadworks.

| Players | Games | Roadworks | Tile spread | Comeback | Mid-leader win | Recovers | Plaza | Own pick | Multi-hit | Beats/same/worse |
|---|---|---|---|---|---|---|---|---|---|---|
| 3 | 3 | off | 2.07 | 55% | 45% | 55% | 21% | - | 0.0% | - |
| 3 | 3 | on | 1.99 | 56% | 44% | 53% | 19% | 86% | 0.1% | 14/80/6% |
| 3 | 5 | off | 0.64 | 41% | 51% | 56% | 100% | - | 0.0% | - |
| 3 | 5 | on | 0.66 | 40% | 53% | 51% | 100% | 82% | 1.1% | 14/77/8% |
| 4 | 3 | off | 2.60 | 62% | 38% | 60% | 6% | - | 0.0% | - |
| 4 | 3 | on | 2.61 | 62% | 38% | 59% | 6% | 70% | 0.3% | 19/75/7% |
| 4 | 5 | off | 2.10 | 45% | 46% | 54% | 100% | - | 0.0% | - |
| 4 | 5 | on | 2.20 | 45% | 46% | 51% | 99% | 66% | 1.4% | 15/75/10% |
| 8 | 3 | off | 3.15 | 75% | 25% | 65% | 2% | - | 0.0% | - |
| 8 | 3 | on | 3.19 | 75% | 25% | 66% | 2% | 46% | 0.1% | 16/48/37% |
| 8 | 5 | off | 3.48 | 58% | 31% | 60% | 55% | - | 0.0% | - |
| 8 | 5 | on | 3.57 | 59% | 30% | 61% | 52% | 39% | 0.9% | 13/51/36% |

## What it says
- Night length: at the current numbers a 3-game night rarely reaches the Plaza (6% at 4 players, 2% at 8; 21% at 3), a 5-game night almost always does at 3-4 players (99-100%) and about half the time at 8. The 3-game and 5-game nights are different games: a 3-game night is decided on distance, a 5-game night on who gets there first.
- Roadworks barely moves the night: spread changes by about 0.1 tile at most, the comeback rate by 1-3 points, and the last-at-midpoint player recovers about as often (up to 3 points lower with Roadworks). It places 0.1-0.5 blocks a night. For the user it is "same" about 75% of the time at 3-4 players, "better" 14-19%, "worse" 6-10%; at 8 players "worse" rises to 36% (child bots pick at random and give up a Build for a block that rarely matters). Blocking the leader is rare (own pick 39-86%); one player blocked twice happens in 0.1-1.4% of nights, only a nuisance.
- The gate at tile 4 never binds with these numbers: before the gate game a player can have at most 1 tile (3-game night) or 3 tiles (5-game night). It is a story beat, not a brake.
- Kids bots (no Roadworks) look like the adult/mixed rows: spread 0.4-3.5 tiles, comeback 44-75%.
- Roadworks free (0 Bolts, mixed bots): beats-Build rises to 24-28% at 3-4 players with "worse" at 4-7%; recovery moves at most 3 points and comeback within 2 points, except 3 players in 3 games where comeback drops from 56% to 43% (more ties at the midpoint, not fewer comebacks to trust).

## Proposed changes (at most 3, provisional)
1. Road of 5 tiles with the gate at tile 3 (or tile cost 2): the Plaza is then reached in 61% of 3-game nights at 4 players and 97-100% of 5-game nights up to 8 players (a variant run, not in the CSV; road 5 is the only change). The owner decides whether the 3-game night should be able to finish.
2. Treat Roadworks as flavour, not as the comeback tool, until measured with real players: keep it but price it at 0 Bolts or let the own-road crew lay a free tile plus the Build; the 1 Bolt price lowers its use for no gain. Do not count on it to rescue the last-place player.
3. Move the gate earlier (tile 2) if the gate is meant to hold players back; at tile 4 it never does.

## Not measured
Real placings (the sim places by noisy bot scores), team games, places 5-8 payouts beyond the 1 Bolt placeholder, human pick behaviour, ties for last place, late joiners, absent players, the Vote picker, the shop timer.
