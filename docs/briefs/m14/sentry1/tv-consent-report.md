# sentry1 tv-consent: the TV and Windows app asks its two questions and starts Sentry

## Summary

The TV/Windows shell starts crash reporting at startup and asks its two consent questions on
first launch: crash reports first (only with a DSN), then stats, each only while unanswered.

- `tv_host_setup.dart`: `const sentryDsn = String.fromEnvironment('SENTRY_DSN')` (empty in
  local builds and tests, no value in the repo) and `tvStartCrashReporting(prefs, {reporter})`,
  which calls `startCrashReporting` with that DSN, `release: versionLabel` from `app_info.dart`
  and `environment: kDebugMode ? 'debug' : 'production'`.
- `main.dart`: `await tvStartCrashReporting(prefs)` before `runApp`; overrides
  `crashAvailableProvider` with `sentryDsn.isNotEmpty` and `crashReporterProvider` with the
  returned reporter, so a later answer turns reports on and off live. The rest is unchanged.
- `first_launch_consent.dart`: reads `consentProvider` (prefs) instead of `statsStateProvider`
  and calls `askConsents`: crash first only where available, then stats, each only while
  unanswered. Still takes no space, still asked once per launch.
- `test/support/pump_app.dart`: `consent` now seeds the kept `statsConsent`, and the optional
  `keptPrefs` and `crashAvailable` keep every existing test on the single stats question.
- New `test/first_launch_consent_test.dart` (6 tests) and `test/crash_setup_test.dart` (2).

Counts: the tv suite ran 62 passed, 1 skipped (`tv_host_setup_test`'s platform case); the 8 new
tests are part of that 62.

Fixed, unverified: needs device check — Sentry starting under a real `SENTRY_DSN`, and the
crash question appearing on the TV and Windows builds.

Decisions: the setup is `tvStartCrashReporting` in `tv_host_setup.dart` (main() cannot be called
in a test); environment and release come from `kDebugMode` and `versionLabel`, as the design
says; `FirstLaunchConsent` reads the consent notifier, the answers' owner, not LiveStats; the
test's crash reporter is local because `party_host/testing.dart` exports no crash fake.

## Tests (new files, and why each would fail on the old code)

Both new files use API that only exists after this change (`pumpApp`'s `crashAvailable` and
`keptPrefs`, and `tvStartCrashReporting`), so on the old code they fail to compile; the
behavioural ones also fail on it, because the old `FirstLaunchConsent` never asked about crash
reports and read a different source for the stats answer.

`tv_test_app/test/first_launch_consent_test.dart`
1. a build with no DSN asks only about sharing stats — stats dialog shown, no crash dialog,
   remote OK answers "Don't share": `fake.stats.consents == [false]`, `statsConsent == false`,
   `crashConsent == null`.
2. a build with a DSN asks about crash reports first, then stats, and the remote answers both —
   crash dialog only at first; after remote OK: stats dialog only; after a second remote OK:
   `crashConsent == false` and `statsConsent == false`.
3. the back button closes either question unanswered and the next one follows —
   `tester.binding.handlePopRoute()` twice: the crash dialog goes and the stats one appears, then
   both gone, `crashConsent == null`, `statsConsent == null`, `fake.stats.consents` empty.
4. an answered question is not asked again on the next launch — answers crash no and stats yes,
   keeps the prefs it wrote (`crashConsent == false`, `statsConsent == true`), unmounts the app
   and mounts it again with those prefs (`keptPrefs`): no dialog at all.
5. with crash reports answered no and sharing yes, nothing prompts — `keptPrefs`
   `{crashConsent: false, statsConsent: true}`, no dialog.
6. with only crash reports answered, only the sharing question is asked — `keptPrefs`
   `{crashConsent: false}`, stats dialog only.

`tv_test_app/test/crash_setup_test.dart`
1. the app starts crash reporting with the reporter its build made — `tvStartCrashReporting`
   returns the reporter passed in, and `CrashReports.capture(...)` (after `enable()`) reaches it
   with `where == 'tvSetup'`, so it is the app's reporter from startup.
2. a build with no DSN sends nothing even after a yes — `crashConsent: true` kept, then the setup
   leaves `enableCount == 0` and `enabled == false`.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** Only the TV/Windows shell changed; the phone apps and `party_host` are
   untouched, and a TV build with no DSN (dev, local, old build) asks the stats question only,
   exactly as before — first_launch_consent_test #1.
2. **When kept state starts and ends.** `crashConsent`/`statsConsent` start as "not asked"
   (absent), are written the moment each answer is given (also from settings later), and have no
   timer: an answer lasts until it is changed. A launch with nothing to ask schedules nothing —
   first_launch_consent_test #4, #5, #6.
3. **How a new state combines with the others.** The two questions are modal routes, one at a
   time, crash first; back closes one unanswered and the other follows; nothing else in the app
   is blocked once they are gone — first_launch_consent_test #2, #3.
4. **Stay in the job's folder.** Changed files: `tv_test_app/lib/...` (3), `tv_test_app/test/...`
   (4) and this report; no `party_host` file, no build or secret file.
5. **Stop rather than overstep.** Nothing needed outside `allow:`; the brief fits the code as
   written, so no block.

## Hand-over

Done: the TV/Windows app starts its build's crash reporter and asks crash reports then stats on
first launch, each once, only while unanswered and only where it can act.

Open (other jobs / decisions): the Stats screen's crash toggle, the phone app's own questions,
the real-DSN device check above.

Computed values: `release` is `versionLabel` = `'0.14.0 (dev)'` on a local build; `environment`
is `'debug'` under `kDebugMode`; `sentryDsn` is `''` without `--dart-define`, so
`crashAvailableProvider` is false there and no crash question is asked.

Questions:
1. Is a `--dart-define=SENTRY_DSN` build tested on the TV at the end of this batch, or does the
   milestone's device check cover it?

Suggestions:
1. Export `src/testing/fake_crash.dart` from `packages/party_host/lib/testing.dart` (a different
   job), so this test can use `FakeCrashReporter` instead of its local `_TestCrashReporter`.

## Commit message

TV asks its two consent questions and starts Sentry

The TV/Windows shell starts crash reporting before the first screen, through
the reporter its build made, and asks crash reports then usage stats on its
first launch: each only while unanswered, and the crash question only in a
build with a DSN. main() provides that reporter so a later answer turns it on
or off live. The test app now seeds its kept answers from the prefs the app
reads, so the existing single-question tests keep their pins and the new ones
pin the crash-first order.

## Status row

TV/Windows: asks its two consent questions (crash first, only with a DSN) and starts Sentry before runApp — done; Stats-screen crash toggle and the real-DSN device check — open.

## Delete

- none
