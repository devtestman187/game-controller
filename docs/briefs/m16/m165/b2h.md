job: m16 m165 b2h — control: the connection chip is visible and readable at 568x320 and 667x375 in every look; three skips removed
stop: after the tests. If a case fails because the chip or the bar is unreadable or overflows, REPORT it (size, text, rects) and do not redesign lib code; mark only that case `skip: 'B-044 control: <measured values>'` so the check stays green, and list it under "Open" in the report.
read: docs/briefs/templates/COMMON.md · controller_app/test/connect_narrow_test.dart:40-70 (knownTopBarOverflow, line 58) · controller_app/test/connection_chip_test.dart:15-75 (`if (tv) return` at 41, the 568 TV skip at ~53) · controller_app/test/touch_targets_test.dart:38-50 (the 568 TV `continue` at 46) · controller_app/test/support/pump_app.dart:1-60 (pumpApp, targetScreens) · the bar now holds one More menu (Key 'moreMenu') instead of Settings and Diagnostics buttons (a1s, committed) · owner (Nov 25): "tests that the connection chip is visible and readable at 568x320 and 667x375 in every look... If the chip is unreadable at 568 TV, report it and do not redesign."
changes: knownTopBarOverflow (connect_narrow_test.dart, removed) · the TV skip conditions of connection_chip_test.dart and touch_targets_test.dart (removed)
model: haiku
turns: 60
expected-min: 30
apply: no
tests-first: exempt tests only, no lib change (the cases pin behaviour that may already hold)
do:
1 New controller_app/test/chip_readable_test.dart: for screens 568x320 and 667x375 and looks menu and TV (toyTvProvider override), paired and connected (see connection_chip_test.dart): Key('connectionChip') exists, its rect lies inside the screen and is at least 48 dp square, its label Text is not cut (RenderParagraph.didExceedMaxLines false, no ellipsis overflow), and no layout overflow was thrown (tester.takeException() null).
2 Remove the three skips named in read: (connect_narrow_test.dart knownTopBarOverflow, connection_chip_test.dart `if (tv) return` and the 568 TV skip, touch_targets_test.dart the 568 TV continue). Where a removed skip now fails, follow the stop: rule.
3 Run the four test files, then `dart analyze` on the changed files; fix every info, warning and error. Report the measured chip rect, label and overflow text for every failing case.
allow: controller_app/test/chip_readable_test.dart · controller_app/test/connect_narrow_test.dart · controller_app/test/connection_chip_test.dart · controller_app/test/touch_targets_test.dart · docs/briefs/m16/m165/b2h-report.md
check: format analyze phone
report: docs/briefs/m16/m165/b2h-report.md
