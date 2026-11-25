STOP 2026-11-25 01:48:38 docs/briefs/m16/wave2-789
cause: checks failed twice on the combined tree after n8e2 n8e3
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  phone       (exit 1, 76s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261125-014700/phone.log
        Expected: exactly one matching candidate
          Actual: _TextWidgetFinder:<Found 0 widgets with text "Connect to a TV": []>
           Which: means none were found but one was expected
        00:06 +83 -1: E:/AI/game-controller-m16/controller_app/test/connect_screen_test.dart: connecting opens the Connect screen when the remembered host is gone and another host is live [E]
          Test failed. See exception logs above.
        01:47:32.406 [mode] Gyro mode unavailable: This phone has no usable gyroscope, so gyro mode is off (PlatformException(NO_SENSOR, No gyroscope, null, null)).
  (+11 more)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-25 01:30:59 skip n8b3a (already done)
  2026-11-25 01:30:59 skip n8e0 (already done)
  2026-11-25 01:31:15 skip f2 (already done)
  2026-11-25 01:31:15 skip f3 (already done)
  2026-11-25 01:31:16 WARN: n8b3 was committed by hand (c5b6246f); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-25 01:32:29 tests-first ok: controller_app/test/launch_home_test.dart fails on the old code
  2026-11-25 01:32:30 hand-fixed n8b3: tests-first proof and worker review done (marked in done.txt)
  2026-11-25 01:32:30 skip n8b3 (already done)
  2026-11-25 01:32:47 start f4
  2026-11-25 01:33:13 start n8e2
  2026-11-25 01:36:53 start n8e3
  2026-11-25 01:40:13 n8e2 finished: result 4 (24 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 28/385019/27051/9789
  2026-11-25 01:40:15 n8e2: dropped generated churn outside its list: site/shots/dpad.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_a...
  2026-11-25 01:42:36 f4 finished: result 4 (75 turns, 6 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 78/1882487/61553/20530
  2026-11-25 01:42:36 job f4 used 75 turns, over its cap of 70 (parked, siblings continue)
  2026-11-25 01:43:58 n8e3 finished: result 4 (20 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 28/325871/23076/8123
  2026-11-25 01:44:00 n8e3: dropped generated churn outside its list: site/shots/dpad.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_a...
  2026-11-25 01:44:12 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-25 01:46:57 checks failed; fetching packages and trying once more
  2026-11-25 01:48:37 STOPPED: checks failed twice on the combined tree after n8e2 n8e3
