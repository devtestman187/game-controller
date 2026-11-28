# map2a wave 4 review: f3 (scene boolean names and the late-joiner test)

Reviewed commit 4dbd33ac against its brief (f3.md), the worker's report (f3-report.md), and the review rules. Read-only: no code or document changed except this report.

## Summary

Verdict: **small fixes**
Counts: must 0 · should 1 · could 2
- **should** the late-joiner test never checks the value the rule gives, so it would still pass if `lateJoinTilePosition` returned another tile (city_scene_test.dart:156).
- **could** two painter-test helpers keep the old boolean names (`complete`, `cone`) that the rename was meant to remove (city_overlay_painter_test.dart:46, :54).
- The four renames are complete: no reader of the old names is left under packages/party_host/lib or test.

## Findings

- **should** packages/party_host/test/city/art/city_scene_test.dart:156 The late-joiner test takes `tilePosition` from `lateJoinTilePosition([3, 1, 4])` and then only checks the centre of that same value, so a rule that returned 2 or 0 would still pass → add `expect(tilePosition, 1);` after line 156, with the reason that 1 is the smallest of [3, 1, 4].
- **could** packages/party_host/test/city/art/city_overlay_painter_test.dart:46 The helper `_road(..., {bool complete = false})` keeps the old name the brief asked to remove → rename the parameter to `isComplete` and its uses in this file (the worker's report says it was left on purpose; the rule "booleans ask a question" covers helper parameters too).
- **could** packages/party_host/test/city/art/city_overlay_painter_test.dart:54 The helper `_scene(..., bool cone = false)` keeps the old name `cone` → rename to `hasRoadworksCone` with its use in the same helper.

## Decisions to confirm

- `CitySnapshot.roadworks` was renamed to `hasRoadworks` (city_scene.dart:37, :56). The brief names "CityScene booleans", and this field is on the input class, not CityScene. The rename is compile-checked by the tests in the same package and is safe, but the brief's wording did not cover it; the worker flagged it as a judgement call. Confirm it is wanted.

## Could not check

- Tests were not re-run. The "61 passing" and `tools/mine.sh` results come from f3-report.md only; run-findings.md has no entry for f3.
- docs/coding-guidelines.md was not opened in full; the guideline checks used the worker extract. Checked: no line over 120 columns in the four changed files (Grep), no TODO, print or debugPrint in them, file lengths 216, 127, 188 and 245 lines.
- docs/briefs/m17/map2a/REVIEW.md (the source of the two findings f3 fixes) was not read.
- Other packages: a grep for the old and new names found no reference outside packages/party_host except in briefs and reports.
- The self-check lines in f3-report.md are true as read (rename-only change, no state, no look change; `lateJoinTilePosition` returns the minimum, 1 for [3, 1, 4], rules.dart:207-212).

## Commit message — a draft

map2a: review of wave 4 (f3) against its brief and the rules

Read-only review of commit 4dbd33ac (boolean renames in the city scene,
late-joiner test uses the rule). Found one should (the late-joiner test
does not pin the rule's value) and two could findings (painter test
helpers keep the old boolean names). No code changed in this commit.

## Status row

map2a wave 4 review (f3): done; 0 must, 1 should, 2 could. Open: pin the late-joiner tile to 1 in city_scene_test.dart; rename the two painter-test helper booleans; Claude to confirm the CitySnapshot.roadworks rename.

## Delete

- none
