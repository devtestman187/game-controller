# board3m wave 2 review: g3h and g3n

## Summary

Verdict: small fixes
Counts: must 1 · should 3 · could 5
1. rules_test.dart:65 and :69: two of the three new re-pricing tests pass on the old code too (old code gives 2), so they do not guard the fix.
2. g3h-report.md:14 and :16: the city test count (99) is larger than the package count (81), so one of the two claimed counts is wrong.
3. sim_rules.dart:114: a `cityRulesWith(tileCost:)` copy breaks the `tileCost` doc in rules.dart:56-57, and `forPlayers` drops that override.

## Findings

- **must** packages/party_host/test/city/rules_test.dart:65 The test "a 6-player night re-prices a copy that was priced for 2 players" (`forPlayers(2).forPlayers(6)` = 2) and the test at :69 (`forPlayers(6).forPlayers(2).forPlayers(6)` = 2) give 2 on the old code too (old: `forPlayers(2)` keeps 3, then `forPlayers(6)` takes 2; `6→2→6` is 2 at every step), so neither fails for the bug → replace :65 and :69 with `expect(rules.forPlayers(6).forPlayers(4).tileCost, 3)` (old code gives 2, new gives 3), and add the brief's single-step expectation `expect(rules.forPlayers(6).tileCost, 2)`, which has no line in the file.
- **should** tools/sim/sim_rules.dart:114 `cityRulesWith` sets `tileCost` from the override but leaves `tileCostSmallNight` at the base value, so for that copy the `tileCost` doc (packages/party_host/lib/src/city/rules.dart:56-57, "[tileCostSmallNight] on a night of 2-4 players") is false, and `forPlayers(2)` silently returns 3 instead of the override → take `tileCostSmallNight: tileCost ?? base.tileCostSmallNight`, or write the limit into `cityRulesWith`'s doc.
- **should** docs/briefs/m17/board3m/g3h-report.md:14 and :16 The report claims `flutter test packages/party_host/test/city` runs 99 tests (`+99`) and `tools/mine.sh` runs "OK 81 tests packages/party_host"; the city tests are part of the package, so both cannot be right → rerun both counts and correct the report.
- **should** tools/board-gate.sh:38 and :39 The limits 500 and 380 are bare literals in `echo`, against coding-guidelines §2 (each limit a named constant with its unit and reason) → name them (for example `testLimitLines=500`, `libLimitLines=380`) with a comment on the reason, and use them in `limit_of`.
- **could** tools/board-gate.sh:51 `wc -l` counts newlines, so a 381-line .dart file with no final newline counts 380 and passes the gate → count lines with `awk 'END { print NR }'`.
- **could** tools/tests/board-gate-test.sh:102 The cases cover no pass at the test-file limit (500 lines) and no `--base` with an unknown ref (board-gate.sh:19-20 exits 2 there, untested) → add one case each.
- **could** docs/briefs/m17/board3m/g3n-report.md:6 says the script is "about 65 lines"; `tools/board-gate.sh` is 77 lines → correct the figure.
- **could** docs/code-health.md:393 says the CityRules copy is "15-field"; after g3h it is 16 fields in the same four places → update the count.
- **could** docs/dev-tools.md:9 The tools table has a row for `tools/mine.sh` and none for `tools/board-gate.sh` → add a row (outside g3n's allow; owner decision whether to do it now).

## Decisions to confirm

- `forPlayers` now ignores the receiver's `tileCost` (rules.dart:117): intended per the brief, but no production code calls `forPlayers` or reads `tileCost` (only rules.dart and tests/sim do), so no played night changes yet, and the review-rules A3 party-night pairs are not reached by this change.
- g3h ran `tools/mine.sh` although its brief says "never tools/mine.sh" (g3h.md:2) and its check line says `format analyze host`; the report flags it (g3h-report.md:51). g3n did the opposite and did not run it (g3n-report.md:48). The conflict between the brief and the worker rules needs one answer from the owner.
- `board-gate.sh` takes the changed paths from the commit (line 20) but reads size (line 51) and layers (lines 59-64) from the working tree. A clean commit with an uncommitted edit can pass or fail on different content. g3n-report.md:32 lists this decision.
- `cityRulesWith(tileCost:)` leaving `tileCostSmallNight` at the base value (sim_rules.dart:114-115) is the question g3h-report.md:53 asks; it matters only once a caller re-prices such a copy.

## Could not check

- The test counts (99 and 81) and the PASS lines of `board-gate-test.sh`: no test run was available to me. `run.log` has only start, finish and commit lines (lines 49-59), no counts.
- "no analyzer findings" in g3h-report.md:16: not checked; `dart analyze` was not run.
- The old-code results of the new tests (rules_test.dart:61, :65, :69) were derived by reading the old `forPlayers` line in the g3h diff, not by running the old code.
- `docs/briefs/m17/board3m/run-findings.md` does not exist, so there were no runner findings to read.
- Windows CRLF behaviour of the gate: not run.

## Commit message — a draft

review: board3m wave 2 (g3h, g3n) against brief, rules and guidelines

Read-only review of the g3h rules change and the g3n merge gate script.
Adds the report only. Findings: two new re-pricing tests pass on the old
code (rules_test.dart:65, :69); the g3h report's test counts contradict
each other; board-gate.sh has bare size limits; plus smaller items in the
report.

## Status row

board3m wave 2 review (g3h, g3n): done, verdict small fixes (1 must, 3 should, 5 could); open: the two re-pricing tests that pass on the old code, the 99-vs-81 test count in g3h-report, bare limits in board-gate.sh, and the owner's call on the mine.sh conflict.

## Delete

- none
