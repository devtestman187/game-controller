# Review of b012b-1-rules (4899764)

## Summary

Verdict: **small fixes**. must 2, should 1, could 1.
The rule-book part is sound: `puzzle_hard_rules_test.dart` and `library_test.dart`
pass (5 tests, run here), and the new tests do fail on the old code.
1. `docs/levels.md:134` says the 8.5 mm floor refuses an under-floor piece at any
   level, but `_phoneSize` still returns early for Hard, so no Hard puzzle is
   ever measured.
2. `puzzle_rule_levels.dart:182` still returns early for Hard, so Decision 3 and
   the Files-changed line saying the skip is gone are false.
3. The shared `_counts` changed Medium's checker message ("Mark one or two" →
   "Mark 1 or 2"), an unmentioned change to a level the brief keeps as it is.

## Findings

- **must** docs/levels.md:134 — the new Hard paragraph says a picture whose smallest piece is under the 8.5 mm floor "is refused whatever its level", but `puzzle_rule_fit.dart:159` returns before the size rule for Hard, so no Hard puzzle is measured and the report's own Question 2 asks whether that skip should go. → Remove "whatever its level" (or the whole floor sentence) until the skip goes, or take `puzzle_rule_fit.dart` into the job and delete the skip, and list it under the Summary's not-done.
- **must** packages/puzzle_game/lib/src/puzzle_rule_levels.dart:182 — `_turned` still starts `if (puzzle.level == Level.hard) return;`, so Decision 3 ("leaving the skip in would have kept a special case") and the Files-changed line ("no skip for Hard in `_turned`") describe a change the diff does not contain. → Delete line 182 (Hard's own rule already needs 6 turned, so nothing changes but the special case) or correct both report lines.
- **should** packages/puzzle_game/lib/src/puzzle_rule_levels.dart:118 — `_counts` now builds Medium's big-piece message from the numbers, so it reads `Mark 1 or 2 pieces "big".` where it read `Mark one or two pieces "big".`; the brief keeps Medium as it is and the report does not mention the change. → Add the phrase to `_PieceCounts` (or restore the words for Medium) and say the message changed.
- **could** packages/puzzle_game/lib/src/puzzle_rule_levels.dart:25 — Hard's doc comment says "at most two pairs of pieces that share a shape", but `_repeatedShapes` groups on `shape.key`, which is shape and size (`piece_shape.dart:124`), as its own message says. → Write "share a shape and size".

## Decisions to confirm

- The parser, schema and `tools/level.sh` still refuse `"hard"` (`puzzle.dart:96`, `puzzle.schema.json` level enum, `level_new.dart`): removing it fails `puzzle_format_test.dart:39`, `puzzle_schema_test.dart:61` and `puzzle_new_test.dart:86`, none in `allow:` — confirm the allow list of the job that takes those three tests plus `tools/level_new.dart`, because phase 3's Hard puzzles cannot be checked until it lands.
- The per-level start-angle table (Easy 30, Medium 60, Hard 90) is not implemented; the worker measured five red tests, four in files outside `allow:` (camera, mirror_place, tablet_board, tray_packing) — confirm that job takes those four files, or narrow the table.
- Brief item 1's "at least half the turned pieces start 90 degrees or more off" is only implied by Hard's 90° floor; nothing in the rule book measures the spread — confirm the floor alone is what was meant.
- The picker test was withdrawn because `games_screen.dart:112` already hides a level with no puzzles, so it passes on the old code — confirm no test is wanted for it, and that the `autofocus: i == 0` bug at `games_screen.dart:116` stays out of scope.

## Could not check

- Whether Medium at 60° and Hard at 90° really move the four pinned layout numbers the report lists (camera_test 4.6574 → 4.6304, mirror_place_test 92.6 → 92.943, tablet_board_test 9.671142 → 9.699315, tray_packing_test 10.273 → 10.913): it needs edits outside this review's scope, so not run.
- The full `tools/check.sh format analyze puzzle host` (419 puzzle, 429 host) and its 17:00 log: I ran only `flutter test test/puzzle_hard_rules_test.dart test/library_test.dart` (5 tests, pass).
- The two withdrawn test files (`start_angles_test.dart`, `games_screen_levels_test.dart`) are not in the commit or the checkout, so their content and their "passes on the old code" claim could not be re-run.
- The report's git-status claim about the five `docs/design` PNGs: the checkout is now at 6f623e0 with `packages/metrics/lib/metrics.dart` modified by something else, so it cannot be confirmed.

## Commit message

Review b012b-1-rules: two musts, one should (B-012b phase 1)

The Hard rules are sound and tested, but docs/levels.md claims the 8.5 mm floor
applies to Hard while _phoneSize still skips it, and puzzle_rule_levels.dart
still returns early from the general turned rule for Hard, which the job's
Decision 3 says it removed. The shared _counts also rewrote Medium's big-piece
message. The report lists what phase 1 could not do inside its allow list: the
parser/schema/level.sh refusal, the per-level start angles and the 8.5 mm skip.

## Status row

B-012b phase 1 reviewed: Hard's rule book and tests pass, but the review found two musts (docs/levels.md's 8.5 mm claim vs the Hard skip in puzzle_rule_fit.dart, and the Hard early return still in `_turned`); open: the parser/schema/level.sh refusal, the per-level start-angle table, the 8.5 mm skip for Hard.

## Delete

- none
