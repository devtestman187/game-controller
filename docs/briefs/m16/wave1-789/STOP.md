STOP 2026-11-24 20:18:00 docs/briefs/m16/wave1-789
cause: checks failed twice on the combined tree after f1 f2
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  phone       (exit 1, 611s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-200729/phone.log
        00:04 +38 -1: E:/AI/game-controller-m16/controller_app/test/connect_narrow_test.dart: the manual address row fits a narrow screen (item 9a) the address field and Connect sit inside 568x320 in the TV look [E]
          'package:flutter_test/src/binding.dart': Failed assertion: line 1912 pos 9: '_pendingExceptionDetails != null': A test overrode FlutterError.onError but either failed to return it to its original state, or had unexpected additional errors that it could not handle. Typically, this is caused b...
        20:08:00.421 [mode] Gyro mode unavailable: This phone has no usable gyroscope, so gyro mode is off (PlatformException(NO_SENSOR, No gyroscope, null, null)).
        20:08:03.600 [haptics] Haptics error (further ones not logged): PlatformException(ENGINE, null, null, null)
        10:03 +660 ~2 -1: E:/AI/game-controller-m16/controller_app/test/connect_narrow_test.dart: the manual address row fits a narrow screen (item 9a) the address field and Connect sit inside 568x320 in the TV look [E]
          TimeoutException after 0:10:00.000000: Test timed out after 10 minutes.
        10:04 +664 ~2 -1: Some tests failed.
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-24 19:08:32 removed the last stop's STOP.md
  2026-11-24 19:08:46 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 19:09:01 skip n9a (already done)
  2026-11-24 19:09:02 skip n9c (already done)
  2026-11-24 19:09:02 skip n9d1 (already done)
  2026-11-24 19:09:18 skip n7a (already done)
  2026-11-24 19:09:18 skip n9d2 (already done)
  2026-11-24 19:09:34 skip n9d3 (already done)
  2026-11-24 19:09:50 start f1
  2026-11-24 19:10:16 start f2
  2026-11-24 19:10:42 start f3
  2026-11-24 19:15:22 f1 finished: result 4 (35 turns, 5 min)
  2026-11-24 19:15:23 f1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 19:18:18 f3 finished: result 4 (46 turns, 5 min)
  2026-11-24 19:18:18 job f3 used 46 turns, over its cap of 45 (parked, siblings continue)
  2026-11-24 19:56:32 f2 finished: result 4 (1 turns, 0 min)
  2026-11-24 19:56:33 f2: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 19:56:47 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-24 20:07:26 checks failed; fetching packages and trying once more
  2026-11-24 20:17:59 STOPPED: checks failed twice on the combined tree after f1 f2
