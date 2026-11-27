STOP 2026-11-27 01:57:59 docs/briefs/m17/night2b
cause: PAUSED after wave 2 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 01:24:55 start d2h
  2026-11-27 01:30:17 start d2i
  2026-11-27 01:30:18 d2h finished: result 0 (43 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 54/1057043/49970/25987
  2026-11-27 01:41:36 d2i finished: result 0 (16 turns, 5 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 26/358058/27714/17983
  2026-11-27 01:41:37 WARN: d2i logged 16 turns, 5 min but ran 11 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 01:50:43 d2x finished: result 0 (62 turns, 8 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 92/3183426/96005/53910
  2026-11-27 01:50:43 WARN: d2x logged 62 turns, 8 min but ran 26 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-27 01:51:21 WARN: job d2x used 62 turns, over its cap of 60 (its own checks passed; accepted)
  2026-11-27 01:51:21 phase: tests-first (worker took 1612s)
  2026-11-27 01:52:52 tests-first ok: packages/party_host/test/night_how_to_reason_test.dart fails on the old code
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
