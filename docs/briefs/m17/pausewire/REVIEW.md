## Summary

Verdict: one fix batch (2 files, 5 findings; 0 must, 4 should, 2 could).
Run scope: one committed job (pw1, 6d2bb15f), 2 source files, 305 lines added. No STATUS.md, per-job review, run-findings.md or REVIEW-VERDICTS.md exists, so nothing was carried over.
Hand-fixes: none (run.log has no HAND-FIX line).

Five findings that matter most:
1. should `packages/party_host/test/choice_round_pausable_test.dart:193` assertion `NightStage.round.index >= 0 ? ... : null` is always true; the test checks nothing about the stage.
2. should `packages/party_host/test/choice_round_pausable_test.dart:171-183` the "closing ... removes the pausable" test passes without detach (a closed round ignores pause, as pw1-report admits), so removal is unproven.
3. should `packages/party_host/test/choice_round_pausable_test.dart:119-132` "picks stay" is not asserted; only `lockedIds` is checked.
4. should `packages/party_host/lib/src/night/choice_round_pausable.dart:12-15` a round already closed at construction never emits on `changes`, so the pausable stays registered.
5. should `packages/party_host/test/choice_round_pausable_test.dart:37` `_Setup` takes 6 parameters (limit 5).

Questions only the owner can answer: see Open questions (4 items).

## Findings

- **should** packages/party_host/test/choice_round_pausable_test.dart:193 the assertion `expect(s.controller.flow.stage, NightStage.round.index >= 0 ? s.controller.flow.stage : null)` compares the value with itself and always passes → replace with an expected stage value, or delete the line (from: pw1)
- **should** packages/party_host/test/choice_round_pausable_test.dart:171 the "closing the round while paused removes the pausable" test also passes if `detach` never runs, because a closed round ignores pause; its name claims removal → make the test observe removal (e.g. a recording NightPausable, or the controller's pausable list) and keep the closed-round check as a second step (from: pw1)
- **should** packages/party_host/test/choice_round_pausable_test.dart:119 the first test asserts `lockedIds` is empty but not that the pick `save` is still held after pause, though the job's rule is "picks stay" → assert the pick is still recorded after `controller.pause()` and after resume (exact ChoiceRound API unverified, see Could not check) (from: pw1)
- **should** packages/party_host/lib/src/night/choice_round_pausable.dart:12 the constructor subscribes to `round.changes` but never checks `round.isClosed` first; a round closed before construction is never detached and stays in the night's pausables → after `controller.addPausable(this)`, add `if (round.isClosed) { detach(); return; }`-style handling, or detach in the constructor when already closed (from: pw1)
- **could** packages/party_host/test/choice_round_pausable_test.dart:37 `_Setup` constructor has 6 parameters (rule: at most 5) → group `server`, `client`, `seen` into one value object, or drop `clock` by reading it from the controller helper (from: pw1)
- **could** packages/party_host/test/choice_round_pausable_test.dart:66 bare magic numbers in `_setup` (`milliseconds: 100`, `1500`, `Duration(minutes: 5)` at line 82 and the matching lines 80-81) → name them as constants with a unit and a doc comment (from: pw1)

Phone-pinned: none. All findings are in `packages/party_host` (host app); no controller_app test imports these files as far as the diff shows.
Fix-job sizing: job A = the lib file (finding 4). Job B = the test file, findings 1-3 (3 findings, one file). Finding 5 and the magic numbers go in a later job after B, because they share the test file.

## Open questions

- Should `ChoiceRoundPausable` stay unexported until the build-stop wiring (M17b), as pw1-report's hand-over says? Suggested answer: yes, keep it unexported until M17b.
- Does "picks stay" mean the pick is kept in the round, or that `lockedIds` must not change? Suggested answer: the pick stays recorded, and `lockedIds` stays empty until grace ends (confirm in the round's API).
- pw1-report self-check item 3 says host away, "Get ready" and player away beyond a drop are not covered. Should those be covered before M17b? Suggested answer: yes, in the wiring job.
- run.log shows "checks failed; fetching packages and trying once more" and then the apply step, with no line recording the retry's result. Was the retry green? Suggested answer: rerun `tools/mine.sh` on pw1 before accepting it.

## Numbers against targets

- Paused `endsInMs` = 30000 - 4000 = 26000; after resume at fake clock 19000 ms it is still 26000. Matches the test expectations (lines 130, 159). No target in the brief to compare against.
- Grace 200 ms, wait 500 ms after a drop during pause: lockedIds empty, round open (lines 143-144). No target in the brief to compare against.
- Test count: 7 tests (per pw1-report, not re-run here).
- Line length: no line over 120 columns in either file (checked).

## Could not check

- Not run: `tools/mine.sh` and the 7 tests. The job is read-only and only the reports were read; the pass claim comes from pw1-report.
- Not read: the ChoiceRound and NightFlowController definitions (the `connection` package and `night_flow_controller.dart` beyond lines 159-181). So `lockedIds`, `changes`, `isClosed`, and whether `NightFlowController.pause()` returns bool are assumed from the tests, not checked.
- Not read in full: docs/coding-guidelines.md and docs/review-rules.md (the worker extract was used as the rules).
- Not present: STATUS.md, per-job review reports, run-findings.md, REVIEW-VERDICTS.md. Carry-over and verdict steps were empty.
- Whether the retried check in run.log passed (see Open questions).

## Commit message — a draft

Review of the pausewire run: five findings for one fix batch

Read the pw1 commit as one change. The lib file has a gap when the round is
closed before construction (no detach). Three test gaps: a tautological stage
assertion, a removal test that passes without detach, and no check that the
pick survives pause. The _Setup helper has six parameters and bare magic
numbers. No code changed in this review; findings are in REVIEW.md.

## Status row

m17 pausewire run review: done (verdict one fix batch, 0 must, 4 should, 2 could); open: fix batch for 5 findings, pw1 retry check, the 4 open questions.

## Delete

- none
