job: M16 bugs2 flk1 — live_stats_unmarked_test: wait for the settled state, not for the first event
tests-first: exempt flaky-test repair: no new test fits; the driver proves it by repeated runs under load
stop: after it. Do not change lib code or what the test asserts.
read: docs/briefs/templates/COMMON.md · packages/party_host/test/live_stats_unmarked_test.dart:1-end · packages/party_host/lib/src/live_stats.dart:159-166 and 306-358 (start, uploadNow, _refreshCounts) · packages/party_host/test/stats_test_support.dart
changes: none-new: waitFor timeout in live_stats_unmarked_test.dart
turns: 35
expected-min: 20
do:
1 Cause (driver diagnosis): the test waits for uploader.uploaded to be non-empty, then for skippedSessions to hold the unmarked id. Files come in any order: if the unmarked file is skipped first, both waits pass while the marked upload is still in flight, before prefs 'uploadedSessions' is written and before the pass's final _refreshCounts. The asserts then see a half-finished pass (uploadedSessions null, waiting 1, saved/uploaded stale). Under CPU load the gap is long enough to fail.
2 Fix: in the test, replace the two waitFor calls by waiting for the finished pass: stats.state.uploaded == 1 && stats.state.waiting == 0 and skippedSessions containing the unmarked id (all inside waitFor). Keep every expect as it is. Raise waitFor's default timeout to 30 seconds (it only bounds a failure). No fixed sleeps.
3 Run flutter test packages/party_host/test/live_stats_unmarked_test.dart 5 times (separate runs) and report the pass count.
allow: packages/party_host/test/live_stats_unmarked_test.dart · docs/briefs/m16/bugs2/flk1-report.md
check: format
report: docs/briefs/m16/bugs2/flk1-report.md
