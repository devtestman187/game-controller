# board3a g3b4 — report

## Summary

Finished the g3b3 items the wave-4 review found open. All in `packages/party_host/lib/src/city/rules.dart`, with tests.

- `CityRules` gains `corners` (the four corner roads, fixed order), `laneSuffix` (`-lane`) and `kidsPreset` (default `false`). `standard` sets `corners` and `laneSuffix`.
- `driveCost()` takes no parameters and returns 0. Its two test calls are updated.
- New `roadworksOffered({required bool kidsPreset})` returns `!kidsPreset`.
- New `roadworksPrice({required CityRules rules})` returns `rules.roadworksCost`.
- Top-level `startCorners` is removed. `assignStarts` reads `CityRules.standard.corners` and `laneSuffix`. Its signature is unchanged.
- `board_test.dart` reads the corner list and lane suffix from `CityRules.standard` instead of its own literals.

Tests-first: `tools/mine.sh` failed on the new tests before the lib change (compile errors: missing `corners`, `laneSuffix`, `roadworksOffered`, `roadworksPrice`; `driveCost()` missing arguments). After the change it passed.

Decisions:
- Used the parameter name `kidsPreset` (step 2 of the brief). Step 1 wrote `kids:`; I took step 2 as the design.
- Added the new test group and corner-config tests to the existing `rules_test.dart`, as the brief's allow list names it.
- `roadworksPrice` test builds a `CityRules` with `roadworksCost + 1` via a local helper, so it proves the field is read and not a constant.

## Self-check (review-rules part A)

1. Host setups: not applicable. Pure rules only; no host wiring (brief stop rule).
2. Kept state: none added.
3. Combination with pause, host away, player away, Get ready, dropped link, results, leaving: not applicable; these are pure functions with no state.
4. Files: only the four allowed paths were changed. `git status` also shows pre-existing changes in `docs/briefs/m17/board3a/` (STOP.md, run.log, .since), which I did not touch.
5. Stop rather than overstep: see Questions 1 and 3.
6. Look: not applicable; no UI.

## Checks

- `tools/mine.sh` before lib change: FAILED (compile errors in `board_test.dart` and `rules_test.dart`, as expected for tests-first).
- `tools/mine.sh` after lib change: `OK 55 tests packages/party_host`, `RESULT: ok: 3 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
- Analyzer: no findings reported on `party_host` by `mine.sh`.

Test names added or changed in `rules_test.dart`:
- `driving`: "driveCost takes no arguments and returns nothing for a move onto a built tile"; "driveCost returns nothing for a tile that is not built, so roadworks never charge a token".
- `roadworks`: "roadworks are offered on an ordinary night"; "roadworks are not offered on a kids night"; "roadworks price is read from the configured roadworksCost, not a constant"; "the standard roadworks price is the standard roadworksCost".
- `corner config`: "the corner roads are read from CityRules in the fixed order" (expects `['cog-hill', 'candy-harbour', 'pepper-park', 'lantern-ridge']`); "the lane beside each corner is named by the configured laneSuffix" (expects `'-lane'`).
- `assignStarts`: "more players than there are starts is rejected" now counts `CityRules.standard.corners.length * 2 + 1` (= 9 players, which is over the 8 starts).

## Questions

1. Brief step 1(a) says `roadworksOffered` is false "for last place on a kids night", but step 2 gives it only `kidsPreset`. I did not add a place parameter. The test covers `kidsPreset` only. Is "last place" meant to change the rule?
2. Brief step 6 says "never tools/mine.sh" and to run raw `dart format`, `dart analyze` and `flutter test`. The job prompt says to check with `tools/mine.sh` only. I followed the job prompt. Please confirm which one applies.
3. The worker rules say new tests go in a new file. The brief's allow list names the existing `rules_test.dart`, so I added there. Confirm if a new file is wanted.
4. `kidsPreset` is only read by `roadworksOffered`. Nothing sets it on a real night yet, since host wiring is out of scope.
5. Suggestion: `assignStarts` reads `CityRules.standard` directly. Passing `rules` in would let a test use a different corner list. That changes the signature, so I left it alone.
6. `tools/mine.sh` reported "3 file(s) formatted". I did not check which files it reformatted beyond the three I edited.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

city: move corners and lane suffix into CityRules; add kids flag

CityRules now holds the corner roads, the lane suffix and a kidsPreset
flag (default off). startCorners is removed and assignStarts reads the
corners from CityRules.standard, so the names live in one place.

driveCost() takes no parameters and returns 0. roadworksOffered and
roadworksPrice are added: roadworks are not offered on a kids night, and
their price comes from roadworksCost. Tests cover each rule first.

## Status row

g3b4 done: kids flag, roadworksOffered/roadworksPrice, driveCost() with no arguments, corners and lane suffix read from CityRules; mine.sh OK (55 tests). Open: "last place" rule for roadworks (Q1), kidsPreset wiring on the host (Q4), assignStarts taking rules (Q5).

## Delete

- none
