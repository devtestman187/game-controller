# race1a f1d: piece rule, at least 2 pieces per player per side

## Files changed

- `packages/puzzle_game/lib/src/puzzle_rule_levels.dart`: added `minPiecesOf(Level)` (the level's min constant: Easy 4, Medium 8, Hard 10) and `maxPerSideFor(Level, int)` (the wanted count, limited to `minPiecesOf ~/ 2` and to at least 1). Both are exported through `puzzle_game.dart` as the rest of `puzzle_rules.dart`. No other behaviour changed; the level checks still use their own constants.
- `packages/puzzle_game/test/per_side_rule_test.dart` (new): 9 tests, one rule each, with expected values below.

## Computed values (test expectations)

Cap = `minPiecesOf(level) ~/ 2`: Easy 4 ÷ 2 = 2, Medium 8 ÷ 2 = 4, Hard 10 ÷ 2 = 5.

| level  | wanted | cap | result |
|--------|--------|-----|--------|
| Easy   | 4      | 2   | 2      |
| Easy   | 2      | 2   | 2      |
| Easy   | 1      | 2   | 1      |
| Medium | 3      | 4   | 3      |
| Medium | 4      | 4   | 4      |
| Hard   | 4      | 5   | 4      |
| Medium | 9      | 4   | 4      |
| Medium | 0      | 4   | 1      |

`minPiecesOf`: Easy 4, Medium 8, Hard 10 (checked against the constants, not literals).

## Checks

- `tools/mine.sh`: OK. Format and analyze clean on the changed package; 10 tests run in `packages/puzzle_game`, all passed (the count is what mine.sh reports; I wrote 9 tests in the new file).
- Tests-first: the brief asked to see the test fail to compile before the code. I wrote the test file first but did not run it against the base, so I did not observe that failure. The brief marks this job tests-first exempt, so this is noted, not a gate miss.

## Questions

1. The brief's doc comment says "Medium and Hard 4", but the formula it gives (`min ~/ 2`) makes Hard's cap 5 (Hard's min is 10). I wrote the doc as the code does: "Easy 2, Medium 4 and Hard 5". If Hard should cap at 4, the cap rule needs a different base for Hard, and the owner plan ("4 a side means Medium/Hard only") should be re-read.
2. `maxPerSideFor` is not used anywhere yet; the seating code that calls it is a later job.

## Suggestions

- If the owner means "4 a side" for both Medium and Hard, a fixed per-level table (`easy: 2, medium: 4, hard: 4`) would be clearer than deriving it from the min piece counts. The test cases above would not change except Hard 4 → 4 (same) and the doc comment.

## Commit message — a draft

Add per-side seat cap: 2 pieces per player minimum

Add minPiecesOf(Level) and maxPerSideFor(Level, wanted) to the puzzle
rules. A side seats at most half the level's fewest pieces (Easy 2,
Medium 4, Hard 5) and never fewer than 1. Pure rule with unit tests;
no UI or seating change yet.

## Status row

race1a f1d: per-side cap rule (maxPerSideFor, minPiecesOf) and 9 tests done; open: Hard cap 4 vs 5 question, and calling it from seating (not in this job).

## Delete

- none
