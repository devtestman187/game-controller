STOP 2026-11-27 01:09:34 docs/briefs/m17/board3b
cause: the base does not compile: FAIL format (exit 1, 2s) log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-010929/format.log (log .dart_tool/run-jobs/docs_briefs_m17_board3b/run-base-check.log); no job of wave 1 was started
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 01:02:00 STOPPED: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
  RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
  2026-11-27 01:04:24 RUN_MAX_MIN=113 min (computed backstop of the jobs still to do)
  2026-11-27 01:04:24 start at 2310d0fd on board-line
  2026-11-27 01:04:24 worker: claude
  2026-11-27 01:04:27 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 01:04:27 removed the old stop file
  2026-11-27 01:04:46 phase: preflight
  2026-11-27 01:05:06 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 01:05:36 phase: worker (preflight took 50s)
  2026-11-27 01:05:37 start g3d1r
  2026-11-27 01:07:53 STOPPED: stop file
  RESULT: STOPPED: stop file
  2026-11-27 01:09:04 RUN_MAX_MIN=113 min (computed backstop of the jobs still to do)
  2026-11-27 01:09:04 start at c521b945 on board-line
  2026-11-27 01:09:04 worker: claude
  2026-11-27 01:09:06 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 01:09:21 phase: preflight
  2026-11-27 01:09:29 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 01:09:34 STOPPED: the base does not compile: FAIL  format      (exit 1, 2s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-010929/format.log (log .dart_tool/run-jobs/docs_briefs_m17_board3b/run-base-check.log); no job of wave 1 was started
