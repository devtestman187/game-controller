# y0c report: old phones play the choices on A/B/X/Y

## Summary

Done: the old-phone fallback for the choice round is in `choice_fallback.dart`, with its tests in a new file. Nothing calls it yet (no host wiring, no phone UI), so it changes no behaviour on its own.

- `oldPhoneButtons(cards)`: the one mapping. Cards take A, B, X in order; Y is "Clear", or the fourth card when there are four.
- `oldPhoneStatus({card, count, currency, defaultTitle})`: "Build 3 = 9 Bolts", "Save +2", "Default: <title>", or hidden. Cut to 24.
- `OldPhoneChoices`: `start()` sets labels, hidden buttons and status for each phone without `Capability.choices`; counts not-held-to-held presses into `round.pick(..., locked: false)`; at close (or `dispose()`) it sets the standard layout and a hidden status.
- Tests: 4 mapping, 3 status, and 9 per transport (webSocket, inProcess) on a started `HostServer`, with `MemoryGameHost`.

Test values computed by hand (the expectations in the test file):
- Three taps on Build (cost 3, maxCount 3): count 3, status "Build 3 = 9 Bolts"; a fourth tap stays at 3.
- Hold, release, hold on Build: count 2, status "Build 2 = 6 Bolts" (the first hold alone gives "Build 1 = 3 Bolts").
- 40-char title: label is the first 12 chars; status is cut to 24.
- Nothing chosen with default "Save +2": "Default: Save +2".

Decisions (the brief left these open):
- Labels are the card title cut to 12 (no count in the label). The count is in the status only. See question 1.
- A press on a disabled card does nothing (the round would ignore the pick anyway).
- Cards after the fourth are not mapped (contract: only four buttons).
- `OldPhoneChoices` gets `start()` and `dispose()` methods. The brief gave only the constructor, but the sets-at-start and reset-at-close steps need a start point.
- A plain card's status is its title only; cost shows only for counted cards.
- No default and nothing chosen gives `StatusMessage.hidden()`.

## Self-check (review-rules part A)

1. Host setups: `TestTransport` loop covers the TV/PC host over webSocket and inProcess; the old phone is `phone-2` (no capability), the capable phone is `phone-1`. Phone on "Play on this phone" / "Show on this device" and a joined phone are not touched by this job (no phone UI; N/A). Test: "start sets the labels and the status of an old phone only".
2. Kept state starts at `start()` (layouts, statuses, input and round listeners) and ends at `_finish()` (close or `dispose()`). Nothing going on: with no old phones, `start()` sets nothing and `_finish()` does nothing. Test: "the layout and the status go back to standard and hidden at close". Not tested: `dispose()` without a close.
3. Combinations with the pause menu, host away, player away, "Get ready", dropped link, results and leaving: not covered here. Round-level behaviour is y0b's. A dropped old phone just stops sending input; no test for that.
4. Files: the four allowed files only.
5. Nothing stopped or overstepped.
6. Looks: no UI in this job (N/A).

## Checks

- `tools/mine.sh`: format OK (3 files), analyze OK (packages/connection), 425 package tests OK. The first run had one analyzer info (redundant `pickId: null`, and a redundant `cardId: null`); both fixed, and the rerun is clean.
- Not run: the brief's direct `dart analyze` and `dart test <two files>` commands. The worker rules say use `tools/mine.sh` only, so I used that. Its test run is the whole package, so I did not get a separate count for the new file.

## Questions

1. The owner's note "A = 'Build 1'" could mean the label carries the count, which would need a `setLayout` on every change. I took labels as the card title (the brief's signature has no count). Please confirm.
2. `choice_fallback.dart` now holds two public types (`OldPhoneButton`, `OldPhoneChoices`). The coding guidelines say one public type per file, but the allowed-file list has only this one file. Kept as the brief names them; a split needs one more allowed file.
3. The brief's `tests-first: exempt` line is kept; the new test file is the first test and passes on the new code.
4. Suggestion: a test for `dispose()` without a close, and for a dropped old phone (input stops), when y0d wires the caller.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

connection: old phones play the choice round on A/B/X/Y

Adds choice_fallback.dart: oldPhoneButtons maps the cards to A, B, X
and Y (Clear, or the fourth card), oldPhoneStatus writes the short
status ("Build 3 = 9 Bolts"), and OldPhoneChoices counts the presses of
a phone without the choices capability as picks in a ChoiceRound.
The layout and the status are reset when the round closes.
Nothing calls it yet; the host wiring comes later.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

y0c: done: old-phone A/B/X/Y mapping, press counting, status and reset (choice_fallback.dart, tests in choice_fallback_test.dart). Open: no caller yet (host wiring and phone UI), and the label question (title or count in the label).

## Delete

- none
