STOP 2026-11-27 02:07:47 docs/briefs/m17/night2b
cause: the base check passed its limit (RUN_BASE_CHECK_MAX_MIN=5 min) (log .dart_tool/run-jobs/docs_briefs_m17_night2b/run-base-check.log); no job of wave 1 was started
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 01:53:08 tests-first ok: packages/party_host/test/night_pick_open_test.dart fails on the old code
  2026-11-27 01:53:18 tests-first ok: packages/party_host/test/night_setup_options_test.dart fails on the old code
  2026-11-27 01:54:06 phase: check (tests-first took 165s)
  2026-11-27 01:54:24 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-27 01:57:53 phase: apply (check took 227s)
  2026-11-27 01:57:55 committed d2h: 1a6c27ad Night how-to card carries the director's reason
  2026-11-27 01:57:56 committed d2i: 08e0178d Setup: offer only what a night can play (d2i)
  2026-11-27 01:57:58 committed d2x: c6c669af party_host: a night's next round opens the game its pick chose
  2026-11-27 01:57:58 phase: review (apply took 5s)
  2026-11-27 01:57:59 STOPPED: PAUSED after wave 2 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
  2026-11-27 02:00:41 reviewed wave2: 8 finding(s)
  RESULT: STOPPED: PAUSED after wave 2 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
  2026-11-27 02:02:28 RUN_MAX_MIN=119 min (computed backstop of the jobs still to do)
  2026-11-27 02:02:29 start at 18d4f96a on m17
  2026-11-27 02:02:29 worker: claude
  2026-11-27 02:02:30 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 02:02:30 removed the last stop's STOP.md
  2026-11-27 02:02:38 phase: preflight
  2026-11-27 02:02:45 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 02:07:47 STOPPED: the base check passed its limit (RUN_BASE_CHECK_MAX_MIN=5 min) (log .dart_tool/run-jobs/docs_briefs_m17_night2b/run-base-check.log); no job of wave 1 was started
