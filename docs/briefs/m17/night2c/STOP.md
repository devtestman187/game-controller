STOP 2026-11-27 11:37:03 docs/briefs/m17/night2c
cause: PAUSED after wave 2 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 11:26:06 hand-fixed c1: tests-first proof and worker review done (marked in done.txt)
  2026-11-27 11:26:06 skip c1 (already done)
  2026-11-27 11:26:07 skip t1 (already done)
  2026-11-27 11:26:07 wave 1 review: wave1-review-report.md does not cover c1, so its review is wave1-c1
  2026-11-27 11:26:29 phase: worker (worker took 25s)
  2026-11-27 11:26:29 resume v2 (applied by hand, not committed yet)
  2026-11-27 11:26:30 resume t2 (applied by hand, not committed yet)
  2026-11-27 11:26:30 resume d1 (applied by hand, not committed yet)
  2026-11-27 11:26:31 phase: tests-first (worker took 2s)
  2026-11-27 11:26:40 phase: check (tests-first took 9s)
  2026-11-27 11:27:15 combined check: skips protocol connection metrics kit look arena puzzle (no job's change reaches them)
  2026-11-27 11:36:55 phase: apply (check took 615s)
  2026-11-27 11:36:55 finding: v2's report has no Summary block in its first 40 lines
  2026-11-27 11:36:57 committed v2: 5a2e4e05 night2c v2: the night director is the default picker
  2026-11-27 11:36:59 committed t2: c5b5834d mine.sh: list untracked files one by one, fail on a folder entry
  2026-11-27 11:36:59 finding: d1's report has no Summary block in its first 40 lines
  2026-11-27 11:37:01 committed d1: 880b275e docs: compat policy, cache remark, Nov 27 owner decisions
  2026-11-27 11:37:01 phase: review (apply took 6s)
  2026-11-27 11:37:03 reviewed wave1-c1: 9 finding(s)
  2026-11-27 11:37:03 STOPPED: PAUSED after wave 2 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
