STOP 2026-11-27 10:14:23 docs/briefs/m17/night2c
cause: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 09:55:27 RUN_MAX_MIN=275 min (computed backstop of the jobs still to do)
  2026-11-27 09:55:27 start at 9117705c on m17
  2026-11-27 09:55:27 worker: claude
  2026-11-27 09:55:29 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 09:55:29 removed the last stop's STOP.md
  2026-11-27 09:55:51 phase: preflight
  2026-11-27 09:55:59 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-27 10:04:23 phase: worker (preflight took 512s)
  2026-11-27 10:04:23 skip v1a (already done)
  2026-11-27 10:04:24 start c1
  2026-11-27 10:04:25 skip t1 (already done)
  2026-11-27 10:10:27 c1 finished: result 0 (48 turns, 5 min) model claude-haiku-5-5, ladder 2, tokens in/read/write/out 68/1512978/51018/24975
  2026-11-27 10:10:27 phase: tests-first (worker took 364s)
  2026-11-27 10:10:32 phase: check (tests-first took 5s)
  2026-11-27 10:10:39 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-27 10:14:19 phase: apply (check took 227s)
  2026-11-27 10:14:21 committed c1: a8ebf10a night2c c1: old phones get no Roadworks; version text names the app
  2026-11-27 10:14:21 phase: review (apply took 2s)
  2026-11-27 10:14:22 wave 1 review: wave1-review-report.md does not cover c1, so its review is wave1-c1
  2026-11-27 10:14:23 STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
