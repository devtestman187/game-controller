STOP 2026-11-26 15:36:57 docs/briefs/m17/night1a
cause: jobs that failed or passed their limit (parked, not committed): e0a n1a e0b (their logs: docs/briefs/m17/night1a/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 15:25:06 start at e1f61d90 on m17
  2026-11-26 15:25:06 worker: claude
  2026-11-26 15:25:07 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-26 15:25:07 run-base e1f61d90f1a66956196f560e43d4aa5944c068b7
  2026-11-26 15:25:23 phase: preflight
  2026-11-26 15:25:30 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-26 15:25:56 phase: worker (preflight took 33s)
  2026-11-26 15:25:56 start n1a
  2026-11-26 15:26:22 start e0a
  2026-11-26 15:31:22 start e0b
  2026-11-26 15:31:24 e0a finished: result 5 (35 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 50/1166553/59214/35592
  2026-11-26 15:31:24 job e0a used 35 turns, over its cap of 35 (parked, siblings continue)
  2026-11-26 15:31:26 job e0a parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_night1a/parked-e0a.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 15:31:57 n1a finished: result 5 (41 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 46/1055212/56999/44927
  2026-11-26 15:31:58 job n1a used 41 turns, over its cap of 35 (parked, siblings continue)
  2026-11-26 15:31:59 job n1a parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_night1a/parked-n1a.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 15:36:54 e0b finished: result 5 (23 turns, 5 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 32/412742/30283/17959
  2026-11-26 15:36:55 job e0b parked (result 5); its siblings continue
  2026-11-26 15:36:56 job e0b parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_night1a/parked-e0b.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 15:36:56 STOPPED: jobs that failed or passed their limit (parked, not committed): e0a n1a e0b (their logs: docs/briefs/m17/night1a/flash-<job>.log)
