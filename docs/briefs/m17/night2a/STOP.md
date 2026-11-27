STOP 2026-11-26 23:26:04 docs/briefs/m17/night2a
cause: jobs that failed or passed their limit (parked, not committed): d2b (their logs: docs/briefs/m17/night2a/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 23:04:55 start d2b
  2026-11-26 23:05:21 start d2d
  2026-11-26 23:09:43 start d2e
  2026-11-26 23:09:44 d2b finished: result 5 (20 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 28/331028/21445/10224
  2026-11-26 23:09:44 job d2b parked (result 5); its siblings continue
  2026-11-26 23:09:47 job d2b parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_night2a/parked-d2b.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 23:09:47 d2d finished: result 0 (11 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 22/267597/27716/20620
  2026-11-26 23:18:22 d2e finished: result 0 (1 turns, 0 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 4/48817/435/40
  2026-11-26 23:18:22 WARN: d2e logged 1 turns, 0 min but ran 8 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-26 23:18:23 phase: tests-first (worker took 808s)
  2026-11-26 23:19:42 tests-first ok: packages/party_host/test/night_director_test.dart fails on the old code
  2026-11-26 23:19:54 tests-first ok: packages/party_host/test/night_pickers_test.dart fails on the old code
  2026-11-26 23:20:31 phase: check (tests-first took 128s)
  2026-11-26 23:20:38 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-26 23:24:00 checks failed; fetching packages and trying once more
  2026-11-26 23:25:59 phase: apply (check took 328s)
  2026-11-26 23:26:01 committed d2d: bd06c717 party_host: NightDirector picks the next variant and says why
  2026-11-26 23:26:03 committed d2e: fdbfdba3 party_host: add the Shuffle, Playlist and Rotating chooser pickers
  2026-11-26 23:26:03 phase: review (apply took 4s)
  2026-11-26 23:26:04 STOPPED: jobs that failed or passed their limit (parked, not committed): d2b (their logs: docs/briefs/m17/night2a/flash-<job>.log)
