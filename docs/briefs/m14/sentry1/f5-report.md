## Summary

The run review's findings 2, 3 and 7 are done.

1. **The host id retry stops with its host.** `persistHostId` takes a
   `HostIdAlive isAlive` check and an optional `LogSink log`, and checks it
   before every try, so a retry still waiting when `LiveHostService.dispose`
   runs writes nothing; the last failure logs one line with no error text
   besides the crash report. `host_service.dart:125` passes `() => !_disposed`
   and `_log` (`packages/party_host/test/host_id_stopped_test.dart`).
2. **The crash-off tests pin the guard.** `crash_reports_test.dart`'s three
   "off" cases use a `RecordingReporter` that keeps every report even while
   off, instead of `FakeCrashReporter`, which drops them;
   `crash_off_guard_test.dart` shows the drop is `CrashReports.capture`'s own.
   With the `enabled` guard deleted, those four tests failed and went green
   again once it was put back.
3. **The TV setup test pins the build.** `crash_setup_test.dart` calls
   `tvStartCrashReporting(prefs)` with no reporter, checks the result is a
   `SentryCrashReporter`, and asserts `release == appWithBuild(appVersion,
   buildNumber)` (`'0.14.0'` under test) and `environment == 'debug'`. No seam
   was needed: neither field needs Sentry initialised, and an empty DSN never
   calls `enable`.

Counts: format PASS, analyze PASS, host 584 tests PASS (580 + 4 new), tv PASS.
Red proof: `host_id_stopped_test.dart` cannot compile against the old
signature; the crash-off and TV changes are pins and pass on the code as it
was (f1/f3 already fixed what they pin).

Fixed, unverified: needs device check — a failed host id write leaving its one
line in a real host's Diagnostics export.

## Decisions

- **Check before each try, never cancel the wait.** `Future.delayed` cannot be
  cancelled, so the wait runs out and the next try does not start; no timer is
  owned by this code (guidelines §2: no timing fixes).
- **A stopped host neither logs nor reports.** The loop's check returns before
  the last-failure block, so a host that is gone leaves no line in a log it no
  longer reads.
- **`log` is `LogSink?`,** null meaning no log: every existing caller and test
  stays valid and only the host service passes its `'host'` sink.
- **`FakePrefs` moved to `test/support/fake_prefs.dart`** instead of being
  copied into the new test file; both host-id files import it.
- **One shared `RecordingReporter`** in `test/support/`, so the "keeps every
  report" property is written once and used by the changed and the new file.
- **The TV test asserts the literal `'debug'`** (flutter test runs
  `kDebugMode`) and the release through `appWithBuild`, not a literal, so the
  rule is what is pinned; under test `BUILD_NUMBER` is unset, so the expected
  value is `'0.14.0'` and the old `versionLabel` format (`'0.14.0 (dev)'`)
  would fail it.

## Files changed

The tree also holds changes I did not make: `run.log`,
`docs/design/m13-tablet-board.png`, `tv_test_app/windows/generated_*`.

- `packages/party_host/lib/src/host_id.dart` — `HostIdAlive` typedef, `isAlive`
  and `log` parameters on `loadOrMakeHostId`/`persistHostId`, the per-try
  check, and the one last-failure log line.
- `packages/party_host/lib/src/host_service.dart` — passes `() => !_disposed`
  and `_log` (line 125); 359 → 361 lines.
- `packages/party_host/test/host_id_test.dart` — `FakePrefs` moved out, import
  added.
- `packages/party_host/test/support/fake_prefs.dart` — new: the moved fake.
- `packages/party_host/test/support/recording_reporter.dart` — new: a reporter
  that keeps every report it is handed.
- `packages/party_host/test/host_id_stopped_test.dart` — new: the two retry
  tests.
- `packages/party_host/test/crash_reports_test.dart` — the three "off" cases
  use `RecordingReporter`.
- `packages/party_host/test/crash_off_guard_test.dart` — new: the two
  `CrashReports.capture` guard tests.
- `tv_test_app/test/crash_setup_test.dart` — the build's release and
  environment are asserted from the real reporter.

## Self-check (review-rules.md part A)

1. **Every host setup.** The retry and its stop live in `LiveHostService`,
   which the TV/PC app and both phone host modes run; joined phones write no id
   and an older build sends nothing new. Test:
   `host_id_stopped_test.dart` (the check is a closure, with no host-type
   branch).
2. **When kept state starts and ends.** The wait starts only after a failed
   write and ends on a successful write, after the third try, or at the check
   after dispose; nothing waits while no write is pending. Tests:
   `host_id_test.dart` "a write that fails twice then succeeds…", and
   `host_id_stopped_test.dart`.
3. **How a new state combines with the others.** It adds no pause, prompt or
   input state: it only gate-keeps a prefs write and a log line, so pause, host
   away, results and leaving are untouched. Tests: `host_id_stopped_test.dart`;
   the host suite (`live_host_service_test.dart` and the rest) is unchanged and
   green.
4. **Stay in the job's folder.** Only `allow:` files were changed (below).
5. **Stop rather than overstep.** Nothing needed outside `allow:`, and no
   brief/code contradiction was found, so nothing was stopped.

## Computed values

- `host_id_stopped_test.dart` case 1: `prefs.writes == 1`, `waits ==
  [hostIdRetryDelay]` (1 s), `saved` empty, no report, no log line.
- Case 2: `prefs.writes == 3` (`hostIdWriteTries`), exactly 1 log line, not
  containing `'The disk is full'`, and 1 report with `where ==
  hostIdWriteWhere`.
- `crash_reports_test.dart` + `crash_off_guard_test.dart`:
  `crash_reports_test` 15 tests, `crash_off_guard_test` 2.
- TV release: `appWithBuild('0.14.0', 'dev')` → `'0.14.0'` (the build-count
  regexp rejects `dev`); environment `'debug'`.
- Host suite: 584 tests (review's last figure 580, +2 host-id, +2 crash-off).
- `tools/review.sh`: 0 fail, 1 note — `host_service.dart` 361 lines (aim 300,
  limit 400), a size it already had before this job.

## Questions

1. Should the last failure still be reported through `CrashReports` after the
   host is gone, or is leaving it silent (as built) right?
2. Should the log line say what a parent loses ("phones will need pairing
   again next time") rather than the try count?
3. The crash-off and TV tests pass on the code as it was (the fixes landed in
   f1/f3): is a pin acceptable to the runner's red-first rule here? Also noted
   in the review: the `host_id_write` tag rename (open question 8) is not in
   this brief.

## Hand-over

- Findings 2, 3 and 7 are done; nothing under `allow:` is left half-changed.
- `host_id.dart` keeps its retry constants and `host_id_write` tag unchanged;
  only the signature and the last-failure lines moved.
- For a device pass: one host with a store that refuses the write, and the
  Diagnostics export's one line.

## Commit message

sentry f5: host id retry stops with its host; off tests pin guard

persistHostId takes a liveness check and a LogSink: a retry still waiting when
the host service is disposed writes nothing, and the last failure leaves one
line without error text besides the crash report. host_service passes both.
crash_reports_test's off cases now use a recording reporter that keeps reports
even while off, so removing CrashReports.capture's enabled check fails four
tests, and a new file shows the same. The TV setup test starts the real
SentryCrashReporter and pins release 0.14.0 (name+build) and environment debug.

## Status row

sentry f5: the host id retry stops at dispose and logs its last failure; the crash-off tests keep `CrashReports.capture`'s enabled check; the TV setup test pins its release and environment; open: a device check of the log line, and the review's findings 1, 4, 5 and 6.

## Delete

- none
