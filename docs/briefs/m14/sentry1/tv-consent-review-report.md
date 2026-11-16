# sentry1 tv-consent review

## Summary

`small fixes` — 0 must, 1 should, 5 could.
The TV wrapper's own values are untested: `crash_setup_test`'s only app-specific assertion is `same(reporter)`,
so a `tvStartCrashReporting` that passed the wrong release or environment would still pass it.
Its second test repeats party_host's no-DSN test, and its tearDown leaks the `PlatformDispatcher.onError` handler.
Otherwise the change holds: every brief item is in the code, no party_host or CI file is touched, `dart format`
(changed files) and `flutter analyze` are clean, and the tv suite is 62 passed, 1 skipped, as the report says.
`run.log:41-42` records both new files failing on the old code, so no test was written to pass on it.

## Findings

- **should** tv_test_app/test/crash_setup_test.dart:59 the only claim about the TV wrapper is `expect(started, same(reporter))`, which restates `startCrashReporting`'s return value, so the test passes even if `tvStartCrashReporting` passed the wrong `release` or `environment` → call `tvStartCrashReporting(prefs)` with no reporter and assert the built `SentryCrashReporter`'s `dsn == ''`, `release == versionLabel` and `environment == 'debug'` (`kDebugMode` is true under `flutter test`).
- **could** tv_test_app/test/crash_setup_test.dart:67 "a build with no DSN sends nothing even after a yes" repeats `packages/party_host/test/crash_reports_test.dart:105` with no TV-specific assertion → delete it, or keep it only if it pins something only the TV wrapper decides.
- **could** tv_test_app/test/crash_setup_test.dart:50 the tearDown restores `FlutterError.onError` but not `PlatformDispatcher.instance.onError`, which `tvStartCrashReporting` replaced via `installCrashHandlers`, so the handler stays installed for the rest of the file → save and restore both, as `packages/party_host/test/crash_reports_test.dart:128-136` does.
- **could** tv_test_app/test/first_launch_consent_test.dart:94 "with crash reports answered no and sharing yes, nothing prompts" is the second half of the test at line 70 (same prefs, same two `findsNothing`) and adds no case of its own → drop it, or cover what test 70 leaves out (crash answered yes, which no test answers).
- **could** tv_test_app/lib/src/ui/home/home_screen.dart:264 the comment still says the widget "asks the adult about sharing stats on the first launch (M9)" → say it asks this instance's consent questions (crash first where available, then stats).
- **could** docs/briefs/m14/sentry1/tv-consent-report.md:77 self-check 4 says `tv_test_app/test/...` (4); the diff has three (`first_launch_consent_test.dart`, `crash_setup_test.dart`, `support/pump_app.dart`) → correct the count.

## Decisions to confirm

- `tv_host_setup.dart:94` adds a `CrashReporter? reporter` parameter to shipped code for tests to use; it mirrors `party_host`'s `startCrashReporting`, but the report's Decisions do not list it.
- The release string differs between the apps: the TV sends `versionLabel` (`'0.14.0 (123)'`, `'0.14.0 (dev)'` locally) while the phone sends `appWithBuild` (`'0.14.0+123'`, `controller_app/lib/main.dart:69`); the design says "as the apps already format it", but the two Sentry projects will group releases differently.
- Nothing in this job takes effect in a release build until the ci-wiring job lands: `.github/workflows/release.yml:95-105` passes no `SENTRY_DSN` today, so `sentryDsn` stays empty, `crashAvailableProvider` is false and the crash question is never asked, as `docs/release.md:90` promises.
- `test/support/pump_app.dart:67` now writes `statsConsent` itself next to `FakeHostService(consent:)`, and a non-null `consent` silently overrides a `keptPrefs` stats entry; confirm that precedence is the intended test API.

## Could not check

- The new tests failing on the old code by running them there (I did not check out 2e8c28c); `run.log:41-42` records the runner doing it, and both files use API (`crashAvailable`, `keptPrefs`, `tvStartCrashReporting`) that does not exist before this change.
- Device behaviour: Sentry starting under a real `SENTRY_DSN`, and the two dialogs' focus and look on a TV box and on Windows — no device run; only the 960x540 widget tests cover the layout.
- The phone app and `party_host`: outside this diff, read only to check the calls this job makes.

## Commit message

Review sentry1 tv-consent: 1 should, 5 could

The TV wrapper's release and environment have no test that would fail
if they were wrong: crash_setup_test only shows that startCrashReporting
returns the reporter it was given, and its no-DSN case repeats the
party_host suite. Its tearDown also leaks the platform error handler.
Smaller: one duplicate consent test, a stale home_screen comment, and a
file count in the report. The feature itself matches the brief.

## Status row

sentry1 tv-consent review: small fixes, 1 should (crash_setup_test pins none of the wrapper's values) and 5 could — open: that test, the leaked platform handler, the duplicate test, the stale comment, the report's file count.

## Delete

- none
