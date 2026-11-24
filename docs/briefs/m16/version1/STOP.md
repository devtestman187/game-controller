STOP 2026-11-24 15:46:44 docs/briefs/m16/version1
cause: tests-first: controller_app/test/app_version_test.dart tv_test_app/test/app_version_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
class: tests-first
repair: fix the test so it fails on the old code (never the gate), or add "tests-first: exempt <reason>" to the brief for a pure refactor (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-24 15:43:18 finding: tests-first: tv_test_app/test/app_version_test.dart passes on the old code, so it does not prove new behaviour
  2026-11-24 15:43:19 STOPPED: tests-first: controller_app/test/app_version_test.dart tv_test_app/test/app_version_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
  RESULT: STOPPED: tests-first: controller_app/test/app_version_test.dart tv_test_app/test/app_version_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
  2026-11-24 15:43:39 RUN_MAX_MIN=125 min (computed backstop of the jobs still to do)
  2026-11-24 15:43:39 start at dc78eb6d on m16
  2026-11-24 15:43:39 worker: claude
  2026-11-24 15:43:39 removed the last stop's STOP.md
  2026-11-24 15:43:49 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 15:44:04 STOPPED: stop file
  RESULT: STOPPED: stop file
  2026-11-24 15:45:00 RUN_MAX_MIN=125 min (computed backstop of the jobs still to do)
  2026-11-24 15:45:00 start at cc76ae89 on m16
  2026-11-24 15:45:00 worker: claude
  2026-11-24 15:45:10 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-24 15:45:25 resume tagver (applied by hand, not committed yet)
  2026-11-24 15:45:25 resume appver (applied by hand, not committed yet)
  2026-11-24 15:45:26 resume aggcost (applied by hand, not committed yet)
  2026-11-24 15:46:33 finding: tests-first: controller_app/test/app_version_test.dart passes on the old code, so it does not prove new behaviour
  2026-11-24 15:46:43 finding: tests-first: tv_test_app/test/app_version_test.dart passes on the old code, so it does not prove new behaviour
  2026-11-24 15:46:44 STOPPED: tests-first: controller_app/test/app_version_test.dart tv_test_app/test/app_version_test.dart pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed
