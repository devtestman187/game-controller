job: <milestone> step<N> G<gate> — <what, in one line>
stop: after G<gate>. <what not to start yet>
read: <contract or design section> · <the survey or last report, the parts that matter> · docs/coding-guidelines.md

decisions (answers to <last report> Q1–n): Q1 … · Q2 …

do:
1 <one change per line: the type or file, what it does, the rule it follows>
2 Tests: <the cases, each a rule that a test must fail on if broken>
3 Report: <anything Claude needs to check: line counts, a move map, computed values>
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.

rules: <limits beyond the guidelines: sizes, no behaviour or text changes, …> · tools/review.sh: no FAIL on your lines.
allow: <path> · <path>
check: <check names: format analyze <packages>>
report: docs/briefs/<milestone>/s<N>-g<gate>-report.md
