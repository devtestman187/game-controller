STOP 2026-11-27 19:14:10 docs/briefs/m17/race1a
cause: commit of f1c refused (see .dart_tool/run-jobs/docs_briefs_m17_race1a/run-commit.log)
class: commit-refused
repair: read run-commit.log in the work folder, commit the job's named paths by hand, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 19:06:27 start at cfdbc40d on m17
  2026-11-27 19:06:27 worker: claude
  2026-11-27 19:06:28 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 19:06:35 phase: preflight
  2026-11-27 19:06:41 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 19:06:56 phase: worker (preflight took 21s)
  2026-11-27 19:06:57 skip f1a (already done)
  2026-11-27 19:06:57 skip f1d (already done)
  2026-11-27 19:07:13 phase: worker (worker took 17s)
  2026-11-27 19:07:13 skip f1b (already done)
  2026-11-27 19:07:29 phase: worker (worker took 15s)
  2026-11-27 19:07:29 resume f1c (applied by hand, not committed yet)
  2026-11-27 19:07:29 start f1e
  2026-11-27 19:10:10 f1e finished: result 0 (12 turns, 2 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 16/169205/19211/8185
  2026-11-27 19:10:10 phase: tests-first (worker took 162s)
  2026-11-27 19:10:14 phase: check (tests-first took 4s)
  2026-11-27 19:10:35 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-27 19:14:09 phase: apply (check took 235s)
  2026-11-27 19:14:09 finding: f1c's report has no Summary block in its first 40 lines
  2026-11-27 19:14:10 STOPPED: commit of f1c refused (see .dart_tool/run-jobs/docs_briefs_m17_race1a/run-commit.log)
