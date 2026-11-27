STOP 2026-11-26 18:36:02 docs/briefs/m17/phone1b
cause: jobs that failed or passed their limit (parked, not committed): y0d y0e y0f (their logs: docs/briefs/m17/phone1b/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 18:00:05 removed the last stop's STOP.md
  2026-11-26 18:00:19 phase: preflight
  2026-11-26 18:00:26 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-26 18:02:59 phase: worker (preflight took 160s)
  2026-11-26 18:02:59 skip y0p (already done)
  2026-11-26 18:03:00 skip y0dc (already done)
  2026-11-26 18:03:15 phase: worker (worker took 16s)
  2026-11-26 18:03:16 start y0d
  2026-11-26 18:20:59 start y0e
  2026-11-26 18:31:24 start y0f
  2026-11-26 18:31:25 y0d finished: result 5 (95 turns, 14 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 108/4245576/111791/44568
  2026-11-26 18:31:25 job y0d used 95 turns, over its cap of 80 (parked, siblings continue)
  2026-11-26 18:31:29 job y0d parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_phone1b/parked-y0d.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 18:31:29 y0e finished: result 5 (44 turns, 7 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 56/1554736/71697/34351
  2026-11-26 18:31:29 job y0e parked (result 5); its siblings continue
  2026-11-26 18:31:31 job y0e parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_phone1b/parked-y0e.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 18:36:00 y0f finished: result 5 (22 turns, 1 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 22/312891/34632/5266
  2026-11-26 18:36:00 job y0f parked (result 5); its siblings continue
  2026-11-26 18:36:02 job y0f parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_phone1b/parked-y0f.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 18:36:02 STOPPED: jobs that failed or passed their limit (parked, not committed): y0d y0e y0f (their logs: docs/briefs/m17/phone1b/flash-<job>.log)
