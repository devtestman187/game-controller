job: M16 w4e wave 3 leftovers: MatchView in its own file, a split-board MatchPainter character test, the Robo comment
pub: no
tests-first: exempt the split-board test guards behaviour the old code already has (characters reach MatchPainter); the move is a refactor
turns: 40
expected-min: 25
stop: after the three items. No behaviour change in the move.
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/play_view.dart:1-20 (imports) and :205-363 (MatchView and its state) · packages/puzzle_game/lib/puzzle_game.dart:1-35 (exports) · packages/puzzle_game/test/worker_identity_test.dart:1-136 (the harness to copy for a split board) · packages/puzzle_game/lib/src/snapshot.dart (MatchSnapshot.split) · packages/party_host/test/puzzle_screen_test.dart:170-188 · docs/code-health.md "i1g wave 3 leftovers"
changes: _MatchViewState
decisions: from code-health: MatchView shares play_view.dart with PuzzlePlayView (two public widgets in one file).
do:
1 (a refactor, exempt from tests-first) New packages/puzzle_game/lib/src/match_view.dart holds `MatchView` and `_MatchViewState` moved unchanged with the imports they need; play_view.dart keeps `PuzzlePlayView` (drop imports it no longer uses); puzzle_game.dart exports match_view.dart.
2 New test packages/puzzle_game/test/match_split_identity_test.dart (copy worker_identity_test's harness): a SPLIT match (two boards, so `MatchPainter` draws, not `PuzzlePainter`) draws a worker in the character the host gave its player (pink crown for player 1), not the number's default, in the menu and TV looks. It must fail if `characters` is not passed to the split painter.
3 packages/party_host/test/puzzle_screen_test.dart:174-176: the comment says Robo is checked; the test checks p1 and p2 only. Make the comment say what it checks.
4 Report: the new line counts of play_view.dart and match_view.dart.
allow: packages/puzzle_game/lib/src/play_view.dart · packages/puzzle_game/lib/src/match_view.dart · packages/puzzle_game/lib/puzzle_game.dart · packages/puzzle_game/test/match_split_identity_test.dart · packages/party_host/test/puzzle_screen_test.dart · docs/briefs/m16/identity1-w4/w4e-report.md
check: format analyze puzzle host
report: docs/briefs/m16/identity1-w4/w4e-report.md
