job: M14 stats2 fix3-apps: close REVIEW.md findings 3, 5 and 10 (phone test that cannot fail; two digit caps; hello keeps the bare version, untested)
stop: after it. Do not edit controller_app/lib/src/host/**, ui/connect_panels.dart, ui/settings_screen.dart, ui/settings_sections.dart, party_host/lib/src/text/settings_text.dart (another session owns them), live_stats.dart, or any existing test file under controller_app/test or party_host/test (new files only).
read: docs/briefs/m14/stats2/REVIEW.md (findings 3, 5, 10) · controller_app/lib/src/storage.dart (loadIdentity) · controller_app/lib/src/app_info.dart · controller_app/test/app_with_build_test.dart · packages/party_host/lib/src/host_identity.dart · packages/party_host/test/host_app_with_build_test.dart
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 TEST FIRST, new files controller_app/test/identity_build_test.dart and packages/party_host/test/host_build_cap_test.dart (must fail on old code): (a) loadIdentity takes an optional build parameter (default buildNumber) and loadIdentity(prefs, build: '654').appVersion is '0.14.0+654' (existing call sites keep working); (b) appWithBuild and HostIdentity.appWithBuild send a build of at most 9 digits, a ten-digit one gives the bare version (the reader, splitAppBuild in session_clean.dart, drops more than 9); (c) the hello and the simulated controllers still send the bare appVersion: assert it on the host service the way host_app_with_build_test.dart does.
2 Implement (a) and (b) in storage.dart, app_info.dart, host_identity.dart.
tests: each new test goes in a NEW file and must fail on the code as it was.
rules: aim for 80-120 turns · no lib file over 380 lines · tests first: the runner checks it · write only inside allow: · stage nothing yourself, never git add -A · tools/review.sh: no FAIL on your lines.
allow: controller_app/lib/src/app_info.dart · controller_app/lib/src/storage.dart · controller_app/test/identity_build_test.dart · packages/party_host/lib/src/host_identity.dart · packages/party_host/test/host_build_cap_test.dart · docs/briefs/m14/stats2/fix3-apps-report.md
check: format analyze host phone
report: docs/briefs/m14/stats2/fix3-apps-report.md
in the report: start with "## Summary" (at most 30 lines, in the first 40): what changed, tests seen failing then passing, decisions. End with "## Hand-over" (at most 20 lines).
