job: M16 identity1 i1f: the Arena (test_game) draws players by their chosen character
pub: no
stop: after it. No change to puzzle_game or party_host.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/identity1/i1a-report.md · packages/test_game/lib/src/arena_roster.dart (arenaCharacterFor uses forPlayer(number)) · arena_marble_painter.dart:87 · arena_hud_widgets.dart:266 (the dot uses player(number)) · arena_module.dart · arena_view_widgets.dart · packages/protocol/lib/src/view.dart (frame chars) · tests that could break: packages/test_game/test arena roster, HUD and marble tests
decisions (owner, Nov 21): "Identity shows everywhere players are drawn: TV and phone-host screen in every game. Any game painter still using forPlayer(n) defaults gets fixed, with a per-game test that a non-default pick is drawn." Robo keeps the next free number's colour with the antenna.
do:
1 Tests first, NEW packages/test_game/test/arena_identity_test.dart: with a frame carrying a non-default character for a player (e.g. player 1 as colour 5 with the crown) the marble painter draws colour 5 and the crown, and the HUD dot is colour 5; with no chars the defaults are unchanged; Robo unchanged. Menu look and TV look.
2 Carry each player's character in the roster (or beside it) from the frame's chars / the host's players; arenaCharacterFor reads it and falls back to the default only when missing.
Every-look rule: any UI you add or change is tested in the menu look AND the TV look (toyTvProvider.overrideWithValue(true); helper packages/party_host/test/support/all_looks.dart if reachable, else the package's own look wrapper).
allow: packages/test_game/lib/src/arena_roster.dart · packages/test_game/lib/src/arena_marble_painter.dart · packages/test_game/lib/src/arena_hud_widgets.dart · packages/test_game/lib/src/arena_module.dart · packages/test_game/lib/src/arena_view_widgets.dart · packages/test_game/lib/src/arena_painter.dart · packages/test_game/test/arena_identity_test.dart · docs/briefs/m16/identity1/i1f-report.md
check: format analyze test_game
report: docs/briefs/m16/identity1/i1f-report.md
rules: aim 70-100 turns · no lib file you touch ends over 380 lines · tests first in NEW test files · sound.dart must not grow · tools/review.sh: no FAIL on your lines.
