# M16 tools7: the run's review (read-only)

Scope: the run's commits 4c29132..b98b1e5 read as one change: the tools7 test scripts (t1a, t1b, t1c), the M16 identity1-w4 Dart files in the same range (listed in run-review.md), run.log, the three job reports and run-findings.md. No per-job review reports (`*-review-report.md`) exist for this run. No checks were run: this review changes nothing.

## Summary

Verdict: **one fix batch**, plus one design call (#8, shared test helpers).

Counts: **must 1 · should 12 · could 4** (17 findings; the findings list below is ordered most severe first).

Most important:
1. #1 (must): `tools/tests/run-worker-switch-test.sh` still writes a DEBUG log (`dbg`, lines 36-39, 127, 131-132) that its own comment says is removed before the report.
2. #6: the environment-leak guard does not cover the new `run-wire2-test.sh`, and no wire test clears `BRIEF_CHECK_CMD`.
3. #4 and #5: a fixed `sleep 0.3` after the signal (run-wire2) and a 30 s bound equal to the stub's sleep (run-wave, measured 24 s under load). Both are timing-based and one is unexplained.
4. #2 and #3 (phone-pinned): `paintToyBadge` now takes 7 parameters (max 5) and one line is over 120 columns.
5. #10, and the Numbers section: no after-timings exist for any script; the t1b and t1c reports on disk still say "stopped, not run" although run.log records a second pass with result 0.

Batches (no shared files within a wave):
- Wave 1, job A (check: tools): #1 and #6. Files: run-worker-switch-test.sh, run-gate-test.sh, run-wire-test.sh, run-limits-wire-test.sh, run-wire2-test.sh.
- Wave 1, job B (check: phone): #2, #3, #14. Files: toy_badge.dart, connect_panels.dart, settings_profile_section.dart.
- Wave 2, job C (check: tools): #4 and #5 (both touch run-wire2 / run-wave; after A). Needs a diagnosis first.
- Separate: #7 (selftest.sh timeout, 1 file), docs fixes #9-#11, and #8 (design).

Questions only the owner can answer: see Open questions (1, 4, 5).

## Findings

- **must** tools/tests/run-worker-switch-test.sh:36 the test leaves a DEBUG log in `.dart_tool` (`dbg`, written at :38-39, :127, :131-132) that its own comment says is removed before the report → delete those lines and keep the PASS/FAIL echo; test-only, nothing else changes. (from: t1b) [check: tools]
- **should** packages/toy_look/lib/src/toy_badge.dart:38 `paintToyBadge` has 7 parameters (max 5 by guideline §3; it had 6 before `numbered`) → group the two badge options (`character`, `numbered`) into a value object, or call it from `_ToyBadgePainter` with that object. Phone-pinned: controller_app/test/join_badge_test.dart, controller_app/test/phone_metrics_test.dart. (from: 52ae31ce w4c) [check: phone]
- **should** packages/toy_look/lib/src/toy_badge.dart:147 the call is 121+ columns (120-column rule; dart format would reflow it; I did not run dart format) → wrap the call as dart format does. Phone-pinned, same tests. (from: 52ae31ce w4c) [check: phone]
- **should** tools/tests/run-wire2-test.sh:36 and :53 `sleep 0.3` after the signal hides a race (guideline §2 "timing fixes"); t1a's condition-wait attempt failed and the run-1 failure was never read (t1a Q1) → diagnose by running the case 3 times, then wait on the runner's exit or a marker; until then state the reason in the comment. (from: t1a) [check: tools, wave 2]
- **should** tools/tests/run-wave-test.sh:159 `elapsed_s -lt 30` equals the stub's `stub-sleep: 30` (:143); t1c measured 24 s under load, and run 1 failed this script once → keep the file-absence check (`hang-report.md`) as the proof and drop or re-derive the time bound from two measured runs. Fixed, unverified: needs device check (cause not reproduced by the worker; the second-pass result is not recorded). (from: t1c) [check: tools, wave 2]
- **should** tools/tests/run-gate-test.sh:247 the leak case checks only `run-wire-test.sh` and `run-limits-wire-test.sh`; the new `run-wire2-test.sh` (t1a) is not checked, and `BRIEF_CHECK_CMD` (in the unset at run-gate-test.sh:26) is cleared by neither wire test (run-wire-test.sh:22-23, run-wire2-test.sh:18-19, run-limits-wire-test.sh:20-21) → add run-wire2-test.sh to the loop and add `BRIEF_CHECK_CMD` to the three unset blocks. (from: t1a) [check: tools]
- **should** tools/selftest.sh:55 `run-wire2-test.sh` is not in `SELFTEST_TIMEOUTS`, so it gets the default 120 s (selftest.sh:9); its wall time was never measured → add it to the default list with a measured limit. (from: t1a) [check: tools]
- **should** across jobs: the same helpers are written out in six scripts: pass/fail/report (run-gate-test.sh:34-39, run-limits-wire-test.sh:29-34, run-wave-test.sh:29-34, process3-fix1-test.sh:34-40, run-wire-lib.sh:36-41) and the stub heredocs (run-gate-test.sh:72-91, run-limits-wire-test.sh:60-79, run-wave-test.sh:71-90, process3-fix1-test.sh:75-101, run-worker-switch-test.sh:74-90). t1a made run-wire-lib.sh; t1b and t1c chose not to use it → one shared lib for all runner tests. This is a design call (Claude), not a batch fix. (from: across jobs)
- **should** docs/briefs/m16/tools7/t1c-report.md:5 has no `## Summary` block (carried over from run-findings.md; the review reads Summary first) → add one. (from: run-findings.md) [docs]
- **should** docs/briefs/m16/tools7/t1b-report.md:5 and t1c-report.md:3 still say "stopped, not run", but run.log:02:19 records both second passes as result 0 and no report records their results → rewrite both with the second-pass results (or say which runs they came from). (from: across jobs) [docs]
- **should** docs/briefs/m16/tools7/t1a-report.md (no `tests-first: exempt` line; docs/briefs/m16/tools7/t1a.md:5 asks for the old file's wall time first, not measured) and run.log:19 (HAND-FIX: apply-job.sh copied 4 files by hand; no review report exists for t1a) → state the exempt reason and the missing before-time in the report; Claude to confirm the 4 copied files. (from: t1a)
- **should** tools/tests/run-wire-lib.sh:209-211 `end_runner` now releases the slow stub after the signal (run.log:20, HAND-FIX; INT case flaked once under load, passes 3 of 3 after) → Fixed, unverified: needs device check. The cause is reasoned from bash's trap order, not reproduced. (from: t1a) [check: tools]
- **should** tools/tests/run-gate-test.sh:52-54, tools/tests/process3-fix1-test.sh:51-55, tools/tests/wait-run-test.sh:52-61 (t1b): the wave gap now 0.1 s and the lock poll are unmeasured; t1b's runs were refused and the second pass result is not recorded in the tree → Fixed, unverified: needs device check. Run the four scripts once and record the seconds. (from: t1b) [check: tools]
- **could** packages/toy_look/lib/src/toy_badge.dart:45 the boolean `numbered` is not question-form (guideline §4; the existing `fillsBackground` has the same shape) → rename to `isNumbered` in the four files that use it (toy_badge.dart:45, :105, :143; connect_panels.dart:83; settings_profile_section.dart:295). Phone-pinned. (from: 52ae31ce w4c) [check: phone]
- **could** tools/tests/run-limits-wire-test.sh:139 and tools/tests/run-wave-test.sh:191 are over 120 columns (shell is not formatted; keep the scripts' own style) → wrap. (from: t1c) [check: tools]
- **could** tools/tests/run-wire2-test.sh:35 and :52 `touch "$STUB_SLOW_DONE"` repeats the touch `end_runner` makes (run-wire-lib.sh:211) → delete both. (from: t1a) [check: tools]
- **could** tools/tests/run-wire-test.sh (header :2) and run-wire2-test.sh: case numbers run 1-9, 12-14 then 10, 11, 15-17 across the two files → renumber one sequence. (from: t1a) [check: tools]

## Open questions

1. Does `tools/tests/claude-worker-test.sh` (failed in t1a's run 2) also fail on 4c29132? Suggest: yes, treat as pre-existing if so; check before the tools suite gates the next batch.
2. What failed in t1a's run 1 signal cases? Suggest: run run-wire2-test.sh 3 times; keep `sleep 0.3` with its reason until then (#4).
3. Keep the run-wave bound? Suggest: keep the `hang-report.md` absence check; drop the 30 s bound unless two measured runs agree (#5).
4. Approve the bare `bash tools/tests/<script>` runs so the before and after seconds can be recorded? Suggest: yes, once per script at 4c29132 and at HEAD.
5. One shared helper lib for the runner tests (#8)? Suggest: yes, as a later job, not in this batch.
6. Keep the 25 s wave-gap as a stub in the tests, or add a runner knob (t1b Q3)? Suggest: a knob later; no runner change now.
7. Keep `timeout 3` in wait-run's locked case (t1b Q2)? Suggest: keep; the case names it.

## Numbers against targets

- Baselines from the briefs (seconds, under load): run-gate 56, wait-run 57, run-worker-switch 59, process3-fix1 42, run-limits-wire 49, run-wave 55, mine-test 34.
- After-seconds: none measured in any report. The briefs require before and after for each script (t1a.md:5, t1b.md:5, t1c.md:5); this is missed for all of them.
- run-wave case 1: 24 s under load (t1c) against the old bound of 20 s, which it missed; the new bound 30 s holds with a 6 s margin, not re-measured (#5).
- Whole tools suite: 826 s (run 1), 690 s (run 2) per t1a. No target is stated in the briefs I could read.
- run-wire2-test.sh: not measured; default limit 120 s (#7).
- Phone and Dart: no timing in scope.

## Could not check

- Per-job review reports: none exist for tools7 or identity1-w4; run-findings.md has one line.
- The second-pass results (run.log 02:19-02:39): the tools suite, run-gate, wait-run, process3 and worker-switch outcomes are not recorded in the tree.
- Dart: `dart format`, `dart analyze` and the package tests were not run; #3 is judged by line length only.
- claude-worker-test.sh on main (open question 1).
- docs/protocol.md and the identity1-w4 docs: outside the files listed for this review.
- The stub text of run-wire-test.sh at 4c29132 was not diffed against run-wire-lib.sh (t1a Q6).

## Commit message — a draft

M16 tools7: run review, findings list only

Read the run's tools7 test changes and the identity1-w4 Dart changes in
4c29132..b98b1e5 as one change. Records 17 findings (1 must, 12 should,
4 could) with the fix batches: a DEBUG log left in run-worker-switch-test,
the leak guard missing run-wire2-test, a fixed sleep and a timing bound
in the wire and wave tests, toy_badge's 7-parameter call, and stale
reports for t1b and t1c. No code changed.

## Status row

M16 tools7 run review: verdict one fix batch (1 must, 12 should, 4 could; phone batch: toy_badge). Open: the claude-worker-test failure on main, the run-1 wire failure, the before and after seconds for every script, and the shared-helper design call.

## Delete

- none
