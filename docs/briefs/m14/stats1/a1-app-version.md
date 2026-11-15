job: M14 stats1 a1-app-version: export the app version in the stats and rounds CSVs
stop: after it. Nothing else of the stats export.
read: packages/metrics/bin/report.dart (stats.csv header near line 104 and the csv() writer it uses) · packages/metrics/lib/src/report_rounds.dart (roundsCsvHeader, _roundCsv) · packages/metrics/lib/src/session.dart lines 78 (player app) and 296 (summary host.app) · the existing metrics CSV tests · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: the stats analysis cannot tell app builds apart; the data is already in each summary.
do:
1 TEST FIRST, new file packages/metrics/test/csv_app_version_test.dart (must fail on old code): stats.csv has columns host_app and app (the player app version; find where the stats rows are built) and the rounds CSV has host_app. A summary with no app (old data) gives empty cells, never a crash. Append the columns at the END of each header so consumers keep working.
2 Add the columns in the CSV writers. The app strings are technical version strings only (session.dart already cleans them).
3 Update any existing test that pins the header text.
tests-first: each new test must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · do not touch controller_app/lib/src/host/phone_host.dart · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/bin/report.dart · packages/metrics/lib/src · packages/metrics/test · docs/briefs/m14/stats1/a1-app-version-report.md
check: format analyze metrics
report: docs/briefs/m14/stats1/a1-app-version-report.md
in the report: start with "## Summary" (at most 30 lines): what changed, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
