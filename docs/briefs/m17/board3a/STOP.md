STOP 2026-11-26 22:33:52 docs/briefs/m17/board3a
cause: jobs that failed or passed their limit (parked, not committed): f3a (their logs: docs/briefs/m17/board3a/flash-<job>.log)
class: job-failed
repair: open the job's flash-<job>.log, apply its result by hand, append "HAND-FIX <job>: ..." to run.log, restart; two failed repairs of one job: report (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  METRICS g3s worker=claude model=claude-haiku-5-5 turns=21 in=36 out=11131 cache=428208 min=2.9 wall=6.4 result=0
  METRICS run-review worker=claude model=claude-haiku-5-5 turns=17 in=22 out=15631 cache=332803 min=1.3 wall=- result=0
  2026-11-26 22:25:34 DONE: every job is committed. Claude reads the Summary of docs/briefs/m17/board3a/REVIEW.md, verifies its findings and writes one fix brief
  RESULT: DONE: 2 jobs, 26 min
  2026-11-26 22:26:20 RUN_MAX_MIN=45 min (computed backstop of the jobs still to do)
  2026-11-26 22:26:20 start at 279c11ab on board-line
  2026-11-26 22:26:20 worker: claude
  2026-11-26 22:26:21 proc-sweep: ORPHAN 20360 bash 2s "C:/Program Files/Git/bin/../usr/bin/bash.exe" -c "source /c/Users/mrman/.claude/shell-snapshots/snapshot-bash-179555545
  2026-11-26 22:26:21 proc-sweep: proc-sweep: 1 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-26 22:26:23 phase: preflight
  2026-11-26 22:26:29 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-26 22:26:45 phase: worker (preflight took 22s)
  2026-11-26 22:26:45 skip g3a (already done)
  2026-11-26 22:26:46 skip g3s (already done)
  2026-11-26 22:27:01 phase: worker (worker took 16s)
  2026-11-26 22:27:02 start f3a
  2026-11-26 22:33:50 f3a finished: result 5 (23 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 32/372182/22709/11401
  2026-11-26 22:33:50 job f3a parked (result 5); its siblings continue
  2026-11-26 22:33:51 job f3a parked: its files are saved in .dart_tool/run-jobs/docs_briefs_m17_board3a/parked-f3a.patch and out of the tree (the siblings' check does not see them)
  2026-11-26 22:33:52 STOPPED: jobs that failed or passed their limit (parked, not committed): f3a (their logs: docs/briefs/m17/board3a/flash-<job>.log)
