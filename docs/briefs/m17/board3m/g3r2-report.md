# board3m g3r2 report: the simulator reads the final rules; the V2 label

## Summary

- Added `SimRules.forNight` (the factory) and gave it the owner's Nov 27 night rules: the tile price of that night size,
  Roadworks R2, the targeted gate, and both gate rules on.
- The two gate flags are owner rules now, so their doc comments no longer say "assumption".
- `simulateNight` takes its gate game from the rules on a shipping-length night (`rules.city.gateGame`); other lengths
  keep `(games + 1) ~/ 2`.
- Roadworks availability passes the gate into `roadworksOffered(..., nextTileGated: ...)` instead of a separate
  `!(gated && ...)` term.
- REPORT-v2.md line 39: "(adult, V2)" is now "(adult, R2 rows)"; nothing else in the file changed.
- Tests were written first in the new file `sim_rules_test.dart` and one new check in `night_sim_test.dart`. The
  factory did not exist, so both files failed to compile before the change (the exemption in the brief).
- Decisions: `copyWith` is unchanged; it already carries both gate flags through. The factory is a `factory`
  constructor, as the brief names it.

## Files changed

- `tools/sim/sim_rules.dart`: added `SimRules.forNight(CityRules base, {required int players, bool kids = false})`;
  the two gate flag doc comments now say "Owner rule (Nov 27)".
- `tools/sim/night_sim.dart`: gate game from `rules.city.gateGame` when `config.games == rules.city.nightGames`, else
  `(config.games + 1) ~/ 2`; Roadworks availability passes `nextTileGated: gated[last] && rules.gateBlocksRoadworks`
  to `roadworksOffered` and drops the separate term.
- `tools/sim/night_sim_test.dart`: one new check at the end of `main`.
- `tools/sim/sim_rules_test.dart` (new): 11 checks of the factory.
- `docs/briefs/m17/city/REPORT-v2.md`: line 39 label only.
- `docs/briefs/m17/board3m/g3r2-report.md` (this file).

## Computed test values

- Tile cost from `CityRules.standard` (small night 3, large night 2): 2 players 3, 4 players 3, 5 players 2, 8 players 2.
- Road length: equal to the base's (6).
- Kids night: `gateOn` false, `roadworksInForce` off.
- New night_sim check: 5 games, 4 players, `SimRules.forNight(CityRules.standard, players: 4)` against the same with
  `targetedGate: false`, over 300 seeds (`seedCount`). The gate game is `CityRules.standard.gateGame` (3, read from the
  value). Games 1 to gateGame - 1 match the no-gate run on every seed; at least one seed differs at the gate game.

## Checks run

- `dart format tools/sim`: "Formatted 9 files (0 changed)" on the final run (the first run reflowed 4 files).
- `bash tools/tests/sim-test.sh`: exit 0. Every `tools/sim/*_test.dart` file prints PASS, including the new lines:
  - `PASS a 5-game 4-player night with forNight places its gate in game CityRules.standard.gateGame`
  - `PASS tools/sim/night_sim_test.dart`
  - `PASS a 2-player night costs 3 Bolts a tile (the small-night price)`
  - `PASS a 4-player night costs 3 Bolts a tile (the small-night price)`
  - `PASS a 5-player night costs 2 Bolts a tile (the large-night price)`
  - `PASS an 8-player night costs 2 Bolts a tile (the large-night price)`
  - `PASS a night keeps the base road length`
  - `PASS a night offers R2 Roadworks (free, replaces one Build)`
  - `PASS a night of adults has the targeted gate on`
  - `PASS a kids night has no gate`
  - `PASS a kids night has no Roadworks`
  - `PASS a kids flag reaches the city rules`
  - `PASS the owner rules are on: a gate blocks Roadworks and opening a gate costs Bolts`
  - `PASS tools/sim/sim_rules_test.dart`
- `dart analyze tools/sim`: "No issues found!"
- `tools/mine.sh`: not run (see question 1).
- `tools/check.sh`: not run (left to the script after I finish).

## Self-check (review-rules part A)

1. Host setups: N/A, no host code is touched; the sim has no host surface.
2. Kept state: N/A; the factory keeps no state.
3. Combinations: the gate flags with Roadworks are covered by the `roadworks R2` and `gate` checks in
   `night_sim_test.dart` (the existing "gate does not change the games" and "gated night builds fewer tiles" checks
   still pass).
4. Files: only the files in `allow:`.
5. Stop: no stop needed.
6. Looks: N/A, no UI.

## Hand-over

- Done: everything in the brief's steps 1 to 4 (tests first, factory and sim changes, label, format, sim tests, analyze).
- Not done: `tools/mine.sh` (the brief forbids it and the task asks for it; see question 1).
- Not verified: that the new night_sim check fails on the code as it was. It cannot compile on the old code (no
  `forNight`), so it fails there by construction; I did not make a separate run against the old code.

## Questions and suggestions

1. The task says "check with tools/mine.sh", but the brief's `stop:` line says "never tools/mine.sh". I followed the
   brief and ran the sim tests, format and analyze instead. Which one should the gate use?
2. `night_sim.dart` header (lines 3-5) still says the gate and Roadworks rules are "assumptions" marked in `SimRules`.
   That is stale now. The brief said no other change in `night_sim.dart`, so I left it; a small doc edit would fix it.
3. `copyWith` cannot change `gateBlocksRoadworks` or `gateOpeningCostsBolts`; it copies them. Nothing needs them
   changed yet, so I left it alone.
4. The gate-game rule `(config.games + 1) ~/ 2` is kept for non-shipping night lengths. If the matrix ever runs
   a length other than 5 games with a gate, the gate game there is the old middle-game rule, not the shipping one.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

board3m g3r2: sim reads the final night rules and the V2 label is fixed

SimRules.forNight builds a night from the shipping rules for its player count: the tile price (3 Bolts at 2-4
players, 2 at 5-8), Roadworks R2, the targeted gate, and both gate rules, which are owner rules from Nov 27 and no
longer assumptions. simulateNight takes the gate game from CityRules on a shipping-length night, and Roadworks
availability uses roadworksOffered with nextTileGated. REPORT-v2 line 39 now says "R2 rows". New tests in
sim_rules_test.dart and night_sim_test.dart; sim-test.sh and dart analyze pass.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- board3m g3r2: done, the sim reads the final Nov 27 night rules via SimRules.forNight, gate game and Roadworks gate follow the rules, REPORT-v2 label fixed; open: tools/mine.sh gate run and the stale night_sim.dart header (question 2).

## Delete

- none
