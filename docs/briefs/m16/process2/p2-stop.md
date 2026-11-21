job: M16 process2 stop — tools/run-stop.sh writes STOP.md for a runner stop
pub: no
stop: after it. The runner is NOT edited here (a later job wires it).
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/script-rules.md · docs/briefs/m16/scriptable-work.md (item 2) · docs/flash-digest.md (Repair a stop) · tools/run-jobs.sh (stop() and every stop "..." message; outside_files) · docs/briefs/m16/phonehost2/run.log and phonehost1/run.log (real STOPPED lines)
decisions (owner, Nov 21): "the runner writes STOP.md on any stop (cause, failing tests, last log lines, suggested repair)".
tests-first: exempt shell tooling; its test is tools/tests/run-stop-test.sh.

do:
1 tools/run-stop.sh <batch-dir> <work-dir> "<cause text>" [<flash-log>]: writes <batch-dir>/STOP.md, at most 40 lines: the cause line, a class (churn-outside, outside-allow, tests-first, check-failed, review-fail, size, brief-lint, preflight, stop-file, commit-refused, job-failed, timeout, other), failing test names and error lines from <work-dir>/run-check.log (like check.sh's interesting filter), the files outside allow from the flash log (CHANGED FILES OUTSIDE block), the last 20 run.log lines, and a suggested repair per class naming the digest section or command.
2 Never fails the runner: exit 0 once STOP.md is written; exit 3 only for bad arguments or an unwritable folder. Missing run-check.log or flash log: say "none found", not an error. Atomic write (temp file then mv). Cause text may contain quotes, spaces, newlines.
3 tools/tests/run-stop-test.sh: one case per class, missing logs, huge logs (output stays at most 40 lines), bad arguments, a path with spaces, nothing else in the folder changed.
allow: tools/run-stop.sh · tools/tests/run-stop-test.sh · docs/briefs/m16/process2/p2-stop-report.md
check: format
report: docs/briefs/m16/process2/p2-stop-report.md
