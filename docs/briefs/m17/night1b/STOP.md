STOP 2026-11-26 18:02:37 docs/briefs/m17/night1b
cause: jobs that failed or passed their limit (parked, not committed): e0c (their logs: docs/briefs/m17/night1b/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 17:39:48 committed n1c: e390700f m17 night1b n1c: cap nights at 5 rounds
  2026-11-26 17:39:50 committed e0e: 016bad75 party_host: "Game full" for a joiner past the cap
  2026-11-26 17:39:50 phase: review (apply took 3s)
  2026-11-26 17:40:06 phase: worker (review took 16s)
  2026-11-26 17:40:07 start n1d
  2026-11-26 17:46:27 n1d finished: result 0 (23 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 30/425811/33244/13018
  2026-11-26 17:46:27 phase: tests-first (worker took 381s)
  2026-11-26 17:47:58 tests-first ok: packages/party_host/test/night_scoring_test.dart fails on the old code
  2026-11-26 17:48:08 phase: check (tests-first took 101s)
  2026-11-26 17:48:12 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-26 17:51:20 phase: apply (check took 192s)
  2026-11-26 17:51:22 committed n1d: b4459fef party_host: championsAmong gives the Quick night champion
  2026-11-26 17:51:22 phase: review (apply took 2s)
  2026-11-26 17:51:23 reviewed wave1: 7 finding(s)
  2026-11-26 17:51:39 phase: worker (review took 16s)
  2026-11-26 17:51:39 start e0c
  2026-11-26 18:02:36 e0c finished: result 5 (53 turns, 8 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 76/2451118/81523/45638
  2026-11-26 18:02:36 job e0c parked (result 5); its siblings continue
  2026-11-26 18:02:37 job e0c parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_night1b/parked-e0c.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 18:02:37 STOPPED: jobs that failed or passed their limit (parked, not committed): e0c (their logs: docs/briefs/m17/night1b/flash-<job>.log)
