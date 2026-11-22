job: M16 process4 p4a: tools/brief-check.sh, the pre-run check of a batch's briefs
pub: no
stop: after it. Only the new script, its test and fixtures; the runner is wired in p4c.
tests-first: exempt (new shell tool: run the new test against a stub brief-check first and show FAIL lines; say so in the report).
expected-min: 35
turns: 120
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process4/PLAN.md (goal 1) · tools/run-jobs.sh lines 85-140 and the brief_lint function (how waves.txt, done.txt, dropped.txt and the allow: line are read; separator ' · ') · tools/commit-job.sh lines 70-110 (allow parsing) · tools/tests/run-base-test.sh (test layout to copy) · docs/briefs/m16/identity1/WAVE1.md (the real misses)
decisions (owner, Nov 22): the check fails a batch when (a) two jobs of one wave have overlapping allow: entries (equal paths, or one a directory of the other); (b) a file a brief creates (a do: line with NEW <path>, path containing a slash and an extension) is not covered by its allow:; (c) an allow: has over 20 entries or over 3 packages (first one or two path parts: packages/<x>, controller_app, tools, docs): WARN, suggest a split; (d) a new field changes: (items separated by ' · ': types, enum values, constants, strings, keys; for a new sealed subtype or enum value list a sibling, whose uses are the switches and lists) is searched in every */lib and */test .dart file; each hit file that no job of the batch allows is a FAIL line naming job, item and file; one allowed only by a job of a LATER wave is also a FAIL (the earlier wave's combined check cannot pass; the runner's BRIEF_CHECK_SKIP=<reason>, wired later, overrides). Only a file allowed by an earlier or the same wave's job passes. Hits in files the same job creates are ignored.
do:
1 NEW tools/brief-check.sh <batch dir>: prints FAIL <rule> <job>: <what> / WARN / a last RESULT line; exit 0 ok (WARN allowed), 1 FAIL, 2 bad use. Skips jobs in done.txt or dropped.txt. Env BRIEF_CHECK_ROOT (repo root to search, default .) and BRIEF_CHECK_REF (a git ref searched with git grep instead of the tree; printed paths have no ref prefix). Header comment doubles as --help.
2 NEW tools/tests/brief-check-test.sh and fixtures under tools/tests/fixtures/brief-check/: good (exit 0), wave-overlap, missing-new-file, big-allow (WARN only), changes-hit-test-file (a test file outside every allow), changes-hit-later-wave (FAIL). Each fixture is a tiny batch plus a tiny lib/test tree. Under 15 s.
allow: tools/brief-check.sh · tools/tests/brief-check-test.sh · tools/tests/fixtures/brief-check/ · docs/briefs/m16/process4/p4a-report.md
check: tools
report: docs/briefs/m16/process4/p4a-report.md
rules: aim 90-110 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
