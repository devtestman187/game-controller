job: m12 step7 s7a G4 — split game.dart, view.dart and match_test.dart as pure moves
stop: after G4.
read: docs/briefs/m12/s7-g1-plan.md §1 (the split map: follow it exactly) · docs/coding-guidelines.md · packages/puzzle_game/lib · packages/puzzle_game/test

Claude's answers for this job: plan Q6 parts are fine for `game.dart` (private state) and `view.dart` (private `_text`, colours) · Q9 the four-file test split is approved, with the helpers at `test/support/match_helpers.dart` (the game_kit convention) instead of `test/match_helpers.dart`.

do: §1 of the plan, nothing else. Only directives (`part`, `part of`, `import`, `export`) may be added or edited; every other line moves unchanged. If a move needs any other text change, stop and report it instead.

tests: none added or changed. Test counts per file group stay the same (31 in the old match_test total across the new files, view_test 7, and the rest unchanged); say the counts before and after.

report: line counts of every new and touched file (flag > 300; any lib file over 400 or test over 500 is a failure), `tools/review.sh --strings` output (must be 0/0 apart from directives), test counts before and after.
rules: pure moves only · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s7a-report.md · packages/puzzle_game/lib · packages/puzzle_game/test
check: format analyze puzzle host
report: docs/briefs/m12/s7a-report.md
