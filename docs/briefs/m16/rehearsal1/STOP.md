STOP 2026-11-22 23:09:01 docs/briefs/m16/rehearsal1
cause: checks failed twice on the combined tree after n3 n2 n1
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 22:21:53 RUN_MAX_MIN=49 min (computed backstop of the jobs still to do)
  2026-11-22 22:21:53 start at d4ec91f4 on m16
  2026-11-22 22:21:53 worker: claude
  2026-11-22 22:21:53 run-base d4ec91f4f8d99e199451f3ac74addc7ad6764c61
  2026-11-22 22:22:07 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 22:22:34 start n1
  2026-11-22 22:22:59 start n2
  2026-11-22 22:23:25 start n3
  2026-11-22 22:25:31 n3 finished: result 0 (9 turns, 1 min)
  2026-11-22 22:28:02 n2 finished: result 4 (18 turns, 4 min)
  2026-11-22 22:28:04 n2: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png 
  2026-11-22 22:34:19 n1 finished: result 4 (34 turns, 11 min)
  2026-11-22 22:34:21 n1: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_regi...
  2026-11-22 22:36:15 tests-first ok: controller_app/test/phone_name_display_test.dart fails on the old code
  2026-11-22 22:36:26 tests-first ok: packages/connection/test/phone_name_test.dart fails on the old code
  2026-11-22 22:52:44 checks failed; fetching packages and trying once more
  2026-11-22 23:09:01 STOPPED: checks failed twice on the combined tree after n3 n2 n1
