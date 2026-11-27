job: phone1b y0e — the TV lobby names players whose phone has an old app
stop: no change to the choice round, the wire or the phone app; no new capability.
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/ui/night_start_names.dart (all) · packages/party_host/lib/src/ui/night_start_screen.dart (where NightStartNames is built) · packages/party_host/lib/src/text/night_text.dart:1-60 · packages/connection/lib/src/host_types.dart:30-135 (ControllerInfo.supports, HostSnapshot.controllers) · packages/party_host/lib/src/providers.dart:165-210 · packages/party_host/test/night_start_frame_test.dart · owner, Nov 26: lobby wording "[Name] has an old app and will play with simple buttons."
changes: NightStartNames.oldAppIds · NightText.oldApp
turns: 60
ladder: 2
repair: the first attempt is saved as E:/AI/game-controller-m17side/.dart_tool/run-jobs/docs_briefs_m17_phone1b/parked-y0e.patch; Read it and re-create its files. It failed: with two old phones in a 6-player night the lines overflow the frame by 28 px (640x360, 852x393, 1920x1080). Decision: show at most ONE line under the names: one old phone = its sentence, two or more = the count line (one line, ellipsised); then the 6-player tests must pass without loosening them.
expected-min: 30
tests-first: exempt new line with no earlier behaviour; its test file is new
do:
1 NightText.oldApp(name) = "$name has an old app and will play with simple buttons." (night_text.dart). NightStartNames gets `Set<String> oldAppIds = const {}` (ids of players whose phone does not list Capability.choices): under the names ONE line only: one such player = that sentence; two or more = "N players have an old app and will play with simple buttons." Same text style as the names, ellipsised, never overflows the TV frame.
2 night_start_screen.dart: pass the ids of players whose ControllerInfo (host snapshot, by controller id) does not support Capability.choices. A player with no phone session (local, simulated) is not listed.
3 Tests (new party_host/test/night_start_old_app_test.dart, copy the frame setup of night_start_frame_test.dart; every look and the TV frame): no line when all phones list the cap; one old phone: the exact sentence; three: the count line, two: the count line; a 6-player night still fits.
4 Before finishing run `flutter analyze` on the changed files and fix every info, warning and error; run `flutter test` on the new test and night_start_frame_test.dart from packages/party_host.
allow: packages/party_host/lib/src/ui/night_start_names.dart · packages/party_host/lib/src/ui/night_start_screen.dart · packages/party_host/lib/src/text/night_text.dart · packages/party_host/test/night_start_old_app_test.dart · packages/party_host/test/night_start_frame_test.dart
check: format analyze host
report: docs/briefs/m17/phone1b/y0e-report.md
