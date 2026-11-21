# s5 — awards reveal in HostFrameScreen, full-width card

## Summary

- `NightRevealScreen` now draws in `HostFrameScreen` (title `NightText.partyNight`, no chip, empty footer with its paper band and 84 px) instead of the old `HostScreen`; `nightRevealCardWidthPx` and the `SingleChildScrollView` are gone.
- The card is one full-width `ToyCard` given the body's width (stage width = frame width − 2 × `hostFrameGutterPx`), so its width never follows its text (ToyCard is an `IntrinsicWidth`).
- Left: a 190 px badge — the first winner's `PlayerBadge` with `NightCrown` on it when the award was won, the award's `NightDisc` and icon when nobody won.
- Right: award name 52 px (Fredoka), one line per winner at 40 px with ellipsis (a tie gets a line each), the reason at 26 px, 2 lines at most with ellipsis, and the existing "+3 points" line kept at 26 px.
- Kept as they were: the 4 s / 2 s timers and the fanfare, `PopScope` + Back then final scores, Escape, the autofocus `Focus`, `LobbyHold`, the confetti behind a won award (`nightRevealConfetti`), the keys `nightReveal` and `nightAwardMissed`, and the `_who` lookup that keeps a leaver's award.
- Tests first: `test/night_reveal_frame_test.dart` (new) failed on the old code at its first rule ("no scrollable", `SingleChildScrollView` found), and now passes 6/6.
- `test/night_reveal_test.dart` needed no change: all five of its cases still pass (it finds `Best Helper`, the reason, the nickname, `+3 points`, `Not won tonight` and the back arrow, which the frame's header also draws).
- No file outside `allow:` was touched; no lib file over 380 lines (screen 152, widgets 184).

### Sizes, in frame px

| device | frame | stage/card width | body height |
| --- | --- | --- | --- |
| 640x360 | 960x540 | 912 | 392 |
| 852x393 | 1170.6870229007634x540 | 1122.6870229007634 | 392 |
| 1024x768 | 960x720 | 912 | 572 |
| 1280x800 | 960x600 | 912 | 452 |
| 1920x1080 | 960x540 | 912 | 392 |

Card width = frame width − 2 × 24 (`hostFrameGutterPx`); body = frame height − 64 − 84.

Text: award name 52, winner name 40, reason 26, "+3 points" 26, header title 40 (`ToyType.frame.title`), so the smallest text on the reveal is 26 ≥ the 20 px floor.

Card height at 640x360 (frame 960x540): padding 32 × 2 = 64 plus name 52 + 8 + two winner lines 2 × 40 + 16 + reason (1 line 26, up to 2 = 52) + 16 + points 26 = 288 (one-line reason) to 314 (two lines) inside the 392 body; the card is centred vertically.

### Tests rewritten

- New `night_reveal_frame_test.dart`: copies the five-device table and the `HostFrame` wrapper from `host_frame_screen_test.dart`, takes the night setup from `night_reveal_test.dart`'s `openReveal` (start a 3-round night, record three rounds with stats only on the first) and the roster from `night_harness.dart` (`TestRoster`). Each device runs three awards (won by P1, shared by P1 and P2, nobody won) and checks: no `Scrollable`, card width = stage width, badge 190 (badge or disc), crown only when won, texts 52/40/26, every `Text` ≥ 20 px, header text is `Party night` and nothing else, footer 84 px with no `ToyButton` and no text, then the three award timers reach "Final scores". A sixth test pushes the reveal over a stub home and taps `hostTitleBarBack`: the reveal is gone and "Final scores" follows.
- It needed `setUpAll(loadLookFonts)` (a card drawn in the test font is wider than a device's) and a unique `ProviderScope` key per mount (Flutter otherwise keeps the first mount's tree, route and night).
- `night_reveal_test.dart`: unchanged.

## Self-check (review-rules part A, 1–5)

1. Every host setup: layout only, no setup-specific branch; the same frame layout is checked at the TV's 1920x1080 and a small phone's 640x360 (`night_reveal_frame_test`) and by `end_night_arena_test` / `end_night_puzzle_test` (pumpHost, no frame) — pass.
2. Kept state (the award timers): unchanged — started in `_announce`, cancelled in `dispose` and `_finish`; `night_reveal_frame_test` pumps the three timers through to "Final scores", `night_reveal_test`'s Escape and Back cases finish it without a timer left.
3. New state combining with others: none added (PopScope, Escape, Focus, LobbyHold untouched); finishing by the back arrow is the new arrow's test in `night_reveal_frame_test`; pausing a round cannot meet the reveal (it is a route after the round's results, unchanged).
4. Stay in the job's folder and `allow:`: `git status` shows only `night_reveal_screen.dart`, `night_reveal_widgets.dart`, `night_reveal_frame_test.dart` and this report (`run.log` and `tv_test_app/windows/flutter/*` were already changed by the runner, not by me).
5. Stop rather than overstep: nothing outside `allow:` was needed; `host_frame_screen.dart`, `night_widgets.dart` (NightDisc, NightCrown, NightConfetti, nightAwardIcon) and `player_badge.dart` were read and used unmodified.

## Checks

- `tools/check.sh format analyze host` — PASS, PASS, PASS (the final run; see the flake note below).
- Before the code change, `flutter test test/night_reveal_frame_test.dart` failed 5/6 on the old code (the scrollable rule), the Back case passing since the old title bar had the same arrow.
- Also run: `night_reveal_test.dart` (5/5), `end_night_arena_test.dart`, `end_night_puzzle_test.dart`, `night_awards_test.dart`, `night_award_results_test.dart` (22/22).

## Hand-over

- Unrelated flake: one full `host` run failed `live_stats_share_test.dart` ("a phone that said no is left out…", saved ids came back `['phone-no', 'phone-yes']`); it passes alone and the next full run was green. Not touched by this job.
- The "+3 points" line is not in DESIGN section 4's list of the card's right side (52/40/26). I kept it, at 26 px, because DESIGN section 3 says Thumby must never cover "+3" and `night_reveal_test` checks the line. Say the word if it should move onto the winner's line or go.
- The old "One winner" / "N winners" count line is dropped: it is not in the design's list and no test used it. `NightText.winners` is now unused; a later job could delete it (a lib file outside this job's allow).
- A tie shows the first winner's badge; the other names carry the rest. DESIGN draws one badge and the brief says "the winner's PlayerBadge", so I read a tie as "the first winner's".
- The crown sits at the badge's top edge (0.32 × the badge wide, 61 px at 190), over the character's accessory; worth a look at 640x360 where the badge is 127 dp on screen.
- `NightCrown`, `NightDisc`, `NightConfetti` and `nightAwardIcon` gained no parameters, so no other screen changed.

## Commit message

```
M16 S5: awards reveal in the frame, one full-width card

NightRevealScreen draws in HostFrameScreen: the night's title with no
chip, one full-width ToyCard (stage width, no fixed width) with a 190 px
badge on the left — the winner's badge and crown, or the award's disc —
and the award name at 52 px, each winner at 40 px and the reason at 26 px
on the right. The footer keeps its paper band and 84 px and stays empty
(no Skip, no dots until M17); the timers, fanfare, Escape, Back and
LobbyHold are unchanged. New night_reveal_frame_test checks this at the
five devices with a won, a tied and a not-won award.
```

## Status row

S5 done: the reveal is a HostFrameScreen with one full-width card (190 px badge, 52/40/26 type, empty footer), tested at the five sizes; open: +3 and tie-badge decisions to confirm, `NightText.winners` now unused.

## Delete

- none
