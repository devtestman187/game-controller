# B021 fix the solo card test — report

## Summary

Test 1 of `solo_arena_card_test.dart` now proves the saved map is really ignored: after `roundStarted` it reads
`arenaSnapshot(tester).mapId` and expects it not to be `'pinball'` (it is `'playroom'`, the round the card started).
`openNightBumperCard` gained a `String? setMap` parameter, applies it before the roster, and test 1 now opens through
it instead of repeating the helper's setup, so the two night tests share one path to the card.
Test-only change: no `lib/` file touched, no behaviour changed, all 3 tests in the file pass and the host suite
(466 tests) is green.

## Files changed

- `packages/party_host/test/solo_arena_card_test.dart` — helper takes `setMap`; test 1 uses it and asserts the started
  round's map.

## Decisions

- Param named `setMap` and applied right after `pumpHost`, before the roster — the saved map has to exist before
  `neutral`/`openNight` read it, and the name is the brief's own word for the case.
- Kept the comment about design section 7b above the new call, since it still explains why a map is saved at all.
- Snapshot read once into `snapshot` and both expectations use it — one `arenaSnapshot` lookup instead of two.

## Computed values

- Saved map: `'pinball'`. Round after `readyUp` + `roundStarted`: mode `ArenaMode.bumper`, mapId `'playroom'`
  (host log: `Round started: arena, bumper, Playroom`), so `isNot('pinball')` holds for the right reason.
- Card before Start still shows `arenaMap-pinball` (the choice is listed) with no `chosenMap-pinball`.

## Checks

- `dart format` on the file: 0 changed.
- `dart analyze` on the file: no issues.
- `flutter test packages/party_host/test/solo_arena_card_test.dart`: 3 passed.
- `tools/check.sh format analyze host`: PASS format, PASS analyze, PASS host (466 tests).

## Questions

None.

## Suggestions

- `arenaSnapshot(tester).mapId` could also be asserted non-null/non-empty in the harness helper; not done here.

## Commit message

Fix the solo card test's map check and share the card setup

Test 1 of solo_arena_card_test now asserts the started round's mapId,
so a saved 'pinball' map is proven ignored rather than only the card.
openNightBumperCard takes an optional setMap and applies it before the
roster; test 1 uses the helper instead of repeating its setup.
Test-only; no shipped code changed and all host checks pass.

## Status row

`b021-fix-card-test` done: solo card test asserts the round's map and shares the helper; open: nothing.

## Delete

- none
