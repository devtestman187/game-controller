## Summary

Three items, all done: the phone host's lobby names are now pinned by a widget test under a real
host, `hosting.dart` puts the host in the state before the game-shown flag, and
`crashNamesProvider` clears `CrashReports.playerNames` when its container goes.

- **controller_app/test/crash_names_host_test.dart** (new, 1 test): hosts on this phone as "Show
  on this device", joins a phone called Sam over the host's own link, and reads
  `CrashReports.playerNames` directly: empty at first, `{'Sam'}` once Sam joins (and
  `scrubText` turns "Sam" into `[name]`), empty again when Sam leaves. No fake reporter; the
  static is reset in `tearDown`. This file passes on the old code: it is the coverage the review
  asked for, not a bug's repro (see Decisions 3).
- **controller_app/lib/src/host/hosting.dart**: `state = host` moved above
  `gameShownProvider.set(true)` in `start()`, with the reason in a comment. Nothing else moved.
- **controller_app/test/hosting_state_order_test.dart** (new, 1 test): a probe override of
  `gameShownProvider` reads `phoneCrashLobbyProvider` inside the flag's own change — the gap — and
  finds the host. Red on the old order: "Bad state: No host is running in this app".
- **packages/party_host/lib/src/crash/crash_names.dart**: `ref.onDispose` clears the names, plus
  the doc comment says so.
- **packages/party_host/test/crash_names_dispose_test.dart** (new, 1 test): a disposed container
  leaves no names. Red on the old code: `Expected: empty / Actual: Set:['Sam']`.

Checks `format analyze host phone`: all PASS. host 581 tests, phone 526 tests (each suite from
`tools/check.sh`, run in this job). `tools/review.sh`: 0 fail, 0 note.

Fixed, unverified: needs device check — nothing in these three items shows only on a device; the
Sentry scrub end to end (a real DSN build with consent on) is still unverified, as it was in f1.

## What changed, file by file

1. `controller_app/lib/src/host/hosting.dart` — `start()` now does `state = host;` before
   `ref.read(gameShownProvider.notifier).set(true);`. The flag is what `phoneCrashLobbyProvider`
   hangs off, and its read goes through `gamePlayersProvider` → `hostServiceProvider` →
   `phoneServiceProvider`, which throws while `hostingProvider` is null. The comment says why.
   Same for both modes: `start()` is one path, `playsHere` only decides the own player.
2. `packages/party_host/lib/src/crash/crash_names.dart` — `crashNamesProvider` gained
   `ref.onDispose(() => CrashReports.playerNames = const {})`; the doc comment records that a
   container that goes leaves no name behind.
3. Three new test files, one test each (above).

No other file touched. Files stay small: hosting.dart 118 lines, crash_names.dart 34,
crash_names_host_test.dart 66, hosting_state_order_test.dart 83, crash_names_dispose_test.dart 29.

## Computed test values

- `crash_names_host_test`: lobby empty → `CrashReports.playerNames` `{}`; after
  `joinPhone(tester, host, 'Sam')` (identity name `Sam`, so `nicknameOf` → `Sam`) →
  `{'Sam'}` and `scrubText('Sam could not pair', {'Sam'})` = `'[name] could not pair'`; after the
  phone's socket closes and the host drops it → `{}` and `'Sam could not pair'` plain again.
  The waits are `until(...)` on the names themselves, not a fixed number of pumps.
- `hosting_state_order_test`: `start(playsHere: false)` → the flag's reader sees `[]` (no phone
  has joined), `container.read(phoneServiceProvider)` is `same(host.service)`,
  `hostingProvider` is `same(host)`; `stop()` leaves `host.live == false`.
- `crash_names_dispose_test`: lobby `[GamePlayer(id: 'p1', number: 1, nickname: 'Sam')]` → names
  `{'Sam'}` while listening; after `container.dispose()` → `{}`.
- Suites as `tools/check.sh` printed them: host 581 passed, phone 526 passed.

## Red-first evidence (run in this job, on the code as it was)

- `flutter test test/crash_names_dispose_test.dart` (old crash_names.dart):
  `Expected: empty / Actual: Set:['Sam']` at the dispose assertion.
- `flutter test test/hosting_state_order_test.dart` (old hosting.dart order): `ProviderException:
  Tried to use a provider that is in error state. / A provider threw the following exception:
  Bad state: No host is running in this app`, from `phoneServiceProvider` (hosting.dart:116 then)
  called under `HostingNotifier.start` (hosting.dart:40 then). After the fix: passes.
- `flutter test test/crash_names_host_test.dart` on the old code: **passed**. It is the review's
  "should" (no test drove the lobby provider under a real host), so there is no old bug for it to
  catch. See Decisions 3.

## Decisions

1. The order test reads through a probe that overrides `gameShownProvider`, not a plain
   `container.listen`: with riverpod 3.4.3 the listener is notified after `start()` has returned
   (measured: it never fired inside the gap), so no ordinary listener can read in between.
2. The probe reads `phoneCrashLobbyProvider` through the container, not the notifier's own `ref`:
   the notifier's `ref` refuses a provider that depends on the flag ("CircularDependencyError"),
   which is a Riverpod rule, not the bug. The container read is the same synchronous moment.
3. `crash_names_host_test` is green on the old code and stays: the review asked for coverage of
   `phoneCrashLobbyProvider` under a real host, and the widget path never hits the order gap (the
   names are recomputed in a later frame, when the host is in the state by then). Reported rather
   than dressed up as red-first.
4. That test hosts as "Show on this device": the host pairs no own player there, so every name in
   the lobby is the joined phone's — the exact case the review wanted pinned.
5. `crash_names_dispose_test` sets `CrashReports.use(const NoopCrashReporter())` in `tearDown`
   beside clearing the names, as `crash_names_test.dart` does, so no report goes anywhere from it.
6. No device-only behaviour was found, so the "Fixed, unverified: needs device check" line is
   limited to the end-to-end Sentry send, which this job does not touch.

## Self-check (review-rules.md part A)

1. **Every host setup** — TV/PC host: unchanged; the shared `crash_names_test.dart` (fake host, the
   TV's wiring) still passes. Phone "Show on this device": `crash_names_host_test.dart`. Phone
   "Play on this phone": the same `start()` path (`hosting_state_order_test.dart` calls it with
   `playsHere: false`; `hosting_test.dart` covers `true`) and the whole phone suite passes. Joined
   phone: it is the player in `crash_names_host_test.dart`. One build older: no protocol or wire
   change at all.
2. **When kept state starts and ends** — `CrashReports.playerNames` starts at the lobby's names
   once the host runs, and ends three ways: the last player leaves (`crash_names_host_test.dart`),
   the host stops (the flag clears, `phoneCrashLobbyProvider` returns null), and the container is
   disposed (`crash_names_dispose_test.dart`). With nothing going on it is empty, not stale.
3. **How it combines with other states** — no new state; the change is an ordering inside
   `start()`. Pause, away, "Get ready", a dropped link and the results do not read `hostingProvider`
   during the start. Pairs that can happen together: the flag on with the host just built
   (`hosting_state_order_test.dart`) and the flag off with the host stopped (`hosting_test.dart`
   stops and restarts). Exactly one owner for each state is unchanged.
4. **Only the job's folder** — changes: `controller_app/lib/src/host/hosting.dart`,
   `packages/party_host/lib/src/crash/crash_names.dart`, three new test files under
   `controller_app/test/` and `packages/party_host/test/`, and this report. All inside `allow:`.
5. **Stop rather than overstep** — nothing needed outside `allow:` and nothing was stopped. The
   brief's `read:` names `docs/briefs/m14/sentry1/REVIEW.md`, which does not exist: finding 8 of
   the latest review (`REVIEW-r2.md`) and the could on hosting.dart:40 both match the brief, so
   that is the one I read. No action taken on it.

## Hand-over

- The order fix is one statement moved; if the flag's set ever needs to go earlier again, the
  lobby's read must be guarded instead (the review's other suggestion).
- `crash_names_host_test.dart` is the place to add cases for a name that is blank or longer than
  `maxNicknameLength` if the reviewer wants those pinned through a real host.
- The probe in `hosting_state_order_test.dart` is the pattern to reuse wherever a provider must be
  read synchronously at a state change under riverpod 3.4.3.

## Commit message

sentry1 f6: lobby names under a real phone host, host set first

The phone's crash lobby names now have a widget test with a real host: a
phone called Sam joins, the scrubber holds the name, and it leaves with him.
HostingNotifier.start puts the host in the state before the game-shown flag,
so a read in between finds the host instead of throwing "No host is running";
the new order test read that gap red on the old code. crashNamesProvider
clears CrashReports.playerNames in ref.onDispose, so a disposed container
leaves no names behind, also red on the old code. format, analyze, host (581)
and phone (526) pass.

## Status row

- **M14 sentry1 f6 (Nov 16, 2026):** done — the lobby names are pinned under a real phone host, `start()` sets the host before the flag, and a disposed container clears the names; open: the other round-2 findings (the Connect pop, the crash-off test, the host-id retry, the code-health entries).

## Delete

- none
