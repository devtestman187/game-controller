STOP 2026-11-27 01:07:53 docs/briefs/m17/board3b
cause: stop file
class: stop-file
repair: a person or Claude asked for this stop: delete <batch>/STOP (the runner does at the next start), fix the cause, then restart.
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 00:48:39 phase: preflight
  2026-11-27 00:48:46 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 00:51:34 phase: worker (preflight took 175s)
  2026-11-27 00:51:35 start g3d1
  2026-11-27 01:01:59 g3d1 finished: result 5 (17 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 30/366564/22279/12437
  2026-11-27 01:01:59 WARN: g3d1 logged 17 turns, 1 min but ran 10 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 01:01:59 job g3d1 parked (result 5); its siblings continue
  2026-11-27 01:02:00 job g3d1 parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_board3b/parked-g3d1.patch and out of the tree (the siblings' check does not see them)
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
