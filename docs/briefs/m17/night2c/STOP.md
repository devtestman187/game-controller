STOP 2026-11-27 09:55:10 docs/briefs/m17/night2c
cause: the base check passed its limit (RUN_BASE_CHECK_MAX_MIN=5 min) (log .dart_tool/run-jobs/docs_briefs_m17_night2c/run-base-check.log); no job of wave 1 was started
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 09:31:24 tests-first ok: packages/party_host/test/night_vote_test.dart fails on the old code
  2026-11-27 09:32:08 phase: check (tests-first took 131s)
  2026-11-27 09:32:15 combined check: skips protocol connection metrics kit look arena puzzle (no job's change reaches them)
  2026-11-27 09:42:06 phase: apply (check took 598s)
  2026-11-27 09:42:07 finding: v1a's report has no Summary block in its first 40 lines
  2026-11-27 09:42:08 committed v1a: 645cfbca night2c v1a: Vote engine and the vote pick
  2026-11-27 09:42:10 committed t1: fb20f723 agent-cost: per-agent split and driver REPORT line (--agents)
  2026-11-27 09:42:10 phase: review (apply took 4s)
  2026-11-27 09:42:11 STOPPED: jobs that failed or passed their limit (parked, not committed): c1 (their logs: docs/briefs/m17/night2c/flash-<job>.log)
  2026-11-27 09:42:55 RUN_MAX_MIN=238 min (computed backstop of the jobs still to do)
  2026-11-27 09:45:14 reviewed wave1: 15 finding(s)
  RESULT: STOPPED: jobs that failed or passed their limit (parked, not committed): c1 (their logs: docs/briefs/m17/night2c/flash-<job>.log)
  2026-11-27 09:49:05 RUN_MAX_MIN=275 min (computed backstop of the jobs still to do)
  2026-11-27 09:49:06 start at 2c85a70d on m17
  2026-11-27 09:49:06 worker: claude
  2026-11-27 09:49:09 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 09:49:09 removed the last stop's STOP.md
  2026-11-27 09:49:49 phase: preflight
  2026-11-27 09:50:09 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 09:55:10 STOPPED: the base check passed its limit (RUN_BASE_CHECK_MAX_MIN=5 min) (log .dart_tool/run-jobs/docs_briefs_m17_night2c/run-base-check.log); no job of wave 1 was started
