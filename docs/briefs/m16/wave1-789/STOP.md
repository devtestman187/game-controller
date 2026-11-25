STOP 2026-11-24 18:40:01 docs/briefs/m16/wave1-789
cause: jobs that failed or passed their limit (parked, not committed): n7a (their logs: docs/briefs/m16/wave1-789/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  site/shots/dpad.png
  site/shots/join.png
  site/shots/menus.png
  site/shots/results.png
  (+5 more)
run.log (last 20 lines):
  2026-11-24 18:24:25 removed the last stop's STOP.md
  2026-11-24 18:24:36 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 18:24:51 skip n9a (already done)
  2026-11-24 18:24:52 WARN: n9c was committed by hand (95a64202); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-24 18:26:08 tests-first ok: controller_app/test/slider_semantics_test.dart fails on the old code
  2026-11-24 18:26:25 tests-first: packages/party_host/test/volume_semantics_test.dart passes on the old code, exempt by its brief
  2026-11-24 18:26:26 hand-fixed n9c: tests-first proof and worker review done (marked in done.txt)
  2026-11-24 18:26:26 skip n9c (already done)
  2026-11-24 18:26:27 skip n9d1 (already done)
  2026-11-24 18:26:44 start n7a
  2026-11-24 18:27:10 start n9d2
  2026-11-24 18:30:15 n9d2 finished: result 4 (23 turns, 2 min)
  2026-11-24 18:30:17 n9d2: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_re...
  2026-11-24 18:36:03 n7a finished: result 4 (51 turns, 9 min)
  2026-11-24 18:36:03 job n7a used 51 turns, over its cap of 50 (parked, siblings continue)
  2026-11-24 18:36:18 tests-first ok: packages/test_game/test/arena_hud_round_test.dart fails on the old code
  2026-11-24 18:36:28 combined check: skips protocol connection metrics look tools (no job's change reaches them)
  2026-11-24 18:39:58 committed n9d2: d796f71f arena: HUD shows Round N of M and warns the clock in its last 15 s
  2026-11-24 18:40:00 reviewed wave1: 8 finding(s)
  2026-11-24 18:40:00 STOPPED: jobs that failed or passed their limit (parked, not committed): n7a (their logs: docs/briefs/m16/wave1-789/flash-<job>.log)
