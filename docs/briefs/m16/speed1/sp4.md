job: M16 speed1 sp4: runner combined check runs only the affected suites with -j 4 and formats the job's files instead of stopping
pub: no
turns: 60
expected-min: 45
tests-first: exempt (shell tools: run the new test before your edits and show its FAIL lines in the report)
stop: after it. tools/run-steps.sh is at its 250-line cap and run-jobs.sh at 380: add no lines there (change a line in place at most); new code goes in tools/run-scope.sh. Do not touch docs.
read: docs/briefs/templates/COMMON.md · tools/run-scope.sh (all) · tools/run-steps.sh:100-135 (check_once, checks) and 36-50 (the allow:/report: path reader) · tools/affected.sh (`--not` prints the unaffected suites on one line) · tools/tests/check-scope-test.sh (pins the tools-suite skip: keep it passing) · tools/tests/run-wire-lib.sh
changes: RUN_CHECK_FULL · RUN_CHECK_JOBS · check_scope · format_job_files
decisions (owner, Nov 23): the combined check runs format and analyze of the whole workspace plus only the suites tools/affected.sh names for the wave's changes; RUN_CHECK_FULL=1 forces every suite. The runner calls check.sh with -j ${RUN_CHECK_JOBS:-4}. Before the combined check the runner runs `dart format` on the jobs' allowed .dart files instead of stopping on format; the full check stays at the batch end.
do:
1 Write tools/tests/run-affected-test.sh first (source tools/run-steps.sh in a temp git repo as check-scope-test.sh does; stubs for check.sh and affected.sh): a wave changing only packages/a runs a's suites (RUN_CHECK_SKIP = the others); RUN_CHECK_FULL=1 skips nothing except the old tools rule; a wave touching tools/check.sh runs everything; affected.sh failing or missing falls back to every suite with a WARN note; one log line says which suites run and why; a misformatted allowed .dart file is formatted (dart stubbed) and logged `formatted <file> for <job>`; a .dart file outside every allow: is not touched.
2 tools/run-scope.sh: check_scope takes the wave's job names ("$@"); builds RUN_CHECK_SKIP from `bash tools/affected.sh --not`, keeping the existing tools rule; calls format_job_files first (reads each job's allow: line as run-steps.sh:39-45 does, runs `dart format` on the existing .dart files only).
3 tools/run-steps.sh: change in place only the line in check_once that runs check.sh (add `-j "${RUN_CHECK_JOBS:-4}"`) and the call `check_scope` (pass "$@"); verify checks() really receives the job names, else say so in the report.
4 Over-cap turns: tools/run-wave.sh turn_cap already accepts result 0 plus a report with a WARN. Do not change it; add one case to the new test that proves it still does (fake usage row) and say in the report what happens at result 1.
5 Run `bash tools/tests/run-affected-test.sh`, `bash tools/tests/check-scope-test.sh`, `bash tools/tests/run-wave-test.sh` and `bash tools/tests/run-jobs-split-test.sh`; all must pass.
allow: tools/run-scope.sh · tools/run-steps.sh · tools/tests/run-affected-test.sh · tools/tests/check-scope-test.sh · docs/briefs/m16/speed1/sp4-report.md
check: format
report: docs/briefs/m16/speed1/sp4-report.md
