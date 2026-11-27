job: night2c v1b — the setup offers Vote
stop: Rotating stays hidden and unbuilt; no vote logic (v1a has it); no start-card or scoreboard change (v1c)
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_setup_options.dart:15-26 · packages/party_host/lib/src/text/night_setup_text.dart:28-40,64-84 · packages/party_host/lib/src/ui/night_setup_screen.dart:105-140 (picker rows) · packages/party_host/test/night_setup_options_test.dart:20-32 · packages/party_host/test/night_setup_screen_test.dart:100-130 (picker rows, "the last row was tapped") · packages/party_host/test/night_labels_fit_test.dart and phone_fit_matrix_test.dart (a fifth picker row must still fit at small phone sizes, 48 dp targets) · owner Nov 27: "wire the Vote now"; "Q6 A: the Rotating chooser moves to M17b. Keep it hidden and unbuilt."
changes: NightSetupOptions.offeredPickers · NightSetupText.pickerVoteHelp · NightSetupText.pickerHelp
model: sonnet
turns: 60
expected-min: 30
tests-first: exempt the offered list is data; the updated tests pin the new list
do:
1 night_setup_options.dart: offeredPickers = host, director, shuffle, playlist, vote (Vote last). Rotating is not offered.
2 night_setup_text.dart: `pickerVoteHelp` = 'Phones vote on the next game for 5 seconds. A tie or no vote picks one by luck.'; pickerHelp(vote) returns it (rotating keeps the host line).
3 Tests: night_setup_options_test: Vote offered, Rotating not; night_setup_screen_test: the Vote row exists, tapping it saves picker vote, its help line shows, and the row order/last-row test follows the new order (the last row is now Vote); the existing fit tests still pass at the small phone sizes and in every look (fix the row layout minimally, never below 48 dp).
4 Before finishing run `flutter analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/night_setup_options.dart · packages/party_host/lib/src/text/night_setup_text.dart · packages/party_host/lib/src/ui/night_setup_screen.dart · packages/party_host/test/night_setup_options_test.dart · packages/party_host/test/night_setup_screen_test.dart · packages/party_host/test/night_labels_fit_test.dart · packages/party_host/test/phone_fit_matrix_test.dart
check: format analyze
report: docs/briefs/m17/night2c/v1b-report.md
