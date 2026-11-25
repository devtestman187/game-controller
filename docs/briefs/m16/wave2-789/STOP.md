STOP 2026-11-24 23:20:07 docs/briefs/m16/wave2-789
cause: tools/review.sh found a FAIL after n8b1 n9b3 n9b2 (see .dart_tool/run-jobs/docs_briefs_m16_wave2-789/run-review.log); nothing of this wave is committed
class: review-fail
repair: run bash tools/review.sh, fix the FAIL lines it prints in the code (never a rule), then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-24 22:48:51 WARN: n8c was committed by hand (01b289b2); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-24 22:50:20 tests-first ok: controller_app/test/coach_marks_test.dart fails on the old code
  2026-11-24 22:50:21 hand-fixed n8c: tests-first proof and worker review done (marked in done.txt)
  2026-11-24 22:50:21 skip n8c (already done)
  2026-11-24 22:50:22 skip n9sr (already done)
  2026-11-24 22:50:22 wave 2 review: wave2-review-report.md does not cover n8c, so its review is wave2-n8c
  2026-11-24 22:50:39 start n8b1
  2026-11-24 22:51:05 start n9b2
  2026-11-24 22:53:29 start n9b3
  2026-11-24 22:55:39 n8b1 finished: result 4 (36 turns, 4 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 42/751692/41018/17198
  2026-11-24 22:55:41 n8b1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 23:00:44 n9b3 finished: result 4 (60 turns, 7 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 82/2106914/71938/21617
  2026-11-24 23:00:45 n9b3: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 23:14:15 n9b2 finished: result 4 (1 turns, 0 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 4/75139/645/185
  2026-11-24 23:14:16 n9b2: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 23:15:32 tests-first ok: controller_app/test/connection_chip_test.dart fails on the old code
  2026-11-24 23:15:37 tests-first ok: controller_app/test/home_view_test.dart fails on the old code
  2026-11-24 23:15:58 tests-first: packages/party_host/test/touch_targets_host_test.dart passes on the old code, exempt by its brief
  2026-11-24 23:17:13 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-24 23:20:07 STOPPED: tools/review.sh found a FAIL after n8b1 n9b3 n9b2 (see .dart_tool/run-jobs/docs_briefs_m16_wave2-789/run-review.log); nothing of this wave is committed
