STOP 2026-11-24 18:19:04 docs/briefs/m16/wave1-789
cause: the base does not compile: FAIL analyze (exit 1, 10s) log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-181848/analyze.log (log .dart_tool/run-jobs/docs_briefs_m16_wave1-789/run-base-check.log); no job of wave 1 was started
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  phone       (exit 1, 71s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-181427/phone.log
        Expected: null
          Actual: FlutterError:<A RenderFlex overflowed by 12 pixels on the right.>
        00:05 +39 -1: E:/AI/game-controller-m16/controller_app/test/connect_narrow_test.dart: the manual address row fits a narrow screen (item 9a) the address field and Connect sit inside 568x320 in the TV look [E]
          Test failed. See exception logs above.
        18:15:05.673 [mode] Gyro mode unavailable: This phone has no usable gyroscope, so gyro mode is off (PlatformException(NO_SENSOR, No gyroscope, null, null)).
        18:15:10.772 [haptics] Haptics error (further ones not logged): PlatformException(ENGINE, null, null, null)
        01:02 +658 ~2 -1: Some tests failed.
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-24 17:56:55 removed the last stop's STOP.md
  2026-11-24 17:57:09 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 17:57:24 resume n9a (applied by hand, not committed yet)
  2026-11-24 17:57:25 start n9c
  2026-11-24 17:57:25 resume n9d1 (applied by hand, not committed yet)
  2026-11-24 18:11:21 n9c finished: result 4 (61 turns, 11 min)
  2026-11-24 18:11:21 job n9c used 61 turns, over its cap of 60 (parked, siblings continue)
  2026-11-24 18:12:39 tests-first ok: controller_app/test/connect_narrow_test.dart fails on the old code
  2026-11-24 18:12:51 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-24 18:14:24 checks failed; fetching packages and trying once more
  2026-11-24 18:15:59 STOPPED: checks failed twice on the combined tree after n9a n9d1
  RESULT: STOPPED: checks failed twice on the combined tree after n9a n9d1
  HAND-FIX n9c: apply-job.sh applied 6 files: controller_app/lib/src/ui/gyro_dialog.dart, controller_app/lib/src/ui/settings_screen.dart, controller_app/lib/src/ui/stick_dialog.dart, controller_app/test/slider_semantics_test.dart, packages/party_host/lib/src/ui/look_and_sound_section.dart, packages/pa...
  HAND-FIX n9c: test helper fixed by the driver, applied with apply-job.sh
  2026-11-24 18:18:36 RUN_MAX_MIN=119 min (computed backstop of the jobs still to do)
  2026-11-24 18:18:36 start at 5560b015 on m16
  2026-11-24 18:18:36 worker: claude
  2026-11-24 18:18:36 removed the last stop's STOP.md
  2026-11-24 18:18:48 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 18:19:03 STOPPED: the base does not compile: FAIL  analyze     (exit 1, 10s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-181848/analyze.log (log .dart_tool/run-jobs/docs_briefs_m16_wave1-789/run-base-check.log); no job of wave 1 was started
