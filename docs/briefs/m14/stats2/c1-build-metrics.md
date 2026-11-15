job: M14 stats2 c1-build-metrics: record the app build number in the session summary and export it in the CSVs
stop: after it. No wiring of the apps (job c2 does that).
read: packages/metrics/lib/src/session.dart (line 78 joined(), line 296 summary host) · session_player.dart (line 86 playerJson) · session_clean.dart · report.dart (header line 114, rows 150, 169, 271) · report_rounds.dart (header line 160, row 191) · packages/metrics/bin/report.dart · tests that pin headers: csv_app_version_test.dart, csv_app_comma_test.dart, round_*_test.dart, report_*_test.dart
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: stats cannot tell builds apart. The apps will send their version as "0.14.0+654" (version, plus, build number); old apps send plain "0.14.0", local builds "0.14.0+dev".
do:
1 TEST FIRST, new file packages/metrics/test/csv_build_test.dart (must fail on old code): joined(app: '0.14.0+654') gives player app '0.14.0' and a 'build' key '654' in the summary; Session(hostApp: '0.14.0+654') gives host app '0.14.0' and host 'build' '654'; plain '0.14.0' or '+dev' gives no build; stats.csv gets host_build and build appended at the END of its header (...,host_app,app,host_build,build) and the rounds CSV gets host_build appended at the end (after start_s); read the real headers; old summaries without build give empty cells, no crash.
2 One helper splitAppBuild(String) -> (app, build) in session_clean.dart (or a new small file), used for players and hostApp; build is 1-9 digits, else empty. The summary keeps the bare version in app.
3 Update tests that pin the header text.
tests: each new test goes in a NEW file and must fail on the code as it was. Run only your test files while working, the full metrics suite once at the end.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/lib/src · packages/metrics/bin/report.dart · packages/metrics/test · docs/briefs/m14/stats2/c1-build-metrics-report.md
check: format analyze metrics
report: docs/briefs/m14/stats2/c1-build-metrics-report.md
in the report: start with "## Summary" (at most 30 lines, in the first 40): what changed, tests seen failing then passing with counts, decisions. End with "## Hand-over" (at most 20 lines).
