## Summary

Verdict: **needs Claude's design** (the cross-job phone gap blocks shipping; the rest could be one fix batch after the owner's answers).

Counts: must 5 · should 9 · could 7 (the wave-1 findings already in REVIEW-VERDICTS.md are skipped, see Findings).

Fix batches (3 or fewer findings per job, no shared files): A `games_screen_widgets.dart` (card height, `_PickerBody`, the 388 comment); B `shop_demo_screen.dart` + `shop_demo_test.dart` (text split, Roadworks comment, format, timing decision); C `night_start_old_app_test.dart` + `night_start_frame_test.dart` (guard, looks, the run); D `touch_targets_host_test.dart` (after A, same button); E `night_start_screen.dart` test; F `controller_app/lib/src/storage.dart` with `check: phone` (phone-pinned: `controller_app/test/joined_view_test.dart:38`).

The five that matter most:
1. **must, across jobs** `controller_app/lib/src/storage.dart:55`: the phone's identity does not list `choices` (no job added it; y0dc chose that and the phone UI y0d never ran). So `night_start_screen.dart:108` names every real phone as an old app on the TV start card. Either hide the line until the app lists `choices`, or land the app capability with y0d.
2. **must** `packages/party_host/test/touch_targets_host_test.dart:63-73`: the six `openShopDemo` entries are 18.8 to 42.7 dp tall, below the brief's 48 dp, and y0f's decisions do not list the exemption.
3. **must** `packages/party_host/test/night_start_frame_test.dart:99`: never run after y0e; its four default phones now show the count line.
4. **must** `packages/party_host/test/shop_demo_test.dart:164`: 121 columns, so the format check fails.
5. **must** `packages/party_host/test/night_start_old_app_test.dart:97`: passes on the old code, so it is a guard, not a fail-first test.

Questions only the owner can answer: card height 340 to 308 (keep or not); the 48 dp exemption; Roadworks "last player number" or "last place"; when the phone app lists `choices`; whether `phoneInfo` (samples.dart:52) takes capabilities.

## Findings

- **must** controller_app/lib/src/storage.dart:55 the phone identity lists metrics, rating, layout, status and view but not `choices` (phone-pinned: `controller_app/test/joined_view_test.dart:38` asserts the exact list; `check: phone`), so `_oldAppIds` (night_start_screen.dart:106-109) marks every real phone an old app and the start card says "N players have an old app" for every real night → list `Capability.choices` in the app identity together with the phone UI (y0d), or hide the old-app line until the app lists it (from: across jobs; y0dc decision 1 and question 2)
- **must** packages/party_host/test/touch_targets_host_test.dart:63 six `openShopDemo` entries at 375, 568 and 640 widths are 18.8 to 42.7 dp tall against the 48 dp rule, and y0f's decision list does not record it → make the button 48 dp on phone sizes (games_screen_widgets.dart, `HostButton` at line 84), or record the exemption as an owner decision (from: wave2-review.md)
- **must** packages/party_host/test/night_start_frame_test.dart:99 its four phones come from `phoneInfo` (packages/party_host/lib/src/testing/samples.dart:52), which sets no capabilities, so the new count line now draws in those frames; y0e's brief asked for this file to be run and it was not → run it through `tools/mine.sh` and fix what it shows (from: wave2-review.md, y0e-report.md)
- **must** packages/party_host/test/shop_demo_test.dart:164 the `sendChoicePick(...)` line is 121 columns, so dart format would wrap it and the format check fails → wrap it the way dart format does (from: wave2-review.md; grep confirms 121+ columns)
- **must** packages/party_host/test/night_start_old_app_test.dart:97 "no old-app line when every phone lists the capability" passes on the old code, where no line existed → say in the test that it is a guard the old code passes, or fold the check into a test that fails on the old code (from: wave2-review.md)
- **should** packages/party_host/lib/src/ui/games_screen_widgets.dart:9 `gameCardHeightPx` 340 → 308 and `gamePictureHeightPx` 186 → 154 (line 16) shrink the three game cards, which the y0f brief said not to change → get the owner's answer, or fit the button without changing the card heights (from: wave2-review.md, y0f-report.md)
- **should** packages/party_host/lib/src/ui/games_screen_widgets.dart:32 `_PickerBody` takes six parameters (the constructor, lines 32-39; `onShop` at line 37) against the five-parameter limit → group the callbacks into a value object (from: wave2-review.md; read)
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:37 the nine demo strings sit in a private `_ShopText`, not in HostText as y0f's brief says; the stated reason (host_text.dart "at 379 lines") is off by one, since the file is at 380 lines, the limit → move them to a text file of their own, or have the owner accept the split (from: wave2-review.md, y0f-report.md; host_text.dart:380 confirmed)
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:62 the comment says Roadworks goes to the "last place", but line 95 (`players.last`) and line 102 (`id == lastId`) give it to the last player number → change the comment to "last player number", and confirm the rule with the owner (from: wave2-review.md; read)
- **should** packages/party_host/test/night_start_old_app_test.dart:97 the brief asked for every look, but the file runs one look, while shop_demo_test.dart:133 loops over the looks → loop `HostLook.values` with `pumpHostLook` in the new tests (from: wave2-review.md)
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:108 the host-own exclusion (`!controller.isLocal`) and the no-phone-session case have no test → add a test with a local controller that must not be named or counted (from: wave2-review.md)
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:109 the old-phone path (`OldPhoneChoices`) and the pause, host-away and dropped-link combinations have no party_host test, as y0f's self-check admits → add a test for a phone without the cap, or list these as open items for Claude (from: wave2-review.md, y0f-report.md)
- **should** docs/protocol.md:267 the `paused` bullet says "The phone shows it and stops its countdown", but no phone UI exists (y0d never ran), so the doc describes behaviour that is not built → reword to say what the phone receives until the phone UI lands (from: across jobs; y0dc and y0p wrote and used it)
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:113 the countdown ticks its own 1 s timer from 20 s rather than showing the round's end time, so the number can drift from the real end → expose the round's remaining time from `ChoiceRound` and show that (from: wave2-review.md; read)
- **could** packages/party_host/lib/src/ui/games_screen_widgets.dart:28 the comment says "the 387 px of cards and line", but the row is 388 px after the card change, which the comment above it (line 9) states → change 387 to 388 (from: across jobs; read)
- **could** packages/party_host/lib/party_host.dart:103 `ShopDemoScreen` is exported from the package but only games_screen.dart uses it → drop the export unless a caller outside the package needs it (from: wave2-review.md; grep confirms)
- **could** packages/party_host/test/shop_demo_test.dart:31 the comment is 121 columns → rewrap (from: wave2-review.md; grep confirms)
- **could** packages/connection/test/client_choices_test.dart:182 a comment is 121+ columns in a new file → rewrap (from: across jobs; grep confirms)
- **could** packages/party_host/test/shop_demo_test.dart:24-29 and :85 the shop test uses a real ServerGameHost, real 10 ms polls and a real 5 s timeout, against the no-real-time rule (§9) → owner decision: accept, or move the timing to an injected clock (from: wave2-review.md)
- **could** packages/connection/lib/src/choice_fallback.dart:199 and packages/party_host/lib/src/ui/night_start_screen.dart:108 the rule "a phone without `choices` is an old phone" is written twice, and the name is "old phone" in one place and "old app" in the other → one shared predicate and one name (from: across jobs)
- **could** docs/briefs/m17/phone1b/y0d-report.md:1 and docs/briefs/m17/phone1b/y0f-report.md:1 have no `## Summary` block (run-findings.md records it) → add the block when re-issued (from: run-findings.md; the y0p one is verdicted)

Skipped because REVIEW-VERDICTS.md lists them (still open until y0h, which is not committed): the wave-1 items on `choice_round.dart:121`, the pause test at `choice_round_pause_test.dart:166` and its real timers, the unlocked-pick line in `docs/protocol.md:276`, `choice_round.dart:167` and `:170`, `choices_codec_test.dart:112`, and the y0p missing Summary. The wave-1 choice to keep the full grace on resume is recorded as the owner's answer.

## Open questions

1. Should the TV hide the old-app line until the phone app lists `choices`? Suggested answer: yes, hide it until y0d lands (finding 1).
2. Is the 48 dp shop button exemption accepted? Suggested answer: no; make the button 48 dp on phone sizes (finding 2).
3. Keep the card heights at 308 and 154 instead of 340 and 186? Suggested answer: keep 308 only if the owner accepts the 32 px change; otherwise fit the button elsewhere (`games_screen_widgets.dart:9`).
4. Roadworks: "last player number" or "last place"? Suggested answer: keep "last player number" and say so in the comment, since the demo has no scores (`shop_demo_screen.dart:62`).
5. Should `phoneInfo` (samples.dart:52) take `capabilities`? Suggested answer: yes, in a small job of its own, since it is outside the allow list (`night_start_frame_test.dart:99`).
6. Is the shop words' split from HostText accepted? Suggested answer: no; move them to their own text file (`shop_demo_screen.dart:37`).
7. Is the real-timer shop test accepted? Suggested answer: accept for the demo, since its real link is the point of the test (`shop_demo_test.dart:24-29`).
8. Does an unlocked pick count at the timer's end (y0dc Q3, still open)? Suggested answer: yes, as the code does (`choice_round.dart:202-204` ignores `locked`); the doc should say so.
9. Is the two-line count wording final ("2 players have an old app and will play with simple buttons.")? Suggested answer: keep it (y0e question 3).
10. The party night's "N players have an old app" line: does it count only joined phones? Suggested answer: yes; the code does not check connection, so this needs a check (see Could not check).

## Numbers against targets

- Touch target 48 dp, `openShopDemo` (touch_targets_host_test.dart:63-73): 375x667 menu 81.2x18.8, tv 81.2x25.0; 568x320 menu 122.9x28.4, tv 122.9x37.9; 640x360 menu 138.5x32.0, tv 138.5x42.7. All six miss 48 dp.
- Picker cards: 340 → 308 px (32 px shorter); picture 186 → 154 px. The y0f brief said no change; this misses it.
- Body fit: 308 + 16 + 64 = 388 px against the 392 px body, so 4 px to spare (the comment says 8 px, for the card alone).
- Six-player night at five frame sizes: fit checked in the frame only, not on a device (y0e).
- Test count: y0e reports "OK 21 tests packages/party_host" from mine.sh; not traceable to its 9 new tests.
- Pause test margins: 100 ms and 1500 ms on real timers (y0p; verdicted).
- Round length 20 s, grace 8 s, Build cost 3 max 3: owner values, matched in the code (shop_demo_screen.dart:19-34).

## Could not check

- Pass or fail of `shop_demo_test.dart`, `night_start_old_app_test.dart` and `night_start_frame_test.dart`: run.log records the combined check (261 s) and the apply phase, but no per-file result; this review did not run any test or analyzer.
- `night_end_client_test.dart` was not run by any job (verdicted, driver's final check).
- The parked y0d patch at `E:/AI/game-controller-m17side/.dart_tool/run-jobs/docs_briefs_m17_phone1b/parked-y0d.patch` is outside the worktree and was not read; y0d has no code.
- Whether `controllers` in the host snapshot includes players with no phone session (`night_start_screen.dart:106-109` checks only `isLocal`); y0e says they are not listed, but the code was not traced.
- Whether the old-app line fits a real TV at six players: not measured.
- No HAND-FIX lines in run.log (so no hand-fix proof to check).
- Connection code not re-read beyond the diff and `choice_round.dart`; `int.clamp` return types (choice_round.dart:139, :194) trusted to the analyzer, which no one re-ran.

## Commit message — a draft

m17 phone1b run review: findings only, no code change

Review of the whole run (y0p, y0dc, y0d, y0e, y0f) as one change.
Only the review report is written. Result: needs Claude's design
(5 must, 9 should, 7 could). Main points: the phone app does not list
the choices capability, so the TV names every phone as an old app;
the shop button is below 48 dp; three new tests have format or
guard issues; the night frame test was never run.
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

phone1b run review written (needs Claude's design): y0p, y0dc, y0e, y0f committed; y0d not started (parked). Open: the phone app's choices capability (old-app line wrong for every real phone), shop button under 48 dp, card height 340→308, night frame test not run, format and guard fixes, shop text split.

## Delete

- none
