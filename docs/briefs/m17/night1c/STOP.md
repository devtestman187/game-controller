STOP 2026-11-26 20:11:10 docs/briefs/m17/night1c
cause: PAUSED after wave 2 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 19:48:24 phase: worker (worker took 17s)
  2026-11-26 19:48:24 start n1g
  2026-11-26 19:48:50 start n1i
  2026-11-26 19:55:08 start n1j
  2026-11-26 19:55:09 n1g finished: result 0 (38 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 54/1514681/69333/42944
  2026-11-26 19:57:56 n1i finished: result 0 (38 turns, 6 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 58/1557284/74741/38248
  2026-11-26 20:01:16 n1j finished: result 0 (28 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 32/479487/31646/13863
  2026-11-26 20:01:17 phase: tests-first (worker took 773s)
  2026-11-26 20:02:42 tests-first ok: packages/party_host/test/night_controls_test.dart fails on the old code
  2026-11-26 20:03:01 tests-first ok: packages/party_host/test/night_roster_wiring_test.dart fails on the old code
  2026-11-26 20:03:07 tests-first ok: packages/party_host/test/night_round_hook_test.dart fails on the old code
  2026-11-26 20:03:15 tests-first: packages/party_host/test/night_scoreboard_champions_test.dart passes on the old code, exempt by its brief
  2026-11-26 20:04:23 phase: check (tests-first took 186s)
  2026-11-26 20:04:49 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-26 20:11:04 phase: apply (check took 401s)
  2026-11-26 20:11:05 committed n1g: 25e9dbe2 Night controller: host pause, skip, reroll and roster events
  2026-11-26 20:11:07 committed n1i: 1a824409 night: the controller starts the next round from the night's screens
  2026-11-26 20:11:09 committed n1j: 6569460e night scoreboard: crown the champions via championsAmong
  2026-11-26 20:11:09 phase: review (apply took 5s)
  2026-11-26 20:11:10 STOPPED: PAUSED after wave 2 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
