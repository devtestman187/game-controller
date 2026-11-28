job: race1a f1d — piece rule: at least 2 pieces per player per side
stop: no join screen, settings or UI change; only the pure rule and its test
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/puzzle_rule_levels.dart:1-40 (piece limits: easyMinPieces 4, mediumMinPieces 8, hardMinPieces 10) · packages/puzzle_game/lib/src/puzzle.dart:82-90 (enum Level) · owner plan: "require at least 2 pieces per player per side (4 a side means Medium/Hard only)"
changes: maxPerSideFor · minPiecesOf
model: haiku
turns: 35
expected-min: 15
tests-first: exempt a new function, its test cannot pass on the base; write it first and see it fail to compile
do:
1 puzzle_rule_levels.dart (part of puzzle_rules.dart, exported): add `int minPiecesOf(Level level)` (the level's min constant) and `int maxPerSideFor(Level level, int wanted)` = wanted limited to `minPiecesOf(level) ~/ 2` and to at least 1. Doc comment: 2 pieces per player per side; Easy seats 2 a side, Medium and Hard 4.
2 New test file packages/puzzle_game/test/per_side_rule_test.dart: Easy 4 -> 2, Easy 2 -> 2, Easy 1 -> 1, Medium 3 -> 3, Medium 4 -> 4, Hard 4 -> 4, Medium 9 -> 4, wanted 0 -> 1.
3 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/puzzle_game/lib/src/puzzle_rule_levels.dart · packages/puzzle_game/test/per_side_rule_test.dart
check: format analyze
report: docs/briefs/m17/race1a/f1d-report.md
