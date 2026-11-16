# sentry-core review

## Summary

`small fixes` — 0 must, 3 should, 4 could.
The Flutter error handler stops presenting framework errors when there was no previous handler, so with
reports off every uncaught Flutter error after startup is silently dropped and no test covers that case.
An `enable()` throw escapes into app startup, the one place crash reporting must not break.
The commit also adds stats-optb's test file, which the report's file list and self-check 4 do not mention.
I re-ran the two new test files: 24/24 pass; the runner logged both failing on the old code (run.log:12-13);
the new files are format-clean and `flutter analyze` in party_host reports no issues.

## Findings

- **should** packages/party_host/lib/src/crash/crash_start.dart:28 the handler calls `previousFlutterError?.call(details)` only, and with Flutter's default `FlutterError.onError == null` the error is no longer presented by `FlutterError.presentError`, so a build with consent off loses every uncaught framework error from the console; the test "the Flutter handler reports the error and still calls the one before it" always installs a previous handler, so nothing catches this → call `(previousFlutterError ?? FlutterError.presentError)(details)` and add a test with `FlutterError.onError = null`.
- **should** packages/party_host/lib/src/crash/crash_start.dart:54 `await chosen.enable()` is unguarded on the app's startup path, so a throw from `SentryFlutter.init` (a bad DSN, a native/plugin failure) escapes `startCrashReporting` and can abort startup → wrap the enable in `try`/`on Object`, keep reports off and log one line without personal data, and test it with a reporter whose `enable` throws.
- **should** packages/party_host/test/live_stats_share_test.dart:1 the commit adds this 152-line test file, which belongs to the parallel stats-optb job (stats-optb-report.md:51, run.log:14), and the report's file list (line 55) and self-check 4 (line 107) do not mention it, so the sentry-core commit is not sentry-core only → leave the file with stats-optb's work and record it as such when the commit is read.
- **could** packages/party_host/lib/src/crash/scrub.dart:28 names are replaced as case-insensitive substrings, so a player called `Sam` turns "same" into "[name]e" and `Ann` turns "channel" into "ch[name]el" in messages and stack frames, making reports hard to read → match on word boundaries (`RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false)`) or say in the doc that over-replacement is intended.
- **could** packages/party_host/lib/src/crash/crash_reporter.dart:72 the `on Object` catch is empty (so are sentry_reporter.dart:80 and :91), so a reporter that always fails or a scrubber that drops every report is invisible, against guidelines §2's "log it through `LogSink`" → log a one-line failure with no error text (it may hold a name) through the package's `LogSink`.
- **could** packages/party_host/lib/src/testing/fake_crash.dart:52 `capture` records even while `enabled` is false, unlike `SentryCrashReporter.capture` (sentry_reporter.dart:62 returns early), so the fake can never show a missing enabled check in the real reporter; the class doc (line 22) presents this as intended without it being listed under Decisions → make the fake ignore captures while off (the CrashReports-level "sends nothing while reports are off" test still holds).
- **could** packages/party_host/lib/src/crash/crash_start.dart:10 `crashConsentKey` is public and exported from `party_host.dart` though only `startCrashReporting` uses it, and the next job's `consent_state.dart` defines the same `crashConsent` pref per its brief, giving one key two constants → keep it private to the crash folder or have the consent notifier use this one.

## Decisions to confirm

- Decision 1 (`SentryFlutter.init` for `Sentry.init`): the design names `Sentry.init`, and whether SentryFlutter's default integrations install their own `FlutterError.onError`/`onError` (a second report, or a handler in front of the new one) cannot be read from this repo.
- Decision 5 (drop a report or breadcrumb that cannot be scrubbed): a scrubber bug then means zero reports; the design does not say this beats a partly scrubbed report.
- Decision 6 (handlers installed on every call): a second `startCrashReporting` in one process chains handlers and one uncaught error is captured once per install; only safe if startup calls it exactly once.
- The fake export (brief item 2) is left out and the report's Blocked gives the reason: `lib/testing.dart` is outside `allow:` and guidelines §2 keeps fakes out of the main library. A later brief should add the one export line, since the apps' tests cannot reach `FakeCrashReporter` until then.

## Could not check

- The `sentry_flutter` 10.4.0 source is outside the repo (pub cache), so its integrations, whether `Sentry.close()` followed by `enable()` restarts the SDK, and the `beforeSend`/`beforeBreadcrumb` JSON round-trip (`SentryEvent.fromJson` losing fields) are unverified here.
- Nothing in this job shows that the apps call `startCrashReporting` after `WidgetsFlutterBinding.ensureInitialized()`, which `SentryFlutter.init` needs; the app wiring is a later job.
- The host suite (report says 538 tests) was not re-run; only the two new test files were.

## Commit message

Review sentry-core: 3 should, 4 could, no must findings

The Flutter error handler stops presenting errors when there was no
previous handler, and an enable() throw escapes into app startup.
The commit also carries stats-optb's live_stats_share_test.dart.
Found over-scrubbing of substrings, an unlogged swallow and a fake
that records while off; the SentryFlutter.init choice and the
drop-unscrubbable decision need the owner's look.
Tests re-run: 24/24 new tests; format and analyze pass.

## Status row

m14 sentry1 sentry-core review: done — 0 must, 3 should, 4 could on the crash reporter, scrubber, start and handlers; open: the should fixes, the fake export from lib/testing.dart, and the device-only Sentry checks.

## Delete

- none
