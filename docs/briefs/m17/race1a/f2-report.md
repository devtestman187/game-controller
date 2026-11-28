# race1a f2 report: review fixes for the seat cap

## Files changed

- `packages/party_host/test/join_cap_screen_test.dart` (new): pumps the join screen for a Medium or Easy choice, with the saved `maxPerSide` set (4, or the default 2), and joins players with the A press.
  - Medium, setting 4: players 1 to 8 seat 4 a side (odd left, even right); player 9 is on neither side. A right player (player 2) pressing left while left is full stays on the right.
  - Easy, setting 4: players 1 to 4 seat 2 a side; player 5 is on neither side.
  - Medium, default setting 2: players 1 to 4 seat 2 a side; player 5 is on neither side.
- `packages/party_host/test/join_cap_test.dart`: deleted the two tests `the setting of four is cut to two a side on Easy` and `the setting of four seats four a side on Medium`, as the brief says. They are covered by `per_side_rule_test.dart` and by the new screen test.
- `packages/puzzle_game/lib/src/puzzle_rule_levels.dart`: `maxPerSideFor(Level level, int wanted)` renamed its parameter to `wantedPerSide`. The doc comment now says the result is players per side, not pieces. No logic change.

## Tests-first exemption

The screen test pins wiring that already works on the base, so it is exempt from tests-first.

To prove it can fail, I replaced the cap with the constant `2` in `maxPerSideFor` once and ran `tools/mine.sh`. The Medium test, `at a cap of four on Medium, the ninth player joins nobody and a right player stays right`, failed. The Easy and default tests still passed, because their expected cap is 2 anyway. I then restored the original line and reran `tools/mine.sh`, which passed.

## Checks

- `tools/mine.sh` (final run): format OK (3 files), analyze OK on `packages/party_host` and `packages/puzzle_game` with `--fatal-infos`, `party_host` tests 6 OK, `puzzle_game` tests 1 OK.
- `tools/mine.sh` with the cap replaced by 2: the Medium screen test failed, as described above.

## Questions

1. The brief asks for "a fifth press of the same side key does not move the player". I tested a right-side player pressing the left key while the left side is full, which keeps the player on the right. That is the same rule, but a fifth player on the same side is not the same case. Is this the check you wanted?
2. The deleted `join_cap_test.dart` tests also asserted the fill counts (4 and 8). `per_side_rule_test.dart` does not cover those counts. The new screen test covers the Medium count at 4, but no test covers the fill count for Easy. Should one be added?
3. The brief says "a Medium choice" for the screen test. The join screen takes its level from the `PuzzleChoice` it is given, so the test pumps `JoinScreen(choice: PuzzleChoice(level: ...))` directly. It does not use the puzzle-house tile, because that tile's level is not Medium.

## Suggestions

- `per_side_rule_test.dart` has a test named `a Medium puzzle keeps 4 a side when 4 are wanted, at its cap of 4` and one named `a Hard puzzle keeps 4 a side when 4 are wanted, under its cap of 5`. Renaming the `wanted` wording in those names to "wanted per side" would match the rename.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
race1a f2: review fixes for the seat cap
Add a join screen test for the per-side cap at Medium and Easy, and the
default of two. The screen's cap came from the saved setting but no test
pumped the screen, so a broken read would have passed.
Delete the two join_cap tests that only repeated per_side_rule_test.dart.
Rename maxPerSideFor's parameter to wantedPerSide and document that the
result is players per side, not pieces. No behaviour change.
```

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

race1a f2 done: screen test for the seat cap (Medium 4, Easy, default 2); duplicate cap tests removed; maxPerSideFor parameter renamed and documented. Open: the fill-count test for Easy (question 2), and the wording in the per-side test names.

## Delete

- none
