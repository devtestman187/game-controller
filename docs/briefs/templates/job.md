job: <milestone> step<N> G<gate> — <what, in one line>
stop: after G<gate>. <what not to start yet>
read: docs/briefs/templates/COMMON.md (worker rules: decide, report, tests, rules) · <contract or design section> · <the survey or last report, the parts that matter> · docs/coding-guidelines.md · docs/code-health.md (<area>: the items Claude names below) · <the existing test files this change could break: callers' tests, pinned strings, phone tests; read them before editing> (while working run only `flutter test <your test files>` plus these; the full `tools/check.sh <suite>` runs once, at the end)

changes: <types, enum values, constants, strings, keys this job changes, ` · ` separated; a sibling for a new sealed subtype or enum value; brief-check searches them in lib and test>
probe: <stub patch adding the new type, optional; probe-deps checks the stubbed workspace's error files are allowed>
(allow: must cover every file those names hit and every NEW file the job creates)

decisions (answers to <last report> Q1–n): Q1 … · Q2 …
code health: <the code-health.md items this job also does, or "none">

do:
1 <one change per line: the type or file, what it does, the rule it follows>
2 Tests: <the cases, each a rule that a test must fail on if broken>
3 Report: <anything Claude needs to check: line counts, a move map, computed values>
UI: say which looks the change touches (menu, TV) and name the test for each.
(template note, delete this line: at most 3 independent jobs per wave (no shared files); a job estimated over about 120 turns is split into phases first; this brief targets about 200 words (350 at most); the repeated decide/report/tests/rules text lives in COMMON.md, so do not copy it here; add a `rules:` line only for limits beyond it: longer context goes in a file named in read:. A review-fix job carries 3 findings or fewer.)

allow: <path> · <path>   (separator is space, middle dot, space); may include sibling test files in the same package that the change can break (you fix them in this job)
check: <check names: format analyze <packages>; add `phone` when the job changes behaviour pinned by controller_app tests, so you fix the pins yourself>
report: docs/briefs/<milestone>/s<N>-g<gate>-report.md
