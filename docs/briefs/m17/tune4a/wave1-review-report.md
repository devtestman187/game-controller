## Summary

Verdict: needs Claude
Counts: must 0 · should 6 · could 6
Top findings:
1. Brief item 5 is not done: no v3 CSV or tables, no plaza-rate range, no row count (h4a-report.md:5-7, 43-44).
2. The exit-2 option parsing, the "rules changed during run" path and `v3Tables` have no test (run_sim_v3.dart:58, :147, :159).
3. The h4a report has no review-rules part A self-check (h4a-report.md:29).

## Findings

- **should** docs/briefs/m17/tune4a/h4a-report.md:29 The report has no part A self-check (six host and state lines), which guidelines §11 requires → add the six one-line answers, each with its test or "not affected".
- **should** docs/briefs/m17/tune4a/h4a-report.md:5-7 Brief item 5 is not done: the run was refused, so sim-results-v3.csv and sim-tables-v3.md are absent and the plaza-rate range and row count are not reported → run the default command (or get approval), then report both numbers.
- **should** tools/sim/run_sim_v3.dart:58 The option parsing and exit 2 (odd argument count, unknown flag, `--nights 0`, `--seed x`) have no test → move the parsing into a function that returns null on bad input and test those cases in run_sim_v3_test.dart.
- **should** tools/sim/run_sim_v3.dart:147 The branch that returns null and writes nothing when a rule file changed has no test, although the brief lists it as a feature → make the rule-file list a parameter of runSimV3 and test a changed file gives null and no output.
- **should** tools/sim/run_sim_v3.dart:159 `v3Tables` and `tableColumns` (:39) have no test; the header and row column counts match by hand today (13 each) but nothing keeps them equal → add a test that counts `|` in the header and each row against `tableColumns + 1`.
- **should** tools/sim/run_sim_v3.dart:47 Bare `64` (`BigInt.one << 64`, `_mask64`) and `radix: 16` at :47-48, and `padLeft(16, '0')` at :134, break the no-magic-number rule → name them (`fnvBitCount`, `digestHexDigits`) with a doc line each.
- **could** tools/sim/run_sim_v3.dart:165 The table header text hard-codes "a 5-game night" and "(3 Bolts)" at :175, while :168 prints the real game count → build those words from `nightGames` and `fiveTileRoad` so they cannot disagree.
- **could** tools/sim/run_sim_v3.dart:26 `usage` and :51 `main` have no dartdoc (guidelines §10 covers every public member) → add one line each.
- **could** tools/sim/run_sim_v3_test.dart:50 The 5-tile check compares against the same `fiveTileRoad` constant the script uses, so it passes if that constant is changed to v3 → assert `fiveTileRoad.roadLength == 5` as well.
- **could** tools/sim/run_sim_v3_test.dart:40 `rwOn` and `rwOff` (and `wellFormed` at run_sim_v3.dart:58) are not question-shaped names (§4) → rename to `hasRoadworksOn`, `hasRoadworksOff`, `isWellFormed`.
- **could** tools/sim/run_sim_v3.dart:52 A repeated option (`--seed 3 --seed 4`) is silently overwritten by the map → reject a duplicate with exit 2.
- **could** tools/sim/run_sim_v3_test.dart:95 The temp directory is deleted only on the last line, so a throw in an earlier check leaks it → wrap the checks in try/finally.
- **could** tools/sim/run_sim_v3_test.dart:66 The `runSimCell(cells.first)` result is discarded; the check reads only the digest, so the cell is run for no reason → drop the call, or assert on its rows.

## Decisions to confirm

- The 5-tile road is `RoadVariant.v1` (5 tiles, 3 Bolts; sim_rules.dart:39). The brief said "in rules.dart", but the enum is in sim_rules.dart; v3 (5 tiles, 2 Bolts) is not measured. Why: the 5-tile figure depends on which one the owner means.
- Mixed cells call `SimRules.forNight` with no `kids` argument (default false), as `finalRulesCells` does (sim_report.dart:167). The brief's `kids: ...` is not in the code, and the report does not say it was dropped. Why: the mixed cells' rules depend on it.
- The digest covers only `rules.dart` and `sim_rules.dart` (run_sim_v3.dart:30-33), but cells also run through night_sim.dart and sim_stats.dart, and the doc at :137-138 says the rows match "the rules on disk". Why: a change to those files passes the check unnoticed.
- One table row per cell instead of per player count (run_sim_v3.dart:179-189). Declared in the report; accept or ask for the brief's layout. Why: the brief named player-count rows.
- The tests step of `tools/mine.sh` runs `dart test` on `*_test.dart` files (mine.sh:14) and fails on a plain `main()` script. The report's proposal is `tools/tests/sim-test.sh` as the gate for `tools/sim` tests. Why: the brief's check list names only format and analyze.
- The "rules changed" message goes to stderr, not stdout (run_sim_v3.dart:74). Declared in the report; fine. Why: the brief said "printing".

## Could not check

- The sim-test.sh PASS lines: run.log has no check output (only "tests-first ok", run.log:14). I did not run the tests, so "all PASS" is unverified.
- `dart format` and `dart analyze` results: not run.
- The refusal of the default run: no transcript here. I verified only that docs/briefs/m17/city/ has no sim-results-v3.csv or sim-tables-v3.md.
- Row count: checked by reading `simMatrixCells` (sim_report.dart:134-148): 28 final cells, plus 7 player counts × 4 `RoadworksVariant` values for the 5-tile cells = 56. The plaza-rate range is not computed.
- Whether `simCsvHeader` and `simCsvRow` are unchanged from v2: not checked.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

tune4a review: findings on the h4a v3 run script

Review only: no code changed. Writes the wave1 review of h4a into
docs/briefs/m17/tune4a/wave1-review-report.md: 6 should and 6 could findings.
The main gaps: the v3 run was never done, and option parsing, the digest-change
path and v3Tables have no tests. Six decisions are listed for Claude to confirm.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

tune4a wave1 review of h4a done (6 should, 6 could); open: run the v3 script for the two outputs, fix the findings, confirm the decisions.

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`.

- none
