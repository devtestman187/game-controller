job: M16 w4b one value object (ArenaCast) for roster + characters in ArenaPainter and ArenaMarblePainter
pub: no
turns: 40
expected-min: 25
tests-first: exempt refactor; existing painter tests are the proof (they change only in how they build the painters)
stop: after the painters take one `cast` parameter. No pixel or behaviour change. Do not touch ArenaField/ArenaBoard/HUD widget parameters (they keep roster and characters and build the object).
read: docs/briefs/templates/COMMON.md · packages/test_game/lib/src/arena_roster.dart:1-20 (the typedefs) · packages/test_game/lib/src/arena_painter.dart:78-100,130-145 · packages/test_game/lib/src/arena_marble_painter.dart:55-97 · packages/test_game/lib/src/arena_map_picture_widgets.dart:35-55 · packages/test_game/lib/src/arena_view_widgets.dart:120-140 · call sites in tests: map_flags_test.dart:35, map_picture_test.dart:59, support/map_sheet.dart:55, coin_badge_legibility_test.dart:70-80 (test_game/test), packages/party_host/test/look_midgame_test.dart:85-100 · docs/coding-guidelines.md (five parameters at most)
changes: ArenaCast
decisions (owner, Nov 23): Q8 yes: "one value object for roster + characters in ArenaPainter / ArenaMarblePainter".
do:
1 arena_roster.dart: add `class ArenaCast { const ArenaCast(this.roster, {this.characters = const {}}); final ArenaRoster roster; final ArenaCharacters characters; }` with a doc comment (the players an arena draws: who they are and what they chose). Default `const ArenaCast({})` usable as an empty cast.
2 ArenaPainter(s, cast, {look, moments, fillsBackground}) and ArenaMarblePainter({snapshot, cast, look, style, moments}): drop the separate roster and characters fields; read `cast.roster` / `cast.characters` (arenaCharacterFor(cast.roster, id, characters: cast.characters)). ArenaPainter passes its cast on.
3 Fix every call site above to build the cast (`ArenaCast(roster, characters: characters)`; `const ArenaCast({})` where the test passed `const {}`).
4 Report: the new parameter counts of both constructors.
allow: packages/test_game/lib/src/arena_roster.dart · packages/test_game/lib/src/arena_painter.dart · packages/test_game/lib/src/arena_marble_painter.dart · packages/test_game/lib/src/arena_map_picture_widgets.dart · packages/test_game/lib/src/arena_view_widgets.dart · packages/test_game/test/map_flags_test.dart · packages/test_game/test/map_picture_test.dart · packages/test_game/test/support/map_sheet.dart · packages/test_game/test/coin_badge_legibility_test.dart · packages/party_host/test/look_midgame_test.dart · docs/briefs/m16/identity1-w4/w4b-report.md
check: format analyze arena host
report: docs/briefs/m16/identity1-w4/w4b-report.md
