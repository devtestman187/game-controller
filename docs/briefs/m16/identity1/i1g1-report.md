# i1g1 report: ViewContext.characters and the Arena phone path

## Summary

Changed (all inside the brief's `allow:`):
- `packages/game_kit/lib/src/game_module.dart`: `ViewContext` gains `Map<String, PlayerCharacter> characters` (player ID to character, empty when the host sent none, a missing player wears the number's default). Imports `PlayerCharacter` from protocol.
- `packages/game_kit/lib/src/frame_view.dart`: fills `characters: a.frame.characters` where the ViewContext is built (the only place).
- `packages/puzzle_game/test/puzzle_module_test.dart`: the one other record literal gets `characters: const {}`.
- `packages/test_game/lib/src/arena_module.dart`: passes `view.characters` to `ArenaBoard`, so the phone path stops using number defaults; the "does not carry yet" comment is replaced.
- New `packages/game_kit/test/view_characters_test.dart` (2 tests).
- New `packages/test_game/test/arena_phone_identity_test.dart` (4 tests).

Tests:
- Tests first: before the implementation both new files failed to compile (`characters` is not a field of `ViewContext`), so the failure seen was the missing field, not a runtime assertion. I did not run the old arena_module against the new phone test separately.
- After the change: `tools/mine.sh` result `ok: 6 file(s) formatted, 3 package(s) analyzed, 3 package(s) tested`. game_kit 3 tests OK, puzzle_game 4 OK, test_game 5 OK. Analyzer clean after removing redundant arguments.
- `tools/review.sh`: 0 fail, 1 note.
- Full suite not run (brief says the runner does it at the end).

Line counts: game_module.dart 79, frame_view.dart 318, arena_module.dart 58 (all under 380).

## Self-check (review-rules part A)

I did not open docs/review-rules.md in this job, so these are not checked against its text. Observed only:
- Item 6 (every look): the phone test draws the menu look (`sunny`) and the TV look (`ToyLook.build(tv: true)`). The test asserts colour, HUD dot and accessory in both.
- No fixed pixel height added; no UI painter changed.

## Decisions

- TV look: the brief names `toyTvProvider.overrideWithValue(true)`, but that symbol does not exist in this repo. I used `ToyLook.build(palette: ToyPalette.sunny, tv: true)` as `arena_identity_test.dart` does.
- The pixel helpers (`capture`, `countOf`) are local to the new test file: the support files are outside `allow:`, so I did not share them.
- The accessory check compares the chosen crown render with a render using another accessory, not the exact crown geometry (the HUD shifts the marble, so fixed offsets are fragile).
- The server already filters `chars` by the viewer (`connection/lib/src/server_game_frames.dart`), so no host change was needed.

## Blocked

Nothing blocked. Nothing outside `allow:` was edited.

## Hand-over

Ready for review. No commits, no pushes, nothing staged.
