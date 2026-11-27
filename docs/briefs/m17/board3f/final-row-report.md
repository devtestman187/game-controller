# board3f final-row report

## Summary

The final-rules row is in the simulator. A cell can now carry its exact night rules (`SimCell.rules`), and
`finalRulesCells` builds the owner's night for every adult and mixed player count (2-8, 14 cells) through
`SimRules.forNight(base, players:)` from `CityRules.standard`. The matrix cells, their numbers, `CityRules`,
`sim_rules.dart` and `night_sim.dart` are unchanged.

Files changed:
- `tools/sim/sim_cell.dart` (80 lines): new optional `rules` field (`SimRules?`, null default), with docs. `road` is documented as ignored by a rules cell.
- `tools/sim/sim_report.dart` (172 lines): `runSimCell` uses `cell.rules` when set, else the old code (inline, same logic). `simCsvRow` writes road `final` for a rules cell, road_length and tile_cost from `rules.city`, roadworks from `rules.roadworks`, gate from `rules.targetedGate`. New `finalRulesCells(nights, seed, base)`.
- `tools/sim/run_sim.dart` (50 lines): writes the matrix cells then `finalRulesCells` into the same CSV (header unchanged); top comment updated to one line.
- `tools/sim/sim_final_test.dart` (101 lines, new): checks (a), (b), (c) from the brief, plus one check that a final row reads road `final`, Roadworks `r2`, gate `true`.
- `tools/sim/sim_stats.dart` (211 lines): not changed.

Test counts seen: `flutter test tools/sim/sim_final_test.dart`: 17 PASS, 0 FAIL (see the self-check and checks below).

Check (a), all 14 cells held: every final row equals its matrix cell in every column except road (road_length and tile_cost included). Matrix cell used: v0 at 2-4 players and v2 at 5-8, roadworks r2, gate true, rwAlways false, same population, 40 nights, seed 3. No OWNER FINDING.

Check (b): adult 6 players final row has tile_cost 2 and road_length 6 (PASS).
Check (c): adult 4 players final row has tile_cost 3 (PASS).

`dart format tools/sim`: formatted 1 file (`sim_final_test.dart`), 12 files checked. `dart analyze tools/sim`: No issues found.

## Decisions

- The brief's `stop:` line says "never tools/mine.sh", but the task says to check with `tools/mine.sh`. I followed the task and ran `tools/mine.sh`.
- `dart run` and `dart test` are not on the allow-list (`dart run` was refused). I ran the file with `flutter test tools/sim/sim_final_test.dart` (allowed), which runs its `main()`.
- The test file stays a plain script, as `sim_report_test.dart` and the other sim tests do. The root package has no `test` dependency to use `package:test`.
- Gate column for a rules cell comes from `rules.targetedGate` (the brief's "from rules"), not `rules.gateOn`.
- `runSimCell` keeps its code inline: the brief said "else keep the current code"; the only change is `cell.rules ??`.

## Self-check (docs/review-rules.md part A)

1. Host setups: not applicable (simulator, no host). Shown by: n/a.
2. Kept state: none added; the simulator is pure per cell. Shown by: `runSimCell is repeatable` (existing test) is unchanged.
3. Combination with pause, host away, player away, Get ready, dropped link, results, leaving: not applicable (no app state). Shown by: n/a.
4. Stayed in the folder and inside `allow:`: yes, five files (plus this report). Shown by: `git status` lists only the five allowed files.
5. Stop rather than overstep: nothing to stop for; no OWNER FINDING. Shown by: check (a) passes for all 14 cells.
6. Every look: not applicable (no UI). Shown by: n/a.

## Checks

- `dart format tools/sim`: formatted `sim_final_test.dart` (1 changed), 12 files.
- `dart analyze tools/sim`: No issues found.
- `flutter test tools/sim/sim_final_test.dart`: all 17 PASS (14 cell checks, (b), (c), and the road/roadworks/gate check). Output ends with "No tests ran / No tests were found."
- `tools/mine.sh`: RESULT: FAILED: 1 check(s) failed (1 package(s), 4 file(s) formatted). The failing part is the "FAILED tests ." line: the runner reports no `test()` calls because the file is a plain script. The 17 PASS lines above come from the same file. Mine's output shows the adult checks but not the mixed or later checks; the full output from `flutter test` shows them all PASS.

## Hand-over

Files changed are listed in the Summary. Not run: `tools/check.sh` (not run by me, per the task). Open: see Questions.

## Questions

1. Brief conflict: its `stop:` says "never tools/mine.sh" while the task asks for `tools/mine.sh`. Which should stand? I used `tools/mine.sh`.
2. `tools/mine.sh` treats the sim plain-script tests as "No tests ran" and fails. Should mine.sh accept plain-script tests (as `dart run` scripts), or should sim tests become `package:test` files with a `test` dependency?
3. Should the gate column for a rules cell be `rules.gateOn` rather than `rules.targetedGate`? (A kids night would show `false`; no final cell is a kids night, so the output is the same today.)

## Commit message — a draft

m17 board3f: final-rules row built through SimRules.forNight

Adds SimCell.rules: a cell can carry its exact night rules, and its road variant is then not applied.
finalRulesCells builds the owner's night for adult and mixed at 2-8 players from the shipping rules
through SimRules.forNight, never from a road-variant copy (cityRulesWith leaves tileCostLargeNight alone).
simCsvRow writes road final with road_length, tile_cost, roadworks and gate read from the rules.
run_sim.dart appends the final cells to the same CSV. Matrix cells and their numbers are unchanged.
sim_final_test.dart checks the 14 final rows against their matrix cells (all match but the road column).

## Status row

board3f final-rules row: done (SimCell.rules, finalRulesCells, CSV row, run_sim, sim_final_test: 14 cells match their matrix cells); open: mine.sh reports "No tests ran" for plain-script sim tests (decide the sim test style).

## Delete

- none
