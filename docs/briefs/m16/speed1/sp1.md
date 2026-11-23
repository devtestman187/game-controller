job: M16 speed1 sp1: tools/check.sh -j N runs the package test suites in parallel
pub: no
turns: 60
expected-min: 45
tests-first: exempt (shell tools: run the new test before your edits and show its FAIL lines in the report)
stop: after it. Do not touch tools/run-steps.sh, tools/run-jobs.sh or docs/dev-tools.md (the driver edits docs). check.sh is 186 lines and has a size cap: new code goes in the sourced tools/check-par.sh.
read: docs/briefs/templates/COMMON.md · tools/check.sh:1-186 (all) · tools/tests/check-failfast-test.sh:1-95 (stubs, report helper) · tools/tests/check-scope-test.sh:1-60 (copies check.sh alone under <tmp>/repo/tools: serial mode must not need check-par.sh)
changes: CHECK_JOBS · check-par.sh · run_parallel_suites
decisions (owner, Nov 23): `check.sh -j N` (and env CHECK_JOBS=N) runs format and analyze first, serially, as today (fail-fast unchanged); then the suites (protocol..tools) N at a time. Each suite's output goes to its own log; the PASS/FAIL lines, the failure excerpts and the final summary print in the fixed check order after the run (same text as serial). Default stays serial (N=1) and then check-par.sh is never loaded. The total line is real elapsed time.
do:
1 Write tools/tests/check-par-test.sh first (temp dir; check.sh copied with check-par.sh under <tmp>/repo/tools; dart and flutter stubbed through CHECK_DART/CHECK_FLUTTER as in check-failfast-test.sh, each stub sleeps 1-2 s and exits as told): -j 4 over 8 stub suites finishes in clearly less than the serial sum; output order equals the serial order; one failing suite gives its FAIL line and excerpt, the others still run, exit 1; CHECK_JOBS=3 works like -j 3; -j 0, -j x and a missing value exit 2; with -j and a failed analyze (fail-fast) no suite starts.
2 tools/check.sh: parse `-j N`, `-jN`, `--jobs N` and CHECK_JOBS; serial path output byte-identical; for N>1 source "$(dirname "$0")/check-par.sh" (exit 2 with a message when missing) and call run_parallel_suites. Do not use `wait -n` (bash 3.2): poll the pids. Header documents -j.
3 tools/check-par.sh: run_parallel_suites, using the same skip, wanted, CHECK_SKIP and printing rules as the serial loop (share the PASS/FAIL printer by moving it into a function in check.sh if needed; keep check.sh under 250 lines).
4 Run `bash tools/tests/check-par-test.sh`, `bash tools/tests/check-failfast-test.sh` and `bash tools/tests/check-scope-test.sh`; all must pass. Report: serial vs -j 4 stub times.
allow: tools/check.sh · tools/check-par.sh · tools/tests/check-par-test.sh · docs/briefs/m16/speed1/sp1-report.md
check: format
report: docs/briefs/m16/speed1/sp1-report.md
