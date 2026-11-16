job: sentry1 host-id: a failed first-run host id write must not lose the phones' saved pairings (bugs15 finding)
pub: no
stop: after it. Nothing else in host_service.dart.
read: packages/party_host/lib/src/host_service.dart (constructor, the host id write around line 125; the file is 370 lines) · docs/code-health.md (the "host_service.dart:125" entry and the host_service size entry) · packages/party_host/lib/src/crash/ (CrashReports.capture, FakeCrashReporter) · packages/party_host/test host service tests (how a LiveHostService is built with fake prefs) · tests the change could break: packages/party_host/test host_service*_test.dart, controller_app/test/hosting_test.dart
decide: low-usage mode: never stop for a question. Make the safest choice that fits docs/design/sentry-consent.md and list each under "Decisions" with one line of why. Stop only if the job cannot be done; then say why under "Blocked".
Owner's decision, quoted: "failed first-run host-id write makes phones lose saved pairing (handle/retry and report via Sentry when consented)".
do:
1 Move the host id handling out of host_service.dart into a new packages/party_host/lib/src/host_id.dart (so host_service.dart shrinks): loadOrMakeHostId(prefs, random) returns the saved id or a fresh one and starts persisting it: persistHostId(prefs, id) tries setString up to 3 times (a false result or a thrown error counts as a failure; wait 1 second between tries, injectable delay for tests), keeps the id in memory meanwhile (the host runs with it as today), and after the last failure calls CrashReports.capture with where 'host_id_write'. It never throws and never blocks the constructor (fire it with CrashReports.guard).
2 host_service.dart uses it; the file ends shorter than 370 lines. Remove the "host_service.dart:125" bullet from docs/code-health.md (and update the size row if the number changes).
3 Tests (new file packages/party_host/test/host_id_test.dart): a write that fails twice then succeeds ends saved with 3 calls; a write that always fails reports once through the fake crash reporter and leaves the in-memory id usable; a saved id is reused and never rewritten; no write happens when an id exists.
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what changed, test counts you saw, decisions; state "Fixed, unverified: needs device check" for anything only a device shows. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: new tests go in NEW files (so the runner can prove they fail on the old code); await every async side effect before teardown.
rules: aim for 80-120 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was · write only inside allow: · stage nothing yourself · never use git add -A · no DSN or secret value in any file · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/sentry1/host-id-report.md · packages/party_host/lib/src/host_id.dart · packages/party_host/lib/src/host_service.dart · packages/party_host/test · docs/code-health.md
check: format analyze host
report: docs/briefs/m14/sentry1/host-id-report.md
