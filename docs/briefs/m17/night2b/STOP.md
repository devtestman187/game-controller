STOP 2026-11-27 03:23:12 docs/briefs/m17/night2b
cause: brief gate: brief-check failed: FAIL changes f3: NightStartScreen is used in packages/party_host/lib/src/ui/games_screen.dart, which no job of wave 4 or earlier allows
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-27 03:19:03 start the run's review
  METRICS d2f worker=claude model=claude-sonnet-5-5 turns=30 in=40 out=17876 cache=691054 min=6.3 wall=- result=0
  METRICS d2g worker=claude model=claude-sonnet-5-5 turns=66 in=68 out=36804 cache=2681855 min=13.6 wall=- result=0
  METRICS d2h worker=claude model=claude-haiku-5-5 turns=43 in=54 out=25987 cache=1107013 min=4.3 wall=5.4 result=0
  METRICS d2i worker=claude model=claude-haiku-5-5 turns=16 in=26 out=17983 cache=385772 min=4.6 wall=11.3 result=0
  METRICS d2w worker=claude model=claude-haiku-5-5 turns=51 in=50 out=42767 cache=1555266 min=6.1 wall=- result=0
  METRICS d2x worker=claude model=claude-haiku-5-5 turns=62 in=92 out=53910 cache=3279431 min=7.7 wall=26.2 result=0
  METRICS f1 worker=claude model=claude-haiku-5-5 turns=33 in=58 out=15652 cache=1056550 min=4.0 wall=- result=0
  METRICS f2 worker=claude model=claude-haiku-5-5 turns=19 in=22 out=9404 cache=277732 min=4.0 wall=- result=0
  METRICS run-review worker=claude model=claude-haiku-5-5 turns=38 in=36 out=33773 cache=1011259 min=2.8 wall=- result=0
  METRICS wave1-review worker=claude model=claude-haiku-5-5 turns=32 in=24 out=35766 cache=609165 min=2.8 wall=- result=0
  METRICS wave2-review worker=claude model=claude-haiku-5-5 turns=30 in=24 out=30668 cache=649614 min=2.4 wall=- result=0
  METRICS wave3-review worker=claude model=claude-haiku-5-5 turns=37 in=46 out=48973 cache=1490639 min=3.9 wall=- result=0
  2026-11-27 03:22:17 DONE: every job is committed. Claude reads the Summary of docs/briefs/m17/night2b/REVIEW.md, verifies its findings and writes one fix brief
  RESULT: DONE: 8 jobs, 14 min
  2026-11-27 03:23:04 RUN_MAX_MIN=63 min (computed backstop of the jobs still to do)
  2026-11-27 03:23:04 start at 99d4e6cc on m17
  2026-11-27 03:23:04 worker: claude
  2026-11-27 03:23:05 proc-sweep: proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
  2026-11-27 03:23:11 STOPPED: brief gate: brief-check failed: FAIL changes f3: NightStartScreen is used in packages/party_host/lib/src/ui/games_screen.dart, which no job of wave 4 or earlier allows
