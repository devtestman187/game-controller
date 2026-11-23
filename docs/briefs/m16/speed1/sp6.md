job: M16 speed1 sp6: brief-check.sh warns when a job's allow: has only test files and no tests-first: exempt line
pub: no
turns: 35
expected-min: 45
tests-first: exempt (shell tools: run the new test first and show its FAIL lines in the report)
stop: after it. brief-check.sh is 294 lines (cap 300): new code goes in a new sourced tools/brief-check-testonly.sh. Do not touch docs.
read: docs/briefs/templates/COMMON.md · tools/brief-check.sh:1-60 (header, how WARN lines and exit codes work) and the part that reads `allow:` · tools/tests/brief-check-test.sh:1-60 (fixture style)
changes: brief-check-testonly.sh · testonly_warn
decisions (owner, Nov 23): the runner proves tests-first on *_test.dart files; a job whose allow: holds only test files (plus its report) has no lib change to prove against and is stopped there. Warn at brief time, never FAIL.
do:
1 Write tools/tests/brief-check-testonly-test.sh first (temp batch with fixture briefs): allow with only `*_test.dart` files (and the report) and no `tests-first: exempt` line gives a WARN naming the job; with the exempt line, or with any lib file, or a shell-tool job (no .dart paths), no warning; exit code unchanged (0 when only warns).
2 tools/brief-check-testonly.sh with testonly_warn; tools/brief-check.sh sources it when present and calls it per brief (a few lines).
3 Run `bash tools/tests/brief-check-testonly-test.sh` and `bash tools/tests/brief-check-test.sh`; both must pass.
allow: tools/brief-check.sh · tools/brief-check-testonly.sh · tools/tests/brief-check-testonly-test.sh · docs/briefs/m16/speed1/sp6-report.md
check: format
report: docs/briefs/m16/speed1/sp6-report.md
