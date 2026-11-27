## Summary

Verdict: needs Claude
Counts: must 4 · should 7 · could 3 (y0d made no code, so nothing to review there)
1. packages/party_host/test/touch_targets_host_test.dart:63 exempts the "Try the shop" button below 48 dp on phone sizes, which no decision lists.
2. packages/party_host/test/night_start_frame_test.dart:99 is a required run that y0e did not do; its four phones are old apps now, so they show the new count line.
3. packages/party_host/test/night_start_old_app_test.dart:97 passes on the old code, which the review rules call a must.

## Findings

- **must** packages/party_host/test/touch_targets_host_test.dart:63 Six `openShopDemo` entries exempt the button from the 48 dp rule at 375, 568 and 640 widths, and y0f's Decisions list does not mention it → make the button 48 dp on phone sizes, or list the exemption in the report as an owner decision.
- **must** packages/party_host/test/night_start_frame_test.dart:99 Its four phones come from `phoneInfo` (packages/party_host/lib/src/testing/samples.dart:52), which sets no capabilities, so they now show "4 players have an old app…"; y0e did not run this file, which its brief required → run it through tools/mine.sh and fix any failure it shows.
- **must** packages/party_host/test/night_start_old_app_test.dart:97 "no old-app line shows when every phone lists the choices capability" passes on the old code, where no line existed → say in the test that it is a guard the old code passes, or fold the check into a test that fails on the old code.
- **must** packages/party_host/test/shop_demo_test.dart:164 The `sendChoicePick(...)` line is 121 columns, so dart format would wrap it and the format check fails → wrap it the way dart format does.
- **should** packages/party_host/lib/src/ui/games_screen_widgets.dart:9 `gameCardHeightPx` 340 → 308 and `gamePictureHeightPx` 186 → 154 (line 10) shrink the three game cards, which the y0f brief said not to change → get the owner's answer, or fit the button without changing the card height.
- **should** packages/party_host/lib/src/ui/games_screen_widgets.dart:32 `_PickerBody` now takes six parameters (lines 33-38, with `onShop` at 37) against the five-parameter limit → group the callbacks into a value object.
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:37 The nine demo strings sit in a private `_ShopText`, not in HostText as the brief says; the report's reason ("host_text.dart at 379 lines") is off, since the file is 380 lines and the limit is 380 → move them to a text file of their own, or ask the owner to accept the split.
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:62 The comment says Roadworks goes to the "last place", but line 102 gives it to `players.last`, the last player number → change the comment to "last player number", and confirm the rule with the owner (its default said "last place").
- **should** packages/party_host/test/night_start_old_app_test.dart:97 The brief asked for every look; the file has no HostLook loop, so it runs one look (shop_demo_test.dart:133 does loop) → loop `HostLook.values` with `pumpHostLook` in the new tests.
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:106 The host-own exclusion (`!controller.isLocal`) and the no-phone-session case have no test → add a test with a local controller that must not be named or counted.
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:109 The old-phone path (`OldPhoneChoices`) and the pause, host-away and dropped-link combinations have no party_host test, as y0f's self-check admits → add a test for a phone without the cap, or list these as open items for Claude.
- **could** packages/party_host/lib/party_host.dart:103 `ShopDemoScreen` is exported from the package but only games_screen.dart uses it → drop the export unless a caller outside the package needs it.
- **could** packages/party_host/test/shop_demo_test.dart:31 The comment is 121 columns → rewrap it.
- **could** docs/briefs/m17/phone1b/y0f-report.md:1 The report has no Summary block, which run-findings.md records → add the block.

## Decisions to confirm

- Card height change (games_screen_widgets.dart:9-10): the picker's three cards are 32 px shorter; owner should confirm, since the brief said not to change the cards.
- Roadworks rule (shop_demo_screen.dart:62-63): built as "last player number", owner's default says "last place"; the two differ once scores exist.
- Touch exemption (touch_targets_host_test.dart:63-73): the button is below 48 dp on phone sizes; the brief asked for 48 dp.
- Real link in tests (shop_demo_test.dart:24-29, 85): real 10 ms polls and a real 5 s timeout, against the rule of no real time in tests; the brief asked for a real ServerGameHost, so confirm this is accepted.
- Countdown (shop_demo_screen.dart:113): it counts its own 1 s ticks, not the round's `endsInMs`, so the number shown can drift from the real end.
- y0e test fixture (packages/party_host/lib/src/testing/samples.dart:52, outside y0e's allow list): whether `phoneInfo` should take capabilities, which decides how many existing tests show the count line.
- y0d: stopped with no code; its parked patch sits outside the worktree. Decide whether to grant that path or re-brief y0d.

## Could not check

- No test or analyzer run was done (review is read-only). Pass or fail for shop_demo_test, night_start_old_app_test, night_start_frame_test and games_screen_frame_test is unknown; run-findings.md has no evidence for them. y0e's "21 tests" claim is unverified.
- The connection package (ChoiceRound, OldPhoneChoices, close and dispose) was not read. The `case null` promotion in shop_demo_screen.dart:222-226 and the `outcomes`/`lockedIds` use were not checked by the analyzer.
- Whether the six-player count line fits a real device was not measured; the test checks only the frame.
- y0f's claim that games_screen_frame_test "stays green" is not backed by a run in its report.
- y0d's parked patch at E:/AI/game-controller-m17side/.dart_tool/run-jobs/docs_briefs_m17_phone1b/parked-y0d.patch is outside this worktree and was not read.
