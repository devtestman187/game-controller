job: M14 stats2 fix2-session: close REVIEW.md findings 2, 7 and 8 (reconnect keeps a stale build; unguarded build cells; read guard untested)
stop: after it.
read: docs/briefs/m14/stats2/REVIEW.md (findings 2, 7, 8) · packages/metrics/lib/src/session.dart (~line 90) · packages/metrics/lib/src/report.dart (~160-175: buildCell, appCell, rowsOf) · packages/metrics/test/csv_build_test.dart (a model; do not edit it)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 TEST FIRST, new file packages/metrics/test/csv_build_guard_test.dart (must fail on old code): (a) joined with app '0.14.0+654' and then again with '0.15.0': the summary says app 0.15.0 and NO build; a rejoin that names no version at all keeps both; (b) a hand-built ModeRow whose build holds a comma gives a CSV row with the same field count as the header; (c) a summary read with 'build': '65a' and another with '1,2' give empty build cells and a 37-field row.
2 session.dart: set p.build = version.build in the same if that sets p.app. report.dart: pass hostBuild and build through buildCell() in toCsv().
tests: each new test goes in a NEW file and must fail on the code as it was.
rules: aim for 80-120 turns · no lib file over 380 lines · tests first: the runner checks it · write only inside allow: · stage nothing yourself, never git add -A · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/lib/src/session.dart · packages/metrics/lib/src/report.dart · packages/metrics/test/csv_build_guard_test.dart · docs/briefs/m14/stats2/fix2-session-report.md
check: format analyze metrics
report: docs/briefs/m14/stats2/fix2-session-report.md
in the report: start with "## Summary" (at most 30 lines, in the first 40): what changed, tests seen failing then passing, decisions. End with "## Hand-over" (at most 20 lines).
