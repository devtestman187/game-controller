# Wave 1 review (d2a, d2c, k1)

## Summary

Verdict: small fixes.
Counts: must 0 · should 3 · could 4.
1. d2a's refactor has no arena-suite proof: its report says only 1 test ran after the move (docs/briefs/m17/night2a/d2a-report.md:35).
2. d2a's report has no review-rules part A self-check lines at all (docs/briefs/m17/night2a/d2a-report.md:1).
3. d2c's test helpers take an unused `mapId` parameter (packages/party_host/test/night_variant_test.dart:7).

Checked and clean: the arena_map.dart move is a pure dedent (diff matches base bodies), arena_map.dart is 308 lines, puzzle_screen.dart is 380 lines (base 379), party_night.dart 152, variant.dart 68, no line over 120 columns, no TODO/print/BISECT in the changed lib files, every new test name states its rule, and the k1 cap never raises Off or little.

## Findings

- **should** docs/briefs/m17/night2a/d2a-report.md:35 The brief's item 1 says to run the arena suite to prove the move; only `tools/mine.sh` ran (1 test) and the arena suite is left to the post-run check → run `tools/check.sh arena` and record its result in the report.
- **should** docs/briefs/m17/night2a/d2a-report.md:1 The report has no Summary and no review-rules part A self-check lines (host setups, kept state, combinations, files, stops, looks) → add the six self-check lines, each with the test that shows it.
- **should** packages/party_host/test/night_variant_test.dart:7 `_mediumMaps(String mapId)` never uses `mapId` (same at :10 for `_easyMaps`) → make them closures `(_) => Level.medium` and `(_) => Level.easy` at the call sites, or keep one `final Level Function(String) _allMedium = (_) => Level.medium;`.
- **could** packages/party_host/test/night_variant_test.dart:91 "keeps all ten with default settings" asserts only `kept.length` 10, so a wrong variant or order would pass → assert `_ids(kept)` equals the ten launch ids in order.
- **could** packages/test_game/lib/src/arena_map.dart:171 The dartdoc says the night director "uses" the tier, but nothing reads it yet (d2b and B8 come later) → say "which the night director will read"; the same claim is in packages/test_game/maps/map.schema.json:46.
- **could** packages/test_game/maps/map.schema.json:46 The brief asked for a one-sentence description; this one has two sentences ("…uses. Left out until the map is rated.") → merge them into one sentence.
- **could** docs/levels.md:235 The file-format table has no `tier` row, so a map author cannot see the field (this file is outside d2a's allow list) → add a `tier` row after `theme` when the owner allows the doc change.

## Decisions to confirm

- d2a: `tier` is optional and reads as null until rated (arena_map.dart:171, map.schema.json not required). A shipped map without a tier gets no tier at all, so d2b must rate every map or the night has none. Why: the brief chose this on purpose; confirm d2b covers all maps.
- d2a: the parse helpers moved to a new part file as top-level private functions (arena_map_parse.dart). Allowed by the brief; the diff shows bodies unchanged except the dedent.
- k1: `NightSettings.isKids` is equality with `NightSettings.kids` (night_settings.dart:71). A Kids night with any one field edited gets no cap. Why: the owner's rule is "Kids nights", and an edited Kids night is no longer the Kids preset; confirm.
- k1: the cap applies only when the host's Chaos is Party; Little and Off are unchanged, as the brief asked (party_night.dart, settingsForRound).
- d2c: `isKind` is `tier == Level.easy`, a stand-in for the kind variant (variant.dart:65). Why: the brief asked for it; B8 may want another rule.
- d2c: the Shape Race id uses the tier name and the map games use the map id (`mapId ?? tier.name`, variant.dart:62). Why: the brief's ids; confirm.

## Could not check

- The arena suite and the host suite were not run (read-only review). The arena claim rests on the diff only.
- The "fails on the base" claims were not checked: I did not read run.log or probe-d2c.patch, and did not run the tests on base. Not seen: whether k1's widget test fails on base for the stated reason, or only because it does not compile there.
- When `_roundSettings` (puzzle_screen.dart:254, passed as a tear-off at :343) is evaluated: I did not trace how PuzzlePlayView calls `settings`, so whether the cap is read once per round is unverified.
- k1's combinations (pause, host away, Get ready, dropped link, results): not tested, as k1-report.md:26 says; I did not verify the code paths.
- `dart format` and `dart analyze` were not re-run on the changed files (read-only review); the workers' reports say they ran mine.sh.
- docs/coding-guidelines.md and docs/review-rules.md were checked through the worker extract, not read whole.

## Commit message — a draft

m17 night2a: review wave 1 (d2a, d2c, k1)

Reviews the three wave 1 jobs against their briefs, the coding guidelines
and the review rules. Changes no code. Findings: d2a's refactor has no
arena suite run and its report has no self-check; d2c's test helpers have
an unused parameter; three doc or test wording points are noted as could.
Verdict: small fixes. The report is the only file written.

## Status row

Wave 1 review (d2a d2c k1) written: verdict small fixes (0 must, 3 should, 4 could). Open: d2a arena suite not run and no self-check in its report; d2c test helpers with unused parameter; decisions on d2b rating every map and on isKids equality.

## Delete

- none
