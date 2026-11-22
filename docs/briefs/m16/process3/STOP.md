STOP 2026-11-22 04:25:03 docs/briefs/m16/process3
cause: checks failed twice on the combined tree after p3d p3e
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
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
  RESULT: STOPPED: CHECK TIMEOUT: the combined check passed RUN_CHECK_MAX_MIN=12 min and was killed
  2026-11-22 04:01:37 start at 6c9c83a1 on m16
  2026-11-22 04:01:48 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 04:01:48 skip p3a (already done)
  2026-11-22 04:01:49 skip p3b (already done)
  2026-11-22 04:01:49 skip p3c (already done)
  2026-11-22 04:01:50 resume p3d (applied by hand, not committed yet)
  2026-11-22 04:01:50 resume p3e (applied by hand, not committed yet)
  2026-11-22 04:13:17 checks failed; fetching packages and trying once more
  2026-11-22 04:25:02 STOPPED: checks failed twice on the combined tree after p3d p3e
