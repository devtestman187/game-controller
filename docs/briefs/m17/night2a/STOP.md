STOP 2026-11-26 23:03:19 docs/briefs/m17/night2a
cause: brief gate: brief-check failed: FAIL changes d2b: tier is used in packages/party_host/lib/src/night/variant.dart, which no job of wave 2 or earlier allows
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
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
  2026-11-26 23:02:29 reviewed wave1: 7 finding(s)
  RESULT: STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
  2026-11-26 23:03:06 RUN_MAX_MIN=75 min (computed backstop of the jobs still to do)
  2026-11-26 23:03:07 start at 322f32f0 on m17
  2026-11-26 23:03:07 worker: claude
  2026-11-26 23:03:08 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-26 23:03:08 removed the last stop's STOP.md
  2026-11-26 23:03:19 STOPPED: brief gate: brief-check failed: FAIL changes d2b: tier is used in packages/party_host/lib/src/night/variant.dart, which no job of wave 2 or earlier allows
