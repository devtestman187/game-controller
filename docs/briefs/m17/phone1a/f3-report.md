# f3 report: old-phone fallback fixes and test tidy

## Summary

Changed: `packages/connection/lib/src/choice_fallback.dart` and `packages/connection/test/choice_fallback_test.dart`. No ChoiceRound change, no mapping change (`oldPhoneButtons` is untouched).

- An old phone of the round that is not in the snapshot at `start()` is now set up when it appears: `OldPhoneChoices` listens to `round.server.changes` (subscription cancelled in `_finish`) and calls the same `_syncPhones` that `start()` uses. The setup is the same as at start (labels, layout, status, counting), with no extra limit.
- When an old phone is no longer connected its `held` set is cleared, so the next press after it is back counts.
- Dartdoc line added to the `OldPhoneButton` and `OldPhoneChoices` constructors.
- Tests: two new tests (late connect; drop clears held). The unread `_Setup.choices` field is removed. `12` and `24` are replaced by `GameLayoutMessage.maxLabelLength` and `StatusMessage.maxTextLength`, and the two test names no longer hard-code the numbers.
- `tools/mine.sh`: format, analyze, and `packages/connection` tests: 59 tests OK, analyze clean.

Decisions:
1. "the outcome at close is the stored pick" was kept. The brief said to delete it only if it repeats the "B after A" path. It checks the A-only pick (cardId `save`, count 1, not by default), which no other test asserts, so it does not repeat that path.
2. "has no cap" was read as: the late phone gets the full setup (layout, status, counting) with no reduced or capped setup.
3. `_isOldPhone` and `_syncPhones` are a top-level function and a method, to keep `start()` and the change listener on one path.

Self-check (docs/review-rules.md part A):
1. Host setups: TV and PC host both run through `TestTransport.values` (webSocket and inProcess); phone-1 is the capable phone, phone-2 the old phone; a late phone is covered by the new test under both transports.
2. Kept state: `_phones` and `held` start empty, are set at `start()`, and are cleared in `_finish`, which also cancels `_serverSub`. With nothing going on (no old phones), `_syncPhones` does nothing. Test: "start sets the labels and the status of an old phone only".
3. Combinations: the `_finished` and `round.isClosed` guards stop the listener after close or dispose. Test: "the layout and the status go back to standard and hidden at close" (existing, unchanged).
4. Only the two allowed files were changed (plus this report).
5. No stop needed.
6. Looks: no layout or size change in this job; the layout and status are the existing `GameLayoutMessage` and `StatusMessage` values.

## Tests and values computed

- Late connect (`oldPhoneIn: false`): before the connect, `layouts` and `statuses` have no `phone-2`. After connect, labels are `a: 'Save +2'`, `b: 'Build'`, `x: 'Roadworks'`, `y: 'Clear'`, status `'Default: Save +2'`. Presses: B (count 1), release, B (count 2). Status `'Build 2 = 6 Bolts'` (cost 3 × 2), close count `2`.
- Drop: B pressed (status `'Build 1 = 3 Bolts'`), `dropAllConnections`, phone back, B pressed again with the held set cleared: status `'Build 2 = 6 Bolts'`, close count `2`. Without the fix the held `{b}` suppresses this press, so the status stays `'Build 1 = 3 Bolts'` and the test fails on the old code.
- The truncated label expectation is `substring(0, 12)` (`GameLayoutMessage.maxLabelLength` = 12); the status expectation is `<= 24` (`StatusMessage.maxTextLength` = 24).

Not run separately: `tools/check.sh` (the script runs it after the job), and the "fails on the code as it was" proof for the two new tests was reasoned from the code path above, not run.

## Questions

1. A phone that drops and comes back keeps its old layout and status in the host. Does the host reset the phone's layout on reconnect? If not, a reconnect with a changed layout is not re-sent; this job does not re-send it.
2. Should a late phone wait until it is connected (`snapshot.connected`) rather than listed (`snapshot.controllers`)? This job matches `start()`, which uses the listed controllers.

## Suggestions

- `run-review.md` has no finding that names `choice_fallback` (a grep for "fallback" found only the brief's own text); the brief's reference to those findings may be out of date.

## Commit message — a draft

Old-phone fallback: set up late phones and clear held buttons on drop

A phone of the round that connects after start is now set up when it
appears (labels, status and counting), not left without them. A phone
that drops forgets its held buttons, so the next press after it is back
counts. Adds two tests for these, and uses the protocol's label and
status limits in the tests instead of 12 and 24.

## Status row

f3 done: old-phone fallback sets up late phones and clears held buttons on drop, with two new tests; open: reconnect does not re-send an old phone's layout (question 1 in f3-report).

## Delete

- none
