job: M16 process2 wait — tools/wait-run.sh (wait for a run without polling)
pub: no
stop: after it.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/script-rules.md · docs/briefs/m16/scriptable-work.md (item 1) · .claude/agents/thumb-batch.md (step 3, the loop it replaces) · docs/briefs/m16/process1/run.log (real line shapes: start at, start <job>, <job> finished: result, STOPPED, DONE) · tools/flash_usage.dart and run-jobs.sh usage() (flash-usage.tsv columns)
decisions (owner, Nov 21): "blocks up to 170 s, prints only new run.log lines, exits on DONE/STOPPED"; "STALLED if run.log is unchanged for 20 minutes and OVERRUN when a job passes ~1.5x its expected time (use flash-usage history or a brief-given figure)".
tests-first: exempt shell tooling; its test is tools/tests/wait-run-test.sh.

do:
1 tools/wait-run.sh <batch-dir> [--max <s>] (default and cap 170; the shell backgrounds a call at 180 s): checks the folder and run.log (exit 3), polls every 5 s, prints only the lines new since the last call (position kept in .dart_tool/wait-run/<name>.pos, reset on a new `start at` line), exits at once on a DONE or STOPPED line after the last `start at`.
2 Exit codes (extends script-rules): 0 DONE · 1 STOPPED · 2 STALLED or OVERRUN · 3 bad input · 4 still running when the window ended. Last line `RESULT: ...`; for 4: `RESULT: running: <job> for <n> min (expected ~<m>)`.
3 STALLED: run.log, the batch's flash-*.log files and the run's work folder unchanged for WAIT_STALL_MIN (default 20) minutes while no DONE/STOPPED. OVERRUN: a `start <job>` line with no `<job> finished` line older than 1.5 x expected; expected = an `expected-min:` line in the job's brief, else the median minutes of that job's recent entries in flash-usage.tsv (FLASH_USAGE_LOG), else 15.
4 Lock per batch dir (two waiters refused, exit 3); trap cleans up; read the pos file defensively (garbage resets it).
5 tools/tests/wait-run-test.sh: fake run.logs for DONE, STOPPED, still running (--max 6), STALLED (old mtimes via touch -d), OVERRUN, missing folder, no run.log, repeat call prints only new lines, a path with spaces, a second waiter, garbage pos file.
allow: tools/wait-run.sh · tools/tests/wait-run-test.sh · docs/briefs/m16/process2/p2-wait-report.md
check: format
report: docs/briefs/m16/process2/p2-wait-report.md
