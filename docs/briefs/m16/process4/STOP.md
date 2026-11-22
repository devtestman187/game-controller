STOP 2026-11-22 12:33:46 docs/briefs/m16/process4
cause: job p4b passed its limit (52 min, estimate 35)
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 11:40:14 RUN_MAX_MIN=282 min (computed backstop of the jobs still to do)
  2026-11-22 11:40:14 start at b7048a7b on m16
  2026-11-22 11:40:14 run-base b7048a7b8f1968c1507b3ec0c1149e73ab88d97a
  2026-11-22 11:40:25 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 11:40:45 start p4a
  2026-11-22 11:41:11 start p4b
  2026-11-22 11:41:37 start p4e
  2026-11-22 12:19:23 p4e finished: result 5 (45 turns, 30 min)
  2026-11-22 12:29:20 p4a finished: result 0 (102 turns, 41 min)
  2026-11-22 12:33:45 STOPPED: job p4b passed its limit (52 min, estimate 35)
