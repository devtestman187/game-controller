# board3m run review (read-only)

## Summary

Verdict: **one fix batch** (no `needs Claude's design` finding; one design question sits in the matrix pricing finding).
Counts: must 3 · should 11 · could 10.
Fixed since the wave reviews, checked in the final code: gateTileIndex gone everywhere (grep), forPlayers re-prices from the night prices (rules.dart:111-118), the gate-tile test removed, the forPlayers copy test extended.
Five that matter most:
1. The two re-pricing tests still pass on the old code (rules_test.dart:65, :69).
2. The v2 matrix never calls `forPlayers`/`forNight`: `run_sim` → `cityRulesForRoad` sets the road's own price at every player count (sim_report.dart:195, sim_rules.dart:146-147). So a 5-8 player v1 cell prices a tile at 3 Bolts, not the owner's 2, and a 2-4 player v2 cell at 2, not 3. REPORT-v2 numbers are on this pricing. Claude: confirm the matrix should follow the owner rule.
3. The gate-game check (night_sim_test.dart:275-300) passes with the old `(games + 1) ~/ 2` formula, so a revert is not caught.
4. The gate-blocks-Roadworks path (night_sim.dart:270) has no test.
5. night_adapter.dart holds two public types (:17, :52) and its decider drops points (:65), so a points chain shares every win.

Questions only the owner can answer: the matrix price (finding 2), and open questions 2-5 below.
Dropped from carry-over: wave2 "code-health 16-field" (it is 15 fields now; docs/code-health.md:393 is right).

## Findings

- **must** packages/party_host/test/city/rules_test.dart:65 and :69 The chains `forPlayers(2).forPlayers(6)` (2) and `forPlayers(6).forPlayers(2).forPlayers(6)` (2) give 2 on the old code too, so they do not guard the fix → replace :65 with `rules.forPlayers(6).forPlayers(4).tileCost` expecting 3 (old code gives 2, new gives 3) and add `rules.forPlayers(6).tileCost` expecting 2 (from: wave2)
- **must** tools/sim/sim_report.dart:195 (with tools/sim/sim_rules.dart:146-147) The v2 matrix prices each cell with `cityRulesForRoad`, which sets `tileCost` to the road's fixed price (v1 3, v2 2) at every player count; `forPlayers`/`forNight` are never called on the matrix path (run_sim.dart:40 passes `CityRules.standard`), so a 5-8 player v1 cell pays 3 where the owner rule gives 2 → build the matrix copy with `base.forPlayers(cell.players)` before the road price, or record that road prices override the night price (from: across jobs)
- **must** tools/sim/night_sim_test.dart:275-300 The gate-game check uses `CityRules.standard` with 5 games, where `gateGame` (3) equals `(5 + 1) ~/ 2` (3), so reverting night_sim.dart:112-115 keeps it green → test a city whose `gateGame` is not 3 (build the `CityRules` in the test, or add a `gateGame` parameter to `cityRulesWith`) and assert the gate lands in that game (from: wave3)
- **should** tools/sim/sim_rules.dart:128-129 `cityRulesWith(tileCost:)` leaves `tileCostSmallNight` at the base value, so `forPlayers(2)` of such a copy returns 3, not the override, and the `tileCost` doc at rules.dart:56-57 is false for it → `tileCostSmallNight: tileCost ?? base.tileCostSmallNight`, or write the limit into the doc (from: wave2)
- **should** tools/sim/night_sim.dart:270 The gate-blocks-Roadworks path (`nextTileGated: gated[last] && rules.gateBlocksRoadworks`) has no test; no check in night_sim_test.dart sets `gateBlocksRoadworks` or asserts a gated last-place player gets no crew → add a night_sim check (gated last place: no crew; flag off: crew), in night_sim_test.dart (from: wave3)
- **should** tools/sim/night_sim.dart:5-6 The header still says the gate and Roadworks rules are "assumptions", but sim_rules.dart:77-80 now calls them owner rules (Nov 27) → reword the two lines (from: wave3)
- **should** tools/sim/sim_rules.dart:84 The new doc line is 121+ columns, over the 120 limit → rewrap it (from: wave3)
- **should** packages/party_host/test/city/night_adapter_test.dart:23-28 No test covers a gap in recorded places (Decision 1); a count-based numbering passes the whole file → add a test with `{ann: 3, ben: 1}` and `cy` unplaced: `placeRound(['cy', 'ann', 'ben'])` must give cy 4 (count-based gives 3) (from: wave1-g3m)
- **should** packages/party_host/lib/src/city/night_adapter.dart:65 `NightChampionDecider` passes `points: 0` for every entry, so with `ChampionChain.quickNight` every entry ties and all share the win → accept only the City Rush chain, or carry points through `CityChampionEntry`, and add a points-chain test (from: wave1-g3m)
- **should** packages/party_host/lib/src/city/night_adapter.dart:17 and :52 Two public types (`RoundResultPlacing`, `NightChampionDecider`) in one file; the guidelines allow one → split the decider into its own file, or record the exception in the brief (from: wave1-g3m)
- **should** docs/briefs/m17/board3m/g3m-report.md:20 and :62 The report says the test file has 18 tests; `night_adapter_test.dart` runs 13 (5 placing, 4 decider, 2 × 2 shared), 18 is with stubs_test.dart's 5 → state 13 for this file and 18 in total (from: wave1-g3m)
- **should** docs/briefs/m17/board3m/g3m-report.md:62 "dart format on both files (formatted, 1 changed)" conflicts with run.log:28, which says the check failed on format and the hand-fix ran dart format → correct the line to the runner's account (the files are formatted now) (from: wave1-g3m)
- **should** docs/briefs/m17/board3m/g3h-report.md:14 and :16 The report gives `flutter test packages/party_host/test/city` as 99 tests and `tools/mine.sh` as "OK 81 tests packages/party_host"; the city tests are part of the package, so both cannot be right → rerun both and correct the report (from: wave2)
- **should** tools/board-gate.sh:38-39 The limits 500 and 380 are bare literals in `echo`, against guidelines §2 → name them with their unit and reason (e.g. `testLimitLines`, `libLimitLines`) and use them in `limit_of` (from: wave2)
- **could** tools/board-gate.sh:51 `wc -l` counts newlines, so a 381-line .dart file with no final newline counts 380 and passes → count with `awk 'END { print NR }'` (from: wave2)
- **could** tools/board-gate.sh:10 `base=m17` is a hard-coded branch name as the default → make `--base` required, or name the default in one constant with its reason (from: across jobs)
- **could** tools/tests/board-gate-test.sh:76 The cases pass a 380-line lib file but have no pass at the test limit (500 lines) and no `--base` with an unknown ref (board-gate.sh:19-20 exits 2, untested) → add one case each (from: wave2)
- **could** docs/briefs/m17/board3m/g3n-report.md:6 says the script is "about 65 lines"; `tools/board-gate.sh` is 77 lines → correct the figure (from: wave2)
- **could** docs/dev-tools.md (tools table) There is a row for `tools/mine.sh` and none for `tools/board-gate.sh` → add the row (outside g3n's allow; owner call) (from: wave2)
- **could** tools/sim/sim_rules_test.dart:1 The header comment is 121 columns, over the limit → shorten it (from: wave3)
- **could** tools/sim/night_sim_test.dart:295 `List.generate(seedCount, (seed) => seed).any(` is hard to read for a loop over seeds → `Iterable<int>.generate(seedCount).any(` (from: wave3)
- **could** tools/sim/night_sim.dart:112-115 Two gate-game rules: the shipping `gateGame` on a 5-game night, and `(games + 1) ~/ 2` on any other length; only the shipping length is tested → say in the doc which lengths are supported, or drop the fallback (from: across jobs)
- **could** packages/party_host/lib/src/city/night_adapter.dart:33 The stat key `'place'` is a bare string; the stat-name doc at packages/game_kit/lib/src/round_result.dart:108-109 does not list it → one named constant, or add it to that doc (from: wave1-g3m)
- **could** tools/sim/sim_report.dart (whole file; not changed in this run) is 423 lines, over the 380 limit board-gate.sh applies to tools/sim files; any job that touches it fails the gate → split before the next change to it (from: across jobs)

## Open questions

1. Matrix price (must, finding 2): should the v2 matrix follow the owner's per-player tile price on every cell, or do road variants override it? Suggested: follow the owner rule (`base.forPlayers(players)`), and rerun the matrix.
2. board-gate.sh reads changed paths from the commit but sizes and layers from the working tree (board-gate.sh:20 vs :51, :59-64). Suggested: read content with `git show` at HEAD, so the gate checks what is committed.
3. night_adapter: gap numbering (highest recorded place + 1) versus count-based. Suggested: keep highest + 1 (it matches "placed after the placed ones") and add the test in the finding.
4. Equal recorded places are kept, not re-ranked (g3m Decision 2), with no test. Suggested: keep, and add one test.
5. Points in the night decider: accept only the City Rush chain, or pass points? Suggested: accept only City Rush now and say so in the type, since no caller passes another chain.
6. g3t's gate tests use an API the old code lacks, so no fail-first proof was shown (g3t-report.md:51-52). Suggested: accept the exemption, since the API did not exist.

## Hand-fixes (run.log)

- g3m: `HAND-FIX` at run.log:28 (parked patch applied with `git apply`, `dart format` on night_adapter_test.dart; check failed on format only). Tests-first proof: run.log:44 "tests-first ok: night_adapter_test.dart fails on the old code". Review: wave1-g3m-review-report.md exists. Done.
- run.log:43: g3m was committed by hand (dce1205f), so the runner re-ran its tests-first and review; both are recorded.
- No other `HAND-FIX` lines. g3r1, g3t and g3h have no tests-first line in run.log; g3r2 has one (run.log:67), g3n is exempt (new files). g3h's red-first claim is in its report (g3h-report.md:13). g3r1 has no red-first evidence in its report.

## Fixes not measured (fixed, unverified)

- None needs a device check. The forPlayers fix was measured red-first (g3h-report.md:13). The g3m format hand-fix is a format check only.

## Numbers against targets

- Line limits: all changed lib files under 380 (rules.dart 257, board.dart 178, night_adapter.dart 68). sim/night_sim.dart 328: over the ~300 aim, under the 380 gate limit. rules_test.dart 385: under the 500 test limit.
- Columns: 2 lines over 120 in the run: sim_rules.dart:84 and sim_rules_test.dart:1.
- Test counts (not verified, reports only): g3r1 "OK 75" and g3t "OK 79" (package); g3h "99" (city) vs "OK 81" (package) — contradictory; g3m "18" for one file vs 13 counted.
- g3n gate script: 77 lines (report says ~65).

## Could not check

- No tests, analyzer or format run (read-only job). All test counts above are as reported.
- Fail-on-old-code claims (g3h, g3r2) were not re-run; the old-code values in findings 1 and 3 were derived by reading.
- run-findings.md and STATUS.md do not exist; DRIVER-NOTES.md and REPORT-v2.md:39 figures (+0.36 to +0.97) were not checked against the CSV.
- g3m-report.md:44 says empty input is tested for the placing; night_adapter_test.dart has an empty-input test only for the decider (line 85). Not fixed in code: a claim to correct.
- The gate's CRLF behaviour on Windows was not run.

## Commit message — a draft

review: board3m run review (findings for one fix batch)

Read-only review of the whole board3m run (g3r1, g3t, g3m, g3h, g3n, g3r2) against the coding guidelines and review rules. Adds this report only. Findings: the two re-pricing tests still pass on the old code; the v2 matrix bypasses the owner's per-player tile price; the gate-game check and the gate-blocks path are untested; night_adapter has no gap test, drops points and holds two public types; board-gate.sh has bare limits.
## Status row

board3m run review: done, verdict one fix batch (3 must, 11 should, 10 could); open: the 3 must (re-pricing tests, matrix price, gate-game test), the gate-blocks test, night_adapter fixes, board-gate limits, report counts; owner: the matrix price.

## Delete

- none

## Status after board3f (driver, Nov 27)
Open: must 0 (2 fixed in wave 4; must 2 valid, fixed by board3f's final rules row) · should 2 (two public types in night_adapter.dart; points chain doc-only guard; both deferred to code-health) · could 2 (dev-tools.md row for board-gate.sh; 'place' stat key constant; deferred). The sim_report.dart size could is fixed (split).
