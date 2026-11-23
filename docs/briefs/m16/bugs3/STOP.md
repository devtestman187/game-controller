STOP 2026-11-23 17:57:17 docs/briefs/m16/bugs3
cause: jobs that failed or passed their limit (parked, not committed): b041 (their logs: docs/briefs/m16/bugs3/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
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
  site/shots/dpad.png
  site/shots/join.png
  site/shots/menus.png
  site/shots/results.png
  (+5 more)
run.log (last 20 lines):
  2026-11-23 17:33:03 STOPPED: checks failed twice on the combined tree after b041
  2026-11-23 17:33:05 reviewed wave1: 8 finding(s)
  RESULT: STOPPED: checks failed twice on the combined tree after b041
  HAND-FIX b036: apply-job.sh applied 8 files: docs/briefs/m16/bugs3/b036-report.md, packages/party_host/lib/src/ui/arena_results.dart, packages/party_host/lib/src/ui/game_field.dart, packages/party_host/lib/src/ui/game_screen.dart, packages/party_host/lib/src/ui/winner_banner.dart, packages/party_hos...
  2026-11-23 17:45:48 HAND-FIX b036: applied kept tree, scroll under banner (owner Card scrolls), frame and matrix pins updated
  2026-11-23 17:46:56 RUN_MAX_MIN=45 min (computed backstop of the jobs still to do)
  2026-11-23 17:46:57 start at dfedefa2 on m16
  2026-11-23 17:46:57 worker: claude
  2026-11-23 17:47:10 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 17:47:31 skip b037 (already done)
  2026-11-23 17:47:31 skip b038 (already done)
  2026-11-23 17:47:32 skip wrap320 (already done)
  2026-11-23 17:47:53 WARN: b036 was committed by hand (b1618ff6); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-23 17:49:53 tests-first ok: packages/party_host/test/winner_banner_test.dart fails on the old code
  2026-11-23 17:49:55 hand-fixed b036: tests-first proof and worker review done (marked in done.txt)
  2026-11-23 17:49:55 skip b036 (already done)
  2026-11-23 17:49:56 start b041
  2026-11-23 17:57:17 b041 finished: result 4 (61 turns, 6 min)
  2026-11-23 17:57:17 job b041 used 61 turns, over its cap of 60 (parked, siblings continue)
  2026-11-23 17:57:17 STOPPED: jobs that failed or passed their limit (parked, not committed): b041 (their logs: docs/briefs/m16/bugs3/flash-<job>.log)
