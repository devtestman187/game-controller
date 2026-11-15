job: <milestone> step<N> G<gate> — <what, in one line>
stop: after G<gate>. <what not to start yet>
read: <contract or design section> · <the survey or last report, the parts that matter> · docs/coding-guidelines.md · docs/code-health.md (<area>: the items Claude names below) · <the existing test files this change could break: callers' tests, pinned strings, phone tests; read them before editing> (while working run only `flutter test <your test files>` plus these; the full `tools/check.sh <suite>` runs once, at the end)

decisions (answers to <last report> Q1–n): Q1 … · Q2 …
code health: <the code-health.md items this job also does, or "none">

do:
1 <one change per line: the type or file, what it does, the rule it follows>
2 Tests: <the cases, each a rule that a test must fail on if broken>
3 Report: <anything Claude needs to check: line counts, a move map, computed values>
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
(template note, delete this line: at most 3 independent jobs per wave (no shared files); a job estimated over 150 turns is split into phases first; this brief stays near 214 words (350 at most): longer context goes in a file named in read:. A review-fix job carries 3 findings or fewer.)

tests: await every async side effect (upload, save, timer) before teardown; in party_host use settleUploads from test/stats_test_support.dart. Run only your test files while working, the full suite once at the end. tests: each new test goes in a NEW test file and must fail on the code as it was (the runner proves it and stops otherwise); for a pure refactor or docs job write `tests-first: exempt <reason>` as a header line. A fix whose cause is not measured says so in the Summary ("Fixed, unverified: needs device check").
rules: <limits beyond the guidelines: sizes, no behaviour or text changes, …> · tools/review.sh: no FAIL on your lines.
allow: <path> · <path>   (separator is space, middle dot, space); may include sibling test files in the same package that the change can break (you fix them in this job)
check: <check names: format analyze <packages>; add `phone` when the job changes behaviour pinned by controller_app tests, so you fix the pins yourself>
report: docs/briefs/<milestone>/s<N>-g<gate>-report.md
