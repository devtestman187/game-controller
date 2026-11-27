## Summary

Verdict: small fixes
Counts: must 0 · should 5 · could 2
1. tools/sim/sim_final_test.dart:64 check (a) compares each final row only with its matrix row; it never asserts the brief's expected road length 6 or tile cost 3 (2-4 players) and 2 (5-8), so a wrong value in both rows passes.
2. tools/sim/sim_cell.dart:66 the `rules` doc says the rules are the exact night, but rwAlways still changes the bots (sim_report.dart:46) and is written to the CSV (sim_report.dart:85).
3. tools/sim/sim_final_test.dart:36 main() is about 66 lines, over the ~40-line function rule.
Not run: `dart run tools/sim/sim_final_test.dart` and the shell commands were refused by the approval gate, so the 17 PASS lines and the computed values are unverified.

## Findings

- **should** tools/sim/sim_final_test.dart:64 check (a) only equates each final row with its matrix row and never asserts the brief's values (road_length 6 at every count, tile_cost 3 at 2-4, 2 at 5-8) → add asserts on tileCostColumn and roadLengthColumn per count, as (b) and (c) do.
- **should** tools/sim/sim_cell.dart:66 the `rules` doc says the rules give the exact night, but runSimCell still reads cell.rwAlways (tools/sim/sim_report.dart:46) and simCsvRow still writes it (sim_report.dart:85), so a rules cell with rwAlways true changes the bots outside its rules → name rwAlways in the doc, or move it into SimRules, or assert it is false in finalRulesCells.
- **should** tools/sim/sim_final_test.dart:36 main() runs from line 36 to the closing brace at about line 101 (about 66 lines), over the ~40-line function rule (guidelines §3) → split out one function per check (checkFinalMatchesMatrix, checkTileCostAndRoadLength, checkFinalRowNames).
- **should** tools/sim/sim_report.dart:152 the new dartdoc line is over 120 columns (grep `^.{121,}$`) → rewrap the two lines of the finalRulesCells doc.
- **should** docs/briefs/m17/board3f/final-row-report.md:39 self-check 4 says "five files (plus this report)"; the diff has four code files and the report, and line 15 lists tools/sim/sim_stats.dart under "Files changed" though it is unchanged → correct both lines to the diff.
- **could** tools/sim/sim_report.dart:154 finalRulesCells repeats the cell constructor already written in the simMatrixCells helper (sim_report.dart:115-133) → share one constructor for both lists.
- **could** tools/sim/sim_report.dart:86 the gate column reads rules.targetedGate, so a kids rules night would print gate true while no gate plays (SimRules.gateOn is false); finalRulesCells never builds one, so the output is right today → read rules.gateOn, or document the choice.

## Decisions to confirm

- The gate column comes from `rules.targetedGate` (sim_report.dart:86), not `rules.gateOn`. Right today; wrong for a future kids rules cell.
- final-row.md:2 says "never tools/mine.sh", yet final-row-report.md:48 says the worker ran it, and it failed on "No tests ran" for plain-script sim tests. The brief and the worker rules disagree; the owner should say which stands.
- final-row-report.md:24 says "formatted 1 file" while mine.sh reports "4 file(s) formatted" (line 48). The git diff shows only the five allowed files, so nothing outside `allow:` changed, but the count is unexplained.
- sim_final_test.dart:27 prints PASS/FAIL lines, the same style as sim_report_test.dart. Guidelines §2 bars `print` in a finished diff; confirm the plain-script style or move to package:test (see the mine.sh item above).
- sim_final_test.dart:94 adds a fourth check (road final, Roadworks r2, gate true) that the brief did not ask for. It is harmless; confirm it stays.
- finalRulesCells sets `games: nightGames` (sim_report.dart:160) while the rules carry their own `city.nightGames` from base. Both are 5 today; the game count has two sources.

## Could not check

- The test run: `dart run tools/sim/sim_final_test.dart` was refused by the approval gate. The 17 PASS count, the matrix road_length 6 and the tile costs 3/2 are unverified.
- Format and analyze results: not run; the 120-column check was done with grep only.
- final-row-report.md:39 says `git status` lists only the five files; I could read only the diff, so this is not verified.
- The 6-player tile cost of 2 depends on CityRules.forPlayers, which I did not read (sim_rules.dart:91 calls it).
- Line counts (wc -l): sim_report.dart 172, sim_cell.dart 80, run_sim.dart 50, sim_final_test.dart 101, sim_stats.dart 211; all under the limits.
