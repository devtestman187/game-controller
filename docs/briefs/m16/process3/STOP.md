STOP 2026-11-22 04:01:17 docs/briefs/m16/process3
cause: CHECK TIMEOUT: the combined check passed RUN_CHECK_MAX_MIN=12 min and was killed
class: timeout
repair: the run passed RUN_MAX_MIN: read the last run.log job, stop the runner if it is stuck, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 02:23:11 p3c finished: result 0 (67 turns, 30 min)
  2026-11-22 02:35:41 committed p3a: c6b21038 wait-run: OVERRUN once per job, a checking result, resume as a start
  2026-11-22 02:35:44 committed p3b: d53bcfc6 Fail-fast check.sh and per-script limits for selftest.sh
  2026-11-22 02:35:46 committed p3c: 0eb48804 tools: run-limits.sh, a watched combined check and a review limit
  2026-11-22 02:35:48 start p3d
  2026-11-22 02:36:14 start p3e
  2026-11-22 03:24:06 p3d finished: result 5 (67 turns, 43 min)
  2026-11-22 03:24:06 p3e finished: result 0 (74 turns, 32 min)
  2026-11-22 03:36:07 checks failed; fetching packages and trying once more
  2026-11-22 03:48:41 STOPPED: checks failed twice on the combined tree after p3e (see .dart_tool/run-jobs/docs_briefs_m16_process3/run-check.log); nothing of this wave is committed
  2026-11-22 03:48:52 reviewed wave1: 16 finding(s)
  2026-11-22 03:49:00 HAND-FIX p3d: raised the stale runner size limit in tools/tests/run-jobs-split-test.sh from 340 to 380 lines (the p3d brief allows 370, p3f adds a few); only failing check
  2026-11-22 03:49:01 start at 620a745e on m16
  2026-11-22 03:49:11 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 03:49:12 skip p3a (already done)
  2026-11-22 03:49:13 skip p3b (already done)
  2026-11-22 03:49:13 skip p3c (already done)
  2026-11-22 03:49:14 resume p3d (applied by hand, not committed yet)
  2026-11-22 03:49:14 resume p3e (applied by hand, not committed yet)
  2026-11-22 04:01:17 STOPPED: CHECK TIMEOUT: the combined check passed RUN_CHECK_MAX_MIN=12 min and was killed
