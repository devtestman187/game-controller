# sentry1 phone consent: the two questions, Sentry at startup, the answer to hosts

## Summary

The phone asks its own two consent questions on a launch (crash first, then stats),
starts Sentry from `main()` when the build has a DSN, carries an older `shareStats`
answer over to `statsConsent`, and tells hosts its stats answer at start and on change.

- `lib/src/host/phone_host_setup.dart`: `sentryDsn` from `--dart-define=SENTRY_DSN`.
- `lib/src/consent_migration.dart` (new): `migrateLegacyStats(prefs)` copies an
  explicit legacy `shareStats` into `statsConsent` only when that is absent.
- `lib/main.dart`: the migration, `startCrashReporting` (release
  `appWithBuild(appVersion, buildNumber)`, environment debug/production), and the
  overrides for `crashAvailableProvider`, `crashReporterProvider`,
  `launchConsentAskProvider` and `party.prefsProvider` (moved here, see Decisions).
- `lib/src/providers/consent.dart` (new): `shareStatsProvider` is read-only now,
  `consentProvider.stats == true`; the launch ask's two providers.
- `lib/src/providers/metrics.dart`: metrics off until stats = yes; `_tellStatsShare`
  tells the client the answer at start and on every change.
- `lib/src/ui/connect_screen.dart`: asks on its first frame, once, never while hosting.
- `lib/src/ui/settings_screen.dart`: the stats switch writes `consentProvider.setStats`;
  a "Crash reports" switch (`settingsCrashReports`) only when `crashAvailableProvider`.
- Tests: 4 new files (16 tests) and the pins the change moved (see Tests).

Test counts: `tools/check.sh phone` → 521 tests, 0 failed (505 before + 16 new).
`tools/check.sh format analyze phone` → all three PASS. `tools/review.sh` → 0 FAIL,
4 NOTE (file and function sizes).

Fixed, unverified: needs device check — Sentry really sending a report from a DSN
build, the prompts' look on a real launch, and the migration on a phone that still
holds the old `shareStats` pref.

## Decisions

- **The launch ask is off unless `main()` ran** (`launchConsentAskProvider`): a
  widget test that mounts `ControllerApp` is not a launch. Without it every test that
  starts on the connect screen (about 60) would get a modal prompt; with it the new
  launch tests turn it on explicitly. Same reason `party.prefsProvider` moved to
  `main()`: consent needs the app's prefs, not only a host's.
- **"Once a launch" is a provider, not the answer** (`launchConsentAskedProvider`): a
  dismissed prompt must not come back every time Connect is opened again.
- **The crash switch works live**, so `main()` also provides `crashReporterProvider`
  with the reporter `startCrashReporting` returns (the brief named only the
  availability override; without it the switch would move a no-op reporter).
- **Release is `appWithBuild(appVersion, buildNumber)`** ("0.14.0+654", "0.14.0" for a
  dev build), the version the stats record; `versionLabel`'s "(dev)" is a label, not a release.
- **Stats answer sent from `phoneMetricsProvider`**, as the brief offered: it is alive
  from the controller screen, and it already owns the client for metrics.
- **Sentry's words for the crash row live in the app** (`_crashReports`,
  `_crashReportsLine`), because `SettingsText`/`ConsentText` have no switch text and
  `party_host` is outside this job; the wording follows `site/privacy.html`. Logged in
  `docs/code-health.md`.

## Blocked

Nothing blocked the job.

## Tests

New (each fails on the old code: they use providers, keys and the migration that did
not exist, and the old default was "share"):

- `test/consent_migration_test.dart` (5): absent / false / true / already answered /
  second launch.
- `test/launch_consent_test.dart` (4): stats only with no DSN; crash then stats with a
  DSN; asked once; a test that mounts the app starts past it.
- `test/settings_consent_test.dart` (3): the stats switch (off, then on, saved); no
  crash row without a DSN; the crash switch records and enables/disables the reporter.
- `test/stats_share_to_host_test.dart` (4): yes at start; unanswered sends false and
  records nothing; a Settings change reaches the client; a launch answer reaches it.

Pins moved (brief item 4):
- `phone_metrics_test.dart`: the recording tests save `statsConsent: true`, the
  "turned off" one `statsConsent: false`, and the switch test reads `statsConsent`
  (was `shareStats`).
- `support/joined.dart`: the joined view's metrics tests save `statsConsent: true`
  (the touch map's segment is the assertion).
- `support/pump_app.dart`, `hosting_test.dart`, `look_prefs_test.dart`: the
  `party.prefsProvider` override the app's root now gives (it left `phoneHostOverrides`).
- `support/fakes.dart`: `FakeClient.statsShares` records every answer, so a test can
  see what the app told the TV.
- `coverage_all_test.dart`: the two new lib files' imports, as the generator would add.

Computed values I asserted: no timeouts or sleeps; the only numbers are the prompt
keys (`consentDialog`, `crashConsentDialog`, `crashYes`, `crashNo`), the switch keys,
and prefs keys `statsConsent` / `crashConsent`.

## Self-check (review-rules part A)

1. **Every host setup.** TV/PC host: no file changed (not run here — the brief says no
   TV work). Phone "Play on this phone" and "Show on this device": the launch ask is
   skipped while hosting, and the host route's B-023 stats prompt still asks an
   unanswered phone — `first_host_consent_test.dart`, `settings_stats_row_test.dart`
   (both pass unchanged). Joined phone: the answer reaches the client at start and on
   change — `stats_share_to_host_test.dart`. One build older: it sends no `stats_share`,
   so its player is not shared (connection's `stats_share_test.dart`), and its own old
   answer is carried over — `consent_migration_test.dart`.
2. **When kept state starts and ends.** `crashConsent`/`statsConsent` are written by
   `consentProvider` (party_host's own tests) or, once, by the migration when the
   answer is absent; `launchConsentAskedProvider` starts false and ends true after the
   launch's questions are put — `launch_consent_test.dart` "asks once". Nothing runs
   when no prompt shows: nothing is timed here.
3. **How a new state combines with the others.** The launch prompt against a running
   game (guard on `hostingProvider.live`) and against the host route's B-023 prompt:
   one ask per launch, and B-023 still covers an unanswered stats question —
   `launch_consent_test.dart` "asks once", `first_host_consent_test.dart`. It is a
   dialog, not a pause: it does not touch `Pausable`.
4. **Stay in the job's folder.** I wrote only inside the allow list. One exception
   happened through the check: `tools/check.sh phone` runs `site_shots_test.dart`,
   which rewrote `site/shots/dpad.png`, `menus.png`, `results.png`, `sticks.png` and
   `tilt.png` — outside `allow:`. They need `git checkout -- site/shots` (see Questions).
5. **Stop rather than overstep.** No stop was needed. Two additions beyond the literal
   brief (`crashReporterProvider` override, `party.prefsProvider` moved to `main()`) are
   in Decisions; both are needed for the feature to work, none touches code outside `allow:`.

## Questions

1. A phone that launches already paired never opens Connect, so its questions wait
   until the first time the adult opens Connect (possibly mid-game). The design puts
   the ask on the connect screen; should the controller screen ask a paired launch too?
2. `site/shots/*.png` were rewritten by the phone check's `site_shots_test`, outside
   my allow: please restore them (`git checkout -- site/shots`) or keep them on purpose.
3. The crash row's words are in the app; moving them next to `ConsentText.crashBody`
   would let the TV's Stats screen say the same (logged in code-health).
4. The sent switch's answer is recorded through `consentProvider`, so `crashAvailable`
   builds only; a build with no DSN never shows the row and never asks. Confirmed as
   the design's "crash question only when it can matter".

## Hand-over

The TV app is untouched (its `FirstLaunchConsent`, Stats screen row and `main()` still
need the sentry1 TV job). `startCrashReporting` is started only from the phone's
`main()`, so nothing in tests initialises Sentry.

## Commit message

```
phone app asks its two consent questions and tells hosts its stats answer

The connect screen asks crash reports (when the build has a DSN) and usage
stats on its first frame, once a launch and never over a running game, and
main() starts Sentry with the build's release and environment, off until
the answer is yes. shareStatsProvider now reads consentProvider.stats, so
nothing is shared before an answer; Settings writes both answers and shows
a Crash reports switch only where a report can be sent. An older build's
shareStats pref is carried over to statsConsent at startup, and the phone
tells the TV its stats answer at start and on every change (stats option B).
```

## Status row

sentry1 phone consent done: the phone asks its two questions, starts Sentry if the build has a DSN, and sends its stats answer to hosts (521 phone tests pass); open: the TV app's half (its launch ask, Stats screen crash row, main), and a device check that Sentry sends from a DSN build.

## Delete

- none
