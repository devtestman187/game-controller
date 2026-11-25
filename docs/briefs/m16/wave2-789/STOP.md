STOP 2026-11-25 01:23:39 docs/briefs/m16/wave2-789
cause: checks failed twice on the combined tree after n8b3
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  phone       (exit 1, 62s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261125-012222/phone.log
        Expected: exactly one matching candidate
          Actual: _TextWidgetFinder:<Found 0 widgets with text "Connect to a TV": []>
           Which: means none were found but one was expected
        00:03 +50 -1: E:/AI/game-controller-m16/controller_app/test/connect_screen_test.dart: connecting opens the Connect screen when there is no saved TV [E]
          Test failed. See exception logs above.
        00:04 +54 -2: E:/AI/game-controller-m16/controller_app/test/connect_screen_test.dart: connecting manual entry checks the address before connecting [E]
  (+34 more)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-25 00:50:25 skip n8b1 (already done)
  2026-11-25 00:50:25 skip n9b2 (already done)
  2026-11-25 00:50:25 skip n9b3 (already done)
  2026-11-25 00:50:41 skip f1 (already done)
  2026-11-25 00:50:41 skip n8b2 (already done)
  2026-11-25 00:50:42 skip n8d2 (already done)
  2026-11-25 00:50:57 skip n8d1 (already done)
  2026-11-25 00:50:58 skip n8b3a (already done)
  2026-11-25 00:50:58 skip n8e0 (already done)
  2026-11-25 00:51:14 WARN: f2 was committed by hand (763c5ba5); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-25 00:51:15 hand-fixed f2: tests-first proof and worker review done (marked in done.txt)
  2026-11-25 00:51:15 skip f2 (already done)
  2026-11-25 00:51:15 skip f3 (already done)
  2026-11-25 00:51:16 start n8b3
  2026-11-25 01:19:11 n8b3 finished: result 4 (1 turns, 0 min) model claude-sonnet-5-5, ladder 2, tokens in/read/write/out 4/73027/620/305
  2026-11-25 01:19:13 n8b3: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-25 01:20:30 tests-first ok: controller_app/test/launch_home_test.dart fails on the old code
  2026-11-25 01:20:57 combined check: skips protocol connection metrics kit look arena puzzle host tv tools (no job's change reaches them)
  2026-11-25 01:22:20 checks failed; fetching packages and trying once more
  2026-11-25 01:23:39 STOPPED: checks failed twice on the combined tree after n8b3
