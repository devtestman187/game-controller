STOP 2026-11-24 15:43:19 docs/briefs/m16/version1
cause: tests-first: controller_app/test/app_version_test.dart tv_test_app/test/app_version_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
class: tests-first
repair: fix the test so it fails on the old code (never the gate), or add "tests-first: exempt <reason>" to the brief for a pure refactor (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-24 15:35:46 RUN_MAX_MIN=125 min (computed backstop of the jobs still to do)
  2026-11-24 15:35:46 start at 5a3877b7 on m16
  2026-11-24 15:35:46 worker: claude
  2026-11-24 15:35:46 run-base 5a3877b7bb56d2ed34f0045936cde5a3c9cff7da
  2026-11-24 15:35:55 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 15:36:10 start tagver
  2026-11-24 15:36:36 start appver
  2026-11-24 15:37:01 start aggcost
  2026-11-24 15:37:33 tagver finished: result 4 (17 turns, 1 min)
  2026-11-24 15:37:35 tagver: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzl...
  2026-11-24 15:38:21 aggcost finished: result 4 (12 turns, 1 min)
  2026-11-24 15:38:23 aggcost: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzz...
  2026-11-24 15:41:52 appver finished: result 4 (21 turns, 3 min)
  2026-11-24 15:41:53 appver: dropped generated churn outside its list: docs/design/m13-placed-look.png docs/design/puzzles/boat.png docs/design/puzzles/butterfly.png docs/design/puzzles/car.png docs/design/puzzles/castle.png docs/design/puzzles/fish.png docs/design/puzzles/house.png docs/design/puzzl...
  2026-11-24 15:43:08 finding: tests-first: controller_app/test/app_version_test.dart passes on the old code, so it does not prove new behaviour
  2026-11-24 15:43:18 finding: tests-first: tv_test_app/test/app_version_test.dart passes on the old code, so it does not prove new behaviour
  2026-11-24 15:43:19 STOPPED: tests-first: controller_app/test/app_version_test.dart tv_test_app/test/app_version_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
