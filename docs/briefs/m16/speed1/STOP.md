STOP 2026-11-23 11:40:23 docs/briefs/m16/speed1
cause: jobs that failed or passed their limit (parked, not committed): sp5 sp2 (their logs: docs/briefs/m16/speed1/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  docs/design/m13-placed-look.png
  docs/design/puzzles/boat.png
  docs/design/puzzles/butterfly.png
  docs/design/puzzles/car.png
  (+18 more)
run.log (last 20 lines):
  2026-11-23 11:22:36 RUN_MAX_MIN=338 min (computed backstop of the jobs still to do)
  2026-11-23 11:22:36 start at 56dce66a on m16
  2026-11-23 11:22:36 worker: claude
  2026-11-23 11:22:37 run-base 56dce66af669aac908cfd784337448e2930db212
  2026-11-23 11:22:58 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 11:23:19 start sp1
  2026-11-23 11:23:44 start sp2
  2026-11-23 11:24:10 start sp5
  2026-11-23 11:28:46 sp5 finished: result 4 (43 turns, 4 min)
  2026-11-23 11:28:46 job sp5 used 43 turns, over its cap of 35 (parked, siblings continue)
  2026-11-23 11:28:51 sp2 finished: result 4 (21 turns, 4 min)
  2026-11-23 11:28:51 job sp2 parked (result 4); its siblings continue
  2026-11-23 11:29:53 sp1 finished: result 4 (21 turns, 6 min)
  2026-11-23 11:29:55 sp1: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzles/...
  2026-11-23 11:29:56 combined check: the tools suite runs (a job changed a file under tools/)
  2026-11-23 11:40:20 committed sp1: 111f6017 check.sh -j N runs the package test suites in parallel ```
  2026-11-23 11:40:22 STOPPED: jobs that failed or passed their limit (parked, not committed): sp5 sp2 (their logs: docs/briefs/m16/speed1/flash-<job>.log)
