# Wave 7 review: f4 (commit 789d4250)

## Summary
Verdict: small fixes
Counts: 1 must, 2 should, 1 could
1. The report has no review-rules part A self-check (A1 to A6); the guidelines' §11 require it.
2. The demo-start branches (during a consent prompt, while hosting live) have no test.
3. The gyro test's cause ("restore timed out") is asserted, not shown, and the test now skips the launch restore it describes.

## Findings
- **must** docs/briefs/m16/wave2-789/f4-report.md:5 The report has no part A self-check lines (every host setup, kept state, combination with other states, folder, stop-rather-than-overstep, every look); guidelines §11 and review checklist item 7 require them → add the six one-line answers, each with the test that shows it.
- **should** controller_app/lib/src/home/phone_home_screen.dart:139-146 The demo listener's two branches (`_promptUp` sets `_closeWaits`; hosting live skips `_close`) and the demo clause in `_afterConsent` (line 103) have no test, though the brief named both → add a test in launch_home_test.dart: demo started during the consent prompt closes Home once it is answered, and demo started while hosting live leaves Home open.
- **should** controller_app/test/host_gyro_test.dart:31-38 The comment's cause ("restore ... timed out") is not shown by any run, and the test now calls `setMode` directly, so the launch restore (`restoreMode`, gyro.dart:~296) is no longer exercised by this test → state the cause as unverified in the report, or run the test with the old timing and report the output; say whether restore is covered elsewhere.
- **could** controller_app/test/support/site_shots.dart:238 The comment says Connect is "behind its Join a Game", but after `reachConnect` the Connect screen is on top of Home → reword to say the shot is of Connect, pushed over Home.

## Decisions to confirm
- host_gyro_test.dart: the job did not pop back to the pad (the brief's first option) but calls `setMode(PadMode.gyro)` itself; this removes the launch-restore path from this test (see the second should above).
- phone_home_screen.dart:139-146: a demo start while hosting live does not close Home and is not retried later, unlike a connection's `_closeWaits` path; the brief asked for the same rule, so confirm the Home left open under a live host is wanted.

## Could not check
- The report's checks (`tools/mine.sh` ok, 66 tests; the five files passed alone): no run output exists in the workspace and run-findings.md has no f4 entry; I did not run tests.
- That the new connect_screen_test and launch_consent_test expectations fail on the old code: not run.
- That store_builds_test passes without change: not run; the report says so, unverified.
- The gyro timing cause (see the second should): not run.

## Commit message — a draft
Add wave 7 review of f4 (Home-first launch)

Review of commit 789d4250 against the coding guidelines, review rules and
the f4 brief. Findings: f4-report.md lacks the part A self-check; the demo
start during a consent prompt and while hosting live is untested; the gyro
test's timing cause is unverified. No code changed.

## Status row
wave7 review (f4): done, verdict small fixes (1 must, 2 should, 1 could); open: f4 self-check, demo-branch tests, gyro test cause.

## Delete
- none
