# m165 run review: B-043 (a2), read as one change

## Summary

- Verdict: **one fix batch** (all findings in controller_app; no must).
- Counts: must 0 · should 4 · could 4.
- Scope read: commits 362a2454 (a2 change) and 86ff90b2 (runner log/brief); `git diff 7529db41..86ff90b2` (6 files, +281 −6).
- Carry-over (step 1): none. No per-job `*-review-report.md`, no `run-findings.md`, no `STATUS.md`, no `REVIEW-VERDICTS.md` exist in the folder. The only per-job report is `a2-report.md`; its findings are the ones below.
- Hand-fix (step 2): one `HAND-FIX` in run.log (a2: `_pad()` extracted by hand after review.sh flagged `_body` over 60 lines). Tests-first proof exists (run.log 13:52:26). Per-job review report for a2 does not exist (wave review was skipped by design).
- Top five:
  1. **should** `controller_screen.dart:209-212`: the tests never show what happens to a press already held on the pad when the card arrives (rule B4, no stuck input).
  2. **should** `result_card_pad_test.dart:82-95`: tests-first gap: the hidden-pad assertion was never seen failing on the old code (a2-report.md:42).
  3. **should** `controller_screen.dart:190-233`: combinations (pause menu, host away, Get ready, dropped link, leaving) and host setups (TV/PC, "Play on this phone") are not tested (rules A1, A3).
  4. **should** `controller_screen.dart:365`: the file is 365 lines, over the ~300 target and 8 lines more than at the run base (357); 15 lines under the 380 cap.
  5. **Fixed, unverified: needs device check**: B-043 (pad hidden under the card; waiting line 15 → 18 px). Tested by widget tests only; no device run; the 18 px line's wrap at 568x320 is not measured.
- Questions only the owner can answer: see Open questions (Q1–Q4).

## Findings

- **should** `controller_screen.dart:209-212` Offstage hides the pad but keeps `_Controls` mounted, and no test checks a press already down when the card arrives (B4: every way input stops releases everything) → add a test: pointer down on a face button, card arrives, pointer up; assert nothing is sent and the press state clears; fix in the pad if it does not. (from: a2) phone-pinned.
- **should** `controller_screen.dart:190` and `result_card_pad_test.dart:82-95` the hidden-pad assertion was never seen failing on the old code: the first run failed on a wrong precondition (`leftStick`), and the face-button version was not run against the old `controller_screen.dart` (a2-report.md:42) → run the test against the pre-a2 `controller_screen.dart`, record the failing `findsNothing` line, put it in the report. Measurement only, no code change. (from: a2) phone-pinned.
- **should** `controller_screen.dart:190-233` combinations not tested: the pad hide with the pause menu, host away, "Get ready", a dropped link and leaving (A3), and the hosting path (`_pad` passes `hosting: _hosting`, so "Play on this phone" and the TV/PC host reach the same code) (A1). The report says "not checked" (a2-report.md:30, 32) → add one test per pair that can happen with a result card, or name them as open in the Status row. (from: a2) phone-pinned.
- **should** `controller_screen.dart:365` the file is 365 lines (357 at 7529db41), over the ~300 target; it grew by 8 lines this run, after the `_body` review limit was hit → move the Stack children of `_body` (or `_pad`) into a named widget in its own file before the next change to this screen. (across jobs) phone-pinned.
- **could** `result_card_pad_test.dart:125` the waiting text is matched by a hard-coded string; the widget uses `PhoneText.waitingForNext` (`result_card.dart:63`), so a copy change silently breaks the size check → compare with `PhoneText.waitingForNext`. (from: a2) phone-pinned.
- **could** `result_card_pad_test.dart:11`, `:17-40`, `:46-61` and `result_card_fit_test.dart:11`: `cardSizes`, the finished-round fixture and the setup are copied between two test files (the first test also repeats `finishRound`'s steps at `:73-81`) → move the shared fixture to a `controller_app/test/support/` file and use it from both. (across jobs) phone-pinned (tests only; the fit test is outside a2's change, so it needs its own job).
- **could** `controller_screen.dart:190`, `:204`, `:209`, `:216`: `resultShown` is a state word, and the guidelines say booleans ask a question → rename to `isResultShown`. (from: a2) phone-pinned.
- **could** `result_card_pad_test.dart:109-111`: `finishRound` returns a `TestApp` that no caller uses → drop the return value. (from: a2) phone-pinned.

Fix-job sizing (all controller_app, all phone-pinned, one wave, no shared file within a job):
- Job A, `controller_screen.dart` only: the split (`:365`) and the rename (`:190-216`). 2 findings.
- Job B, `result_card_pad_test.dart` only: held-press test (`:209-212`), the tests-first measurement (run only), the string match (`:125`), the unused return (`:109-111`). 3 findings plus a measurement.
- Job C (after B, same file set): the shared fixture (both test files). Needs B first: the pad test file is in both.
- Job D: combination tests (new file, phone-pinned) — can run with A and B.

## Open questions

- Q1: Should the pad test also cover the TV/PC host and "Play on this phone" (a2-report.md:75)? Suggested answer: yes, for "Play on this phone" (it uses `_Controls` with `hosting: true`); TV/PC not touched by this change.
- Q2: Does the 18 px waiting line wrap on the smallest phone, 568x320 (a2-report.md:76)? Suggested answer: check on a device before the next TestFlight build; the widget test passes but does not show the wrap.
- Q3: Does the all-looks rule (review-rules A6, `packages/party_host/test/support/all_looks.dart`) apply to phone palettes? The new test covers only `sunny` and `night` (a2-report.md:35). Suggested answer: no for the phone (its look is the palette); the TV look is not on the phone.
- Q4: The head-to-head arms `a1s` (rc 0, 95 turns) and `a1h` (rc 4, 119 turns) are kept, not committed, with no reports in this folder. Which one, if either, goes forward? Suggested answer: `a1s` (it finished with rc 0); discard `a1h` after the driver records why it exited 4.

## Numbers against targets

- Waiting line (`result_card.dart:66`, `look.type.button`): 18 px, from `packages/toy_look/lib/src/toy_type.dart:17` (`_buttonPhonePx = 18.0`); was 15 (`_bodyPhonePx`, `:18`). Target (brief): at least the name row and larger than the standings rows. Name row 18, standings rows 15: **met** (test `result_card_pad_test.dart:114-142`).
- Header title 32 px (`_titlePhonePx`): excluded from the check by the brief; not a target miss.
- `controller_screen.dart` length: 365 lines, target ~300 (hard limit 400, touched-file cap 380): **misses the ~300 target**; under the cap.
- Test count: `tools/mine.sh` reported 63 controller_app tests passing (a2-report.md:39); not re-run in this review.

## Could not check

- The a2 review report, the tests-first run against the old code, and the arms `a1s`/`a1h` are not in this folder; their results come from run.log and a2-report.md only.
- Whether `_Controls` stops its own tickers or gyro input under the card: `Offstage` does not stop tickers, and I did not read the pad's press code, so the held-press finding (S1) needs the pad's code read by the fix job.
- Device behaviour (touch under the card, the 18 px line's wrap): not run; the review did not start apps or devices.
- The menu look: a2-report.md:35 says not checked; the code path is the same, so I did not judge it.
- The three checks named in the run (`tools/mine.sh`, `flutter analyze`) were not run here: this review changes no code.

## Commit message — a draft

- none: this review changes no code and makes no commit.

## Status row

m165 review: the run's one commit (a2, B-043) is reviewed; open: held-press and combination tests, the tests-first measurement on the old code, the 365-line `controller_screen.dart`, the 568x320 device check of the 18 px line.

## Delete

- none
