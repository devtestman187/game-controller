STOP 2026-11-26 17:56:14 docs/briefs/m17/phone1b
cause: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-26 17:32:22 run-base 04eceb44c7402f7e81587f0c88587de5e3cf1c24
  2026-11-26 17:32:42 phase: preflight
  2026-11-26 17:32:49 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-26 17:34:57 phase: worker (preflight took 135s)
  2026-11-26 17:34:57 start y0p
  2026-11-26 17:41:12 start y0dc
  2026-11-26 17:41:13 y0p finished: result 0 (26 turns, 2 min) model claude-sonnet-5-5, ladder 1, tokens in/read/write/out 26/369501/44271/13257
  2026-11-26 17:41:13 WARN: y0p logged 26 turns, 2 min but ran 6 min wall: a resumed session's usage row covers its last resume only, its real turns are unknown
  2026-11-26 17:46:59 y0dc finished: result 0 (36 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 52/1059445/56997/31435
  2026-11-26 17:47:00 phase: tests-first (worker took 723s)
  2026-11-26 17:47:14 tests-first ok: packages/connection/test/choice_round_pause_test.dart fails on the old code
  2026-11-26 17:47:17 tests-first ok: packages/connection/test/client_choices_test.dart fails on the old code
  2026-11-26 17:48:09 phase: check (tests-first took 69s)
  2026-11-26 17:48:25 combined check: the tools suite is skipped (no job changed a file under tools/)
  2026-11-26 17:56:10 phase: apply (check took 481s)
  2026-11-26 17:56:10 finding: y0p's report has no Summary block in its first 40 lines
  2026-11-26 17:56:11 committed y0p: 2f34624e m17 phone1b y0p: ChoiceRound pause and resume
  2026-11-26 17:56:13 committed y0dc: 66704121 m17 phone1b y0dc: phone client receives choices and sends picks
  2026-11-26 17:56:13 phase: review (apply took 3s)
  2026-11-26 17:56:14 STOPPED: PAUSED after wave 1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
