STOP 2026-11-26 23:00:01 docs/briefs/m17/night2a
cause: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 22:36:40 start d2a
  2026-11-26 22:37:06 start d2c
  2026-11-26 22:44:41 start k1
  2026-11-26 22:44:43 d2a finished: result 0 (33 turns, 2 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 30/655814/50250/19924
  2026-11-26 22:44:43 WARN: d2a logged 33 turns, 2 min but ran 8 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-26 22:47:58 d2c finished: result 0 (8 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 16/158208/17917/11074
  2026-11-26 22:47:59 WARN: d2c logged 8 turns, 3 min but ran 10 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-26 22:52:30 k1 finished: result 0 (27 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 32/437650/26674/12707
  2026-11-26 22:52:31 phase: tests-first (worker took 950s)
  2026-11-26 22:53:56 tests-first ok: packages/party_host/test/night_variant_test.dart fails on the old code
  2026-11-26 22:54:11 tests-first ok: packages/test_game/test/map_tier_test.dart fails on the old code
  2026-11-26 22:54:46 phase: check (tests-first took 136s)
  2026-11-26 22:55:03 combined check: skips protocol connection metrics look tools (no job's change reaches them)
  2026-11-26 22:59:53 phase: apply (check took 307s)
  2026-11-26 22:59:53 finding: d2a's report has no Summary block in its first 40 lines
  2026-11-26 22:59:55 committed d2a: 097e2e7d m17 d2a: Arena maps can say their difficulty tier
  2026-11-26 22:59:57 committed d2c: 2f071d86 m17 d2c: Variant model, launch variants and pool filter
  2026-11-26 22:59:59 committed k1: 53724b58 Cap the cat at A little in Kids nights
  2026-11-26 22:59:59 phase: review (apply took 6s)
  2026-11-26 23:00:00 STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
