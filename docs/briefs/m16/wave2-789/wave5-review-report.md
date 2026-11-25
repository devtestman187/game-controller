# wave5 review: n8b3a, n8e0, n8d1

## Summary

- Verdict: **needs Claude**
- Counts: must 3, should 4, could 2
- Top 1: phone_home_screen.dart:164 — `onDone` saves `showTips` false even when no anchor was laid out, which REVIEW-VERDICTS.md:23 forbade.
- Top 2: phone_home_marks_test.dart:76-91 — two "tests first" tests pass on the old code (no marks existed), and n8d1-report.md:3 says they fail.
- Top 3: tools/mine.sh:286 — the churn revert ran in all three jobs and reverted the owner's uncommitted tv_test_app generated files (run.log:149-153).

## Findings

- **must** controller_app/lib/src/home/phone_home_screen.dart:164 `onDone: seen` saves false when every anchor lacks a render box: coach_marks.dart:93-115 skips each step and then calls onDone with nothing shown → show the marks only when all three anchors are laid out, or have `seen` ignore onDone while no step was shown.
- **must** controller_app/test/phone_home_marks_test.dart:76-82 "a saved showTips false shows none" passes on the old code (old Home never shows marks) → add a positive control in the same test: after `set(true)` through the notifier, expect `_marks` to appear.
- **must** controller_app/test/phone_home_marks_test.dart:84-91 "a client that is connecting shows none" passes on the old code → after the idle check, emit `ClientStatus.idle` again and expect `_marks` to appear, so the test fails on the old code.
- **should** docs/briefs/m16/wave2-789/n8d1-report.md:3 claims the new tests "fail on the old Home"; tests at phone_home_marks_test.dart:76-91 do not → correct the line once the two must findings are fixed.
- **should** controller_app/test/phone_home_marks_test.dart:134-143 the tap-under-marks test asserts only that ConnectScreen is absent; it never checks that the tap advanced the marks, and the final `tester.tap(_marks)` has no expectation → after the first tap expect `HomeText.tipPlay` on screen; after Skip expect `_marks` gone.
- **should** tools/mine.sh:286 `churn_revert` runs on every job and reverted the three modified tv_test_app/windows/flutter generated files that were already dirty before the wave (run.log:149-153); its comment says "never a person's file" → keep the revert to paths the job's own run changed, or skip it when the file was dirty at start.
- **should** controller_app/test/phone_home_marks_test.dart:182 `reason: 'the pad alone overflows'` sits on an `isNull` check that says no overflow → change the reason to 'the pad alone must not overflow', or remove the check.
- **could** controller_app/test/phone_home_marks_test.dart:163-165 the test named "is true when the client failed or is idle" only checks `failed`; `idle` is never asserted → add `expect(idle(clientStatus: ClientStatus.idle), isTrue)`.
- **could** controller_app/test/touch_targets_test.dart:55 `if (screen != TargetScreen.pad) await reachConnect(tester);` branches inside the test body → split the pad case into its own test, or call `reachConnect` in every case if the pad's button is absent by design.

Checked and clean: n8b3a adds only lines (no expectation changed); its 7 files and pump_app.dart are inside allow; reachConnect (pump_app.dart:156-163) is a no-op when the Join button is absent. n8e0 changed only its allowed inventory file; host_text.dart is 379 lines and the table sums to 50 hits in 14 files.

## Decisions to confirm

- n8d1: `reconnecting`, `pairing` and `waitingForCode` count as idle, so marks can show during a dropped link (phone_home_screen.dart:~150, phone_home_marks_test.dart:163-167); the brief says only connecting or connected. Why: the report's own question 1.
- n8d1: `_promptUp` now starts true (phone_home_screen.dart:53) instead of being set in the post-frame callback; this also changes the close path at lines 109-110 for a connection that lands before the first frame. Why: the marks need it, but it changes existing close timing.
- n8b3a: `launch_consent_test.dart` "a launch asks once" was left without `reachConnect` (n8b3a-report.md, question 1). Why: it taps `connectionChip` and calls `pageBack` on a Home-first launch; owner should say whether it belongs in the repin.
- n8e0: log and diagnostic strings are proposed as CHANGE, and "TV app" as "Thumb Party TV app" (n8e0-report.md Decisions 2-3). Why: owner decision 7 covers user-visible text only.

## Could not check

- I did not run any test or `tools/mine.sh` (read-only job). The "fails on the old code" verdicts are by reading the code; run-findings.md has no evidence line for these jobs beyond the churn notes.
- n8e0's "50 hits" is consistent with its table, but I could not re-derive the literal-only hit list: `rg -w TV` on controller_app/lib alone gives 105 occurrences in 37 files, mostly identifiers and comments.
- The full `ClientStatus` enum was not read; only the values the marks code and tests use were checked.
- Whether each of the 14 test-pin lists in n8e-inventory.md is complete was not checked.

## Commit message — a draft

Review wave5 jobs n8b3a n8e0 n8d1 (report only)

Review of the wave5 commits against the coding guidelines, review rules
and briefs. Adds wave5-review-report.md with 3 must, 4 should and 2 could
findings: the onDone path that saves tips seen with nothing shown, two
"tests first" tests that pass on the old code, and the churn revert in
tools/mine.sh. No code or other document changed.

## Status row

wave2-789 wave5 review: done (report written, verdict needs Claude: 3 must, 4 should, 2 could). Open: fix the onDone anchor guard and the two old-code-passing marks tests in n8d1; the churn revert in tools/mine.sh; the four decisions above.

## Delete

- none
