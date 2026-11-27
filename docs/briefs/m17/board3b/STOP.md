STOP 2026-11-27 01:02:01 docs/briefs/m17/board3b
cause: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 00:48:11 g3d1 finished: result 5 (15 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 22/250844/18480/9534
  2026-11-27 00:48:11 WARN: g3d1 logged 15 turns, 1 min but ran 10 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 00:48:11 job g3d1 parked (result 5); its siblings continue
  2026-11-27 00:48:12 job g3d1 parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_board3b/parked-g3d1.patch and out of the tree (the siblings' check does not see them)
  2026-11-27 00:48:12 STOPPED: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
  RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
  2026-11-27 00:48:27 RUN_MAX_MIN=113 min (computed backstop of the jobs still to do)
  2026-11-27 00:48:27 start at 3e3d8127 on board-line
  2026-11-27 00:48:27 worker: claude
  2026-11-27 00:48:28 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 00:48:28 removed the last stop's STOP.md
  2026-11-27 00:48:39 phase: preflight
  2026-11-27 00:48:46 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 00:51:34 phase: worker (preflight took 175s)
  2026-11-27 00:51:35 start g3d1
  2026-11-27 01:01:59 g3d1 finished: result 5 (17 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 30/366564/22279/12437
  2026-11-27 01:01:59 WARN: g3d1 logged 17 turns, 1 min but ran 10 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 01:01:59 job g3d1 parked (result 5); its siblings continue
  2026-11-27 01:02:00 job g3d1 parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_board3b/parked-g3d1.patch and out of the tree (the siblings' check does not see them)
  2026-11-27 01:02:00 STOPPED: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
