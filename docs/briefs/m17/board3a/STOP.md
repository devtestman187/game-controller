STOP 2026-11-26 23:18:34 docs/briefs/m17/board3a
cause: commit of g3b refused (see .dart_tool/run-jobs/docs_briefs_m17_board3a/run-commit.log)
class: commit-refused
repair: read run-commit.log in the work folder, commit the job's named paths by hand, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 23:15:43 DONE: every job is committed. Claude reads the Summary of docs/briefs/m17/board3a/REVIEW.md, verifies its findings and writes one fix brief
  RESULT: DONE: 4 jobs, 16 min
  2026-11-26 23:16:54 RUN_MAX_MIN=45 min (computed backstop of the jobs still to do)
  2026-11-26 23:16:54 start at b7510a95 on board-line
  2026-11-26 23:16:54 worker: claude
  2026-11-26 23:16:55 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-26 23:17:00 phase: preflight
  2026-11-26 23:17:05 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-26 23:17:21 phase: worker (preflight took 21s)
  2026-11-26 23:17:21 skip g3a (already done)
  2026-11-26 23:17:22 skip g3s (already done)
  2026-11-26 23:17:37 phase: worker (worker took 16s)
  2026-11-26 23:17:38 skip f3a (already done)
  2026-11-26 23:17:53 phase: worker (worker took 16s)
  2026-11-26 23:17:53 resume g3b (applied by hand, not committed yet)
  2026-11-26 23:17:54 phase: tests-first (worker took 1s)
  2026-11-26 23:17:54 phase: check (tests-first took 0s)
  2026-11-26 23:18:00 combined check: skips protocol connection metrics kit look arena puzzle host phone tv tools (no job's change reaches them)
  2026-11-26 23:18:33 phase: apply (check took 39s)
  2026-11-26 23:18:34 STOPPED: commit of g3b refused (see .dart_tool/run-jobs/docs_briefs_m17_board3a/run-commit.log)
