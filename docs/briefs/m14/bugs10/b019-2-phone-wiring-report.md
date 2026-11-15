# b019-2 phone wiring: the phone host's stats follow the app lifecycle

## Summary

Phase 2 of B-019: the phone app's host ends its stats session when the app goes
to the background and retries the upload queue when it comes back.

- `PhoneHost`'s one `AppLifecycleListener` now also has `onPause`/`onResume`,
  which call `stats.pause()` / `stats.resume()` unawaited; a failure is logged
  through the host's `LogSink` and never thrown (the framework's callbacks must
  not throw). Both are disposed with the listener in `dispose()`.
- `PhoneHost.live` takes an optional `stats` (like `nowMs`): the host service
  builds its own `LiveStats`, so a test cannot put a fake inside it.
- New `test/phone_host_stats_lifecycle_test.dart`, cases (a) to (e), with
  `party_test.FakeStats`'s `pauses`/`resumes` counters.

Tests: on the old code the new file failed to load (`No named parameter with
the name 'stats'`, line 106) and the other 468 phone tests passed. After the
change `tools/check.sh format analyze phone` passes: 473 phone tests (468 + 5
new), format and analyze clean. `tools/review.sh`: 0 fail, 0 note.

Computed values the tests assert: background → `pauses` 1, `resumes` 0; return
→ `resumes` 1, `pauses` 1; inactive + hidden alone → `pauses` 0, `resumes` 0
and `host.away.value` true; after `dispose` → 0 and 0; the presence case goes
`away` false → true → false and keeps the same host.

Decisions:
1. The fake goes in through a new optional `stats` on `PhoneHost.live` (the
   `nowMs` pattern): `LiveHostService` builds its `LiveStats` privately, so the
   real service cannot carry a fake. The app passes nothing and the service's
   own stats are used, so shipped behaviour is unchanged.
2. The log and the stats travel as one positional record `_AppServices`
   through the private constructor: it adds one parameter, not two, and a bare
   `_stats = stats` named initializer would trip `prefer_initializing_formals`,
   which cannot be satisfied for a private name.
3. `onPause`/`onResume`, not `onHide`/`onShow`: iOS reports inactive and
   hidden for a phone call or the app switcher, and only `paused` means the
   timers stop; only `resumed` means the queue can be retried.
4. The tests move the lifecycle in the sequence the app sees (inactive, hidden,
   paused; hidden, inactive, resumed), as `host_lifecycle_test.dart` does.

Fixed, unverified: needs device check (background the app on an iPhone host,
reopen, see the session uploaded).

## Self-check (review-rules part A)

1. **Every host setup.** The TV, PC and a joined phone never build a
   `PhoneHost`, so they are untouched; both phone host modes ("Play on this
   phone" and "Show on this device") get the same listener. Test (e).
2. **When kept state starts and ends.** A session still starts on the first
   presence and ends on the gap, `pause()` or `dispose()`; the phone now ends
   it on `paused`, and after a resume the next presence starts a new one
   (phase 1's `live_stats_lifecycle_test.dart` case (c)). Tests (a), (b), (e).
3. **How a new state combines with the others.** Pause and resume are the app
   lifecycle's, not the round's: the pause menu, host away, the grace period
   and "Get ready" are only driven by `onHide`/`onShow` as before. Test (c)
   (hidden alone pauses the round, ends no session) and test (e).
4. **Stay in the job's folder.** `controller_app/lib/src/host/phone_host.dart`,
   `controller_app/test/phone_host_stats_lifecycle_test.dart` and this report.
5. **Stop rather than overstep.** Not needed; nothing outside `allow:` was
   required.

## Hand-over

- `PhoneHost` drives `StatsService.pause()`/`resume()` from `onPause`/`onResume`
  of its one `AppLifecycleListener`; `dispose()` already disposes that listener,
  so a stopped host calls neither.
- `PhoneHost.live(inputs, playsHere:, nowMs:, stats:)`: `stats` is the test
  seam; `_AppServices` carries the log sink and the stats the callbacks use.
- `phone_host.dart` is 218 lines; the new test file 125.

Open: the device check above; nothing else.

## Commit message

Phone host: the stats session follows the app lifecycle (B-019)

iOS stops the host's timers in the background, so the running session waited
on disk until the next start. The phone host's lifecycle listener now ends the
session on paused and retries the upload queue on resumed; hidden and inactive
alone (a phone call, the app switcher) do neither, so the round's presence
behaviour is unchanged. Failures are logged through the host's log, never
thrown from a framework callback. PhoneHost.live takes an optional stats so a
test can count the calls, and the new phone_host_stats_lifecycle_test covers
the background, the return, hidden alone, a stopped host and the presence.

## Status row

B-019 done: the phone host ends its stats session when the app is paused and retries the queue on resume (`test/phone_host_stats_lifecycle_test.dart`); open: a device check on an iPhone host.

## Delete

- none
