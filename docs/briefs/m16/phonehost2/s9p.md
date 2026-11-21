job: M16 phonehost2 S9p — refresh docs/design/m13-tablet-board.png once
tests-first: exempt a picture refresh, no code change
stop: after the refresh. No Dart file changes.
read: packages/puzzle_game/test/tablet_board_png_test.dart (the UPDATE_PNG guard, its doc comment) · docs/briefs/m16/phonehost1/s9a-report.md
decisions: the committed picture is stale (126,808 bytes vs 167,512 today); the owner's team wants it refreshed once, deliberately.

do:
1 From the repository root run `flutter test --dart-define=UPDATE_PNG=true packages/puzzle_game/test/tablet_board_png_test.dart` (use `cd packages/puzzle_game && flutter test --dart-define=UPDATE_PNG=true test/tablet_board_png_test.dart` if the first form is not allowed). Check that docs/design/m13-tablet-board.png changed and is a valid PNG of roughly 167 KB. Then run the same test once without the define and confirm it passes and leaves the file unchanged (compare size and `git status`).
2 Do not touch any other file in docs/design/ (other pictures a run may rewrite are churn: leave them, never stage them).
3 Report: sizes before and after, both test results.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, item 5 only (what the job did not touch).
rules: aim 15-30 turns · write only inside allow: · stage nothing · no git add -A.
allow: docs/design/m13-tablet-board.png · docs/briefs/m16/phonehost2/s9p-report.md
check: format
report: docs/briefs/m16/phonehost2/s9p-report.md
