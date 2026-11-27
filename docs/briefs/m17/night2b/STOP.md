STOP 2026-11-27 01:15:01 docs/briefs/m17/night2b
cause: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 01:06:14 worker: claude
  2026-11-27 01:06:15 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 01:06:15 removed the last stop's STOP.md
  2026-11-27 01:06:41 phase: preflight
  2026-11-27 01:06:48 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 01:07:03 phase: worker (preflight took 22s)
  2026-11-27 01:07:04 resume d2w (applied by hand, not committed yet)
  2026-11-27 01:07:04 resume d2f (applied by hand, not committed yet)
  2026-11-27 01:07:04 phase: tests-first (worker took 1s)
  2026-11-27 01:09:06 tests-first: controller_app/test/choices_vote_test.dart passes on the old code, exempt by its brief
  2026-11-27 01:09:29 tests-first ok: packages/party_host/test/night_pick_test.dart fails on the old code
  2026-11-27 01:09:41 tests-first ok: packages/party_host/test/variant_text_test.dart fails on the old code
  2026-11-27 01:09:54 tests-first ok: packages/party_host/test/vote_round_test.dart fails on the old code
  2026-11-27 01:11:03 phase: check (tests-first took 239s)
  2026-11-27 01:11:23 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-27 01:14:56 phase: apply (check took 233s)
  2026-11-27 01:14:58 committed d2w: 4104f8b7 m17 night2b d2w: the night's pick behind one provider
  2026-11-27 01:15:00 committed d2f: 65f7fcdd Vote round rules and vote card texts for the host
  2026-11-27 01:15:00 phase: review (apply took 4s)
  2026-11-27 01:15:01 STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
