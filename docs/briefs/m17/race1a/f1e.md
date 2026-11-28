job: race1a f1e — a settings row for players per side, so the setting can be reached
stop: no join, panel or rule change; one row on the settings screen and its label
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/ui/puzzle_settings_screen.dart:15-45 (the key and label list) :160-180 and :250-262 (how a value is shown; an int like timeLimitS) · packages/party_host/lib/src/text/host_text.dart (find HostText.timeLimit; the file is at the 380-line gate) · packages/puzzle_game/lib/src/settings.dart maxPerSide (already there, range 2 to 4) · packages/party_host/test/puzzle_settings_screen_test.dart (rows pinned) · owner plan: "maxPerSide becomes a setting (2 to 4)"
changes: puzzleSettingsRows · playersPerSideLabel
model: haiku
turns: 50
expected-min: 25
tests-first: exempt the row test fails on the base (no row); write it first
touch-target: exempt one more row of the same stepper control as the others; row size unchanged
do:
1 puzzle_settings_screen.dart: add the row ('maxPerSide', label 'Players per side') after the time limit row, shown as the plain number. Text: host_text.dart must not grow past 380 lines; put the label as a top-level const `playersPerSideLabel` in a new file packages/party_host/lib/src/text/race_text.dart and use it from the screen.
2 Test in puzzle_settings_screen_test.dart: the row is there, plus tap moves 2 to 3 to 4 and stops at 4 (copy how an existing int row is tested). Fix any test that counts the rows. Under every look as the existing tests do.
3 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/ui/puzzle_settings_screen.dart · packages/party_host/lib/src/text/race_text.dart · packages/party_host/test/puzzle_settings_screen_test.dart · packages/party_host/test/puzzle_settings_test.dart
check: format analyze
report: docs/briefs/m17/race1a/f1e-report.md
