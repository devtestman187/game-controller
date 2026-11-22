STOP 2026-11-22 14:07:42 docs/briefs/m16/process4
cause: jobs that failed or passed their limit (parked, not committed): p4g (their logs: docs/briefs/m16/process4/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  RESULT: STOPPED: job p4d passed its limit (45 min, estimate 30)
  HAND-FIX p4c: copied tools/run-jobs.sh, tools/run-wave.sh, tools/tests/run-wave-test.sh, tools/tests/run-wire-test.sh, tools/tests/run-base-test.sh, tools/tests/run-jobs-split-test.sh, tools/tests/run-limits-wire-test.sh, tools/tests/process3-fix1-test.sh from the kept tree (worker killed by p4d's l...
  HAND-FIX p4d: copied tools/apply-job.sh, tools/tests/apply-job-test.sh from the kept tree (worker passed its limit); wrote p4d-report.md
  2026-11-22 13:28:49 RUN_MAX_MIN=45 min (computed backstop of the jobs still to do)
  2026-11-22 13:28:49 start at 9ef5dc70 on m16
  2026-11-22 13:28:49 removed the last stop's STOP.md
  2026-11-22 13:29:00 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 13:29:21 skip p4a (already done)
  2026-11-22 13:29:21 skip p4b (already done)
  2026-11-22 13:29:22 skip p4e (already done)
  2026-11-22 13:29:43 WARN: p4c was committed by hand (f458237e); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 13:29:44 hand-fixed p4c: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 13:29:44 skip p4c (already done)
  2026-11-22 13:29:45 WARN: p4d was committed by hand (df1295aa); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 13:29:46 hand-fixed p4d: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 13:29:46 skip p4d (already done)
  2026-11-22 13:29:46 skip p4f (already done)
  2026-11-22 13:30:09 start p4g
  2026-11-22 14:07:41 job p4g passed its limit (37 min, estimate 25) (parked, siblings continue)
  2026-11-22 14:07:41 STOPPED: jobs that failed or passed their limit (parked, not committed): p4g (their logs: docs/briefs/m16/process4/flash-<job>.log)
