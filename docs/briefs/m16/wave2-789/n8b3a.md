job: wave2-789 n8b3a — tests that start on the Connect screen reach it through a helper that also works when Home comes first
stop: No lib file is edited. After this job the tests pass on today's launch AND on a launch that opens Home first (n8b3 changes the launch next wave).
read: docs/briefs/templates/COMMON.md · controller_app/test/support/pump_app.dart:40-100 · controller_app/test/launch_consent_test.dart · controller_app/test/connect_consent_pop_test.dart · controller_app/test/connect_identity_gap_test.dart · controller_app/test/connect_narrow_test.dart · controller_app/test/identity_change_link_test.dart · controller_app/test/join_badge_test.dart · controller_app/test/touch_targets_test.dart · controller_app/lib/src/home/home_text.dart (HomeText.joinGame) · owner decision: an unpaired launch will open Home, and "Join a Game" opens the Connect screen.
changes: reachConnect
turns: 45
expected-min: 25
tests-first: exempt a test-helper refactor; the repinned tests pass on the base
do:
1 pump_app.dart: add `Future<void> reachConnect(WidgetTester tester)`: if the text HomeText.joinGame is on screen, tap it and settle (as pumpApp's `settle`); otherwise do nothing (the launch today opens Connect). Document it.
2 In each of the 7 test files above, after each `pumpApp(...)` with an unpaired launch that then expects the Connect screen, call `await reachConnect(tester)`. Do not change any expectation. Where a test pumps unpaired and expects NOT the Connect screen, leave it.
3 Run those 7 files; all pass.
4 Before finishing run `dart analyze` on the files you changed and fix every info.
allow: controller_app/test/support/pump_app.dart · controller_app/test/launch_consent_test.dart · controller_app/test/connect_consent_pop_test.dart · controller_app/test/connect_identity_gap_test.dart · controller_app/test/connect_narrow_test.dart · controller_app/test/identity_change_link_test.dart · controller_app/test/join_badge_test.dart · controller_app/test/touch_targets_test.dart
check: format analyze
report: docs/briefs/m16/wave2-789/n8b3a-report.md
