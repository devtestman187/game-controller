job: m17prep ci — raise analyze-test-android to 45 min and run each package's tests once (with coverage)
stop: do not touch ci.yml by hand (the runner applies the patch), codemagic.yaml, ios/, or windows-desktop's limit.
read: docs/briefs/templates/COMMON.md · docs/briefs/m17/m17prep/ci-timeout.patch · docs/briefs/m17/m17prep/ci-evidence.md
changes: timeout-minutes · Test with coverage
ci-patch: docs/briefs/m17/m17prep/ci-timeout.patch
turns: 20
expected-min: 8
tests-first: exempt CI configuration, checked on the next push
do:
1 Write the report only: summarise ci-evidence.md in 15 lines or fewer (cause, the patch, expected new timings, what to check on the next push). Change no other file.
allow: docs/briefs/m17/m17prep/ci-report.md
check: format
report: docs/briefs/m17/m17prep/ci-report.md
