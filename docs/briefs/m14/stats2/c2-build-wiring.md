job: M14 stats2 c2-build-wiring: the host and the phone send "version+build" as their app string
stop: after it. Do not edit controller_app/lib/src/host/**, ui/connect_panels.dart, ui/settings_screen.dart, ui/settings_sections.dart, party_host/lib/src/text/settings_text.dart (another session owns them); do not touch live_stats.dart (380 lines).
read: controller_app/lib/src/app_info.dart · controller_app/lib/src/storage.dart (~line 49, ControllerIdentity) · packages/party_host/lib/src/host_identity.dart · packages/party_host/lib/src/host_service.dart (~line 152, hostApp) · existing tests that pin an identity's appVersion (grep appVersion in controller_app/test and packages/party_host/test)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Today versionLabel is "0.14.0 (654)" and buildNumber is a const ('dev' locally), but only appVersion ("0.14.0") reaches the stats. Fix: send "0.14.0+654".
do:
1 TEST FIRST, new files controller_app/test/app_with_build_test.dart and packages/party_host/test/host_app_with_build_test.dart (new files only; must fail on old code): appWithBuild('0.14.0','654') == '0.14.0+654'; with 'dev' or '' it is '0.14.0'; the phone's controller identity built in storage.dart has appVersion using it; HostIdentity gets a getter appWithBuild built from appVersion and the digits inside versionLabel ('0.11.0 (123)' gives '0.11.0+123'; '(dev)' gives '0.11.0'); host_service.dart passes it as LiveStats hostApp. Everything else keeps the bare appVersion (hello to controllers, logs, UI).
2 appWithBuild(version, build) in controller_app/lib/src/app_info.dart, used in storage.dart only.
3 Fix existing tests that pin the changed strings.
tests: each new test goes in a NEW file and must fail on the code as it was. Run only your test files while working, the full suites once at the end.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself, never git add -A · tools/review.sh: no FAIL on your lines.
allow: controller_app/lib/src/app_info.dart · controller_app/lib/src/storage.dart · controller_app/test · packages/party_host/lib/src/host_identity.dart · packages/party_host/lib/src/host_service.dart · packages/party_host/test · docs/briefs/m14/stats2/c2-build-wiring-report.md
check: format analyze host phone
report: docs/briefs/m14/stats2/c2-build-wiring-report.md
in the report: start with "## Summary" (at most 30 lines, in the first 40): what changed, tests seen failing then passing, decisions. End with "## Hand-over" (at most 20 lines).
