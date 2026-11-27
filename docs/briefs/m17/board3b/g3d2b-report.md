# g3d2b report: metrics over many nights, CSV and the command line

## Summary

- `tools/sim/sim_report.dart` (new): `populationProfiles`, `SimCell` (value object), `SimCellStats`, `runSimCell`,
  `simCsvHeader`, `simCsvRow`, `simMatrixRows`. Metrics follow sim-model.md "Metrics"; the Roadworks-on cells replay
  each night with the flag off from the same seed.
- `tools/sim/sim_report_test.dart` (new): 16 checks, plain Dart script, all PASS under `bash tools/tests/sim-test.sh`.
- `tools/sim/run_sim.dart` (new): `--nights N` (5000), `--seed S` (17), `--out <path>` (docs/briefs/m17/city/sim-results.csv,
  folder created). Prints the path and the row count. Uses `CityRules.standard`. Not run (the brief says so).
- Not changed: night_sim.dart, bots.dart, and their tests.
- Checks: `dart format` on the three files: formatted. `tools/mine.sh`: format and analyze pass; the test step FAILS for a
  reason in the harness, not in the code (see Questions 1).
- Test output (sim-test.sh, sim_report_test.dart): all 16 lines PASS, then `PASS tools/sim/sim_report_test.dart`.
- Runtime: one `runSimCell` of 200 nights, 4 players, 5 games, mixed, Roadworks off: 11 ms (timed once with a temporary
  Stopwatch in the test, removed afterwards). Roadworks-on cells play each night twice, so about 2x that.
- Computed values: the checks print PASS/FAIL only, so the expectation values were not printed. Only the stated bounds
  were checked (blocks > 0 on 300 nights, own pick share in 0..1, beats + same + worse within 0.001 of 1, tile spread > 0
  on 200 nights, 36 matrix rows).

## Decisions

1. `runSimCell` takes a `SimCell` value object (fields: population, players, games, roadworks, nights, seed, rules), not
   seven named parameters. Reason: the worker rule caps parameters at five and asks for a value object beyond that. The
   brief's `runSimCell({...})` shape is therefore `runSimCell(SimCell)`. Easy to change back if the brief wins.
2. A kids cell ignores the Roadworks flag: `SimCellStats.roadworksOn` is false, and the CSV `roadworks` column says `false`.
   The cell keeps the requested flag in `cell.roadworks`.
3. The CSV writes `roadworks` as `true`/`false` (not 1/0).
4. Population names are constants (`adultPopulation`, `mixedPopulation`, `kidsPopulation`); an unknown name throws
   `ArgumentError`. `runSimCell` throws `ArgumentError` when `nights < 1`.
5. Mixed population: even player indices are adults, odd are children (player 1 an adult).
6. `midLeaderWinRate` uses `midLeaders.first`: `midLeaders` is built in ranking order, so it is the best-ranked mid leader.
7. Roadworks comparison: a lower place number is better. "Beats" = on-run place < off-run place.
8. `meanFirstPlazaGame` and `meanBlocks` are not rates; they get the same four decimals as the rates in the CSV.
9. `run_sim.dart` parses options by hand (no new package). An unknown option, a missing value, `N < 1` or a non-integer
   prints the usage line to stderr and exits 2.
10. `freeRoadworksCost` is the constant 0 for the cheap-Roadworks rows.

## Self-check (review-rules part A)

1. Host setups: N/A (simulator, no host UI). Matrix row count covers 3, 4 and 8 players: "matrix has 36 rows".
2. Kept state: none across calls. Each `runSimCell` starts a fresh `_CellTally` and returns the stats; the empty cell is
   refused by `ArgumentError` ("nights < 1" path, not tested).
3. Combinations: Roadworks off and on are both covered ("roadworks off: ..." and "roadworks on, 4 players ..."); the
   kids flag combination is covered ("kids cell ignores the roadworks flag").
4. Folder and allow: only the three `.dart` files and this report were written.
5. Stop rather than overstep: nothing overstepped; the signature deviation is Decision 1.
6. Looks: N/A (no UI).

## Questions

1. `tools/mine.sh` cannot pass this test file: it runs `dart test`, which reports "No tests were found" for a plain
   script with `main()`. Its output was `FAILED tests .` / `No tests were found.` / `RESULT: FAILED: 1 check(s) failed`.
   Format and analyze were not the failing step. The existing `night_sim_test.dart` and `bots_test.dart` have the same
   shape, so they fail the same way under mine.sh. Options: (a) mine.sh runs `tools/tests/sim-test.sh` for `tools/sim`
   tests; (b) convert the tests to package:test (then `dart run` would silently run nothing, so sim-test.sh would
   stop meaning anything). I recommend (a).
2. The CSV has `games` and `night_games` as the same number (`cell.games`). Drop one, or define `night_games` differently?
3. Decision 1: confirm the value object instead of the brief's named parameters.
4. Decision 3: `true`/`false` or `1`/`0` for the `roadworks` column?
5. The matrix in `run_sim.dart` was not run (per the brief). Expected runtime is an estimate from the 11 ms of one
   200-night cell: about 36 cells at 5000 nights, Roadworks-on cells doubled. Roughly a minute or two; not measured.

## Suggestions

- Add the expected numbers to the check messages (the way night_sim_test prints counts), so a reader sees the value and not
  only PASS.
- The paired Roadworks run doubles the cost of every Roadworks-on cell; if the full matrix is slow, the off run could be
  reused across the on cells with the same players and games.

## Commit message — a draft

Subject: m17 board3b g3d2b: night metrics, CSV and run_sim CLI

- sim_report.dart: SimCell, SimCellStats, runSimCell, populationProfiles, simCsvHeader, simCsvRow, simMatrixRows.
- Roadworks-on cells replay each night with the flag off (same seed) for the beats/same/worse shares.
- Kids cells ignore the Roadworks flag and report it as off.
- sim_report_test.dart: 16 plain-script checks (determinism, CSV shape, rate bounds, Roadworks off/on, profiles, matrix).
- run_sim.dart: --nights, --seed, --out; writes the matrix CSV; not run here.
- mine.sh cannot run plain-script tests; sim-test.sh runs them.

## Status row

g3d2b done: metrics (sim_report.dart), CSV and matrix, run_sim.dart CLI, 16 sim_report checks PASS via sim-test.sh.
Open: mine.sh test step fails on plain-script tests (harness, Question 1); CSV not generated (driver's job); signature
and `night_games` need a decision (Questions 2-3).

## Delete

- none
