STOP 2026-11-23 15:35:06 docs/briefs/m16/bugs2
cause: checks failed twice on the combined tree after b039 flk1 b035
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  phone       (exit 1, 70s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261123-153333/phone.log
        Expected: null
          Actual: 'Multiple exceptions (2) were detected during the running of the current test, and at
        00:03 +20 -1: E:/AI/game-controller-m16/controller_app/test/connect_identity_gap_test.dart: the join line keeps a gap before its Change link (M16 identity, B-035) a narrow phone shows the join line and Change without an exception [E]
          Test failed. See exception logs above.
        15:34:12.587 [mode] Gyro mode unavailable: This phone has no usable gyroscope, so gyro mode is off (PlatformException(NO_SENSOR, No gyroscope, null, null)).
        15:34:17.962 [haptics] Haptics error (further ones not logged): PlatformException(ENGINE, null, null, null)
        01:00 +623 ~2 -1: Some tests failed.
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-23 15:21:15 RUN_MAX_MIN=82 min (computed backstop of the jobs still to do)
  2026-11-23 15:21:15 start at 2aeec568 on m16
  2026-11-23 15:21:15 worker: claude
  2026-11-23 15:21:15 run-base 2aeec5681f3f99e05352e7f47fa2fe49b57a831d
  2026-11-23 15:21:30 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 15:21:51 start b035
  2026-11-23 15:22:16 start b039
  2026-11-23 15:22:42 start flk1
  2026-11-23 15:26:38 b039 finished: result 4 (11 turns, 4 min)
  2026-11-23 15:26:40 b039: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-23 15:27:01 flk1 finished: result 4 (13 turns, 4 min)
  2026-11-23 15:27:03 flk1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-23 15:28:04 b035 finished: result 4 (25 turns, 5 min)
  2026-11-23 15:28:06 b035: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-23 15:29:58 tests-first ok: controller_app/test/connect_identity_gap_test.dart fails on the old code
  2026-11-23 15:30:09 tests-first ok: controller_app/test/lobby_alignment_test.dart fails on the old code
  2026-11-23 15:30:33 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-23 15:33:29 checks failed; fetching packages and trying once more
  2026-11-23 15:35:06 STOPPED: checks failed twice on the combined tree after b039 flk1 b035
