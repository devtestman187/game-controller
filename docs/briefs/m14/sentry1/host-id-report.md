# sentry1 host-id report

## Summary

The first run's host id write no longer fails silently (bugs15): the host id moved out of
`host_service.dart` into `packages/party_host/lib/src/host_id.dart`.

- `loadOrMakeHostId(prefs, random)` returns the saved id, or makes a fresh 16-byte id and starts
  saving it with `CrashReports.guard(..., where: 'host_id_write')`; it returns at once.
- `persistHostId(prefs, id)` tries `prefs.setString` 3× (`hostIdWriteTries`), 1 s apart; a false
  answer and a thrown error both fail a try; after the last one it calls `CrashReports.capture`
  with `where: 'host_id_write'` and returns, so it never throws and the id stays in memory.
- `host_service.dart` now calls it, lost `_hostIdKey`/`_randomHex`, and is 359 lines (was 370).
- `docs/code-health.md`: the `host_service.dart:125` bullet is gone; both size mentions say 359.
- New `packages/party_host/test/host_id_test.dart`: 6 tests.

Ran here: host_id_test 6/6 (it fails to load on the old code: "Method not found:
'loadOrMakeHostId'"); `tools/check.sh format analyze host` PASS/PASS/PASS, host 545 tests;
`controller_app/test/hosting_test.dart` 3/3; `tools/review.sh` 0 fail, 1 note (size).

Fixed, unverified: needs device check — a real first launch whose preferences write is refused.

Decisions (low-usage mode, why one line each):
1. `prefs` stays `SharedPreferences` (brief); the test hand-writes `FakePrefs`, the only way to fail a write.
2. `HostIdWait` is injectable in `persistHostId` (brief) and `loadOrMakeHostId`, so no test waits a real second.
3. A false answer reports a fresh `StateError`; a thrown write keeps its own stack.
4. `persistHostId` reports and also runs under `CrashReports.guard` (both in the brief).
5. Key, size, tries, delay and tag are named constants; `host_id.dart` is not exported.

## Files changed

- `packages/party_host/lib/src/host_id.dart` (new, 83 lines): the constants above, the
  `HostIdWait` typedef, `loadOrMakeHostId`, `persistHostId`, and the private `_waitOneRetry` and
  `_randomHex` moved from `host_service.dart` (the hex writer now takes the `Random`).
- `packages/party_host/lib/src/host_service.dart` (359 lines): imports `host_id.dart`, the
  constructor body is `final id = loadOrMakeHostId(prefs, Random.secure());`; `_hostIdKey` and
  `_randomHex` removed. Nothing else touched.
- `packages/party_host/test/host_id_test.dart` (new, 169 lines): 6 tests and `FakePrefs`.
- `docs/code-health.md`: `host_service.dart:125` bullet removed; the M14 stats2 size row (369 → 359,
  "back under the 360 budget"), the 1107f Sizes row (361 → 359), and the "Host writes" row's
  parenthetical (the host id is no longer an uncaught save).

## Tests and values computed for them

`FakePrefs(failures: n, throwsOnWrite: ...)` fails the first `n` `setString` calls (by answering
false, or by throwing `StateError('The disk is full')`), saves after that, and counts every try.

1. "a write that fails twice then succeeds is saved on the third try": failures 2 → writes 3,
   `saved['hostId'] == 'host-id-1'`, waits `[hostIdRetryDelay, hostIdRetryDelay]` (2 waits = tries
   - 1, each 1 s), captures 0.
2. "a thrown error counts as a failed try and the next one saves" (extra): failures 1, throwing →
   writes 2, saved, captures 0.
3. "a write that always fails reports once and the host keeps its new id": failures 3, false →
   writes 3, `saved` empty, id returned by `loadOrMakeHostId` matches `^[0-9a-f]{32}$` (16 bytes ×
   2 hex digits), captures 1 with `where == 'host_id_write'` and a `StateError`.
4. "a write that keeps throwing reports the thrown error once" (extra): failures 3, throwing →
   writes 3, captures 1, error `StateError`, stack not null.
5. "a saved id is reused and never rewritten": `saved['hostId'] = 'saved-host-id'` → returned id
   is `'saved-host-id'`, writes 0.
6. "no write happens when an id exists": same setup → writes 0, captures 0.

Every awaited side effect (the write future, via `pumpEventQueue()` where `loadOrMakeHostId` owns
it) finishes inside the test; no test waits a real second.

## Self-check (docs/review-rules.md part A, items 1-5)

1. **Every host setup.** Not affected, one shared path: TV/PC, phone "Play on this phone" and
   "Show on this device" all build `LiveHostService`, which still reads/makes the same id and the
   same key; a joined phone only sees the id in the TXT record. Shown by
   `test/live_host_service_test.dart` (advertising keeps the id) and `controller_app/test/hosting_test.dart`.
2. **When kept state starts and ends.** The id lives as long as the process (as before). The write
   is a fire-and-forget future that ends on the first success or after 3 tries and 2 waits (~2 s)
   and leaves no timer or subscription. Test 3/4: the write ends in 3 tries and a single report.
3. **How a new state combines with the others.** Not affected: nothing pauses, hides or blocks
   input; the constructor still returns immediately and the host starts with the id. Test 5/6: an
   existing id takes no wait and no report.
4. **Stay in the job's folder.** Only allow-listed files changed: `host_id.dart`,
   `host_service.dart`, `test/host_id_test.dart`, `docs/code-health.md`, this report.
5. **Stop rather than overstep.** Not needed: no file outside `allow:` and the brief fitted the
   code; `tools/check.sh` and `tools/review.sh` pass.

## Hand-over

- The id is still in memory only until a try succeeds; the job reports the failure, it does not
  retry later in the session (a failed first launch still loses pairings on the next launch). If
  the owner wants a retry on `resume()` or on the next pairing, that is a new job.
- The report goes through `CrashReports`, so it is sent only when the crash answer is yes
  (design sentry-consent.md); with reports off the failure is still silent, as the design says.
- The extra two tests (thrown error on a try; every try throwing) exist because both branches of
  the failure rule are in the code; the brief named four cases.
- `tools/review.sh` leaves one note: `host_service.dart` is 359 lines (lib limit 400, aim 300).

## Commit message

Report a failed first-run host id write instead of losing pairings

Move the host id out of host_service.dart into host_id.dart.
loadOrMakeHostId returns the saved id or a new one and saves it in the background.
persistHostId tries setString three times, 1 s apart, counts a false answer and
a thrown error as failures, and reports the last one through CrashReports with
where 'host_id_write'; it never throws, so the host runs with the id it has.
Tests cover retry-then-save, always failing, a thrown write and reuse.
host_service.dart is 359 lines; code-health drops the host id bullet.

## Status row

- **sentry1 host-id (Nov 16, 2026, unpushed):** the first run's host id write retries 3× 1 s apart and reports a lasting failure via `CrashReports` (`where: 'host_id_write'`) from `host_id.dart`; 6 tests in `host_id_test.dart`, host 545, controller_app hosting 3; `host_service.dart` 359 lines; mine to verify on a device: a real first launch whose preferences write fails. Open: no later retry in the session.

## Delete

- none
