job: M16 wave1-789 n9a — Connect screen's manual-address row fits at 320 px in both looks
stop: Do not change the host list, consent order or any string. No Home work.
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/ui/connect_screen.dart:80-128,317-378 · controller_app/test/connect_screen_test.dart:180-268 (how a size is set: pumpApp screen:) · controller_app/test/support/pump_app.dart · packages/party_host/test/support/all_looks.dart (looks) · decision (owner, Nov 24): "Accept all"; item 9a: the manual row overflows 39 px in the menu look and 109 px in the TV look at 320 px; the app bar 45 px.
changes: _ManualEntry · connect_manual_entry.dart
turns: 60
expected-min: 35
do:
1 Tests: write controller_app/test/connect_narrow_test.dart FIRST and run it (it must fail): pump the Connect screen in the menu look and the TV look at 320x640, 375x667, 568x320, 640x360 and with text scale 1.3 at 320x640; expect no overflow (tester.takeException is null), the field 'manualAddress' and the Connect button fully inside the screen.
2 Move _ManualEntry and its state to a NEW file controller_app/lib/src/ui/connect_manual_entry.dart (public class ManualEntry, same behaviour, same keys). connect_screen.dart imports it.
3 When the field plus the Connect button do not fit side by side (LayoutBuilder, about 360 dp), put Connect under the field (Column, button aligned to the end); otherwise keep the Row.
4 App bar (connect_screen.dart:~101-117): title ellipsis (overflow ellipsis, one line) so the StatusChip and the diagnostics button stay and the bar does not overflow at 320.
5 Report: connect_screen.dart line count (378 or fewer), the sizes tested.
UI: both looks; test names say which.
allow: controller_app/lib/src/ui/connect_panels.dart · controller_app/lib/src/ui/connect_screen.dart · controller_app/lib/src/ui/connect_manual_entry.dart · controller_app/test/connect_narrow_test.dart · controller_app/test/connect_screen_test.dart · controller_app/test/connect_identity_gap_test.dart · controller_app/test/connect_consent_pop_test.dart
repair: a first attempt (kept in the job log flash-n9a.log) left ONE failing case: the TV look at 568x320 overflows a RenderFlex by 12 px on the right. Find the overflowing widget first (print the exception's widget path with tester.takeException().toString() or debugDumpApp), then fix it: in ManualEntry or the app bar, or (allowed now) in connect_panels.dart if the overflow is in the right-hand panel in the TV look. All 9 narrow cases must pass in both looks; also fix the stale line references in connect_identity_gap_test.dart if a test fails on them.
check: format analyze phone
report: docs/briefs/m16/wave1-789/n9a-report.md
