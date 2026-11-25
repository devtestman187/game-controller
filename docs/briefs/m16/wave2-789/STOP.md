STOP 2026-11-25 02:05:27 docs/briefs/m16/wave2-789
cause: PAUSED after wave 8 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
class: other
repair: read the cause and the lines below, fix the one cause, append "HAND-FIX <job>: ..." to run.log, then restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  none found
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-25 01:53:02 WARN: f4 was committed by hand (789d4250); a plain restart would skip its tests-first proof and worker review, so both run now
  2026-11-25 01:53:02 hand-fixed f4: tests-first proof and worker review done (marked in done.txt)
  2026-11-25 01:53:02 skip f4 (already done)
  2026-11-25 01:53:03 skip n8e2 (already done)
  2026-11-25 01:53:03 skip n8e3 (already done)
  2026-11-25 01:53:20 start n8e1
  2026-11-25 01:53:46 start n8e4
  2026-11-25 01:55:09 start n8e6
  2026-11-25 01:58:01 n8e6 finished: result 4 (20 turns, 2 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 24/241945/16003/7695
  2026-11-25 01:58:03 n8e6: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_re...
  2026-11-25 01:59:57 n8e4 finished: result 4 (15 turns, 3 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 20/186514/13360/5940
  2026-11-25 02:00:00 n8e4: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_re...
  2026-11-25 02:00:51 n8e1 finished: result 4 (36 turns, 4 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 38/615927/35633/15772
  2026-11-25 02:00:53 n8e1: dropped generated churn outside its list: site/shots/dpad.png site/shots/join.png site/shots/menus.png site/shots/results.png site/shots/sticks.png site/shots/tilt.png tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_re...
  2026-11-25 02:01:21 combined check: skips protocol metrics look tools (no job's change reaches them)
  2026-11-25 02:05:22 committed n8e6: 2e455893 connection, game_kit: say "screen" in user-visible text, not "TV"
  2026-11-25 02:05:24 committed n8e4: 8c8738b1 Wording: TV to screen in controller_app status and log strings
  2026-11-25 02:05:25 committed n8e1: 53579879 Phone text: say screen, not TV (n8e1)
  2026-11-25 02:05:27 reviewed wave7: 4 finding(s)
  2026-11-25 02:05:27 STOPPED: PAUSED after wave 8 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart
