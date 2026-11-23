STOP 2026-11-23 17:33:04 docs/briefs/m16/bugs3
cause: checks failed twice on the combined tree after b041
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  phone       (exit 1, 71s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261123-173131/phone.log
        17:32:08.328 [mode] Gyro mode unavailable: This phone has no usable gyroscope, so gyro mode is off (PlatformException(NO_SENSOR, No gyroscope, null, null)).
        17:32:13.443 [haptics] Haptics error (further ones not logged): PlatformException(ENGINE, null, null, null)
        00:53 +546 ~2 -1: E:/AI/game-controller-m16/controller_app/test/tablet_shape_race_test.dart: the two sides on a tablet: own side large, the other side a mirror (B-041) a tablet of 1180 x 820 draws its side large and the mirror small [E]
          Expected: not null
            Actual: <null>
        Expected: false
  (+8 more)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-23 17:12:26 RUN_MAX_MIN=75 min (computed backstop of the jobs still to do)
  2026-11-23 17:12:26 start at ae49a443 on m16
  2026-11-23 17:12:26 worker: claude
  2026-11-23 17:12:42 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 17:13:03 WARN: b037 was committed by hand (6e6f32a2); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-23 17:14:53 tests-first ok: packages/party_host/test/score_row_winner_fit_test.dart fails on the old code
  2026-11-23 17:14:55 hand-fixed b037: tests-first proof and worker review done (marked in done.txt)
  2026-11-23 17:14:55 skip b037 (already done)
  2026-11-23 17:14:55 skip b038 (already done)
  2026-11-23 17:14:56 skip wrap320 (already done)
  2026-11-23 17:15:19 start b036
  2026-11-23 17:15:45 start b041
  2026-11-23 17:26:16 b041 finished: result 4 (43 turns, 7 min)
  2026-11-23 17:26:18 b041: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_re...
  2026-11-23 17:27:40 b036 finished: result 4 (61 turns, 12 min)
  2026-11-23 17:27:40 job b036 used 61 turns, over its cap of 60 (parked, siblings continue)
  2026-11-23 17:29:35 tests-first ok: controller_app/test/tablet_shape_race_test.dart fails on the old code
  2026-11-23 17:29:54 combined check: skips protocol connection metrics kit look arena puzzle host tv tools (no job's change reaches them)
  2026-11-23 17:31:27 checks failed; fetching packages and trying once more
  2026-11-23 17:33:03 STOPPED: checks failed twice on the combined tree after b041
