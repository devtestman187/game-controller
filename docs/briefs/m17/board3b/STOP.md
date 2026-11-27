STOP 2026-11-27 00:48:13 docs/briefs/m17/board3b
cause: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 00:36:36 RUN_MAX_MIN=113 min (computed backstop of the jobs still to do)
  2026-11-27 00:36:36 start at e7d50dd0 on board-line
  2026-11-27 00:36:36 worker: claude
  2026-11-27 00:36:37 proc-sweep: ORPHAN 75484 bash 3s "C:/Program Files/Git/bin/../usr/bin/bash.exe" -c "source /c/Users/mrman/.claude/shell-snapshots/snapshot-bash-179555545
  2026-11-27 00:36:37 proc-sweep: proc-sweep: 1 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 00:36:37 run-base e7d50dd00aeb7380503227932c81d85ed6ae9975
  2026-11-27 00:36:48 phase: preflight
  2026-11-27 00:36:55 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 00:37:16 phase: worker (preflight took 28s)
  2026-11-27 00:37:17 start g3d1
  2026-11-27 00:48:11 g3d1 finished: result 5 (15 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 22/250844/18480/9534
  2026-11-27 00:48:11 WARN: g3d1 logged 15 turns, 1 min but ran 10 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 00:48:11 job g3d1 parked (result 5); its siblings continue
  2026-11-27 00:48:12 job g3d1 parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_board3b/parked-g3d1.patch and out of the tree (the siblings' check does not see them)
  2026-11-27 00:48:12 STOPPED: jobs that failed or passed their limit (parked, not committed): g3d1 (their logs: docs/briefs/m17/board3b/flash-<job>.log)
