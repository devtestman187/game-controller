# map2a f3 report: scene boolean names and the late-joiner test

## Summary

- Renamed the four booleans the brief names, in the scene and every reader:
  - `CityRoadScene.complete` → `isComplete`
  - `CityGateScene.open` → `isOpen`
  - `CityScene.roadworksCone` → `hasRoadworksCone`
  - `roadworks` → `hasRoadworks`. This field sits on `CitySnapshot` (the input), not `CityScene`; the brief's "CityScene booleans" list covers it, so I renamed it too. It is the only one of the four not on the output class.
- The late-joiner scene test now takes its tile from `lateJoinTilePosition([3, 1, 4])` instead of a typed `1`. The rule returns the smallest position, 1, so the expected tile is still 1 and the test asserts the same centre. No rule change; `rules.dart` untouched.
- `_sceneOf`'s helper parameter `roadworks` is now `hasRoadworks` to match the field.
- Left alone: the painter test helpers `_road(..., complete:)` and `_scene(..., cone:)`. Those are helper parameter names, not the renamed fields.

Test counts:
- Before edits: `flutter test` on `city_scene_test.dart` and `city_overlay_painter_test.dart` gave 61 passing tests.
- After edits: the same two files gave 61 passing tests.
- `tools/mine.sh` (run from the repo root): `OK 61 tests packages/party_host`, and `RESULT: ok: 4 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.

Decisions:
- Tests-first is exempt: this is a rename plus a test change whose behaviour already held (the rule gives 1 for `[3, 1, 4]`, the same as the typed value). The before/after runs above are the check.
- Renamed `CitySnapshot.roadworks` to `hasRoadworks` (see summary); the brief's wording did not name the class, so this is a judgement call.

Self-check (review-rules part A):
1. Host setups: no behaviour change; the rename does not touch any host path. Covered by the existing scene and overlay tests (61 pass).
2. Kept state: no state added or removed.
3. Combinations with the pause menu, host away, player away, "Get ready", dropped link, results, leaving: not affected; pure data-class rename.
4. Stayed inside the allow list: the four listed files plus this report.
5. No stop needed.
6. Looks: no look or layout change; the painter still paints the same cone, road and gate, only the field names differ.

## Hand-over

- Files changed:
  - `packages/party_host/lib/src/city/art/city_scene.dart`: four booleans renamed, plus `CitySnapshot.roadworks` → `hasRoadworks`; constructor, field and reader updated.
  - `packages/party_host/lib/src/city/art/city_overlay_painter.dart`: readers of `isComplete`, `isOpen`, `hasRoadworksCone` (three lines).
  - `packages/party_host/test/city/art/city_scene_test.dart`: `_sceneOf` parameter and all field references renamed; late-joiner test uses `lateJoinTilePosition([3, 1, 4])`.
  - `packages/party_host/test/city/art/city_overlay_painter_test.dart`: constructor arguments for `CityRoadScene`, `CityScene` and `CityGateScene` renamed.
  - `docs/briefs/m17/map2a/f3-report.md`: this report (new).
- Checks run: `flutter test` on the two files, before and after (61 pass each); `tools/mine.sh`, OK, 61 tests, analyze clean on party_host.
- Not run: `tools/check.sh` (per the brief, the script runs it after I finish).

## Commit message — a draft

map2a: boolean names in the city scene, late-joiner test uses the rule

Renames the scene booleans to isComplete, isOpen, hasRoadworks and
hasRoadworksCone (review finding: names). The late-joiner scene test now
takes its tile from lateJoinTilePosition([3, 1, 4]) instead of a typed 1,
so the rule is what is tested. No rule change; the expected tile is still 1.

## Status row

map2a f3: scene boolean names fixed (isComplete, isOpen, hasRoadworks, hasRoadworksCone); late-joiner test uses lateJoinTilePosition. Open: nothing in f3's scope.

## Delete

- none
