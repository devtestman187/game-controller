STOP 2026-11-24 12:58:15 docs/briefs/m16/bugs4
cause: checks failed twice on the combined tree after nh2 np1
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  host        (exit 1, 83s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261124-125633/host.log
        12:57:04.450 [host] Best times: FormatException: Unexpected character (at character 1)
        12:57:04.464 [host] Best times: FormatException: Unexpected character (at character 1)
        The following ProviderException was thrown running a test:
        UnimplementedError: hostIdentityProvider must be overridden
        #0      throwProviderException (package:riverpod/src/common/stack_trace.dart:10:3)
        #1      $ResultError.valueOrProviderException (package:riverpod/src/common/result.dart:108:7)
  (+20 more)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-24 12:34:13 nh1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 12:36:51 nk1 finished: result 4 (43 turns, 4 min)
  2026-11-24 12:36:53 nk1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 12:37:05 tests-first ok: packages/connection/test/night_end_client_test.dart fails on the old code
  2026-11-24 12:37:08 tests-first ok: packages/connection/test/night_end_send_test.dart fails on the old code
  2026-11-24 12:37:26 combined check: skips protocol metrics look tools (no job's change reaches them)
  2026-11-24 12:41:11 committed nh1: babbc3b4 connection: GameHost.showNightEnd sends the night's end to night phones
  2026-11-24 12:41:13 committed nk1: 6e40b9ef Phone client lists night and exposes the night's end
  2026-11-24 12:41:15 reviewed wave3: 10 finding(s)
  2026-11-24 12:41:31 start nh2
  2026-11-24 12:41:57 start np1
  2026-11-24 12:50:46 nh2 finished: result 4 (69 turns, 9 min)
  2026-11-24 12:50:48 nh2: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 12:52:00 np1 finished: result 4 (46 turns, 7 min)
  2026-11-24 12:52:01 np1: dropped generated churn outside its list: tv_test_app/windows/flutter/generated_plugin_registrant.cc tv_test_app/windows/flutter/generated_plugin_registrant.h tv_test_app/windows/flutter/generated_plugins.cmake 
  2026-11-24 12:53:17 tests-first ok: controller_app/test/night_end_provider_test.dart fails on the old code
  2026-11-24 12:53:35 tests-first ok: packages/party_host/test/night_end_send_test.dart fails on the old code
  2026-11-24 12:53:55 combined check: skips protocol connection metrics kit look arena puzzle tools (no job's change reaches them)
  2026-11-24 12:56:30 checks failed; fetching packages and trying once more
  2026-11-24 12:58:15 STOPPED: checks failed twice on the combined tree after nh2 np1
