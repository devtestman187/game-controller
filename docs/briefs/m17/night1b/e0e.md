job: night1b e0e — a joiner past the cap sees "Game full" instead of "Not joined"
stop: no change to the cap (maxPerSide stays 2; f1b changes it later), to sides or to how players join; text and one flag only
read: docs/briefs/templates/COMMON.md · packages/party_host/test/support/all_looks.dart (existing helper) · packages/party_host/lib/src/ui/join_screen.dart:70-85 and :323-362 · packages/party_host/lib/src/ui/join_screen_widgets.dart:34-50 and :160-195 · packages/party_host/lib/src/text/host_text.dart:79 (379 lines: keep it at or under 380) · tests that pin it: packages/party_host/test/join_screen_test.dart:130-150, join_screen_frame_test.dart:145-160 · plan, quoted (city-rush e0e): "'Game full' message for a joiner past the cap (join_screen.dart:330-333)."
changes: HostText.notJoined · _NotJoined.full · _JoinBody.full
model: haiku
turns: 45
expected-min: 20
tests-first: exempt none; the new test fails on the base (the text is "Not joined")
do:
1 host_text.dart:79: keep the file's line count. Replace the one line with `static String notJoined(String names, {bool full = false}) => full ? 'Game full, watching: $names' : 'Not joined: $names';` (if the formatter splits it, trim a blank line elsewhere in that file so it stays at 380 or fewer).
2 join_screen_widgets.dart: `_NotJoined` and `_JoinBody` take `required bool full`; `_NotJoined` passes it to HostText.notJoined. Keep Key('notJoined').
3 join_screen.dart build(): compute `final full = sideForNewPlayer(_teams) == null;` and pass `full: full` to _JoinBody. Change nothing else (join_screen.dart is 366 lines; stay under 380).
4 Tests: NEW packages/party_host/test/join_screen_full_test.dart, written and run first (follow join_screen_test.dart for the harness; run under the TV look via toyTvProvider.overrideWithValue(true) and one phone look; the existing helper in read: is only imported, never edited): with 4 players joined (2 a side) and a 5th watching, the notJoined text starts with "Game full"; with 2 players joined and a 3rd watching (room left), it still says "Not joined". Fix any existing test that pins the old text for a full game.
5 Report: the two texts and which existing tests changed.
6 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/text/host_text.dart · packages/party_host/lib/src/ui/join_screen.dart · packages/party_host/lib/src/ui/join_screen_widgets.dart · packages/party_host/test/join_screen_full_test.dart · packages/party_host/test/join_screen_test.dart · packages/party_host/test/join_screen_frame_test.dart
check: format analyze host
report: docs/briefs/m17/night1b/e0e-report.md
