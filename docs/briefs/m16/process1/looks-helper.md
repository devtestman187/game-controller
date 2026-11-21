job: M16 process1 looks-helper — an all-looks pump helper for party_host tests, used by the award popover test
pub: no
stop: after it. No lib changes; no change to existing award tests.
read: docs/briefs/templates/COMMON.md · packages/party_host/test/support/host_harness.dart (pumpHost :54, its overrides and size arguments) · packages/party_host/test/award_explanation_tv_test.dart (the TV pump at :75-85, the checks :95-125) · packages/party_host/test/award_explanation_size_test.dart (the menu-look checks) · packages/party_host/lib/src/look_providers.dart:56 (toyTvProvider)
decisions (owner, Nov 21): "UI sizes are tested under every look, menu and TV (toyTvProvider.overrideWithValue(true))". controller_app has no look providers, so the helper is party_host only.

do:
1 Tests first, NEW file packages/party_host/test/all_looks_support_test.dart: the helper pumps a probe widget once per look; in the menu look `toyTvProvider` reads false, in the TV look true; `forEachLook` runs its body for both looks in order menu, TV; a caller's own overrides are kept in both looks. It must fail on the old code (the helper does not exist yet).
2 NEW packages/party_host/test/support/all_looks.dart (under 150 lines, doc comments): `enum HostLook { menu, tv }`; `pumpHostLook(WidgetTester, HostLook, {...the same named arguments pumpHost takes})` which calls pumpHost and adds `toyTvProvider.overrideWithValue(true)` for tv (keeping the caller's overrides); `Future<void> forEachLook(WidgetTester, Future<void> Function(HostLook) body)` that runs body for each look.
3 NEW packages/party_host/test/award_explanation_looks_test.dart using the helper: for each of the five devices in award_explanation_tv_test.dart (copy its device list) and for BOTH looks, open every award's "i" and assert the title, line and OK button lie inside the card, the guard scroll has maxScrollExtent 0, and the OK button closes it. It must fail on old code (the helper is missing). Do not edit the two existing award tests.
4 Report: the helper's signature, the tests' counts and which looks each test saw.
UI: both looks are tested in item 3.
allow: packages/party_host/test/all_looks_support_test.dart · packages/party_host/test/support/all_looks.dart · packages/party_host/test/award_explanation_looks_test.dart · docs/briefs/m16/process1/looks-helper-report.md
check: format analyze host
report: docs/briefs/m16/process1/looks-helper-report.md
