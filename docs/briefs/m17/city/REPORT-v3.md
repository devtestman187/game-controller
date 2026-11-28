# City Rush tuning report v3 (tune4a h4b2)

For the owner. Report only: no rule, no constant, no setting is changed. Data: `sim-results-v3.csv` (56 rows, 5000 nights
each, seed 17, 5 games a night) and `sim-tables-v3.md`. `csv:<n>` is data row n (row 1 = first data row, i.e. file line
2). Rows 1-14 adult final rules (per player count: Roadworks r2, then off), 15-28 mixed final rules (same order), 29-56
adult 5-tile road "v1" (3 Bolts a tile; per player count: off, r1, r2, r3; 2p = 29-32, 3p = 33-36, 4p = 37-40,
5p = 41-44, 6p = 45-48, 7p = 49-52, 8p = 53-56). Final rules: 6 tiles, 3 Bolts at 2-4 players, 2 Bolts at 5-8.

## Proposals (one line each; the owner picks in Q-A)

- **A. No change.** Both targets that the model can measure are met (section 1).
- **B. 5-8 players on the 5-tile road at 3 Bolts (v1) instead of 6 tiles at 2 Bolts.** 8p Plaza 100.0% -> 97.8%,
  first Plaza game 4.20 -> 4.84 (csv:13, csv:55).
- **C. Roadworks off.** Last-at-midpoint finishing not-last +0.2 to +4.2 points (adult), -0.5 to +5.7 (mixed); costs
  spread and 4-player Plaza (csv:1-14, csv:15-28).
- **D. 4 players at 2 Bolts a tile (the cost step moves from 5 to 4 players).** Not simulated; today's 4p figures are
  csv:5, csv:6, csv:19, csv:20. Needs one more run before it can be chosen.

## 1. Results against the targets

| Target | Result | Rows |
| --- | --- | --- |
| Winner reaches the Plaza in 9 of 10 nights (0.90) | Met in all 28 final-rule rows. Lowest: 0.9858 (adult 4p, Roadworks off); lowest with Roadworks r2: 0.9982 adult 4p, 0.9968 mixed 4p. All other final-rule rows 0.9978-1.0000. | csv:6, csv:5, csv:19, csv:20 |
| 5-game night of 25-35 min (N1) | Not measured. The model has no clock. | none |

The target is overshot, not just met: the model reaches 98.6-100.0% where the bar is 90%. The 5-tile road (v1) sits
closer to the bar: lowest 0.9524 (8p, Roadworks off), 0.9778 with r2 (csv:53, csv:55).

## 2. Fable-flagged measures, 3-8 players, final rules

Catch-up rate = `mid_last_not_last_rate` (the player last at the midpoint finishes not last). It replaces
`comeback_rate`. Spread = `mean_tile_spread` (tiles, leader minus last). Plaza reach = `plaza_rate`.

| Players | Catch-up r2 adult | Catch-up off adult | Catch-up r2 mixed | Spread r2 adult | Spread r2 mixed | Plaza r2 adult / mixed |
| --- | --- | --- | --- | --- | --- | --- |
| 3 | 0.6542 (csv:3) | 0.6812 (csv:4) | 0.5892 (csv:17) | 0.6262 (csv:3) | 0.7172 (csv:17) | 1.0000 / 1.0000 |
| 4 | 0.6306 (csv:5) | 0.6510 (csv:6) | 0.5634 (csv:19) | 1.8180 (csv:5) | 2.1488 (csv:19) | 0.9982 / 0.9968 |
| 5 | 0.5992 (csv:7) | 0.6134 (csv:8) | 0.5830 (csv:21) | 1.0402 (csv:7) | 1.2012 (csv:21) | 1.0000 / 1.0000 |
| 6 | 0.6066 (csv:9) | 0.6370 (csv:10) | 0.5812 (csv:23) | 1.8148 (csv:9) | 1.9512 (csv:23) | 1.0000 / 1.0000 |
| 7 | 0.6310 (csv:11) | 0.6730 (csv:12) | 0.6138 (csv:25) | 2.2854 (csv:11) | 2.4162 (csv:25) | 1.0000 / 1.0000 |
| 8 | 0.6918 (csv:13) | 0.7300 (csv:14) | 0.6610 (csv:27) | 2.6140 (csv:13) | 2.7310 (csv:27) | 1.0000 / 1.0000 |

Reading, from the rows above:
- Roadworks does not raise the catch-up rate: every adult pair is lower with r2 than off, by 0.2 to 4.2 points
  (csv:1-2 ... csv:13-14). Mixed: lower in 5 of 7 pairs; higher by 0.5 points at 6 players and 0.2 at 8 (csv:23-24,
  csv:27-28).
- Roadworks does shrink spread: adult 3p 1.1340 -> 0.6262 (csv:4, csv:3), 4p 2.2934 -> 1.8180 (csv:6, csv:5), 8p
  2.7482 -> 2.6140 (csv:14, csv:13).
- Context (my arithmetic, not a CSV column): a player picked at random would finish not-last with probability (n-1)/n.
  Adult r2 is below that at every count: 3p 0.654 vs 0.667, 5p 0.599 vs 0.800, 8p 0.692 vs 0.875. Last at the
  midpoint tends to stay near the bottom; nothing in the rules moves that.
- Plaza reach is not what limits a night; the first Plaza comes at game 3.74-4.91 of 5 (csv:21 ... csv:6).

Not measured by this model: **repeat rate** (do players start another night) and **night length in minutes**. Both
are proposed as new data in section 4.

## 3. The open Fable findings, one line each

1. *Roadworks at 1 Bolt gives no catch-up (last at midpoint finishes not-last 51-60% with or without it).* Answered,
   the first half holds, the numbers differ: the v1 5-tile road with r1 (1 Bolt) gives 0.6062-0.6610 at 3, 4, 6, 7, 8
   players (csv:34, csv:38, csv:46, csv:50, csv:54), against off 0.6168-0.6690 (csv:33, csv:37, csv:45, csv:49,
   csv:53): no gain. The 51-60% range is not in v3; the final-rule range is 0.4292-0.6918 adult, 0.2344-0.6610 mixed.
2. *At 8 players the Roadworks user ends worse off 37%.* Not supported by v3. Roadworks user worse: 10.67% adult,
   6.02% mixed (csv:13, csv:27); better 29.17% / 29.02%. The nearest 58.61% is the gated player finishing worse
   (csv:13, `gated_worse`), a different group.
3. *"Comeback" is a weak measure.* Agreed. `comeback_rate` moves 0.3408 -> 0.4064 when Roadworks is on at 2 players
   (csv:2, csv:1) while the catch-up rate does not (0.4308 -> 0.4292). Replaced by the catch-up rate above.
4. *A 3-game night almost never reaches the Plaza.* Unresolved: every row is a 5-game night (`games` = 5). Indirect
   only: the mean first Plaza game is 3.34 or later in all 56 rows (lowest csv:32, 3.3352), so a 3-game night would
   miss it most of the time. Needs `games` = 3 cells to settle.
5. *The tile-4 gate never binds.* Unresolved: no column names a tile-4 gate. `rules.dart` sets one gate game (game 3)
   and one gate a night; the gate costs one tile's Bolts (`gateOpenCost`). What the CSV does show is that the gate
   changes places: gated player finishes worse 43.67% (adult 2p, csv:1) to 58.61% (adult 8p, csv:13), mean place
   change 0.4341 to 0.9734. Gate night rate 0.9008 adult, 0.8008-0.8544 mixed (csv:1, csv:15-28).
6. *61% Plaza figure for a 5-tile road.* Struck: no v3 row has a Plaza rate near 61% on the 5-tile road (lowest
   0.9524, csv:53). The nearest 61.5 is v2's 6-tile 3-Bolt road, 7 players, mixed, R1 (REPORT-v2.md headline table).

## 4. Proposed rule changes (at most 3, nothing applied)

**B. 5-8 players: 5 tiles at 3 Bolts (v1), Roadworks r2 as now.** Final rules -> v1 r2 (adult only; no mixed v1 rows):

| Players | Plaza | First Plaza game | Spread | Catch-up | Roadworks user worse |
| --- | --- | --- | --- | --- | --- |
| 5 | 1.0000 -> 1.0000 (csv:7, csv:43) | 3.75 -> 4.55 | 1.0402 -> 1.7310 | 0.5992 -> 0.6300 | 0.0795 -> 0.0800 |
| 6 | 1.0000 -> 0.9998 (csv:9, csv:47) | 3.93 -> 4.71 | 1.8148 -> 2.3058 | 0.6066 -> 0.6054 | 0.0890 -> 0.0835 |
| 7 | 1.0000 -> 0.9946 (csv:11, csv:51) | 4.07 -> 4.79 | 2.2854 -> 2.6600 | 0.6310 -> 0.6148 | 0.0976 -> 0.0853 |
| 8 | 1.0000 -> 0.9778 (csv:13, csv:55) | 4.20 -> 4.84 | 2.6140 -> 2.8752 | 0.6918 -> 0.6594 | 0.1067 -> 0.0838 |

Downside: the Plaza comes about a game later (4.5-4.8 of 5), so a night has less slack, a 3-game night is out of
reach, spread grows at every count, and catch-up falls at 7-8 players. It moves the Plaza rate toward the 90% bar
only by 0.2-2.2 points; the target is met either way.

**C. Roadworks off (final rules).** Catch-up, off minus r2, adult: 2p +0.0016, 3p +0.0270, 4p +0.0204, 5p +0.0142,
6p +0.0304, 7p +0.0420, 8p +0.0382 (csv:1-14); mixed: +0.0568, +0.0342, +0.0206, +0.0128, -0.0046, +0.0068, -0.0022
(csv:15-28). Downside: spread up 0.13-0.51 tiles adult (3p 0.6262 -> 1.1340, csv:3, csv:4); 4-player Plaza 0.9982 ->
0.9858 adult, 0.9968 -> 0.9878 mixed (csv:5, csv:6, csv:19, csv:20); the user who gets Roadworks loses a better-off
chance of 14.5-29.2% adult (`rw_better`, csv:1-13 odd rows).

**D. 4 players at 2 Bolts a tile.** Why: the cost step between 4 and 5 players is a cliff. Adult 4p first Plaza at
game 4.8920 (csv:5), spread 1.8180; 5p at game 3.7546 (csv:7), spread 1.0402. Number it moves: not measured, the v3
run has no 4p cost-2 cell. Downside: probably the 4p Plaza arrives a game earlier and the night gets easier (4p is
already 0.9858-0.9982, csv:5, csv:6). Do not pick this without a run.

### Context only: Shape Race team payout (provisional, not applied)

Winners 3 Bolts, losers 1, doubled in the last game; solo 5/3/2/1, places 5-8 at 1. My arithmetic over 5 games, one
team game of each kind: a team player who always wins earns 4 x 3 + 6 = 18 Bolts, one who always loses 4 x 1 + 2 = 6,
one who wins half 12. A 6-tile road at 2 Bolts costs 12, at 3 Bolts 18. So the 2-Bolt road is reachable for an
even-split team player and the 3-Bolt road only for an always-winner; the simulator's payout (places 5-8 at 1, a
placeholder) is not this table. No CSV row models it.

## 5. Firestore stats fields (proposal, not applied)

| Field | Meaning | Unit | Why |
| --- | --- | --- | --- |
| `spread_tiles` | leader's tiles minus last place's at night end | tiles | compare with `mean_tile_spread` |
| `plaza_reached` | the night's winner reached the Plaza | bool | rate against the 0.90 target |
| `catch_up` | last at the midpoint finished not last | bool | the headline measure |
| `night_length_s` | first game start to results | s | the 25-35 min target (N1), not measurable by the model |
| `repeat_next_night` | the same party starts another night within a set window | bool | repeat rate, not measurable by the model |
| `player_count`, `games_played`, `roadworks_used` | cell keys | count / bool | split every rate above by setup |

## Q-A (for the owner)

Which do you choose: **A** (no change), **B** (5-tile 3-Bolt road for 5-8 players), **C** (Roadworks off), or **D**
(run a 4-player 2-Bolt cell first)? Reply with one letter.
