# wave2 review report (c3, c5, c4)

## Summary

small fixes
Counts: must 0 · should 2 · could 2
1. **should** volume_semantics_test.dart:38: the test name states only the percentage rule, while the new formatter assertions (:47-56) pin a different rule.
2. **should** c5-report.md:17: self-check A1 (host setups) says "not separately verified" and names no test for any setup.
3. **could** c4-report.md:8: "568 - barPadding 12 + 8" has the wrong sign; the value 548 is right (568 - 12 - 8).

## Findings

- **should** packages/party_host/test/volume_semantics_test.dart:38 The test name ("each Sounds and Music slider reads the percentage shown above it") does not state the new rule, which is that each slider has its own spoken-value formatter (asserts at :47-56); a failure reads as a percentage mismatch → rename it to state the formatter rule, e.g. "the $palette palette: each Sounds and Music slider speaks and shows its percentage".
- **should** docs/briefs/m16/close/c5-report.md:17 Self-check A1 (every host setup) says "not separately verified here" and maps no setup to a test; review-rules part A needs one line per item with the test that shows it → map each setup (TV or PC host, "Play on this phone", "Show on this device", joined phone, one build older) to a test in `launch_consent_test.dart` / `paired_launch_consent_test.dart`, or write "not affected" with the reason.
- **could** docs/briefs/m16/close/c4-report.md:8 "568 - barPadding 12 + 8" is the wrong expression: `barPadding` is `fromLTRB(12, …, 8, 0)` (controller_app/lib/src/ui/top_bar_metrics.dart:8), so the row is 568 - 12 - 8 = 548; the number 548 is right → write "568 - 12 - 8 (left 12, right 8)".
- **could** docs/briefs/m16/close/c4-report.md:1 No `## Summary` block (c3 and c5 have one); run-findings.md lists this as a finding → add a Summary of at most 12 lines at the top.

Checked and clean (no finding):
- controller_app/lib/src/home/launch_consent.dart:14-20: `launchConsentDue` holds the same three checks and the mark as before, in the same order; `askLaunchConsent` calls it; imports used.
- controller_app/lib/src/ui/connect_screen.dart:63: calls `launchConsentDue(ref)`; `hosting.dart`, `providers.dart` and `unawaited` still used (lines 10, 77, 86, 65); 329 lines.
- No copy of the guard in controller_screen.dart (`git grep` for `launchConsentAskedProvider`: only launch_consent.dart:16-17 and tests).
- packages/party_host/test/volume_semantics_test.dart:47-56: `HostText.percent(int)` (host_text.dart:378) returns `'0%'`, `'30%'`, `'100%'` for 0, 30, 100, the same as the lib's `HostText.percent(value.round())` (look_and_sound_section.dart:164). The callback is non-null in the lib, so the assertion holds on the committed code.
- controller_app/test/connect_narrow_test.dart:58: the `knownTopBarOverflow` exception is still there, so c4 left the test as it was.
- `git status` shows no change under packages/party_host/lib or controller_app at the start; c3's claim that look_and_sound_section.dart is unchanged is consistent with that.

## Decisions to confirm

- `launchConsentDue` (launch_consent.dart:14): the name is the brief's, but the function marks the launch asked, so the name hides a side effect; a verb such as `claimLaunchConsentAsk` would follow guidelines §4 (commands as verbs). Owner to pick.
- c4 (owner question, unchanged): option A (narrower segment padding under about 600 dp), B (scroll or overflow menu under that width), or C (declare 568x320 TV look unsupported and keep the test exception).
- c3 test covers Sounds and Music sliders in the palette tests only; phone "Play on this phone" / TV setups not asserted (c3 Q2). Judge whether that is enough.
- c5 brief said connect_screen.dart was 378 lines; it was 332 before the job (git show 24e692b9:…), 329 after. The shrink is met; the brief's figure was wrong.

## Could not check

- Test results: c3's mutation run (FAIL with the callback deleted, PASS restored) and c5's "OK 121 tests controller_app" were not re-run in this read-only review; they are the workers' claims.
- c3 "old code" claim: the mutation shows the new assertions fail without the callback; whether the original assertion alone passes on the old code (REVIEW.md:117) is not separately verified, as c3 says.
- c5 host setups: which of the 121 tests cover each host setup was not mapped (c5 did not map them either).
- The brief's review-report sections are Summary, Findings, Decisions to confirm and Could not check; the closing sections below follow the designer's request.

## Commit message — a draft

Review wave2 jobs c3, c5 and c4 (report only)

Read-only review of the wave2 changes against the guidelines, review rules
and each brief. No code or document changed; findings are in
docs/briefs/m16/close/wave2-review-report.md. Two should findings are open:
the volume test name does not state the formatter rule, and c5's self-check
A1 names no test. c4 stays an owner question.

## Status row

wave2 review (c3, c5, c4): verdict small fixes, 0 must; open: rename the volume test, c5 self-check A1 with tests, c4 barPadding expression, c4 Summary block; owner picks c4 option A, B or C.

## Delete

- none
