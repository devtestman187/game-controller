STOP 2026-11-25 03:37:40 docs/briefs/m16/wave2-789
cause: PAUSED after wave 10 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-25 03:28:07 skip n8b3 (already done)
  2026-11-25 03:28:22 skip f4 (already done)
  2026-11-25 03:28:23 skip n8e2 (already done)
  2026-11-25 03:28:23 skip n8e3 (already done)
  2026-11-25 03:28:39 skip n8e1 (already done)
  2026-11-25 03:28:39 skip n8e4 (already done)
  2026-11-25 03:28:40 skip n8e6 (already done)
  2026-11-25 03:28:55 skip n8e5 (already done)
  2026-11-25 03:28:56 skip n9e3 (already done)
  2026-11-25 03:28:56 skip f5 (already done)
  2026-11-25 03:29:12 start f6
  2026-11-25 03:29:38 start f7
  2026-11-25 03:31:22 f7 finished: result 4 (15 turns, 1 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 24/241568/15322/5795
  2026-11-25 03:31:23 f7: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-25 03:33:46 f6 finished: result 4 (27 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 40/809996/49506/18231
  2026-11-25 03:33:48 f6: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-25 03:34:01 combined check: skips protocol metrics look tools (no job's change reaches them)
  2026-11-25 03:37:37 committed f7: 70ada00c Say "screen" in connection's client log and give-up strings
  2026-11-25 03:37:38 committed f6: bfe68d48 test: pin Home for a demo under the prompt and a live host
  2026-11-25 03:37:39 STOPPED: PAUSED after wave 10 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
