# board3m g3h report: wave-1 review findings 1-3

## Summary

Done. Findings 1, 2 and 3 of `wave1-review-report.md` are fixed; finding 6 (the two `roadworksPrice` tests) is not in this job.

Changes:
- **Finding 1 (must): `gateTileIndex` deleted everywhere.** Removed from `CityRules` (doc, field, constructor parameter, `standard` value, `forPlayers` copy), from the `rules_test.dart` copy helper and its "keeps every other field" expect, from the `roadworks_offer_test.dart` copy helper, and from `cityRulesWith` in `tools/sim/sim_rules.dart`. Removed the test "the gate tile is on the road, before the Plaza" (it asserted only on constants).
- **Finding 2 (should): chained re-pricing fixed.** New required field `tileCostSmallNight` (value 3, doc "tile price with 2-4 players"). `forPlayers` now sets `tileCost` from `tileCostLargeNight` (from `largeNightFrom` players) or `tileCostSmallNight` (otherwise), whatever the receiver's own `tileCost` is. `tileCost`'s doc says it is the price of the copy in hand. `tileCostSmallNight` is copied in `forPlayers`, the three full copies (`rules_test.dart`, `roadworks_offer_test.dart`, `cityRulesWith`) and the `standard` constant.
- **Finding 3 (could, fixed because it sits with finding 2): the "keeps every other field" test** now also expects `tileCostLargeNight`, `largeNightFrom` and `tileCostSmallNight`.

Tests seen:
- Red first (before the lib change): `flutter test packages/party_host/test/city/rules_test.dart` gave `Expected: <3> Actual: <2>` for "a 2-player night re-prices a copy that was priced for 6 players back to 3 Bolts a tile". This is the only failure in that run; the other two new tests passed on the old code as well (old code gives 2 for `forPlayers(2).forPlayers(6)` and 2 for the three-step chain, which is the expected value for those).
- Green after the change: `flutter test packages/party_host/test/city` → `All tests passed!` (whole city folder).
- `bash tools/tests/sim-test.sh` → 0 lines starting with FAIL; the last lines are PASS (for example `PASS tools/sim/sim_report_test.dart`).
- `tools/mine.sh` → the mine.sh package-wide result (not comparable with the city folder count), `RESULT: ok: 4 file(s) formatted, 2 package(s) analyzed, 1 package(s) tested`. No analyzer findings were printed.

Computed expectations (values from the code, not guessed):
- `CityRules.standard.forPlayers(6).forPlayers(2).tileCost` = 3 (`tileCostSmallNight`).
- `CityRules.standard.forPlayers(6).tileCost` = 2 (`tileCostLargeNight`, 6 ≥ `largeNightFrom` 5).
- `CityRules.standard.forPlayers(2).forPlayers(6).tileCost` = 2.
- `CityRules.standard.forPlayers(6).forPlayers(2).forPlayers(6).tileCost` = 2.
- Existing forPlayers expects unchanged: 2 → 3, 4 → 3, 5 → 2, 8 → 2.

Grep result: `grep gateTileIndex` over `packages` and `tools` → no matches (Grep tool, both trees).

Self-check (docs/review-rules.md part A):
1. Host setups: the change is pure data and a pure function; it does not touch a host screen. Covered by the city tests and the sim run (sim-test), not by a device run.
2. Kept state: none added. `tileCostSmallNight` is a constant of the rules.
3. Combinations with pause, host away, Get ready, dropped link, results, leaving: not applicable; no state flow changed.
4. Stayed in `allow:` (the four lib/test/sim files named in the brief, plus this report). No other file was edited.
5. Nothing stopped.
6. Looks: no UI change.

## Hand-over

- Files changed:
  - `packages/party_host/lib/src/city/rules.dart`: `gateTileIndex` removed; `tileCostSmallNight` field, constructor parameter and `standard` value added; `forPlayers` re-prices from the night prices; docs updated (257 lines).
  - `packages/party_host/test/city/rules_test.dart`: copy helper updated; gate-tile test deleted; "keeps every other field" expects extended; three re-pricing tests added in the `forPlayers` group (385 lines, under the 500 test limit).
  - `packages/party_host/test/city/roadworks_offer_test.dart`: copy helper updated (54 lines).
  - `tools/sim/sim_rules.dart`: `cityRulesWith` updated for the new field; `gateTileIndex` line removed (133 lines).
  - `docs/briefs/m17/board3m/g3h-report.md`: this report (new).
- Decisions:
  - Named the new field `tileCostSmallNight` (the brief's name) and placed it after `tileCost` in the constructor.
  - Kept `tileCost` as a field (not a getter), because callers read it as a value and `cityRulesWith` can still override it.
  - Left `cityRulesWith`'s `tileCost` override as it was: it replaces the copy's price in hand and keeps the base's night prices.
- Not done (outside this job's scope): finding 6 (`roadworksPrice` tests), finding 4 (config pins), finding 5 (the 15-field copy written three times; the helper now carries 16 fields and still exists in three places).

## Questions

1. The brief's stop line says "never tools/mine.sh", but the job's check line and the task say to check with `tools/mine.sh`. I ran `tools/mine.sh` (it passed) and did not run `tools/check.sh`. Which one governs for the next jobs? (Same conflict as in the wave-1 review.)
2. `forPlayers` now ignores the receiver's `tileCost`. Any caller that builds a copy with a custom `tileCost` and then calls `forPlayers` will lose that custom price. No such caller exists in the repo (grep of `forPlayers(` shows only the tests); confirm this is the intended rule.
3. `tools/sim/sim_rules.dart` `cityRulesWith` still lets `tileCost:` override the price while `tileCostSmallNight` stays at the base value. Should a `tileCost` override also set `tileCostSmallNight`? Left as is, since the brief named only the field addition.

## Suggestions

- Finding 5 (the 15-field copy written three times) is now a 16-field copy. A shared test helper or `copyWith` would cut the next such change to one place; this needs the owner's agreement (as the review says).
- The new re-pricing tests are in the `forPlayers` group, not in a new file. The brief allowed this (the job edits `rules_test.dart`); a new file was not required.

## Commit message — a draft

rules: drop gateTileIndex, re-price forPlayers from the night prices

Removes gateTileIndex (no lib code read it; its test asserted constants only).
Adds tileCostSmallNight so forPlayers prices any copy from the two night
prices, not from its own tileCost, so forPlayers(6).forPlayers(2) costs 3.
Extends the "keeps every other field" test to the three night-price fields.

## Status row

board3m g3h: wave-1 review findings 1-3 fixed (gateTileIndex removed; forPlayers re-prices any copy via tileCostSmallNight; field test extended), city tests and sim-test pass. Open: owner decision on the tools/mine.sh vs "never mine" stop line; finding 5 (copy helper written three times) and finding 6 (roadworks price tests) not in this job.

## Delete

- none
