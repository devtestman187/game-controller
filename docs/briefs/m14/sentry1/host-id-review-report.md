# Review of sentry1 host-id

## Summary

Verdict: **small fixes** — 0 must, 2 should, 2 could.
- The change is what the brief asks: `host_id.dart` (83 lines) holds the key, tries, delay and tag; `host_service.dart:123` calls it and is 359 lines; the four required tests plus two null/false-answer extras exist in `test/host_id_test.dart`, and the runner recorded the file failing on the old code (`run.log:26`). `format`, `analyze` and `host` pass here (host 554 tests now).
- Most serious: the retry is not stopped by `LiveHostService.dispose`, so a phone that stops and restarts "Host a game" inside the ~2 s window on a store that failed once can leave the stopped session's id in prefs, and the next launch mints the other one — the pairing loss this job fixes.
- Self-check A1 cites `live_host_service_test.dart` for "advertising keeps the id", but that test only passes a literal `HostAddress.local(hostId: 'this-device')`; no test covers the `host_service.dart:123` wiring.
- Also: no `LogSink` line for the final failure (with reports off it stays invisible), and test 6 repeats test 5.

## Findings

- **should** packages/party_host/lib/src/host_id.dart:75 nothing stops the retry when the host is disposed (`host_service.dart:316`), so a phone host stopped and started again within the ~2 s window on a store whose first writes fail can have the stopped session's id written last, and the next launch then mints the live session's id differently and pairings drop again. → let the service stop a pending write on dispose (a live/cancelled check passed into `persistHostId`), or mint one id per app so every service writes the same one.
- **should** docs/briefs/m14/sentry1/host-id-report.md:71 self-check A1 says `live_host_service_test.dart` shows "advertising keeps the id", but that test only passes a literal `HostAddress.local(hostId: 'this-device')` (`live_host_service_test.dart:95`) and `controller_app/test/hosting_test.dart` never mentions the id, so no test shows that `host_service.dart:123` reuses a saved id. → add a test that a prefs-held id is what the server and the TXT record carry and cite it, or say the wiring is untested.
- **could** packages/party_host/lib/src/host_id.dart:77 the last failure goes only to `CrashReports`, so with reports off (the default until the adult says yes) the pairing loss leaves no line in the host's log. → take the service's `LogSink` into `persistHostId` and log one line on the final failure (guidelines §2: a caught error is logged).
- **could** packages/party_host/test/host_id_test.dart:78 "no write happens when an id exists" is test 5 (`:67`) on the same saved-id path, adding only `captures` empty. → fold that assertion into test 5 and drop this test, or give it a different rule.

## Decisions to confirm

- The retry is a repeat with `Future.delayed` (`host_id.dart:20`, `:80`), which guidelines §2 forbids for races; the brief and the owner's quote ask for it, so confirm it stays as written.
- The tag `'host_id_write'` (`host_id.dart:24`) is snake_case while the existing tags are camelCase (`crash_start.dart:13`, `:16`); the brief fixed the string, but Sentry filters will see two styles — pick one before more tags arrive.
- `prefs` stays `SharedPreferences`, so the failing store in tests is a hand-written `FakePrefs` implementing the whole interface (`host_id_test.dart:93`); accept that, or make a storage seam a later job.
- The id is minted per `LiveHostService` (`host_service.dart:123`), which on a phone is per "Host a game" (`controller_app/lib/src/host/hosting.dart:24`); one id per app would remove the first finding.

## Could not check

- `tools/review.sh`'s "0 fail, 1 note" in the report: I did not run it (it writes its own report).
- A real first launch whose preferences write is refused (needs a device), as the report itself says.
- The old code's failure: `run.log:26` records the runner's tests-first run; I did not re-run the tests against commit 14dc30b5.
- The report's host count is 545 and mine is 554 because the consent-model tests landed in 14dc30b5 after this job; I can't tell which count the worker saw, only that the suite passes now.

## Commit message

Review of sentry1 host-id: the retry can outlive its host (docs)

`docs/briefs/m14/sentry1/host-id-review-report.md` is the read-only review.
The brief's items are done and the four required tests exist, but the
retry in `host_id.dart:75` is not cancelled on dispose, so a stopped
phone host can write its stale id last. The self-check's A1 evidence
(`live_host_service_test.dart`) asserts nothing about the host id, the
final failure is not logged, and test 6 repeats test 5.

## Status row

review of sentry1 host-id done (small fixes: retry outlives dispose, self-check A1 cites nothing); open: the retry cancellation, a wiring test, a log line, and merging tests 5 and 6.

## Delete

- none
