STOP 2026-11-27 01:23:56 docs/briefs/m17/board3b
cause: jobs that failed or passed their limit (parked, not committed): g3d1s (their logs: docs/briefs/m17/board3b/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 01:09:04 worker: claude
  2026-11-27 01:09:06 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 01:09:21 phase: preflight
  2026-11-27 01:09:29 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 01:09:34 STOPPED: the base does not compile: FAIL  format      (exit 1, 2s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-010929/format.log (log .dart_tool/run-jobs/docs_briefs_m17_board3b/run-base-check.log); no job of wave 1 was started
  RESULT: STOPPED: the base does not compile: FAIL  format      (exit 1, 2s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-010929/format.log (log .dart_tool/run-jobs/docs_briefs_m17_board3b/run-base-check.log); no job of wave 1 was started
  2026-11-27 01:09:57 RUN_MAX_MIN=113 min (computed backstop of the jobs still to do)
  2026-11-27 01:09:57 start at bc638723 on board-line
  2026-11-27 01:09:57 worker: claude
  2026-11-27 01:09:58 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 01:09:58 removed the last stop's STOP.md
  2026-11-27 01:10:13 phase: preflight
  2026-11-27 01:10:21 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 01:10:41 phase: worker (preflight took 28s)
  2026-11-27 01:10:42 start g3d1s
  2026-11-27 01:23:55 g3d1s finished: result 5 (18 turns, 2 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 30/418435/25976/17205
  2026-11-27 01:23:55 WARN: g3d1s logged 18 turns, 2 min but ran 13 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 01:23:55 job g3d1s parked (result 5); its siblings continue
  2026-11-27 01:23:56 job g3d1s parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_board3b/parked-g3d1s.patch and out of the tree (the siblings' check does not see them)
  2026-11-27 01:23:56 STOPPED: jobs that failed or passed their limit (parked, not committed): g3d1s (their logs: docs/briefs/m17/board3b/flash-<job>.log)
