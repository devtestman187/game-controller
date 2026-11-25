# m16 m165 wave1 review: a2 (B-043, the pad under the result card)

Commit reviewed: 362a24545dc7b242c8f26d550090f4110ba7190d (read with `git show` and `git diff`; nothing changed).

## Summary

- Verdict: small fixes
- Counts: must 0 · should 3 · could 2
- Top findings:
  1. A joined phone's gyro tilt keeps sending under the result card: the pad is only hidden (Offstage), and `padOnScreenProvider` is always true off a host.
  2. The pad test's standings loop passes with no rows at all, because it never asserts that `standing-1` and `standing-2` exist.
  3. No test holds a press on the pad when the card arrives, so the input-safety rule (B4) for a hidden pad is untested.

## Findings

- **should** controller_app/lib/src/ui/controller_screen.dart:209 `_pad` hides the pad with `Offstage`, but a joined phone's tilt (gyro.dart:141, `_followPad`) follows `padOnScreenProvider`, which is always true off a host (providers/pad.dart:29-41), so tilt keeps sending to the TV while the card covers the pad → make the card's showing release tilt or feed `padOnScreen` (or record it as a decision with a test that tilt stops).
- **should** controller_app/test/result_card_pad_test.dart:133-142 the standings loop runs `for (final text in ...)` over `standing-N` rows, and an empty finder passes every `lessThan` check, so the check passes if the rows never render → add `expect(find.byKey(Key('standing-$number')), findsOneWidget)` before the loop.
- **should** controller_app/test/result_card_pad_test.dart:68 no test covers B4 (input safety): a finger held on `faceButtons` when `view_end` with a result arrives, then lifted, is never checked for a stuck press or a release sent to the host → add a test that presses the pad, sends the result, lifts, and asserts the host received a release for each held button.
- **could** controller_app/test/result_card_pad_test.dart:71-81 the pre-card setup repeats lines 46-59 (`finishRound`) → split the helper so the pad precondition runs before the card, and reuse it.
- **could** controller_app/test/result_card_pad_test.dart:125 the header is skipped by the literal `'You win!'`, so a different outcome would make the header count against the waiting line → skip by a key on the header instead of its text.

## Decisions to confirm

- `Offstage` rather than removing the pad: the pad keeps its state and its tilt (see the first finding). Why it matters: the card does not stop input the way the rules say a hidden pad must.
- Waiting line uses `look.type.button` (18 px on a phone) instead of body (15 px): the owner's B-043 asked for readability; the card still scales as a whole (`FittedBox`, result_card.dart:46). Confirm on a device at 568x320.
- The pad test copies the setup of `result_card_fit_test.dart` rather than importing it. Fine, but the copy is now a second maintained setup.
- Host setups (A1): the change is in the joined controller only; a TV or PC host, "Play on this phone" and "Show on this device" are not tested, and the report says so. Confirm that is acceptable for B-043.

## Could not check

- docs/briefs/m16/m165/run-findings.md does not exist, so there is no runner evidence on whether the new tests fail on the old code.
- I did not run the tests or `flutter analyze` (read-only job). The report's claims (63 tests, analyze clean, 2/1/13/2/7 passes) are unverified.
- By reading, the `findsNothing` assertions at result_card_pad_test.dart:91-95 fail on the old code (the pad is in the tree and not offstage); the report says this was not seen, so it is still unconfirmed by a run.
- Whether the joined phone's tilt is also stopped by some other path after a round ends (I traced only `padOnScreenProvider`).
- The menu look and the TV look were not checked for the waiting line; the tests cover the sunny and night palettes only.
- Wrapping of the larger waiting line on the smallest phone (568x320) on a device.

## Commit message — a draft

none: this is a review; it changes no code and no document except this report.

## Status row

m165 wave1 review of a2 (362a2454): verdict small fixes (0 must, 3 should, 2 could); open: the tilt-under-card question, the vacuous standings loop, the held-press test, and an unrun check of the new tests on the old code.

## Delete

- none
