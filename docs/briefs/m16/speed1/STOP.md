STOP 2026-11-23 12:45:04 docs/briefs/m16/speed1
cause: REVIEW TIMEOUT: the run's review passed RUN_REVIEW_MAX_MIN=10 min and was killed
class: timeout
repair: the run passed RUN_MAX_MIN: read the last run.log job, stop the runner if it is stuck, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-23 12:18:03 reviewed wave2: 9 finding(s)
  RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): sp3 (their logs: docs/briefs/m16/speed1/flash-<job>.log)
  HAND-FIX sp3: apply-job.sh applied 5 files: docs/briefs/m16/speed1/sp3-report.md, tools/check-cache.sh, tools/check-par.sh, tools/check.sh, tools/tests/check-cache-test.sh
  2026-11-23 12:31:29 RUN_MAX_MIN=20 min (computed backstop of the jobs still to do)
  2026-11-23 12:31:29 start at 190373ad on m16
  2026-11-23 12:31:29 worker: claude
  2026-11-23 12:31:30 removed the last stop's STOP.md
  2026-11-23 12:31:40 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-23 12:32:01 skip sp1 (already done)
  2026-11-23 12:32:01 skip sp2 (already done)
  2026-11-23 12:32:02 skip sp5 (already done)
  2026-11-23 12:32:23 WARN: sp3 was committed by hand (3a15cabf); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-23 12:32:24 hand-fixed sp3: tests-first proof and worker review done (marked in done.txt)
  2026-11-23 12:32:24 skip sp3 (already done)
  2026-11-23 12:32:24 skip sp4 (already done)
  2026-11-23 12:32:25 skip sp6 (already done)
  2026-11-23 12:32:25 wave 2 review: wave2-review-report.md does not cover sp3, so its review is wave2-sp3
  2026-11-23 12:34:59 reviewed wave2-sp3: 10 finding(s)
  2026-11-23 12:35:00 start the run's review
  2026-11-23 12:45:04 STOPPED: REVIEW TIMEOUT: the run's review passed RUN_REVIEW_MAX_MIN=10 min and was killed
