job: M14 g1: Shape Race groundwork before points and the cat: split game.dart, the rule book's three missing rules, `Level.hard` and the parser's casts (docs/design/party-night.md section 13, wave 1)
pub: no
stop: after it.
read: docs/design/party-night.md (sections 2, 3, 5, 13) · docs/briefs/m14/scan-m14-refresh-report.md (sections 1, 2) · docs/briefs/m13/m13-review-r4-report.md (findings 5, 6, 9, 10 and "Claude's review") · packages/puzzle_game/lib/src/game.dart, tray.dart (how a split by content was done), puzzle_rules.dart, puzzle.dart, library.dart · packages/puzzle_game/puzzles/puzzle.schema.json · packages/puzzle_game/test/rules_test.dart, puzzle_schema_test.dart, puzzle_check_test.dart · controller_app/test/puzzle_size_test.dart · tools/puzzle_new.dart · docs/puzzles.md · docs/coding-guidelines.md · docs/review-rules.md

Points (G1) and the cat (G3) both land in Shape Race's rules next. `game.dart` is 399 of 400 lines and `puzzle_rules.dart` 391, so neither can take a line. Claude's design:
1. **Split `game.dart` by a pure move.** By content, as `tray.dart` was: `PuzzlePlayer` and its counters in one file, the tick helpers (`_presses`, `_moveAll`, `_turnAll`, `_keepHeldInField`, `_highlight`, `_tapAll` and what they call) in another, `PuzzleGame` keeping its state, `update()` and the drop/turn entry points. A `part` file or extension on the game is fine if it keeps privacy simple; pick the one that reads best and say why. No behaviour change: every existing test passes unchanged, and the mirror pictures (`docs/design/m12-mirror-*.png`) come out byte-identical. Leave `game.dart` under 300 lines so a2's cat and a1's points have room.
2. **Split `puzzle_rules.dart`** the same way (the level rules, the fit rules, the colour rules: your call), then move the three rules that live only in tests into `check`:
   - at least two pieces start turned (Easy: exactly two), as `rules_test.dart` "Every puzzle needs some turning" says;
   - no two tray boxes overlap at any seed 0–199, as `rules_test.dart`'s 200-seed loop says;
   - every piece is at least `minPieceMm` across on the narrowest phone, as `controller_app/test/puzzle_size_test.dart` says. The rule book cannot import the phone. Put the narrowest phone's board size (in mm) as a named constant in puzzle_game, and change `puzzle_size_test.dart` to pin that the phone's real layout is never smaller than the constant, so the two cannot drift.
   Each rule's message names the puzzle and piece and says what to change. The old tests become thin tests over `check` (no rule written twice). Fix docs/puzzles.md line 42 (R4 finding 6) to say what `check` now asks.
3. **`Level.hard` refused** in the schema, the parser and the rule book until it has rules (R4 finding 9): a "hard" file is a clear error, the same message in each, matching `tools/puzzle.sh new`.
4. **The parser's bare casts** (`raw['id'] as String`, `raw['kind'] as String?`, and any other bare cast in `puzzle.dart`) give a `FormatException` naming the puzzle and field, like every other bad field (R4 finding 10).

tests (each failing first):
- One test per new rule, each with a puzzle that breaks only that rule, checking the message; the whole library still passes `check`.
- `puzzle_size_test.dart`: the phone's narrowest board is at least the constant.
- A "hard" puzzle is refused by the schema, the parser and `check`, with the same words.
- A number in `id` and in `kind` gives a `FormatException` naming the field.
- All existing tests pass unchanged (puzzle, phone, tv); the split adds no test of its own beyond what the move needs.

in the report: the files and their line counts before and after; which functions moved where; the three rules' messages; test counts before and after; the mirror pictures unchanged (say so, or why not).
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · a move is a move: no renames or rewrites inside moved code · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch packages/test_game, packages/party_host, packages/game_kit or assets (other jobs are working there)
allow: docs/briefs/m14/g1-puzzle-groundwork-report.md · docs/puzzles.md · packages/puzzle_game/lib · packages/puzzle_game/puzzles/puzzle.schema.json · packages/puzzle_game/test · controller_app/test/puzzle_size_test.dart · tools/puzzle_new.dart
check: format analyze puzzle phone tv
report: docs/briefs/m14/g1-puzzle-groundwork-report.md
