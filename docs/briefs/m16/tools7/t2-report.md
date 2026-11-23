# tools7 t2 report: selftest.sh -j N, wire2 limit, run-wave bound

## Summary

- `tools/selftest.sh` takes `-j <n>` (1-16, also `SELFTEST_JOBS`, the option wins; default 1). With n > 1 up to n scripts run at once, each under its own `timeout`, and their lines print in list order. `-j 1` keeps the serial loop (same lines, order, exit codes).
- `SELFTEST_TIMEOUTS` default now `run-wire-test.sh=240,run-wire2-test.sh=240`. No limit lowered.
- `run-wave-test.sh`: dropped only the `elapsed_s -lt 30` bound; the `rc 1` and `! -e hang-report.md` checks stay, and the elapsed seconds stay in the report text.
- New `-j` cases in `selftest-test.sh`: 9 new cases, all PASS on two runs and once more after line wrapping.
- Checks: `selftest-test.sh` 18/18 (three runs), `selftest-limits-test.sh` 7/7, `run-wave-test.sh` 4/4, `check-scope-test.sh` 9/9, `flash-prompt-test.sh` 17/17, `tools/check.sh format` PASS, `bash tools/selftest.sh -j 4` RESULT: FAILED 1 of 26 (25 passed, 204 s): `claude-worker-test.sh`, which also fails when run alone (see below).

## Files changed

- `tools/selftest.sh`: `-j <n>` option (parsing, validation, `bad_input` exit 3 for `-j 0`, `-j x`, `-j` alone, `-j 17`); `SELFTEST_JOBS`; `start_script`, `reap_finished`, `show_result`, `run_parallel` (new); `cleanup()` kills and reaps every running timeout process; the serial loop is unchanged in behaviour (re-indented inside `else`); `SELFTEST_TIMEOUTS` default adds run-wire2; header comment and help range (`sed -n '2,25p'`) updated.
- `tools/tests/selftest-test.sh`: 9 new cases, after the existing ones; helpers `norm` and `bad_jobs`; fixtures built in the temp folder.
- `tools/tests/selftest-limits-test.sh`: header comment only (the default is now written with run-wire2). No case pins the default text, so no case changed.
- `tools/tests/run-wave-test.sh`: the `[ "$elapsed_s" -lt 30 ]` bound removed from case 1; nothing else.
- `docs/briefs/m16/tools7/t2-report.md`: this file.

## Computed test values

selftest-test.sh (`bash tools/tests/selftest-test.sh`, three runs, all 18/18):
- -j 3 over five fixtures (sleeps a1 1 s, a2 0.2 s, a3 0.6 s, a4 0.2 s, a5 0.4 s): line order a1..a5; normalized output equal to the -j 1 run (run times replaced by `Ns`); RESULT "ok: 5 script(s) passed".
- -j 2, failing (exit 1) plus timing-out (SELFTEST_TIMEOUT=2): both runs rc 2, normalized output equal, FAIL line present.
- `-j 0`, `-j x`, `-j` alone, `-j 17`: each rc 3, RESULT: BAD INPUT.
- SELFTEST_JOBS=2 with two fixtures that each wait up to 3 s for the other's start mark: both PASS, rc 0.
- `-j 1` overriding SELFTEST_JOBS=2 on the same fixtures: rc 1, "FAIL c1 never saw c2 start" (so the serial run won).
- TERM to a `-j 2` run with two `exec sleep 30` fixtures: exit 143, both fixture pids dead, lock gone; 0 polls needed after the TERM (the existing cases' timings are unchanged; the hanging case reported 2-3 s).

selftest-limits-test.sh: 7/7 (quick-test 3 s; slow-test stopped at its 2 s limit; mixed list 2 scripts passed in 3 s; three bad-input entries exit 3).

run-wave-test.sh: 4/4. Case 1 elapsed 14 s on this run (the stub sleeps 30 s and was parked at its 1 s limit).

check-scope-test.sh: 9/9. flash-prompt-test.sh: 17/17.

`bash tools/selftest.sh -j 4` (bare, once): RESULT: FAILED: 1 of 26 script(s) failed (25 passed, 204s). Per-script seconds from its lines: apply-job 16, brief-check 10, check-failfast 12, check-scope 12, claude-worker 6 (FAIL), fake-flash 11, flash-prompt 3, job-metrics 11, mine 33, probe-deps 29, process3-fix1 39, replay-identity1 7, run-base 38, run-gate 58, run-jobs-split 14, run-limits 15, run-limits-wire 43, run-stop 28, run-wave 47, run-wire 79, run-wire2 44, run-worker-switch 50, selftest-limits 11, selftest-test 35, wait-run 53, wait-run3 21.

Failure under -j 4: `claude-worker-test.sh`, case "plain flash.sh still runs the DeepSeek worker with --bare and 150 turns" (14 of 15 cases pass). Run alone (`bash tools/tests/claude-worker-test.sh`) it fails the same case, so it is not caused by parallel runs. Its output shows the plain flash.sh worker is `claude` with `max-turns: 35`, not DeepSeek with 150 turns. I did not change it and did not check the pre-change tree.

## Self-check (review-rules part A)

1. Host setups: not applicable (shell tooling only; no app host touched).
2. Kept state: the lock is taken once per run and removed on exit, including on TERM (case "a TERM to a -j 2 run ..."); the temp folder is removed on exit (existing case "an interrupted run removes its lock and temp files").
3. Combinations: -j with SELFTEST_TIMEOUTS, SELFTEST_TIMEOUT, bad input, and a timeout beats a failure (-j 2 mixed case, rc 2).
4. Files: only the allow-listed files changed.
5. Stopped: nothing; no other file needed.
6. Looks: not applicable.

## Decisions

- `-j` parsing: `-j` takes the next argument as its number; `-j` with nothing after is bad input (exit 3).
- Parallel scheduling polls each started script with `kill -0` every 0.1 s (no `wait -n`, which macOS bash 3.2 lacks). Each script's line prints when it and every earlier script have ended.
- Fixtures in the new cases end in `exec sleep`, so the TERM that `timeout` forwards reaches the sleep itself; a plain `bash` fixture would leave its `sleep` orphaned.
- The default run-wire2 limit is 240 s, same as run-wire.

## Questions

1. Should the serial loop and `show_result` share one printing function? I kept the serial loop untouched as the brief asked, so the TIMEOUT/FAIL printing exists twice (about 15 lines).
2. `claude-worker-test.sh` fails under -j 4 and alone; it expects the DeepSeek worker. Is that expected, or is it a stale test? Not in this job's files.
3. `selftest.sh -h a b` now prints help (the old code refused two folders before reading the option). The default path with two folders still refuses with the old message.

## Suggestions

- Run the full `tools/selftest.sh` at `-j 4` in the driver as parallel-safety data: 204 s here, versus about 526 s quoted in context.md for a serial run (not measured in this job).
- The "Git will replace LF with CRLF" warnings printed during run-wave and check-scope tests come from their fixture repos, not from these changes; they are harmless noise.

## Commit message

selftest.sh: -j N parallel runs, wire2 240 s limit, run-wave bound

- Add -j <n> (1-16, or SELFTEST_JOBS; the option wins). Up to n scripts run
  at once, each under its own timeout; output keeps list order.
- -j 1 keeps the serial loop. Bad n exits 3.
- SELFTEST_TIMEOUTS default adds run-wire2-test.sh=240; no limit lowered.
- Tests: -j order and exit codes, bad input, SELFTEST_JOBS, TERM cleanup.
- run-wave-test: drop the 30 s elapsed bound; rc 1 and the report check stay.

## Status row

Done: `selftest.sh -j N` (parallel, list-ordered output, cleanup on TERM), wire2 240 s default, run-wave elapsed bound dropped; selftest/limits/run-wave/scope/prompt tests pass; `-j 4` full run has one failure, `claude-worker-test.sh` (fails alone too, not investigated). Open: that failure; unify the serial and parallel print code.

## Delete

- none
