## Summary

Verdict: small fixes
Counts: must 1, should 3, could 2
1. must: the new gate-game check passes with the old `(games + 1) ~/ 2` formula too (5 games gives 3 either way), so it does not catch a revert of night_sim.dart:112-115.
2. should: no test sets `gateBlocksRoadworks` or checks that a gated player is refused Roadworks (night_sim.dart:270 has no test); the report's self-check line says it is covered.
3. should: night_sim.dart:5 still calls the gate and Roadworks rules "assumptions", and sim_rules.dart:84 is 121 columns.

## Findings

- **must** tools/sim/night_sim_test.dart:275 The new gate-game check passes with the old `(games + 1) ~/ 2` formula too (5 games gives 3 both ways, and CityRules.standard.gateGame is 3), so reverting night_sim.dart:112-115 keeps it green → add a check with a city whose gateGame is not 3 (cityRulesWith has no gateGame parameter, so add one or build CityRules directly) and assert the gate lands in that game.
- **should** tools/sim/night_sim.dart:270 The gate-blocks-Roadworks path (`nextTileGated: gated[last] && rules.gateBlocksRoadworks`) has no test: no night_sim_test.dart check sets `gateBlocksRoadworks` or asserts a gated last-place player gets no crew, and sim_rules_test.dart:61 only reads the factory default → add a night_sim check (R2, gated last place: no crew; with the flag off: crew) or drop the self-check claim in g3r2-report.md.
- **should** tools/sim/night_sim.dart:5 The header still says the gate and Roadworks rules are "assumptions" marked in SimRules, but sim_rules.dart:77-81 now calls both owner rules (Nov 27) → reword lines 5-7 to say they are owner rules.
- **should** tools/sim/sim_rules.dart:84 The new doc line is 121 columns, over the 120 limit → rewrap it.
- **could** tools/sim/sim_rules_test.dart:1 The header comment is 120-121 columns, at the limit → shorten it.
- **could** tools/sim/night_sim_test.dart:296 `List.generate(seedCount, (seed) => seed).any(` is hard to read for a loop over seeds → use `Iterable<int>.generate(seedCount).any(` or a for loop.

## Decisions to confirm

- The job did not run `tools/mine.sh`. Its brief says "never tools/mine.sh", while the worker rules name mine.sh as the check. Claude to say which gate applies (g3r2-report.md question 1).
- Two gate-game rules now exist: the shipping `gateGame` on a 5-game night, and `(games + 1) ~/ 2` on any other length. A gated night of another length keeps the old middle game. This is safe only if the matrix runs 5-game nights; no caller of other lengths was checked.
- `SimRules.copyWith` cannot set `gateBlocksRoadworks` or `gateOpeningCostsBolts` (sim_rules.dart:111-117). Nothing needs that yet; add it when a caller does.
- The report's closing sections (commit, status, delete) are added here; the brief asked for "this order and nothing else". Claude to say which one it wants.

## Could not check

- The sim test output in g3r2-report.md (the PASS lines, `sim-test.sh` exit 0, "No issues found!"). I did not run the sim tests, and run.log (line 67) records only "tests-first ok: sim_rules_test.dart fails on the old code".
- "At least one seed differs at the gate game" and "the existing checks still pass" (g3r2-report.md computed values): not run.
- The night_sim check "passes on the old code": judged by reading (both formulas give 3), not run against the old file.
- REPORT-v2.md:39 "adult, R2 rows": the CSV was not read, so I cannot tell which rows the +0.36 to +0.97 figures come from.
- `docs/briefs/m17/board3m/run-findings.md` does not exist, so there were no run-findings entries to check.

## Commit message

none: review only, no code or document change.

## Status row

- board3m wave3 review (g3r2): reviewed; 1 must and 3 should open (gate-game test, gate-blocks test, stale header, 121-column line).

## Delete

- none
