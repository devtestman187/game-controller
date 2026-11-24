STOP 2026-11-24 17:56:14 docs/briefs/m16/wave1-789
cause: checks failed twice on the combined tree after n9d1 n9a
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  phone       (exit 1, 64s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-175452/phone.log
        Expected: null
          Actual: FlutterError:<A RenderFlex overflowed by 12 pixels on the right.>
        00:04 +39 -1: E:/AI/game-controller-m16/controller_app/test/connect_narrow_test.dart: the manual address row fits a narrow screen (item 9a) the address field and Connect sit inside 568x320 in the TV look [E]
          Test failed. See exception logs above.
        17:55:23.315 [mode] Gyro mode unavailable: This phone has no usable gyroscope, so gyro mode is off (PlatformException(NO_SENSOR, No gyroscope, null, null)).
        17:55:27.058 [haptics] Haptics error (further ones not logged): PlatformException(ENGINE, null, null, null)
        00:56 +658 ~2 -1: Some tests failed.
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-24 17:38:16 RUN_MAX_MIN=219 min (computed backstop of the jobs still to do)
  2026-11-24 17:38:16 start at 8168e09e on m16
  2026-11-24 17:38:16 worker: claude
  2026-11-24 17:38:16 run-base 8168e09ec575d14554069e319f9b16da644d50ba
  2026-11-24 17:38:30 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 17:38:45 start n9a
  2026-11-24 17:39:11 start n9c
  2026-11-24 17:39:36 start n9d1
  2026-11-24 17:43:52 n9d1 finished: result 4 (20 turns, 4 min)
  2026-11-24 17:43:54 n9d1: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzles...
  2026-11-24 17:49:13 n9c finished: result 4 (46 turns, 7 min)
  2026-11-24 17:49:13 job n9c used 46 turns, over its cap of 45 (parked, siblings continue)
  2026-11-24 17:50:50 n9a finished: result 4 (59 turns, 10 min)
  2026-11-24 17:50:52 n9a: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzles/...
  2026-11-24 17:52:09 tests-first ok: controller_app/test/connect_narrow_test.dart fails on the old code
  2026-11-24 17:52:20 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-24 17:54:49 checks failed; fetching packages and trying once more
  2026-11-24 17:56:14 STOPPED: checks failed twice on the combined tree after n9d1 n9a
