# board3a wave5 review (g3b4) — report

## Summary

Verdict: **small fixes**.
Counts: must 0 · should 3 · could 2.
Top three:
1. `CityRules.kidsPreset` is never read; `roadworksOffered` takes its own flag, so the two can disagree (rules.dart:80, :122).
2. Brief 1(a) "false for last place on a kids night" is neither built nor tested (rules_test.dart:140).
3. Brief 4 allows the corner names once in tests; `assignStarts` expectations repeat them (rules_test.dart:220).

## Findings

- **should** packages/party_host/lib/src/city/rules.dart:80 `kidsPreset` on `CityRules` is set by the constructor but read by nothing; `roadworksOffered` (line 122) takes a separate `kidsPreset` argument, so `CityRules(kidsPreset: true)` still offers roadworks unless the caller repeats the value → Claude decides: make `roadworksOffered` read `rules.kidsPreset`, or drop the field; the brief names both, so this is a brief question.
- **should** packages/party_host/test/city/rules_test.dart:140 Brief 1(a) asks for `roadworksOffered` to be false "for last place on a kids night"; there is no place parameter in `rules.dart:122` and no test for it → add the place rule and its test, or Claude confirms it is out of scope (worker Q1).
- **should** packages/party_host/test/city/rules_test.dart:220 `assignStarts` expectations spell out `'cog-hill'`…`'lantern-ridge'` and `'…-lane'` at lines 220–234; brief 4 allows the names once as the expected config value (rules_test.dart:156) → build these maps from `CityRules.standard.corners` and `laneSuffix`, keeping the one literal at line 156.
- **could** packages/party_host/test/city/rules_test.dart:105 and :109 the two `driveCost` tests have the same body, `expect(driveCost(), 0)`, so the second repeats the first → delete one, or give it a distinct case.
- **could** packages/party_host/lib/src/city/rules.dart:71 the doc says "The first four players" and "players 5-8", but `assignStarts` (line 163) uses `corners.length`; if the list changes the doc goes stale → say "one player per corner, then one per lane".

## Decisions to confirm

- `kidsPreset` as both a `CityRules` field (rules.dart:26, :80) and a `roadworksOffered` argument (:122): two sources for one flag. The brief specified both; the worker followed it. Confirm one source.
- Brief 1(a) last-place rule not built (worker Q1, rules_test.dart:140): confirm it is deferred.
- Worker ran `tools/mine.sh` although brief step 6 says "never tools/mine.sh" (report "Checks"; worker Q2). Confirm which the brief means. The worker's pass covers format, analyze and test.
- New tests were added to the existing `rules_test.dart`. The worker rules say new tests go in a new file; the brief's allow list named that file. Guidelines §11 say a brief/rule conflict is stopped and reported. Confirm.
- `assignStarts` reads `CityRules.standard` directly (rules.dart:163–164), so no test can vary the corner list (worker Q5). The brief kept the signature; confirm it stays this way.

## Could not check

- Worker's run output (`tools/mine.sh` "OK 55 tests", "3 file(s) formatted", the tests-first FAILED run, analyzer clean): no run log exists in `docs/briefs/m17/board3a/`; not re-run (review is read-only).
- `run-findings.md` does not exist, so there are no "passes on the old code" entries to check.
- Report self-check 4 says `run.log` has a pre-existing change in `docs/briefs/m17/board3a/`; not verified (the start-of-session status shows no `run.log`).
- Library export of `roadworksOffered`/`roadworksPrice` (the `party_host` library file) was not read.
- Sizes: `rules.dart` and `board_test.dart` are small; `rules_test.dart` line count was not measured.
- Rules B/C (round lifecycle, host authority, protocol) are not applicable: pure functions, no state, no protocol; no host setups are touched.
