STOP 2026-11-24 22:26:19 docs/briefs/m16/wave2-789
cause: jobs that failed or passed their limit (parked, not committed): n9b1 (their logs: docs/briefs/m16/wave2-789/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  docs/design/m13-placed-look.png
  docs/design/puzzles/boat.png
  docs/design/puzzles/butterfly.png
  docs/design/puzzles/car.png
  (+19 more)
run.log (last 20 lines):
  2026-11-24 22:14:04 RUN_MAX_MIN=207 min (computed backstop of the jobs still to do)
  2026-11-24 22:14:04 start at c492f58b on HEAD
  2026-11-24 22:14:04 worker: claude
  2026-11-24 22:14:05 run-base c492f58bf89329b9670a56c01e8fc5cb30612cca
  2026-11-24 22:14:28 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 22:14:48 start n8a
  2026-11-24 22:15:14 start n9b1
  2026-11-24 22:15:39 start n9e
  2026-11-24 22:16:58 n9e finished: result 0 (18 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 20/206841/20200/6139
  2026-11-24 22:18:21 n8a finished: result 4 (16 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 24/259610/18028/9158
  2026-11-24 22:18:22 n8a: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzles/...
  2026-11-24 22:23:08 n9b1 finished: result 4 (65 turns, 7 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 98/1861105/58884/20151
  2026-11-24 22:23:08 job n9b1 used 65 turns, over its cap of 60 (parked, siblings continue)
  2026-11-24 22:24:14 tests-first ok: controller_app/test/home_contract_test.dart fails on the old code
  2026-11-24 22:24:30 tests-first ok: controller_app/test/home_prefs_test.dart fails on the old code
  2026-11-24 22:24:50 combined check: skips protocol connection metrics kit look arena puzzle host tv tools (no job's change reaches them)
  2026-11-24 22:26:16 committed n9e: 032b4f3a (no commit: job stopped before any change)
  2026-11-24 22:26:18 committed n8a: 729cbe77 Add Home contract: roles, anchors, highlight rule, showTips flag, strings
  2026-11-24 22:26:19 STOPPED: jobs that failed or passed their limit (parked, not committed): n9b1 (their logs: docs/briefs/m16/wave2-789/flash-<job>.log)
