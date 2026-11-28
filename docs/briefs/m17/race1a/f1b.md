job: race1a f1b — maxPerSide setting (2 to 4) and the join logic follows it, limited by the level
stop: no side-panel seat drawing, no MatchFormat, no popup change (later jobs); the top-level const maxPerSide in join_screen.dart stays (the panel still reads it until f1c)
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/settings.dart:14-35 (ctor) and :75-153 (ranges, toJson, fromJson, withValue) · packages/party_host/lib/src/ui/join_screen.dart:55-80 (sideForNewPlayer) :240-250 (key handling) :282-290 (_pickSide) · packages/party_host/lib/src/puzzle_settings_provider.dart (the provider the screens read; find its name there) · maxPerSideFor(Level, int) in packages/puzzle_game/lib/src/puzzle_rule_levels.dart (made by f1d) · tests: packages/party_host/test/join_screen_test.dart, join_screen_full_test.dart, join_screen_frame_test.dart (grep sideForNewPlayer, maxPerSide) and the settings tests (grep -l pointsScale in packages/puzzle_game/test and packages/party_host/test) · owner plan: "maxPerSide becomes a setting (2 to 4) and the join logic follows"; default stays 2 so a 2 a side game plays exactly as now
changes: PuzzleSettings.maxPerSide · PuzzleSettings.ranges · sideForNewPlayer
model: haiku
turns: 50
expected-min: 30
tests-first: exempt the new join cases fail on the base only by a missing parameter; write them first
do:
1 settings.dart: int field maxPerSide, default 2, ctor, toJson, fromJson (clamped to 2..4, a bad value gives 2), ranges entry 'maxPerSide': (min: 2.0, max: 4.0, step: 1.0). Follow how timeLimitS (an int) is done.
2 join_screen.dart: sideForNewPlayer(teams, {int cap = maxPerSide}) uses cap instead of the const in :77-79. In the state class compute `cap = maxPerSideFor(widget.choice.level, <the saved setting's maxPerSide>)` where the setting comes from the settings provider (ref.read in handlers, ref.watch in build) and use it in :245, :287, and wherever sideForNewPlayer is called. The const `maxPerSide = 2` stays as is.
3 Tests (new file packages/party_host/test/join_cap_test.dart plus a settings test case): sideForNewPlayer with cap 3 and 4 fills evenly and returns null at cap each side; with default 2 same as before; setting 4 on Easy still seats only 2 a side, on Medium 4; fromJson clamps 9 to 4 and 1 to 2. Fix any existing test the setting breaks (settings screen tests that list every range).
4 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/ui/puzzle_settings_screen.dart · packages/puzzle_game/lib/src/settings.dart · packages/party_host/lib/src/ui/join_screen.dart · packages/party_host/test/join_cap_test.dart · packages/party_host/test/join_screen_test.dart · packages/party_host/test/join_screen_full_test.dart · packages/party_host/test/join_screen_frame_test.dart · packages/party_host/test/puzzle_settings_test.dart · packages/puzzle_game/test/settings_test.dart · packages/party_host/test/puzzle_settings_screen_test.dart
check: format analyze
report: docs/briefs/m17/race1a/f1b-report.md
