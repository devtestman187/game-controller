# Wave 5 review: the nh2 job (efb59bdf)

## Summary

needs Claude
Counts: must 0 · should 6 · could 0
1. The committed nh2-report.md is stale: it says the two reveal test files FAIL and need an override, but the same commit adds those overrides (hand-fix, outside nh2's allow list).
2. The reveal's Back path is claimed in the self-check to send the night's end once, but no test covers Back.
3. nightEndFor sends `points: awardPoints` (3) for an award nobody won, against the protocol doc "the points the award adds to each of its winners" (a "Not won" row can show +3).

## Findings

- **should** packages/party_host/test/night_end_send_test.dart:128 The `expect` reason line is over 120 columns (lines 83 and 134 too: the testWidgets names); dart format would split these, so the file is not formatted to the 120-column rule → wrap them as dart format does (`dart format` on the file) and run the format check again.
- **should** packages/party_host/test/round_results_test.dart:60 The new comment is over 120 columns → wrap it onto two `//` lines.
- **should** packages/party_host/lib/src/night/night_end.dart:36 An award nobody won is sent with `points: awardPoints` (3), while the protocol doc at packages/protocol/lib/src/night.dart:15-16 says "the points the award adds to each of its winners" → send 0 when `outcome.winners` is empty, or amend the doc; Claude decides which (see Decisions).
- **should** docs/briefs/m16/bugs4/nh2-report.md:43 The Blocked section, question 1 and the Status row (line 80) say the frame and tie tests fail and need an override, and the commit message draft (lines 75-76) says the override is "not yet done"; the commit now adds both overrides → rewrite those lines to the state of the committed tree (both files pass or not, as the runner shows).
- **should** packages/party_host/test/night_reveal_frame_test.dart:131 The override was added by the runner's hand-fix (DRIVER-NOTES: "class c"), in two files outside nh2's allow list (night_reveal_frame_test.dart and night_reveal_tie_test.dart at line 119) → Claude to confirm the edit stays, and record it in nh2-report.md and in the allow list.
- **should** packages/party_host/test/night_end_send_test.dart:73 The self-check (nh2-report.md:36) says Escape, Back and the timer all send exactly once, but only Escape and the timer are tested; the Back path (PopScope → `_finish`) has no test → add a test that presses Back (as the reveal tests do) and expects `hasLength(1)`.

## Decisions to confirm

- `points` of an award nobody won is `awardPoints` (3) in `nightEndFor` (night_end.dart:36): the brief's literal wording, but it contradicts the protocol doc; the phone would show +3 on a "Not won" row if it reads this field.
- Robo's standing has `id: null` (round_results.dart `viewStandingsOf`, Robo branch): the brief said `id: row.id`; the worker followed the protocol doc for null-for-Robo. Confirm, or carry `roboPlayerId`.
- `place` in a last-round card now comes from the pre-award rows (round_results.dart:34-35 area, `rowsById[id]?.place`): beyond the brief's item 3, which named only the standings; it matches the standings beside it.
- Hand-fix of the two reveal test files (see Findings): the job's allow list did not include them.

## Could not check

- Tests were not run: this review is read-only (git show and reads only). The "passes" claims in nh2-report.md (+31, `tools/mine.sh`) are unverified here.
- Whether the Try Again outcome (test "awards change who is first", night_end_send_test.dart:137) gives no win, which the expected `[10, 9]` needs; the reveal logic was not read.
- Whether `night_reveal_frame_test.dart` and `night_reveal_tie_test.dart` pass with the hand-fix, and whether the other reveal tests (DRIVER-NOTES: "11 reveal tests") pass; no run.log entry for nh2 exists.
- Whether `sampleState` exists in `package:party_host/testing.dart` (the two files import it; the definition was not opened).
- run-findings.md does not exist in docs/briefs/m16/bugs4, so there are no run-findings entries to check.
- The full coding-guidelines and review-rules files were not opened; the worker extract was used for the rules.

## Commit message — a draft

M16 bugs4 wave5 review: findings on nh2 (efb59bdf)

Read-only review of nh2 against its brief and the rules. Adds this report
only. Findings: test lines over 120 columns (night_end_send_test,
round_results_test); no Back test for the night's end; nh2-report.md is
stale on the two reveal test files; the hand-fix outside allow needs a
decision; unwon awards send 3 points against the protocol doc.

## Status row

wave5 review of nh2: done (report written, no code changed); open: five should findings and the points/Robo/hand-fix decisions for Claude.

## Delete

- none
