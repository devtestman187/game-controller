STOP 2026-11-26 19:47:48 docs/briefs/m17/phone1b
cause: commit of y0d refused (see .dart_tool/run-jobs/docs_briefs_m17_phone1b/run-commit.log)
class: commit-refused
repair: read run-commit.log in the work folder, commit the job's named paths by hand, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 19:24:28 phase: preflight
  2026-11-26 19:24:34 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-26 19:24:50 phase: worker (preflight took 22s)
  2026-11-26 19:24:50 skip y0p (already done)
  2026-11-26 19:24:51 skip y0dc (already done)
  2026-11-26 19:25:06 phase: worker (worker took 16s)
  2026-11-26 19:25:07 skip y0e (already done)
  2026-11-26 19:25:07 skip y0f (already done)
  2026-11-26 19:25:28 phase: worker (worker took 22s)
  2026-11-26 19:25:28 resume y0d (applied by hand, not committed yet)
  2026-11-26 19:25:29 start y0h
  2026-11-26 19:29:49 start y0h2
  2026-11-26 19:29:50 y0h finished: result 0 (38 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 54/1155901/50098/25161
  2026-11-26 19:42:28 y0h2 finished: result 0 (35 turns, 8 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 68/1449620/49398/24280
  2026-11-26 19:42:29 phase: tests-first (worker took 1021s)
  2026-11-26 19:42:41 phase: check (tests-first took 12s)
  2026-11-26 19:43:17 combined check: the tools suite is skipped (no job changed a file under tools/)
  2026-11-26 19:47:46 phase: apply (check took 305s)
  2026-11-26 19:47:46 finding: y0d's report has no Summary block in its first 40 lines
  2026-11-26 19:47:47 STOPPED: commit of y0d refused (see .dart_tool/run-jobs/docs_briefs_m17_phone1b/run-commit.log)
