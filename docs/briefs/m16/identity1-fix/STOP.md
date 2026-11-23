STOP 2026-11-23 08:29:20 docs/briefs/m16/identity1-fix
cause: jobs that failed or passed their limit (parked, not committed): fq6 fpad (their logs: docs/briefs/m16/identity1-fix/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  tv_test_app/windows/flutter/generated_plugin_registrant.cc
  tv_test_app/windows/flutter/generated_plugin_registrant.h
  tv_test_app/windows/flutter/generated_plugins.cmake
run.log (last 20 lines):
  2026-11-23 08:01:58 STOPPED: checks failed on the combined tree after fm1 fm2: format cannot be fixed by a retry
  RESULT: STOPPED: checks failed on the combined tree after fm1 fm2: format cannot be fixed by a retry
  2026-11-23 08:25 HAND-FIX fm3: the worker left a debug expect (DBG) in the test and the file unformatted (parked, result 4 + check fail); removed the debug expect, dart format, mine ok, review 0 fail
  2026-11-23 08:07:50 RUN_MAX_MIN=132 min (computed backstop of the jobs still to do)
  2026-11-23 08:07:50 start at 016f6b3c on m16
  2026-11-23 08:07:50 worker: claude
  2026-11-23 08:07:50 removed the last stop's STOP.md
  2026-11-23 08:08:08 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 08:08:29 start fq6
  2026-11-23 08:08:55 start ft
  2026-11-23 08:09:21 start fpad
  2026-11-23 08:11:47 ft finished: result 0 (40 turns, 2 min)
  2026-11-23 08:13:05 fq6 finished: result 4 (44 turns, 4 min)
  2026-11-23 08:13:05 job fq6 used 44 turns, over its cap of 35 (parked, siblings continue)
  2026-11-23 08:18:59 fpad finished: result 4 (51 turns, 6 min)
  2026-11-23 08:18:59 job fpad used 51 turns, over its cap of 50 (parked, siblings continue)
  2026-11-23 08:19:00 combined check: the tools suite runs (a job changed a file under tools/)
  2026-11-23 08:29:19 committed ft: a3b94b90 tools: run the tools suite four scripts at once
  2026-11-23 08:29:19 wave review skipped: wave 1 is the whole run, the run review covers it
  2026-11-23 08:29:20 STOPPED: jobs that failed or passed their limit (parked, not committed): fq6 fpad (their logs: docs/briefs/m16/identity1-fix/flash-<job>.log)
