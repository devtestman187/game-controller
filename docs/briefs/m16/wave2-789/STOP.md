STOP 2026-11-25 00:48:14 docs/briefs/m16/wave2-789
cause: stop file
class: stop-file
repair: a person or Claude asked for this stop: delete <batch>/STOP (the runner does at the next start), fix the cause, then restart.
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-25 00:13:42 skip n8b0 (already done)
  2026-11-25 00:13:42 skip n8c (already done)
  2026-11-25 00:13:43 skip n9sr (already done)
  2026-11-25 00:13:58 skip n8b1 (already done)
  2026-11-25 00:13:59 skip n9b2 (already done)
  2026-11-25 00:13:59 skip n9b3 (already done)
  2026-11-25 00:14:15 skip f1 (already done)
  2026-11-25 00:14:15 skip n8b2 (already done)
  2026-11-25 00:14:15 skip n8d2 (already done)
  2026-11-25 00:14:31 skip n8d1 (already done)
  2026-11-25 00:14:31 skip n8b3a (already done)
  2026-11-25 00:14:32 skip n8e0 (already done)
  2026-11-25 00:14:48 start f2
  2026-11-25 00:15:14 start f3
  2026-11-25 00:15:40 start n8b3
  2026-11-25 00:19:18 f3 finished: result 4 (23 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 34/494200/30800/15362
  2026-11-25 00:19:20 f3: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-25 00:24:23 f2 finished: result 4 (69 turns, 9 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 106/4007081/116139/67764
  2026-11-25 00:24:23 job f2 used 69 turns, over its cap of 60 (parked, siblings continue)
  2026-11-25 00:48:13 STOPPED: stop file
