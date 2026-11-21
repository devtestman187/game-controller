job: M16 phonehost1 S9a — stop the tablet-board test rewriting a committed PNG on every run
tests-first: exempt test-hygiene change; the behaviour is the test's own file side effect
stop: after S9a. Nothing else in puzzle_game.
read: packages/puzzle_game/test/tablet_board_png_test.dart (:84 writes docs/design/m13-tablet-board.png) · docs/flash-digest.md (churn) · docs/briefs/m16/STATUS.md (S9)

do:
1 In packages/puzzle_game/test/tablet_board_png_test.dart write docs/design/m13-tablet-board.png only when the environment has UPDATE_PNG=1 (Platform.environment) or --dart-define=UPDATE_PNG=true. Otherwise render the same picture but keep the bytes in memory and still assert their length (greaterThan(5000)); the test must still run and pass without the flag. Update the file's doc comment to say how to refresh the PNG.
2 Verify: run flutter test test/tablet_board_png_test.dart in packages/puzzle_game and report that `git status --short docs/design` shows no change after the run.
in the report: `## Summary` (at most 15 lines), then `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each.
tests: await async effects.
rules: no lib change · write only inside allow: · stage nothing · no git add -A.
allow: packages/puzzle_game/test/tablet_board_png_test.dart · docs/briefs/m16/phonehost1/s9a-report.md
check: format analyze puzzle
report: docs/briefs/m16/phonehost1/s9a-report.md
