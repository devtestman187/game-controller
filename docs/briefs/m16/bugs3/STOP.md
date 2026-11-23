STOP 2026-11-23 17:01:29 docs/briefs/m16/bugs3
cause: checks failed twice on the combined tree after b037 b038 wrap320
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  host        (exit 1, 92s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261123-165931/host.log
        17:00:12.476 [host] Best times: FormatException: Unexpected character (at character 1)
        17:00:12.490 [host] Best times: FormatException: Unexpected character (at character 1)
        00:32 +352 -1: E:/AI/game-controller-m16/packages/party_host/test/live_stats_answer_kept_test.dart: a yes given before the pause still shares in the resumed session, and a no stays no [E]
          Expected: null
            Actual: <Instance of 'SessionCollector'>
        Expected: a value greater than or equal to <19.99>
  (+18 more)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-23 16:35:14 RUN_MAX_MIN=88 min (computed backstop of the jobs still to do)
  2026-11-23 16:35:14 start at ee87cb56 on m16
  2026-11-23 16:35:14 worker: claude
  2026-11-23 16:35:14 run-base ee87cb56ec66ed7f42e8639afe133396daf9a1b8
  2026-11-23 16:35:33 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 16:35:59 start b037
  2026-11-23 16:36:25 start b038
  2026-11-23 16:36:50 start wrap320
  2026-11-23 16:43:12 b037 finished: result 4 (47 turns, 6 min)
  2026-11-23 16:43:14 b037: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzles...
  2026-11-23 16:44:01 b038 finished: result 4 (26 turns, 4 min)
  2026-11-23 16:44:03 b038: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzles...
  2026-11-23 16:51:54 wrap320 finished: result 4 (2 turns, 0 min)
  2026-11-23 16:51:56 wrap320: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzz...
  2026-11-23 16:53:45 tests-first ok: packages/party_host/test/score_row_winner_fit_test.dart fails on the old code
  2026-11-23 16:54:01 tests-first ok: packages/puzzle_game/test/puzzle_module_bar_test.dart fails on the old code
  2026-11-23 16:55:08 combined check: skips protocol connection metrics kit look arena tools (no job's change reaches them)
  2026-11-23 16:59:26 checks failed; fetching packages and trying once more
  2026-11-23 17:01:29 STOPPED: checks failed twice on the combined tree after b037 b038 wrap320
