job: M16 identity1 i1g: Shape Race workers, TV scores and badges draw the chosen character; audit of every painter
pub: no
stop: after it. The Arena is i1f's.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/identity1/i1a-report.md · i1f-report.md · packages/puzzle_game/lib/src/worker_painter.dart:82 (forPlayer(p.number)) · puzzle_module.dart · packages/party_host/lib/src/ui/score_row.dart:259 (bar colour by number; 346 lines) · player_badge.dart (Robo disc) · join_side_panel.dart · away_card.dart · packages/party_host/lib/src/night/round_results.dart:40-48 · packages/party_host/test/support/all_looks.dart · tests that could break: packages/puzzle_game/test, party_host/test score row, player badge and join side panel tests
changes: _ScoreBar · PlayerView.character
probe: docs/briefs/m16/identity1/probe-i1g.patch
decisions (owner, Nov 21): "Identity shows everywhere players are drawn: TV and phone-host screen in every game (incl. Shape Race), lobby, results, scores. Any game painter still using forPlayer(n) defaults gets fixed, with a per-game test that a non-default pick is drawn."
do:
1 Tests first, NEW packages/puzzle_game/test/worker_identity_test.dart and packages/party_host/test/identity_everywhere_test.dart: a non-default pick (e.g. player 1 as colour 5 with the crown) is drawn by the Shape Race worker, the score bar, the score row badge, the results rows, the lobby side panel and the pause/away cards; every look, menu and TV (all_looks.dart).
2 Fix: the worker painter takes the character from the frame's chars / roster (default only when missing); the score_row bar uses the character's colour; move code out of score_row.dart so it ends at or under 380.
3 Audit: say in the report which other painters draw a player (Cat Chaos, if it has workers) and fix any still using forPlayer(n) or player(number).
Every-look rule: any UI you add or change is tested in the menu look AND the TV look (toyTvProvider.overrideWithValue(true); helper packages/party_host/test/support/all_looks.dart); no fixed pixel height on look-sized content.
allow: packages/puzzle_game/lib/src/worker_painter.dart · packages/puzzle_game/lib/src/puzzle_module.dart · packages/puzzle_game/lib/src/snapshot.dart · packages/party_host/lib/src/ui/score_row.dart · packages/party_host/lib/src/ui/score_row_bar.dart · packages/party_host/lib/src/ui/score_row_parts.dart · packages/party_host/lib/src/ui/player_badge.dart · packages/party_host/lib/src/ui/join_side_panel.dart · packages/party_host/lib/src/ui/puzzle_results_widgets.dart · packages/puzzle_game/test/worker_identity_test.dart · packages/party_host/test/identity_everywhere_test.dart · docs/briefs/m16/identity1/i1g-report.md
check: format analyze puzzle host
report: docs/briefs/m16/identity1/i1g-report.md
rules: aim 85-115 turns, never over 120 · no lib file you touch ends over 380 lines · tests first in NEW test files · sound.dart must not grow · tools/review.sh: no FAIL on your lines.
