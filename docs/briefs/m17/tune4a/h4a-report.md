# tune4a h4a: simulator run script for the final rules (v3)

## Summary

STATUS: stopped. The two output files were not written: running `dart run tools/sim/run_sim_v3.dart` was refused by the
permission prompt ("This command requires approval"), in the foreground, in the background and with `--nights 5000`.
The script and its tests are written; the run is the open step.

Changed (all inside allow:):
- `tools/sim/run_sim_v3.dart` (new, 216 lines): `v3Cells`, `runSimV3`, `rulesDigest` (FNV-1a 64-bit over the bytes
  of `packages/party_host/lib/src/city/rules.dart` and `tools/sim/sim_rules.dart`), `v3Tables`, and `main` with the
  same option parsing and exit 2 as run_sim.dart, plus `--tables`. A digest change during the run exits 1 with
  `rules changed during run` and writes nothing.
- `tools/sim/run_sim_v3_test.dart` (new, 96 lines): the checks in the Checks section below.
- Not written yet: `docs/briefs/m17/city/sim-results-v3.csv`, `docs/briefs/m17/city/sim-tables-v3.md`.

Cells (56 rows once run): adult and mixed at 2-8 players, `SimRules.forNight(CityRules.standard, players: n)` with
Roadworks as the rules give it (r2) and with Roadworks off (`copyWith`); plus the adult 5-tile road (`RoadVariant.v1`,
5 tiles at 3 Bolts) at 2-8 players, one cell per Roadworks variant with the gate on, taken from `simMatrixCells`.

Decisions:
1. The 5-tile cells: the brief says "a RoadVariant with a 5-tile road exists in rules.dart". `RoadVariant` is not in
   rules.dart; it is in `tools/sim/sim_rules.dart`, and it has 5-tile variants (v1, v3). I read the condition as met and
   used v1. v3 (5 tiles at 2 Bolts) is not measured.
2. Tables: one row per cell, grouped by population, with road and roadworks columns (not one row per player count),
   so the 5-tile rows fit the same table. `rw_*` cells are `-` for Roadworks-off rows.
3. A digest change prints `rules changed during run` to stderr (the brief says "printing"; stderr chosen).

## Checks

- `bash tools/tests/sim-test.sh`: `PASS tools/sim/run_sim_v3_test.dart` (and every other sim test PASS). No FAIL line.
- `bash tools/mine.sh`: format and analyze of the two files pass. The tests step FAILS for a reason outside this job's
  code: `mine.sh` runs `dart test` on each touched `_test.dart`. The root pubspec has no `test` package and the file
  is a plain `main()` script (as the brief asks, like sim_report_test.dart), so `dart test` runs no tests. Its output
  shows only the first 8 lines; no FAIL line is in the log, so no check failed inside the file.
- Checks in `run_sim_v3_test.dart` (all PASS under sim-test.sh):
  - (a) `v3Cells(20, 3)` twice gives identical CSV text through `runSimCell` and `simCsvRow`.
  - (a) every population at 2-8 players has a Roadworks-on and a Roadworks-off cell; the 5-tile road is present for
    adults at 2-8 players.
  - (b) `rulesDigest` is unchanged across a 20-night cell; two different temp files give different digests.
  - (c) two `runSimV3(nights: 20, seed: 3)` runs write byte-identical CSV, and both return rows.
- `dart analyze` on the two files: no findings in `mine.sh`'s analyze step.
- Not run: the default-settings script run (5000 nights, 56 cells); the winner plaza_rate range and the row count are
  NOT reported because the run was refused.

## Questions

1. Approval: the default run (`dart run tools/sim/run_sim_v3.dart`) needs approval. Please approve it, or run it and
   commit the two CSV/markdown files. Plaza-rate range and row count are then to be filled in.
2. Tests step: plain `main()` scripts cannot pass `tools/mine.sh` (it runs `dart test`, and the root has no `test`
   package). Should the tests step use `tools/tests/sim-test.sh` for `tools/sim/*_test.dart`?
3. 5-tile road: confirm v1 (5 tiles at 3 Bolts) is the one meant; v3 (5 tiles at 2 Bolts) is not measured.

## Suggestions

- Put the rules digest in the tables header so each table names the rule files it was run with.
- `tableColumns` and `tableHeader` in run_sim_v3.dart must change together; a test could check the column count.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

tune4a h4a: add the v3 final-rules simulator run script

Adds tools/sim/run_sim_v3.dart: the final rules (SimRules.forNight) at 2-8 players, adult and mixed, Roadworks on
and off, plus the adult 5-tile road. Writes the v3 CSV and markdown tables. A FNV-1a digest of the rule files
stops the run if they change while it runs. No rule or constant changed. Output files pending the run.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

tune4a h4a: v3 run script and its tests done; sim-results-v3.csv and sim-tables-v3.md not yet generated (run refused).

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`.

- none
