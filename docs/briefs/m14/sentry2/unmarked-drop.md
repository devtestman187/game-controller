job: sentry2 unmarked-drop: a saved session with no per-player `share` mark is never uploaded
pub: no
stop: after it. No other upload or consent change.
read: docs/briefs/m14/sentry1/REVIEW-r2.md (Q4) · packages/metrics/lib/src/uploadable.dart · packages/party_host/lib/src/live_stats.dart (uploadNow :~308, _refreshCounts, _uploadedIds) · tests that could break: packages/metrics/test/uploadable_old_players_test.dart (asserts the OLD behaviour: rewrite it to the new rule), uploadable_test.dart, packages/party_host/test/live_stats_test.dart, live_stats_share_test.dart, live_stats_lifecycle_test.dart, stats_test_support.dart (settleUploads) · controller_app/test/host_stats_test.dart
owner decision (quoted): "Sessions should be dropped." Sessions saved before this build have no `share` key on any player and uploaded every player. Now they are never uploaded; the local file stays for the on-device Stats screen. Sessions with share marks are unchanged.
decide: low-usage mode: never ask; list choices under "Decisions".
do:
1 metrics `uploadable.dart`: add exported `bool hasShareMarks(Map<String, Object?> summary)` (true when any player entry has a `share` key). Remove the legacy branch of `uploadableSummary` (the "no answer on any player uploads as it did then" early return); an entry without an answer now counts as no. Update the doc comment.
2 party_host `live_stats.dart`: in `uploadNow`, a pending file with `!hasShareMarks(f.summary)` is not uploaded: add its id to a new prefs list `skippedSessions` (save it) and `continue`. Pending and `_refreshCounts` waiting exclude skipped ids and unmarked files, so `waiting` is 0 for them. Do not add them to `uploadedSessions`. Local files are untouched.
3 Tests first, NEW files: `packages/metrics/test/uploadable_unmarked_test.dart` (hasShareMarks false for no-mark players, true when any player has `share` even false; uploadableSummary of an unmarked summary has no players and no round winner) and `packages/party_host/test/live_stats_unmarked_test.dart` (write two JSON session files into the sessions dir before `start`, one unmarked and one with `share: true`, consent true, a FakeUploader: only the marked one uploads; both files still listed by `stats.sessions()`; `state.waiting` is 0; prefs `skippedSessions` equals the unmarked id; await `settleUploads`). Then rewrite `uploadable_old_players_test.dart` to assert the new rule (it is an allowed edit of an existing test).
4 Do not edit site/ or docs.
in the report: start `## Summary` (at most 30 lines), state decisions and the tests you saw pass; end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: new tests go in NEW files and must fail on the old code; await async side effects (settleUploads) before teardown.
rules: no lib file you touch ends over 380 lines (live_stats.dart is ~369: keep additions small or move a helper out) · tests first · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/sentry2/unmarked-drop-report.md · packages/metrics/lib/src/uploadable.dart · packages/metrics/test · packages/party_host/lib/src/live_stats.dart · packages/party_host/test
check: format analyze metrics host
report: docs/briefs/m14/sentry2/unmarked-drop-report.md
