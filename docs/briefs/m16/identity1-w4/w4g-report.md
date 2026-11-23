# M16 w4g: test hardening report

## Summary

Three test-only changes, no lib code. `tools/check.sh format analyze phone connection look` passed: format, analyze, phone (181 s), connection (353 tests), look (145 tests).

Changes:

1. `controller_app/test/host_chip_test.dart`: the badge test now changes the saved profile to `orangeBow` (colour slot 2, bow) after the phone has paired. The chip must still wear the host's answer, `tealCrown` (slot 4, crown), so it passes only when the chip shows what the host answered. Added the `orangeBow` constant beside `tealCrown`. `pumpHostApp` now returns its `TestApp`, whose `prefs` is used to save the new profile through `tester.runAsync`.
2. `packages/connection/test/identity_host_test.dart`: the `second` phone was `newClient(..., capabilities: viewOnly)`. The library adds `Capability.identity` to every hello (`controller_identity.dart`, `libraryCapabilities`), so that phone does listen for `players`; its `clientUntil(... players.isNotEmpty)` wait proves it. The `viewOnly` label was wrong. I removed the capability and fixed the comment. The assertions are unchanged: the first identity phone's list must include `phone-2` on join and drop it on leave.
3. New `packages/toy_look/test/palette_order_test.dart`: checks that `PlayerCharacter.colourIds[slot - firstSlot]` equals `ToyCharacter.colourNames[slot - firstSlot].toLowerCase()` for slots 1 to 6, and that both lists have six entries.

## Computed values

- Chip test: host answer `tealCrown` = `PlayerCharacter(colourSlot: 4, accessory: crown)`; saved profile after pairing `orangeBow` = `PlayerCharacter(colourSlot: 2, accessory: bow)`. The badge must equal `tealCrown`.
- Palette: `colourIds` = blue, orange, purple, teal, pink, yellow. `colourNames.toLowerCase()` = blue, orange, purple, teal, pink, yellow. Each slot matches; both lists have length 6.
- Identity test: expected first-phone list on join `['phone-9', 'phone-1', 'phone-2']`, after leave `['phone-9', 'phone-1']` (unchanged).

## How each changed test fails on a broken value

I did not show these by mutation. Changing lib code is out of this job, so the claims below are from reading the code and are not run.

- Chip test: if the chip showed the saved profile, `badge.character` would be `orangeBow` and the `expect(badge.character, tealCrown)` line fails. The `own.character` check at the top is unaffected by the profile change, which is why it is kept.
- Identity test: the change is to a test's own setup, not a broken value. It makes the test honest, so there is no failure to show. The list assertions are unchanged.
- Palette test: a broken word, such as `'Teal'` in `colourIds`, or a list out of order, fails the slot's `expect` with `reason: 'slot N'`. It passes on the current code, since both lists agree. This is a pin, not a test that fails today.

## Self-check (review-rules part A)

1. Host setups: the chip test uses the menu and TV looks (`tv` loop); no lib change, so the other setups are unchanged.
2. Kept state: not applicable; no state changed.
3. Combinations: not applicable; test-only.
4. Stayed in allow:. Yes: the three test files plus this report.
5. Stopped: nothing overstepped.
6. Looks: the chip test runs at both the menu size and the TV size; no fixed pixel height added.

## Questions

1. Mutation check: should someone run a broken `PlayerCharacter.colourIds` or the chip's answer locally to see the new checks fail? I can do it if you allow a temporary lib edit.
2. The identity test could use a raw `WirePhone` for `phone-2` with no identity, but leaving the phone needs a disconnect helper in `wire_phone.dart`, which is outside allow:. I took the simpler route.

## Suggestions

- `wire_phone.dart` has no way to close the channel; a `disconnect()` there would let a raw phone leave, which the identity test could then use.

## Commit message — a draft

M16 w4g: test the chip's host answer, identity join, palette words

- host_chip_test: change the saved profile after pairing, so the badge passes only with the host's answer
- identity_host_test: the second phone is a current build (library adds identity), not viewOnly; assertions unchanged
- palette_order_test (new): colourIds match the look's lower-case colour names for all six slots

## Status row

w4g: three test-only changes done (chip answer pinned, identity label fixed, palette words cross-checked); checks pass; mutation runs not done, open for a go-ahead.

## Delete

- none
