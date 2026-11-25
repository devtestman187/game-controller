STOP 2026-11-24 18:15:59 docs/briefs/m16/wave1-789
cause: checks failed twice on the combined tree after n9a n9d1
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
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
  2026-11-24 17:50:52 n9a: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzles/...
  2026-11-24 17:52:09 tests-first ok: controller_app/test/connect_narrow_test.dart fails on the old code
  2026-11-24 17:52:20 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-24 17:54:49 checks failed; fetching packages and trying once more
  2026-11-24 17:56:14 STOPPED: checks failed twice on the combined tree after n9d1 n9a
  RESULT: STOPPED: checks failed twice on the combined tree after n9d1 n9a
  2026-11-24 17:56:55 RUN_MAX_MIN=219 min (computed backstop of the jobs still to do)
  2026-11-24 17:56:55 start at da2771a9 on m16
  2026-11-24 17:56:55 worker: claude
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
