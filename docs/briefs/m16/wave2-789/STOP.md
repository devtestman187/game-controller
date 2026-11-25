STOP 2026-11-24 22:44:12 docs/briefs/m16/wave2-789
cause: jobs that failed or passed their limit (parked, not committed): n8c (their logs: docs/briefs/m16/wave2-789/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  tv_test_app/windows/flutter/generated_plugin_registrant.cc
  tv_test_app/windows/flutter/generated_plugin_registrant.h
  tv_test_app/windows/flutter/generated_plugins.cmake
run.log (last 20 lines):
  2026-11-24 22:31:41 tests-first: controller_app/test/touch_targets_test.dart passes on the old code, exempt by its brief
  2026-11-24 22:31:42 hand-fixed n9b1: tests-first proof and worker review done (marked in done.txt)
  2026-11-24 22:31:42 skip n9b1 (already done)
  2026-11-24 22:31:43 skip n9e (already done)
  2026-11-24 22:31:43 wave 1 review: wave1-review-report.md does not cover n9b1, so its review is wave1-n9b1
  2026-11-24 22:32:00 start n8b0
  2026-11-24 22:32:26 start n8c
  2026-11-24 22:34:04 start n9sr
  2026-11-24 22:35:32 n8b0 finished: result 4 (21 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 28/328882/20554/11081
  2026-11-24 22:35:34 n8b0: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 22:39:05 n9sr finished: result 4 (58 turns, 5 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 76/2119070/87015/45041
  2026-11-24 22:39:06 n9sr: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 22:40:02 n8c finished: result 4 (66 turns, 7 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 80/2114247/63783/32796
  2026-11-24 22:40:02 job n8c used 66 turns, over its cap of 50 (parked, siblings continue)
  2026-11-24 22:40:17 tests-first ok: packages/puzzle_game/test/round_label_test.dart fails on the old code
  2026-11-24 22:40:42 combined check: skips protocol connection metrics kit look arena tools (no job's change reaches them)
  2026-11-24 22:44:08 committed n8b0: 421d3386 Extract host start into launchHosting for Home to call
  2026-11-24 22:44:10 committed n9sr: b4f70808 puzzle HUD: a night's round shows as "Round N of M" before the name
  2026-11-24 22:44:11 reviewed wave1-n9b1: 9 finding(s)
  2026-11-24 22:44:12 STOPPED: jobs that failed or passed their limit (parked, not committed): n8c (their logs: docs/briefs/m16/wave2-789/flash-<job>.log)
