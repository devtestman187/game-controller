STOP 2026-11-26 19:39:39 docs/briefs/m17/night1c
cause: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 19:21:11 start n1f
  2026-11-26 19:21:36 start n1h
  2026-11-26 19:27:03 start e0d
  2026-11-26 19:27:04 n1h finished: result 0 (27 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 34/557589/39190/25239
  2026-11-26 19:27:20 n1f finished: result 0 (40 turns, 6 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 40/780823/49958/22426
  2026-11-26 19:29:55 e0d finished: result 0 (14 turns, 2 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 14/128707/14718/5738
  2026-11-26 19:29:56 phase: tests-first (worker took 526s)
  2026-11-26 19:31:11 tests-first ok: packages/party_host/test/night_flow_controller_test.dart fails on the old code
  2026-11-26 19:31:28 tests-first ok: packages/party_host/test/night_flow_provider_test.dart fails on the old code
  2026-11-26 19:31:45 tests-first ok: packages/party_host/test/night_settings_test.dart fails on the old code
  2026-11-26 19:32:04 tests-first ok: packages/party_host/test/player_badge_ring_test.dart fails on the old code
  2026-11-26 19:33:26 phase: check (tests-first took 210s)
  2026-11-26 19:33:42 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-26 19:37:15 checks failed; fetching packages and trying once more
  2026-11-26 19:39:32 phase: apply (check took 366s)
  2026-11-26 19:39:34 committed n1h: 71c6f3bd m17 night1c n1h: saved night settings and the Kids preset
  2026-11-26 19:39:36 committed n1f: 302bb451 night1c n1f: night flow controller auto-advances rounds
  2026-11-26 19:39:38 committed e0d: e91bf9e7 m17 e0d: ring on host badges of players 7 and 8
  2026-11-26 19:39:38 phase: review (apply took 6s)
  2026-11-26 19:39:39 STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
