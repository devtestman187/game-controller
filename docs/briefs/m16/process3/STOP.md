STOP 2026-11-22 07:02:11 docs/briefs/m16/process3
cause: commit of f1 refused (see .dart_tool/run-jobs/docs_briefs_m16_process3/run-commit.log)
class: commit-refused
repair: read run-commit.log in the work folder, commit the job's named paths by hand, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 05:59:59 skip p3d (already done)
  2026-11-22 05:59:59 skip p3e (already done)
  2026-11-22 06:00:21 WARN: p3f was committed by hand (4d08818b); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-22 06:00:22 hand-fixed p3f: tests-first proof and worker review done (marked in done.txt)
  2026-11-22 06:00:22 skip p3f (already done)
  2026-11-22 06:00:22 wave 3 review skipped: the committed wave3-review-report.md already covers p3f
  2026-11-22 06:00:43 start f1
  2026-11-22 06:45:45 STOPPED: job f1 passed its limit (45 min, estimate 30)
  RESULT: STOPPED: job f1 passed its limit (45 min, estimate 30)
  2026-11-22 06:47:29 HAND-FIX f1: copied the worker's five files from its kept worktree (it hit the 45 min job limit before writing a report); wrote f1-report.md; process3-fix1-test and run-jobs-split-test pass
  2026-11-22 06:47:30 start at 96b0fafe on m16
  2026-11-22 06:47:39 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 06:48:00 skip p3a (already done)
  2026-11-22 06:48:01 skip p3b (already done)
  2026-11-22 06:48:01 skip p3c (already done)
  2026-11-22 06:48:22 skip p3d (already done)
  2026-11-22 06:48:23 skip p3e (already done)
  2026-11-22 06:48:43 skip p3f (already done)
  2026-11-22 06:49:04 resume f1 (applied by hand, not committed yet)
  2026-11-22 07:02:10 STOPPED: commit of f1 refused (see .dart_tool/run-jobs/docs_briefs_m16_process3/run-commit.log)
