# board3f run review verdicts (Claude)
- must sim_final_test.dart plain script, mine.sh "No tests ran" - invalid: all sim tests are plain scripts run with `dart run` (exit 0: night_sim_test 29 PASS, sim_report_test 15, sim_final_test 17); mine.sh is not their runner (the worker ran it by the task text). No new dependency.
- should rwAlways doc (cell:66), stats:14 link, stats:68 wrap, code-health.md text, exit codes of the two older tests - fixed by hand (exit codes 0 recorded above)
- should :25-32 FAIL only prints / :27 :29 print - invalid (sim convention: exit code 1 on FAIL)
- should final_test:64 per-count asserts, :36 main length, report:40 kidsPreset, stats:100 dartdoc, cell:16 and report wraps, split-report Summary - minor - docs/code-health.md (board3f)
- could (9) - minor - docs/code-health.md or left (all one-liners, no behaviour)
- board3m must 2 (matrix prices every cell by road variant) - valid, fixed by the added row: finalRulesCells builds the owner's night through SimRules.forNight; all 14 final rows equal their matrix cells (v0 at 2-4, v2 at 5-8, r2, gate on) in every column except road. No OWNER FINDING.
- board3m must 1 and must 3 - fixed in wave 4 (1d8af754, 66eee5dc); re-proved here on temp copies of HEAD: reverting forPlayers to `: tileCost` fails 2 rules_test tests (the 2-player and 4-player re-pricing); reverting the gate game to `(games + 1) ~/ 2` fails the night_sim_test gateGame-2 check. Worktree removed, no diff left.
