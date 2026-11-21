job: M16 process2 harness — tools/selftest.sh and a "tools" check in tools/check.sh
pub: no
stop: after it. No change to other checks.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/script-rules.md · tools/check.sh (the checks array, the help range :2-15)
decisions (owner, Nov 21): "self-tests for each script ... wired into tools/check.sh's existing tool/self-test suite" (none exists, so this job adds it).
tests-first: exempt shell tooling; its own test is tools/tests/selftest-test.sh. You cannot run shell tests yet (not allow-listed): check with bash -n and by reading; the driver runs them.

do:
1 tools/selftest.sh [dir]: runs every `<dir>/*-test.sh` (default tools/tests) one by one, each under `timeout` (SELFTEST_TIMEOUT, default 120 s; TIMEOUT line, exit 2), prints one `PASS|FAIL|TIMEOUT <script> (<n>s)` line each and, for a failure, the script's FAIL lines. Missing dir or no scripts: exit 3 with a plain message. Exit 1 if any failed. Last line: RESULT. Follow script-rules.md.
2 tools/check.sh: add the check `tools|.|bash tools/selftest.sh|shell tool self-tests (tools/tests/*-test.sh)` after `tv`; update the header's Checks list. Nothing else.
3 tools/tests/selftest-test.sh: cases for the rules (empty dir, missing dir, a passing and a failing fixture script, a hanging fixture with SELFTEST_TIMEOUT=2, a path with spaces, a second copy refused by the lock).
allow: tools/selftest.sh · tools/check.sh · tools/tests/selftest-test.sh · docs/briefs/m16/process2/p2-harness-report.md
check: format
report: docs/briefs/m16/process2/p2-harness-report.md
