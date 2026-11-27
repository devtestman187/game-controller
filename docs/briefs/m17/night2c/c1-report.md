# night2c c1 report: old phones get no Roadworks; the version message names the app to update

## Summary

- Old phones (no `Capability.choices`) are never offered the Roadworks card, even as the last player number. Capable phones are unchanged: the last one still gets Build, Save and Roadworks.
- The version-mismatch text now says plainly which app to update, in one line for kids and parents. No `protocolVersion` change, no new message, no new compatibility code. `choice_fallback.dart` is untouched.
- Tests: `tools/mine.sh` → `OK 20 tests packages/party_host`, 4 files formatted, 1 package analyzed (party_host), no findings. Connection was not touched and not run.
- Tests that pin the new behaviour:
  - `shop_demo_test.dart`, "Roadworks is offered to the last player number only, and only if it lists choices": Ann (player 1) gets `build, save`; Bea (last, capable) gets `build, save, roadworks`. Run in both the menu and TV looks.
  - `shop_demo_test.dart`, "an old phone that is the last number gets Build and Save only, so its X button is hidden": Bea is an old phone. Her layout has A = `Build`, B = `Save +2`, no X label, and X is in `hidden`. Run in both looks.
  - `phone_text_test.dart`, "a version mismatch says in plain words which app to update, for kids and parents": the text equals the new line, its length is 150 characters (< 200), and it does not contain "protocol".
- No test pinned the old text. `git grep "Install matching builds"` finds only `phone_text.dart`, so no test was updated for it. `controller_app` has no copy.

## Files changed

- `packages/party_host/lib/src/ui/shop_demo_screen.dart`: `cardsFor` gives `_lastPlaceCards` only when the last player is also capable. A new `_listsChoices(host, playerId)` looks the phone up in `host.server.snapshot.controllers` and calls `supports(Capability.choices)`. The `_lastPlaceCards` doc comment says so.
- `packages/party_host/lib/src/text/phone_text.dart`: `versionMismatch` text is now "This phone app and the TV app are not the same version. Update the Thumb Party app on the TV, or on this phone (Android or iPhone), so both are new." It is split across two string literals for the 120-column limit.
- `packages/party_host/test/shop_demo_test.dart`: `_openRig` and `_pumpDemo` take `oldNames`. An old name's phone joins with `Capability.layout` only, so it gets no offers and waits only on its layout. The Roadworks test name now says "and only if it lists choices". The new old-phone test is added. It ends the round, so no timer is left pending.
- `packages/party_host/test/phone_text_test.dart`: new test for the mismatch text. It also gained a `package:connection` import for `ClientSnapshot`, `ClientStatus` and `ClientProblem`.
- `docs/briefs/m17/night2c/c1-report.md`: this report.

Not touched: `packages/connection/test/choice_fallback_test.dart`. Its tests call `oldPhoneButtons` directly, and that code did not change, so I left it alone. I did not run it, since it is in another package and was not touched.

## Computed values for the expectations

- New version text length: 150 characters (count of the literal, under 200).
- Old phone's layout for a two-card round: `labels` A = `Build` (`ShopText.build`), B = `Save +2` (`ShopText.save`), Y = `Clear`; X is in `hidden` (`_layoutFor` hides every card button not used).
- Round length in the test is 20 s (`_roundLength`), the same value as before.

## Self-check (review-rules part A)

1. Host setups: the TV test rig (`shop_demo_test`) covers the TV host; the old phone is "a peer one build older" in the test (no choices capability). A phone on "Play on this phone" or "Show on this device" is not touched by this change, and the test does not cover those setups.
2. Kept state: the old-phone test starts a round and ends it with `pump(_roundLength)` and `_until(ends)`. Nothing new is kept.
3. Combinations: pause menu, host away, player away, "Get ready", dropped link, results and leaving were not changed and are not exercised by the new tests. The existing "leaving closes the round" test still passes.
4. Files: all inside `allow:`.
5. No stop needed.
6. Looks: the new test runs in the `menu` and `tv` looks (both pass). No fixed pixel height was added.

## Decisions

- An old phone's identity in the test carries `Capability.layout`, so it receives layouts. Without it the layout would not reach the phone. I assumed a real old app also has layout; I did not verify this against the old app build.
- The old-phone test waits for the layout whose A label is `Build`, not for the first layout. The phone can hear other layouts first; I did not measure which.
- `_listsChoices` uses `controllers` (not `connected`), as the brief said.

## Questions

1. Should the version text name the phone app as "Thumb Party app on this phone (Android or iPhone)" as written, or does the owner want the store names?
2. Is `Capability.layout` the right capability for an old app in the test? I assumed so.

## Suggestions

- `night_start_screen.dart:135-140` has the same "old phone = no `Capability.choices`" rule. A shared helper could replace the inline checks in both places. Not done here: it is outside `allow:`.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
night2c c1: old phones get no Roadworks; version text names the app

Phones without the choices capability are never offered the Roadworks
card, even as the last player number, because they have no card for it.
The version-mismatch text now says in plain words which app to update
(the TV app, or the phone app on Android or iPhone). No protocol bump.
```

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2c c1: done — old phones get no Roadworks (shop demo); version mismatch text names the app to update; open: device check of the old-app layout assumption.

## Delete

- none
