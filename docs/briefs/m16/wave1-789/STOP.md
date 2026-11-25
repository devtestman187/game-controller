STOP 2026-11-24 18:24:04 docs/briefs/m16/wave1-789
cause: tests-first: packages/party_host/test/volume_semantics_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
class: tests-first
repair: fix the test so it fails on the old code (never the gate), or add "tests-first: exempt <reason>" to the brief for a pure refactor (docs/flash-digest.md "Repair a stop").
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
  RESULT: STOPPED: checks failed twice on the combined tree after n9a n9d1
  HAND-FIX n9c: apply-job.sh applied 6 files: controller_app/lib/src/ui/gyro_dialog.dart, controller_app/lib/src/ui/settings_screen.dart, controller_app/lib/src/ui/stick_dialog.dart, controller_app/test/slider_semantics_test.dart, packages/party_host/lib/src/ui/look_and_sound_section.dart, packages/pa...
  HAND-FIX n9c: test helper fixed by the driver, applied with apply-job.sh
  2026-11-24 18:18:36 RUN_MAX_MIN=119 min (computed backstop of the jobs still to do)
  2026-11-24 18:18:36 start at 5560b015 on m16
  2026-11-24 18:18:36 worker: claude
  2026-11-24 18:18:36 removed the last stop's STOP.md
  2026-11-24 18:18:48 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 18:19:03 STOPPED: the base does not compile: FAIL  analyze     (exit 1, 10s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-181848/analyze.log (log .dart_tool/run-jobs/docs_briefs_m16_wave1-789/run-base-check.log); no job of wave 1 was started
  RESULT: STOPPED: the base does not compile: FAIL  analyze     (exit 1, 10s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-181848/analyze.log (log .dart_tool/run-jobs/docs_briefs_m16_wave1-789/run-base-check.log); no job of wave 1 was started
  2026-11-24 18:22:02 RUN_MAX_MIN=119 min (computed backstop of the jobs still to do)
  2026-11-24 18:22:03 start at 0ba463db on m16
  2026-11-24 18:22:03 worker: claude
  2026-11-24 18:22:03 removed the last stop's STOP.md
  2026-11-24 18:22:14 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 18:22:30 skip n9a (already done)
  2026-11-24 18:22:30 WARN: n9c was committed by hand (95a64202); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-24 18:23:46 tests-first ok: controller_app/test/slider_semantics_test.dart fails on the old code
  2026-11-24 18:24:03 finding: tests-first: packages/party_host/test/volume_semantics_test.dart passes on the old code, so it does not prove new behaviour
  2026-11-24 18:24:04 STOPPED: tests-first: packages/party_host/test/volume_semantics_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
