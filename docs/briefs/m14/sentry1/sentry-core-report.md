# sentry1 sentry-core: report

## Summary

Built the crash reporter, the pure scrubber and the `CrashReports` helper in `party_host`, plus
the fake and two new test files. Nothing outside `packages/party_host` changed.

- `lib/src/crash/crash_reporter.dart`: `CrashReporter` (enable/disable/enabled/capture),
  `NoopCrashReporter`, and `CrashReports` with `use`, `capture`, `guard` and the `playerNames`
  setter; `capture` and `guard` never throw.
- `lib/src/crash/scrub.dart`: `scrubText` and `scrubEvent`, pure, over plain JSON-like maps.
- `lib/src/crash/sentry_reporter.dart`: `SentryCrashReporter` with the design's options (no PII,
  screenshot, view hierarchy, tracing or interaction breadcrumbs; scrubbed on the way out); an
  empty DSN makes `enable()` do nothing, and `disable()` closes Sentry.
- `lib/src/crash/crash_start.dart`: `crashConsentKey`, `installCrashHandlers()` (reports, then
  calls the handler it replaced / returns its answer, else `false`), and `startCrashReporting`
  (reporter or `SentryCrashReporter`, `CrashReports.use`, handlers, enable only for
  `crashConsent == true` and a non-empty DSN; returns the reporter in use).
- `lib/src/testing/fake_crash.dart`: `FakeCrashReporter` (records every `capture` as a
  `RecordedCrash`, enabled flag, `enableCount`/`disableCount`).
- `lib/party_host.dart`: exports the four crash files. **The fake is not exported**: `testing.dart`
  is outside `allow:` (see Blocked).
- `test/crash_scrub_test.dart` (9 tests) and `test/crash_reports_test.dart` (15 tests): 24 tests,
  all passing in this job (24/24). They import the fake by its `src/` path, being in the package.

Checks seen in this job: `tools/check.sh format analyze host` → PASS format, PASS analyze,
PASS host (538 tests, 54 s); `tools/review.sh` → 0 fail, 0 note. The new test files could not
pass before this job: they use symbols that did not exist.

Nine decisions, one line each under "Decisions". Fixed, unverified: needs device check — Sentry
initialising and sending a scrubbed report (plugin, `--dart-define` DSN and the `beforeSend` JSON
round-trip run on a device only; no test starts the real Sentry).

## Decisions

1. `SentryFlutter.init` instead of `Sentry.init`: the Flutter options carry `attachScreenshot` and
   `attachViewHierarchy`, which the design asks to turn off.
2. The fake is not exported from `party_host.dart`: coding guidelines §2 forbids exporting a fake
   from the main library, and `lib/testing.dart` (where the other fakes are) is not in `allow:`.
3. Names are replaced ignoring case and longest first, blank names ignored: a case variant would
   leak the name, and a short name first would leave part of a longer one.
4. `scrubEvent` drops `user` and `server_name` at the top, and any `ip_address` at every level
   (where a phone's address sits in breadcrumb data), and scrubs every string.
5. A report or breadcrumb that cannot be rebuilt after scrubbing is dropped, not sent as it is:
   an unscubbed report is the one failure this feature must not have.
6. `installCrashHandlers()` installs on each call and forwards to the handler it replaced then;
   startup calls it once, and the handler is process-wide as the design says.
7. `startCrashReporting` returns the reporter it started: callers get the one in use without
   reading the static.
8. Release and environment are passed in, not computed here: the design puts that in the apps'
   `crashSetup`.
9. `startCrashReporting` also skips `enable()` for a fake reporter when the DSN is empty: the
   consent-and-DSN rule is one rule, whatever reporter is passed.

## Files changed

- `packages/party_host/lib/src/crash/crash_reporter.dart` — new: interface, no-op reporter,
  `CrashReports` (use/capture/guard/playerNames).
- `packages/party_host/lib/src/crash/scrub.dart` — new: `scrubbedName`, `scrubText`,
  `scrubEvent`.
- `packages/party_host/lib/src/crash/sentry_reporter.dart` — new: `SentryCrashReporter` and its
  two scrub callbacks.
- `packages/party_host/lib/src/crash/crash_start.dart` — new: `crashConsentKey`,
  `installCrashHandlers`, `startCrashReporting`.
- `packages/party_host/lib/src/testing/fake_crash.dart` — new: `RecordedCrash`,
  `FakeCrashReporter`.
- `packages/party_host/lib/party_host.dart` — exports the four crash files.
- `packages/party_host/test/crash_scrub_test.dart` — new: 9 scrubber tests.
- `packages/party_host/test/crash_reports_test.dart` — new: 15 capture/guard/start/handler tests.

## Test values (computed)

- `scrubText('Ann won the round', {'Ann'})` → `'[name] won the round'`.
- `scrubText('ann beat Bo at puzzle', {'Ann', 'Bo'})` → `'[name] beat [name] at puzzle'`
  (case-insensitive).
- `scrubText('Anna and Ann played', {'Ann', 'Anna'})` → `'[name] and [name] played'`
  (longest first: `Anna` is replaced before `Ann`).
- `scrubText('P1 won in 3 tries', {'Ann'})` → unchanged.
- `scrubText('Ann', {'', '  ', 'Ann'})` → `'[name]'` (blank names skipped, no empty match).
- `scrubEvent` of `{message: 'boom', user: {id, username}, server_name: 'living-room-pc',
  extra: {ip_address: '192.168.1.20', note: 'kept'}}` → `{message: 'boom', extra: {note: 'kept'}}`.
- `scrubEvent` of a message, an exception value, a breadcrumb message and breadcrumb data with
  `Ann` → each `Ann` is `[name]`, `round: 2` unchanged.
- `guard` on `Future.error(e)`: one capture, `where == 'upload'`, the returned future completes.
- `guard` with reports off: zero captures, no throw.
- `startCrashReporting`: consent true + DSN → `enableCount 1`, `enabled`; consent false, no
  answer, or empty DSN → `enableCount 0`, not enabled; the started reporter gets the captures
  and the one from `setUp` gets none.
- Handlers: `where` is `flutterError` / `platformError`; the previous Flutter handler gets the
  same `FlutterErrorDetails`; the platform handler returns `true` when the previous one did, and
  `false` when there was none.
- Turning reports off again: the capture before `disable()` is kept, the one after is not
  (1 capture, `disableCount 1`).

## Self-check (review-rules part A)

1. Every host setup — not affected: the code is host-type free (TV/PC, phone host, shown on this
   device, and a joined phone all take the same path); an older build without a DSN asks nothing
   and enables nothing (`crash_reports_test`: "leaves reports off when the build has no DSN, even
   after a yes").
2. Kept state — the enabled flag starts off, turns on only through `enable()` after a yes and a
   DSN, and off through `disable()` (`Sentry.close()`); `playerNames` holds the last set given;
   the handlers last for the process. `crash_reports_test`: "stops sending when reports are turned
   off again" and the `startCrashReporting` group.
3. New state combinations — not affected: reporting pauses, hides and blocks nothing, and reads no
   round state, so the pause menu, away, "Get ready", results and leaving cannot combine with it.
4. Folder — only files in `allow:` were written (`git status`: the four crash files, the fake,
   `party_host.dart`, the two test files). `tv_test_app/windows/flutter/generated_plugin_registrant.*`
   and `generated_plugins.cmake` were rewritten by the Flutter tool's pub get (they now list
   `sentry_flutter`); no hand edit, and not in `allow:`.
5. Stop rather than overstep — one item: the fake's export belongs in `lib/testing.dart`, which is
   outside `allow:`; left out and listed under Blocked.

## Blocked

The fake export (brief item 2, "export ... the fake ... the way the other fakes are"). The other
fakes are exported from `lib/testing.dart`, and that file is not in `allow:`; exporting the fake
from `party_host.dart` instead breaks coding guidelines §2. Suggested next brief: add
`export 'src/testing/fake_crash.dart';` to `packages/party_host/lib/testing.dart`. Until then the
apps' tests cannot reach `FakeCrashReporter` (`party_host`'s own tests import it by its `src/`
path).

## Hand-over

- Next: the consent notifier (`crashConsent` key, the only writer), the question UI, the apps'
  `crashSetup` (DSN from `--dart-define`, release, environment, `crashAvailableProvider`) and
  `CrashReports.playerNames` wiring on lobby change.
- Reviewers: the `on Object` catches are the crash-reporting boundary (an error there must not
  raise a second one); `crash_reports_test` "does not throw when the reporter itself fails" and
  "the Flutter handler ... still calls the one before it" show it.
- Questions: (1) should the fake be exported from `testing.dart` (outside `allow:`)? (2) is
  dropping an unscruable report (Decision 5) what you want, or keep it and strip only the
  message? (3) should `installCrashHandlers()` be once-only per process instead of per call?

## Commit message

Add the crash reporter, scrubber and CrashReports helper to party_host

Introduce CrashReporter with a no-op default, SentryCrashReporter set up
per the sentry-consent design (no personal data, no screenshots, no
tracing, scrubbed reports) and the static CrashReports helper whose
capture and guard never throw.
Add the pure scrubber that replaces player names and drops the user,
server name and IP addresses, and startCrashReporting with the Flutter
and platform error handlers that report and then pass on.
Add FakeCrashReporter and tests for scrubbing, capture, guard, consent
and DSN gating, and handler forwarding.

## Status row

m14 sentry1 sentry-core: done — crash reporter, Sentry reporter, scrubber, crash start with the error handlers and 24 new tests; open: fake export from lib/testing.dart, consent UI, app wiring and playerNames.

## Delete

- none
