STOP 2026-11-22 09:14:03 docs/briefs/m16/identity1
cause: tools/review.sh found a FAIL after i1d i1f i1e2 (see .dart_tool/run-jobs/docs_briefs_m16_identity1/run-review.log); nothing of this wave is committed
class: review-fail
repair: run bash tools/review.sh, fix the FAIL lines it prints in the code (never a rule), then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 08:57:09 RUN_MAX_MIN=69 min (computed backstop of the jobs still to do)
  2026-11-22 08:57:10 start at 573c24f6 on m16
  2026-11-22 08:57:10 removed the last stop's STOP.md
  2026-11-22 08:57:22 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 08:57:43 STOPPED: stop file
  RESULT: STOPPED: stop file
  2026-11-22 08:58:23 RUN_MAX_MIN=69 min (computed backstop of the jobs still to do)
  2026-11-22 08:58:24 start at f1d5f9ff on m16
  2026-11-22 08:58:24 removed the old stop file
  2026-11-22 08:58:24 removed the last stop's STOP.md
  2026-11-22 08:58:35 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 08:59:01 skip i1a (already done)
  2026-11-22 08:59:02 skip i1b (already done)
  2026-11-22 08:59:02 skip i1c (already done)
  2026-11-22 08:59:23 resume i1d (applied by hand, not committed yet)
  2026-11-22 08:59:23 resume i1f (applied by hand, not committed yet)
  2026-11-22 08:59:24 resume i1e2 (applied by hand, not committed yet)
  2026-11-22 09:00:02 tests-first ok: packages/connection/test/identity_host_test.dart fails on the old code
  2026-11-22 09:00:16 tests-first ok: packages/test_game/test/arena_identity_test.dart fails on the old code
  2026-11-22 09:14:03 STOPPED: tools/review.sh found a FAIL after i1d i1f i1e2 (see .dart_tool/run-jobs/docs_briefs_m16_identity1/run-review.log); nothing of this wave is committed
