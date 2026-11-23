# M16 identity1-fix: the run's review

Read-only review of the run's 14 commits (`git diff 4f273fb5..14d577d1`, 35 files, +1013 / -89). Rules applied: the worker extract in the job's prompt. No tests were run.

## Summary

- Verdict: **one fix batch** (no finding needs Claude's design).
- Counts: must 0, should 8, could 6.
- The five that matter most:
  1. The fpad pixel tests have no proof that they fail on the old code (run.log has no tests-first line for fpad); on the old painters the whole file can only fail by compile error, so no fill behaviour is shown to be pinned.
  2. The fm3 crown assertion has no recorded proof that it fails when the accessory is swapped (no fm3-report.md).
  3. `StickPainter` now takes 8 named parameters (limit 5); fpad added the 8th.
  4. The worker's own turn cap now reads a brief's `turns:` line (tools/flash.sh:244): no test covers it and no report names it.
  5. `docs/briefs/m16/identity1/MILESTONE-VERDICTS.md:31` says `docs/code-health.md` notes ToyBadgeFace as an accepted exception; that file does not mention it.
- Hand-fixes: 3 (fm3, fq6, fpad). Hand-fixed jobs with missing reports: fm3 and fpad.
- Questions only the owner can answer: the fq6 hold scope (open question 1), the flash.sh `turns:` change's author (open question 7), and reverting the working-tree churn (open question 8).

## Findings

- **should** packages/test_game/test/arena_phone_identity_test.dart:242 The crown assertion (share above 0.95) was never shown to fail when the chosen accessory is swapped for the default; fm3-report.md is missing → run the test once with `{}` in place of `chosen`, record the share, and write the fm3 report with it (from: fm3; test_game, not phone-pinned)
- **should** controller_app/test/pad_character_fill_test.dart:34 No tests-first proof exists for fpad; on the old painters the file fails only by compile error (the new `character:` parameter is unknown), so no fill behaviour is shown to be pinned → add a tests-first run that uses the pre-fpad painters with the character-free calls only, record the failures, and write fpad-report.md (from: fpad; phone-pinned)
- **should** controller_app/lib/src/ui/stick_widgets.dart:203 `StickPainter` has 8 named parameters (7 before the run); the limit is 5 → pass the fill inputs (player and character) as one value object (from: fpad; phone-pinned)
- **should** tools/flash.sh:244 The worker's own cap now reads a brief's `turns:` line; no test in tools/tests covers it, and no job report names the change, so the fm3 cap miss is fixed by reasoning only → add a case to tools/tests/claude-worker-test.sh that a `turns: 50` brief runs with max-turns 50 (from: across jobs; tools-pinned, not phone)
- **should** tools/selftest.sh:29 The unset list is `WORKER NO_PUSH CHECK_FAIL_FAST CHECK_SKIP RUN_CHECK_SKIP`, without `FLASH_WORKER`, so any test run from a claude-worker shell that calls flash.sh inherits `claude`; only claude-worker-test.sh clears it → add `FLASH_WORKER` to the unset list (from: ft; tools-pinned)
- **should** docs/briefs/m16/identity1/MILESTONE-VERDICTS.md:31 It says `docs/code-health.md` notes ToyBadgeFace as an accepted exception; code-health.md does not mention ToyBadgeFace and this run did not change it → add the note to docs/code-health.md, or correct the verdict line (from: across jobs)
- **should** docs/briefs/m16/identity1-fix/run.log:18 and :38 Hand-fixes: fm3 (debug expect removed, reformatted; no fm3-report.md, tests-first exempt by brief); fq6 (apply-job wrong files; report and tests-first line present, no worker review file); fpad (Vec3 import added, unused import removed; no fpad-report.md, no tests-first line). No `*-review-report.md` exists for any job → write the missing reports, or record in REVIEW that they were not kept (from: across jobs)
- **should** (working tree, not committed) tv_test_app/windows/flutter/generated_plugin_registrant.cc, generated_plugin_registrant.h, generated_plugins.cmake and docs/briefs/m16/identity1-fix/run.log are modified and uncommitted → owner to revert or commit deliberately; not touched here (from: across jobs; no fix job)
- **could** packages/connection/test/identity_hello_hold_test.dart:23-46 `_clientWith`, `_join`, `_identityView` and `_longGrace` repeat identity_fix_test.dart:5-46 → move them to a shared file under packages/connection/test/ (from: across jobs; connection-pinned)
- **could** controller_app/lib/src/ui/host_chip.dart:101 No test pins the `hostCode` key (the fm2 brief said host_chip_test.dart does; grep finds none in controller_app/test) → add the pin in a new test file (from: fm2; phone-pinned)
- **could** packages/connection/lib/src/host_server.dart:362-363 `roundRunning` has no blank line before the next member; the file is at the 380-line cap (378 before the run), so the next change must split the adapter → add the blank line now; split when next touched (from: fq6; connection-pinned)
- **could** packages/connection/lib/src/host_connection.dart:81 The file grew from 300 to 303 lines, past the ~300 target → no change needed now; note for the next split (from: fq6; connection-pinned)
- **could** packages/connection/lib/src/host_character_reservation.dart:57 The doc comment's first line runs long and the last line is one short phrase ("still looks as it did before M14.") → re-wrap the paragraph (from: fm1; connection-pinned)
- **could** packages/test_game/test/arena_phone_identity_test.dart:169 `_Reference` copies ArenaMarblePainter's drawing, so the test checks the copy, not the painter → accept as is, or pin the painter through its output alone (from: fm3; test_game, not phone-pinned)

## Open questions

1. fq6 Q2: the re-pairing hold is not gated on the `identity` capability, so a phone one build older waits too. Suggested answer: keep it ungated and confirm.
2. fq6 Q1: the in-process transport keeps no away row, so the hold has no row there. Suggested answer: keep (m12 N5).
3. fm1 Q1: `Map.cast` makes a non-string key a TypeError, not a FormatException. Suggested answer: accept; JSON keys are always strings.
4. fm2 Q2: `coverage_all_test.dart` and `puzzle_module_test.dart` are in the allow list but were not needed. Suggested answer: drop them from the next brief's allow list.
5. ft Q2: which other tests call flash.sh without clearing FLASH_WORKER? Suggested answer: grep them in the batch for finding 5.
6. fm3 and fpad: did the new assertions fail on the old code (fm3: on the swapped accessory; fpad: on the pre-fpad painters)? Suggested answer: run each once and record the result.
7. Who made the flash.sh `turns:` change, and why is it not in any report? Suggested answer: record it in the run notes and cover it with the finding 4 test.
8. Working-tree churn (finding 8): revert the generated plugin files and run.log once the run is closed? Suggested answer: revert them; the owner decides, nothing was touched here.

## Numbers against targets

- fm3: 36 turns against `turns: 50` in its brief → miss; the cap was not raised by flash.sh (fixed in flash.sh, not measured).
- fq6: 44 turns against cap 35 → miss (its brief had no `turns:` line).
- fpad: 51 turns against cap 50 → miss.
- ft: 40 turns, 2 min, against expected-min 45 (DRIVER-NOTES) → met.
- claude-worker-test: 1 of 15 failing before the fix, 15 of 15 after, and 15 of 15 in each of four concurrent runs → met.
- host_chip.dart `build`: 63 → 31 lines (target under 60) → met; file 149 → 180 (cap 380) → met.
- host_server.dart: 378 → 380 lines (cap 380) → at cap, no headroom.
- host_connection.dart: 300 → 303 lines (target about 300) → over by 3.
- pad_widgets.dart: 346 → 358 lines (target about 300, cap 380) → over target.
- StickPainter: 7 → 8 named parameters (limit 5) → miss.
- DpadPainter: 5 named parameters (limit 5) → at limit.
- Tests reported: connection 360 pass (fm1), 364 pass (fq6); protocol 140 pass; puzzle 450 pass; phone passed in fm2 (count not logged).
- Expectations computed in the tests: `forPlayer(1)` = slot 1, ears; nearest free to it = (slot 2, antenna); away row keeps (slot 5, crown); fq6 `_worn` = (slot 5, crown), `_asked` = (slot 3, bow); arena crown share must be above 0.95 and ears share below 0.5.

## Could not check

- docs/coding-guidelines.md and docs/review-rules.md were not opened; I applied the worker extract in the prompt, as the job says.
- No `*-review-report.md`, `STATUS.md` or `run-findings.md` exists in the folder, so nothing was carried over from them.
- fm3-report.md and fpad-report.md do not exist; their Summary blocks could not be read.
- No test, format or analyze was run (read-only job). Pixel results, the TV look and the menu look are unverified; no device check.
- Whether the new pad and arena tests fail on the old code is not measured.
- The tools-suite result after ft is not in run.log ("the tools suite runs" with no result line).
- Review results (tools/review.sh) appear in run.log only for the fm3 hand-fix ("review 0 fail"); no other job's review result is logged.

## Commit message — a draft

M16 identity1-fix: run review, findings list only

Read the run's 14 commits as one change against the worker rules. No code,
test or document other than this report was changed. Verdict: one fix batch:
0 must, 8 should, 6 could. The should items: fpad and fm3 tests not shown to
fail on the old code, StickPainter at 8 parameters, the untested flash.sh turns
cap, FLASH_WORKER missing from selftest's unset list, a false code-health claim
in MILESTONE-VERDICTS, missing fm3 and fpad reports, and uncommitted churn.

## Status row

M16 identity1-fix run review: done (one fix batch: 0 must, 8 should, 6 could, see REVIEW.md). Open: the 14-finding fix batch; the fq6 hold scope and the flash.sh turns owner question; uncommitted churn in tv_test_app windows files and run.log to revert.

## Delete

- none
