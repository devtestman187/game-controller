job: M14 stats1 fix1-csv-review: three review findings in the stats CSVs (a1, a2, a3)
stop: after it. No new columns.
read: docs/briefs/m14/stats1/a1-app-version-review-report.md (Findings 1-4) · packages/metrics/bin/report.dart (~150, ModeRow._row ~212) · packages/metrics/lib/src/report_rounds.dart (~186) · packages/metrics/lib/src/session.dart:352 (_technical allows commas) · packages/metrics/test/csv_app_version_test.dart · docs/design/m12-report.md (~22) · docs/dev-tools.md (~343) · docs/code-health.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 TEST FIRST, new file packages/metrics/test/csv_app_comma_test.dart (must fail on old code): a summary whose host app or player app is "1.0,2" must give a stats.csv row and a rounds row with the same number of fields as the header. Fix by replacing a comma in the app cells with a semicolon in the CSV writers (both files), not by changing what session.dart accepts.
2 In csv_app_version_test.dart lines ~46 and ~72 assert the literal header text instead of the writer's own constant.
3 Update docs/design/m12-report.md and docs/dev-tools.md so the CSV column lists and counts match the code now: stats.csv ends host_app,app; the rounds CSV ends tags,host_app,winner,draw,players,frames_drawn,frames_late,fps. Read the headers in the code, do not guess the count.
4 ModeRow._row (57 lines) over the ~40 guideline: add a code-health.md entry (area metrics report), no refactor.
tests-first: each new test file must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/bin/report.dart · packages/metrics/lib/src/report_rounds.dart · packages/metrics/lib/src/report_table.dart · packages/metrics/test/csv_app_comma_test.dart · packages/metrics/test/csv_app_version_test.dart · docs/design/m12-report.md · docs/dev-tools.md · docs/code-health.md · docs/briefs/m14/stats1/fix1-csv-review-report.md
check: format analyze metrics
report: docs/briefs/m14/stats1/fix1-csv-review-report.md
in the report: start with "## Summary" (at most 30 lines): what changed, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
