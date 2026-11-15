# M14 bugs6 b012b-3-hard — review

## Summary
Verdict: **small fixes** (1 must, 2 should, 4 could).
- The six new puzzles never enter `puzzleIds`, so the match, tray, phone-layout, split, view and PNG tests still cover only the twelve old ids (the brief's item 2).
- `hard_library_test` repeats what `puzzle_check_test` and `library_test` already check.
- The report's Question 1 and Status row call `docs/levels.md` stale; the job's base commit (28b423c) already fixed that line.

## Findings
- **must** packages/puzzle_game/test/support/match_helpers.dart:12 `puzzleIds` still lists only the twelve Easy and Medium ids (its doc comment "six Easy, then six Medium" is now false), so the six Hard puzzles run in none of the eleven sites that use it (match_test, tray_packing_test, tray_pile_test, phone_tray_reach_test, split_layout_test, slot_contrast_test, view_test, puzzles_png_test), against the brief's "any test that lists puzzle ids" → add the six ids at the end, add a Hard bag list to `puzzle_pick_test.dart:44`, and give `split_layout_test.dart:236`'s `overlaps` map their measured values.
- **should** packages/puzzle_game/test/hard_library_test.dart:13 its three rule tests repeat what `puzzle_check_test.dart:11` already runs on every file (`checkLibrary` → `checkPuzzle`), and its count and id order repeat `library_test.dart:24-33` → delete the file, or keep one count-and-order test and drop the rule copies.
- **should** docs/briefs/m14/bugs6/b012b-3-hard-report.md:88 Question 1 (and self-check 5 at line 56, and the Status row) say `docs/levels.md` still has the "no Hard puzzle" line, but 28b423c changed it to "The library has six Hard puzzles" (`docs/levels.md:98`) before this job → drop the question and the Status row's levels.md item.
- **could** packages/puzzle_game/test/puzzles_png_test.dart:43 the design contact sheet it writes (`docs/design/m13-puzzles.png`, line 100) is a fixed 3×4 grid of `puzzleIds`, so the repo's design overview still shows 12 of 18 puzzles → extend the grid to the Hard six in the same change as the `puzzleIds` fix.
- **could** packages/party_host/test/games_screen_levels_test.dart:31 `expect(hard.label, isNotEmpty)` passes for any non-empty label, so the Hard card's text is not checked → assert the label the picker's text gives, or drop the line.
- **could** packages/party_host/test/controller_menus_test.dart:143 the bare `24` is a magic press count (22 buttons today), against guidelines §2 → name it with its reason, or count the pressable buttons from the tree.
- **could** docs/briefs/m14/bugs6/b012b-3-hard/tractor-solved.png (image) the finished tractor reads as a stack of coloured rectangles with two wheels and a sun, and dragon-solved.png reads little better, so "child-recognisable" is not obvious by eye → put both to the owner with the other four before the next build.

## Decisions to confirm
- Pink `#E91E63` and teal `#00897B` are hex literals in four of the six files (windmill, lighthouse, tractor, tower) where the palette tokens are close; the look milestone's C-row wants colours as tokens, so decide whether they become `piece_colors.dart` entries.
- The decision not to extend `puzzleIds` (and the `overlaps` map) is made but not listed under Decisions, while self-check 4 says no other file was touched.
- The tractor's bumper and the tower's bush were dropped to clear the tray; both puzzles stay at 11 pieces.
- The six puzzles and their pictures were made by hand, and `tools/level.sh check/render` never ran on them; the rule-book tests stand in.

## Could not check
- The mm, span and split-scale numbers in the report's Computed test values: they need the deleted measurement test. The rule book does cover them (8.5 mm floor at 21 seeds on both sides, tray fit at 200 seeds, span share, split scale) and is green for all six.
- Whether `tools/level.sh` really cannot run in this sandbox.
- The controller_app phone suite: I ran only the changed tests (puzzle_game: `hard_library`, `library`, `puzzle_new`, `puzzle_check`; party_host: `games_screen_levels`, `puzzle_continue`, `best_times_screen`, `controller_menus` — all green, `dart format` clean on the nine changed Dart files, `flutter analyze` clean on puzzle_game); the report claims all host and phone tests pass.
- The six `docs/design/puzzles/*.png` sheets' content (I opened the brief's dragon, dinosaur and tractor pictures only).

## Commit message
Review of b012b-3-hard: one must, two should

The six Hard puzzle files, pictures and picker tests are sound and green,
but the shared id list the puzzle tests iterate still holds only the
twelve old ids, so the new puzzles never reach the match, tray or phone
layout tests. The new hard_library_test repeats the rule book and the
library pin, and the report's levels.md question was already answered by
the base commit.

## Status row
Hard puzzles: the six files, pictures and picker tests are in and green; open: the six ids missing from `puzzleIds` (with the split-layout overlap pins and the design contact sheet), and the report's stale `docs/levels.md` question.

## Delete
- none
