# Wave 1 review: e0f and p0a

## Summary
- Verdict: **needs Claude**
- Counts: must 1, should 11, could 7
- 1. (must) p0a-report.md has no self-check (review-rules part A), so one required answer is missing.
- 2. e0f-report.md brief item 4 is not done: inputs/s, lag and bytes at 4/6/8 are all "not measured".
- 3. p0a's brief asks the test to assert the 20 px floor, the free band, the corner width and the verdicts; it asserts only "no overflow". Start and scoreboard texts are 15.0 to 18.72 px (p0a-fit.json).

## Findings
- **must** docs/briefs/m17/m17prep/p0a-report.md:1 The report has no self-check (review-rules A, answered one line each with its test) → add the six answers, each with the test that shows it.
- **should** docs/briefs/m17/m17prep/e0f-report.md:32 The numbers section says "not measured" for inputs/s, lag and bytes at 4/6/8 (brief item 4) → run `bash tools/load8.sh` (needs approval) and fill the two result lines in.
- **should** packages/party_host/test/night_cards_fit_test.dart:94 The brief's asserts for the 20 px floor, the free band, the corner width and the verdict are missing; only "no overflow" is asserted → assert them, or get the owner's decision on the floor (see Decisions) and record it in the brief. No skip or ignore.
- **should** packages/party_host/test/night_cards_fit_test.dart:198 The measurer's geometry (band, corner width, backdrop rule) is never checked against a known layout; the stub at :100 only checks that errors are captured → add a stub with one known box and assert its band and corner values.
- **should** packages/party_host/test/night_cards_fit_test.dart:190 `_measure` takes 6 parameters (tester, root, layout, scale, bodyStyle, errors); the limit is 5 → pass the frame (layout, scale, bodyStyle) as a value object.
- **should** packages/party_host/test/night_cards_fit_test.dart:190 `_measure` is 80 lines (190 to 269); controller_app/test/night_result_fit_test.dart:243 is 74 lines; packages/connection/test/load_eight_phones_test.dart:115 `runLoad` is 67 lines → split each at its seam, about 40 lines per function.
- **should** packages/party_host/test/night_cards_fit_test.dart:100 The measurer, the results-file writer and the overflow stub are copied into controller_app/test/night_result_fit_test.dart:132-164 and :243-330; the copies already differ (rounding, belowFloor) → move the shared measurer to a `lib/testing.dart` in party_host (guideline §2 allows this) and import it from both.
- **should** packages/puzzle_game/test/snapshot_eight_players_test.dart:80 The line is over 120 columns (guideline §4 / format width) → split the string into adjacent literals.
- **should** packages/party_host/test/night_cards_fit_test.dart:216 Bare `1000` (and bare `100` at :292) breaks the no-magic-numbers rule → name them; night_result_fit_test.dart:33 already uses `_decimals`.
- **should** controller_app/test/night_result_fit_test.dart:101 The 360x640 cases are named "draws without overflow", but at :114-121 they assert the card is absent and measure nothing, so brief item 2's 360x640 measure is not made → rename the test to say what it checks, and get the decision in Decisions.
- **should** docs/briefs/m17/m17prep/p0a-report.md:41 Conclusion 3 says option C's strip "is the setup that gives it"; this job did not measure option C → cut the claim to what was measured, or measure option C.
- **should** docs/briefs/m17/m17prep/p0a-report.md:1 There is no Summary block in the first 40 lines (run-findings.md:1 records this) → add a Summary block at the top.
- **could** packages/connection/test/load_eight_phones_test.dart:213 `second.sent == first.sent` cannot fail, because each phone sends seconds × 60 inputs by construction; the seed claim rests on :215 alone → drop :213, or keep it as a note.
- **could** packages/party_host/test/night_cards_fit_test.dart:218 The floor check counts empty-text paragraphs too (p0a-report.md:24 says two exist) → skip paragraphs whose text is empty.
- **could** controller_app/test/night_result_fit_test.dart:126 The second `expect(measured.errors, isEmpty)` checks the same list as :113 → remove it.
- **could** packages/connection/test/load_eight_phones_test.dart:190 The literal `8 phones:` repeats the count → interpolate `phoneCount`.
- **could** docs/briefs/m17/m17prep/p0a-report.md:9 The scale is given as 0.6948; the code (night_cards_fit_test.dart:142) gives min(667/960, 375/540) = 0.6944, and p0a-fit.json rounds it to 0.69 → correct the report.
- **could** packages/party_host/test/night_cards_fit_test.dart:79 `as Map<String, Object?>` on the decoded results file is unchecked → test `is Map` before the cast (same at controller_app/test/night_result_fit_test.dart:92).
- **could** docs/briefs/m17/m17prep/e0f-report.md:21 "The JSON is ASCII, so this equals the byte count" is not asserted by any test → assert it, or drop the claim.

## Decisions to confirm
- The load test uses real time: load_eight_phones_test.dart:117 (Stopwatch) and :147 (`Future.delayed`). Guideline §9 says no real time in tests; the brief asked for a real 60 Hz loop, and the job flagged it. Owner to accept as a measuring exemption.
- The 20 px floor is not asserted (night_cards_fit_test.dart:218). Start and scoreboard fail it: 15.0 to 18.72 px. An assert would fail the suite. Owner to choose: fix the layout later, or record it as a finding.
- The phone card at 360x640 is not measured (night_result_fit_test.dart:114-121). The app shows "Make the window bigger" below `minWindowWidth` 540 (layout.dart:37, controller_parts.dart:184). Owner to confirm that 360x640 means the phone-as-host's portrait window, or to accept the absence result.
- The backdrop rule: a box covering at least 50% of the view each way is ignored (night_cards_fit_test.dart:226, night_result_fit_test.dart:275). The free band and the corner depend on this threshold.
- headFits counts only elements whose top is above 56 dp (night_cards_fit_test.dart:245). This is right for a 56 dp corner square; confirm.
- The eight e0f phones each send the same seeded sequence (load_eight_phones_test.dart:81). The counts are right, but the phones are not eight different players. Confirm.
- e0f-report.md is written but is not in the e0f brief's allow list (it is in its report field). Confirm.

## Could not check
- Whether the tests pass: run.log records "result 0" for both jobs, with no per-test output. I did not run the tests or `dart analyze` (the review is read-only). p0a-report.md has no analyze result (brief item 4).
- The LOAD8 path has never run: the summary line, the 30 s load and the 6/8-player numbers are unverified. The plain run under 15 s is unmeasured.
- ControllerClient.sendInput incrementing inputsSent once per call (load_eight_phones_test.dart:152) and hostUntil's timeout (:161) were not read.
- Popup worst case: maxPopups is per side and each board gets the same list (cat_snapshot_test.dart:61, game.dart:107); I judged the frame consistent with the cat test, not measured.

## Commit message — a draft
m17prep wave1 review: e0f and p0a findings (report only)

Adds docs/briefs/m17/m17prep/wave1-review-report.md: a review of the e0f and p0a jobs against
the coding guidelines, the review rules and their briefs. No code or other document changed.
Findings: 1 must, 11 should, 7 could. Main: p0a has no self-check; e0f numbers unmeasured;
p0a's floor and verdict asserts missing (owner decision on the 20 px floor).
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row
wave1 review (e0f, p0a): done: both jobs reviewed, 1 must / 11 should / 7 could in wave1-review-report.md; open: e0f numbers not measured (tools/load8.sh), p0a self-check and floor/verdict asserts, owner decision on the 20 px floor.

## Delete
- none
