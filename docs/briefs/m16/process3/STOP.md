STOP 2026-11-22 05:06:01 docs/briefs/m16/process3
cause: job p3f passed its limit (22 min, estimate 15)
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 04:01:50 resume p3d (applied by hand, not committed yet)
  2026-11-22 04:01:50 resume p3e (applied by hand, not committed yet)
  2026-11-22 04:13:17 checks failed; fetching packages and trying once more
  2026-11-22 04:25:02 STOPPED: checks failed twice on the combined tree after p3d p3e
  RESULT: STOPPED: checks failed twice on the combined tree after p3d p3e
  2026-11-22 04:30:52 HAND-FIX p3c: RUN_CHECK_MAX_MIN default 12 -> 20 in tools/run-limits.sh (a normal full check takes about 12 min on this PC; main session decision); exporting RUN_CHECK_MAX_MIN=20 made tools/tests/run-wire-test.sh fail 7 cases (env leak), so the default was changed instead and the...
  2026-11-22 04:30:53 start at 2ac1ee22 on m16
  2026-11-22 04:31:03 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 04:31:03 skip p3a (already done)
  2026-11-22 04:31:04 skip p3b (already done)
  2026-11-22 04:31:04 WARN: p3c was committed by hand (0eb48804); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 04:31:05 hand-fixed p3c: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 04:31:05 skip p3c (already done)
  2026-11-22 04:31:06 wave 1 review skipped: the committed wave1-review-report.md already covers p3c
  2026-11-22 04:31:06 resume p3d (applied by hand, not committed yet)
  2026-11-22 04:31:07 resume p3e (applied by hand, not committed yet)
  2026-11-22 04:43:23 committed p3d: 269882af tools: per-job limits, a turn cap and a RESULT line in the runner
  2026-11-22 04:43:25 committed p3e: c013ff71 p3e: add a stand-in worker for runner rehearsals
  2026-11-22 04:43:27 start p3f
  2026-11-22 05:06:00 STOPPED: job p3f passed its limit (22 min, estimate 15)
