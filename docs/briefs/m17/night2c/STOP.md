STOP 2026-11-27 09:42:11 docs/briefs/m17/night2c
cause: jobs that failed or passed their limit (parked, not committed): c1 (their logs: docs/briefs/m17/night2c/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 09:16:14 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 09:16:50 phase: worker (preflight took 43s)
  2026-11-27 09:16:50 start v1a
  2026-11-27 09:17:16 start c1
  2026-11-27 09:23:14 start t1
  2026-11-27 09:23:15 v1a finished: result 0 (48 turns, 5 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 50/1086962/64268/21947
  2026-11-27 09:24:20 c1 finished: result 1 (36 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 70/1488929/51874/24779
  2026-11-27 09:24:21 job c1 used 36 turns, over its cap of 35 (parked, siblings continue)
  2026-11-27 09:24:22 job c1 parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_night2c/parked-c1.patch and out of the tree (the siblings' check does not see them)
  2026-11-27 09:29:56 t1 finished: result 0 (45 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 60/1585862/59644/39713
  2026-11-27 09:29:57 phase: tests-first (worker took 787s)
  2026-11-27 09:31:24 tests-first ok: packages/party_host/test/night_vote_test.dart fails on the old code
  2026-11-27 09:32:08 phase: check (tests-first took 131s)
  2026-11-27 09:32:15 combined check: skips protocol connection metrics kit look arena puzzle (no job's change reaches them)
  2026-11-27 09:42:06 phase: apply (check took 598s)
  2026-11-27 09:42:07 finding: v1a's report has no Summary block in its first 40 lines
  2026-11-27 09:42:08 committed v1a: 645cfbca night2c v1a: Vote engine and the vote pick
  2026-11-27 09:42:10 committed t1: fb20f723 agent-cost: per-agent split and driver REPORT line (--agents)
  2026-11-27 09:42:10 phase: review (apply took 4s)
  2026-11-27 09:42:11 STOPPED: jobs that failed or passed their limit (parked, not committed): c1 (their logs: docs/briefs/m17/night2c/flash-<job>.log)
