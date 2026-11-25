STOP 2026-11-25 04:02:31 docs/briefs/m16/wave2-789
cause: checks failed twice on the combined tree after n8g
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  tools       (exit 1, 291s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261125-035724/tools.log
        FAIL  tools/tests/run-tune2-test.sh (1s)
          FAIL pause-off-by-default: got '7' want '0'
        FAIL  tools/tests/run-wire2-test.sh (40s)
          FAIL a stop waits for the running wave review and commits its report (exit 1)
          FAIL a STOP-file stop kills the running wave review at once, with no report committed (exit 1)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-25 03:44:31 skip f2 (already done)
  2026-11-25 03:44:31 skip f3 (already done)
  2026-11-25 03:44:31 skip n8b3 (already done)
  2026-11-25 03:44:47 skip f4 (already done)
  2026-11-25 03:44:47 skip n8e2 (already done)
  2026-11-25 03:44:48 skip n8e3 (already done)
  2026-11-25 03:45:03 skip n8e1 (already done)
  2026-11-25 03:45:04 skip n8e4 (already done)
  2026-11-25 03:45:04 skip n8e6 (already done)
  2026-11-25 03:45:20 skip n8e5 (already done)
  2026-11-25 03:45:20 skip n9e3 (already done)
  2026-11-25 03:45:20 skip f5 (already done)
  2026-11-25 03:45:36 skip f6 (already done)
  2026-11-25 03:45:37 skip f7 (already done)
  2026-11-25 03:45:53 start n8g
  2026-11-25 03:52:31 n8g finished: result 4 (23 turns, 2 min) model claude-haiku-5-5, ladder 1, tokens in/read/write/out 34/709672/49502/20256
  2026-11-25 03:52:33 n8g: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-25 03:52:35 combined check: skips protocol connection metrics kit look arena puzzle host phone tv (no job's change reaches them)
  2026-11-25 03:57:21 checks failed; fetching packages and trying once more
  2026-11-25 04:02:31 STOPPED: checks failed twice on the combined tree after n8g
