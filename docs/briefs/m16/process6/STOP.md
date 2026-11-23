STOP 2026-11-23 00:27:12 docs/briefs/m16/process6
cause: checks failed twice on the combined tree after p6a
class: check-failed
repair: run tools/check.sh <suite> for the failing name above, fix the one cause, append "HAND-FIX <job>: ..." to run.log and restart (docs/flash-digest.md "Repair a stop").
failing tests and errors (run-check.log):
  FAIL  tools       (exit 1, 460s)  log: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261123-001356/tools.log
        FAIL  tools/tests/run-jobs-split-test.sh (7s)
          FAIL the sizes hold (runner 380 <= 380, wave 85, steps 261 and review 141 < 250)
        FAIL  tools/tests/run-wire-test.sh (53s)
          FAIL a failed check writes STOP.md with the cause and commits it (exit 1)
          FAIL the STOP file writes STOP.md with its cause and commits it (exit 1)
          FAIL result 4 with only generated churn (site/shots, the test's *-results.json) is applied (exit 0)
  (+5 more)
files outside allow (flash log):
  none found
run.log (last 20 lines):
  2026-11-22 23:41:00 RUN_MAX_MIN=57 min (computed backstop of the jobs still to do)
  2026-11-22 23:41:00 start at dbab34d2 on m16
  2026-11-22 23:41:00 worker: claude
  2026-11-22 23:41:00 run-base dbab34d2eb1396628ea0396dd318b63a3eec206d
  2026-11-22 23:41:09 preflight ok: the worker ran flutter --version and tools/check.sh --list
  2026-11-22 23:41:25 start p6a
  2026-11-23 00:00:15 p6a finished: result 0 (31 turns, 18 min)
  2026-11-23 00:13:52 checks failed; fetching packages and trying once more
  2026-11-23 00:27:12 STOPPED: checks failed twice on the combined tree after p6a
