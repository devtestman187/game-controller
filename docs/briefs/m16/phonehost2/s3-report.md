# M16 phonehost2 S3 — night start in HostFrameScreen, AwardTile, NightFooterButtons, footer band, back arrow

## Summary

- `HostFrameScreen` grew the two things the brief put in it: the footer now sits on the look's **paper band**
  (key `hostFrameFooterBand`, an ink line of the look's outline width along its top, full frame width), and the
  header shows the **back arrow** (key `hostTitleBarBack`, `HostText.back` tooltip, `HostFocusRing` around an
  `IconButton`, `Navigator.maybePop`) only when `Navigator.canPop`; the header's row carries `Key('hostTitleBar')`.
- New `award_tile.dart`: `AwardTile(award, colour)` (icon + name in one row, an "i" that opens the award's own
  line in a small `ToyCard` dialog keyed `awardExplanation`, closed by a tap outside, Escape or its
  `HostText.ok` button keyed `awardExplanationClose`), with `awardTileHeightPx` 84, `awardTileDiscPx` 48,
  `awardTileInfoPx` 48, `awardTileGapPx` 16, `awardExplanationWidthPx` 480.
- New `night_footer_buttons.dart`: `NightFooterButtons(onShapeRace, onBumperRound, autofocus)` — the Shape Race
  (`nightShapeRace`) and Bumper Round (`nightBumper`) `HostButton`s on a fixed 480 frame px pair
  (`nightFooterButtonsWidthPx`), each 232 (`nightFooterButtonWidthPx`), Bumper disabled when its callback is
  null. Made for S4 to reuse.
- `night_start_screen.dart` is now a `HostFrameScreen`: `NightText.partyNight` as the title, the round
  `RoundSegment` as the trailing chip (unpickable while a night runs), the body = awards heading + one row of
  three `AwardTile`s + the cat line + the joined players on one line + "Pick round 1", and the two
  `NightFooterButtons` in the footer. `nightStartCardWidthPx` is deleted; the `ListView` shell and
  `hostMenuPadding` are gone.
- Tests first: new `test/night_start_frame_test.dart` (31 tests over the five devices plus six single-size
  tests); `night_screens_test.dart` was moved to the new card (named below). `controller_menus_test.dart`,
  `host_title_bar_test.dart`, `host_frame_screen_test.dart` and `host_frame_screen_safe_area_test.dart` needed
  **no** change and pass.
- Checks: `tools/check.sh format analyze host` → PASS format, PASS analyze, PASS host (the whole package, 701
  tests). `tools/review.sh` → 0 fail, 1 note (`colors.player(5)` in `_CatLine`, a line that was already there).
  `dart analyze packages/party_host`: clean.
- Only the allowed files changed; the `tv_test_app/windows/flutter/generated_plugin*` files were rewritten by
  `flutter pub get` inside `check.sh`, not by me.

## The frame px this draws (960x540 frame unless said)

- Header 64, footer 84, body 392 (a 960x540, 1170.687x540 or 960x600 frame) / 572 (960x720): unchanged.
- Footer band: the footer's whole 84 x frame width; its ink line is the look's `outlineWidth` (4 px with the
  TV look, 3 px with a menu look), and the buttons' row is inset 24 either side from under it, so a 64 px
  button has 16 px of air above it inside the band.
- Stage = frame width - 48 (912 at 960, 1122.687 at 1170.687). Award tiles: `(stage - 2*16)/3` =
  **293.333 x 84** at 960, **363.562 x 84** at 852x393's frame; the three share one row (asserted equal and
  asserted against that formula).
- Body content at 960: heading (22 px line), 12, tiles 84, 16, cat line 48, 16, players line 48, the pick-round
  line (22) → about **292 of the 392** body; the rest is the `Spacer` above "Pick round 1". 6 players add no
  height (one line). Nothing scrolls at the five sizes: `maxScrollExtent == 0` (test below).
- Footer buttons: the pair is 480 wide (**232 each**, the look's 16 between), and 64 tall with the TV look:
  `NightText.bumperRound` ("Bumper Round") ellipsises inside 232 at the frame's 28 px label, which the brief
  allows.
- Round chip 48 inside the 64 header; the chip sits in the header's trailing end at every size (asserted).

## Tests written and rewritten

New `test/night_start_frame_test.dart` (five sizes = the device table and the frame from
`host_frame_screen_test.dart`, mounted with `pumpHost` and the screen wrapped in `hostFrameBuilder`, four joined
phones):

1. "`<device>`: the night start fits its body, so nothing scrolls, and its footer fits" — the body's list has
   `maxScrollExtent == 0` at all five sizes, no layout exception, and both footer buttons are inside the device
   and `hitTestable`.
2. "… every text on the night start is at least 20 frame px" — every `Text` under the screen, with its effective
   style (`DefaultTextStyle.of(element).style.merge(text.style)`), >= 20.
3. "… the round segment sits inside the 64 px header" — 48 px chip, inside the header at every size, "3 rounds"
   and "5 rounds" both in the header.
4. "… the three awards are one row of equal tiles" — three `AwardTile`s, equal widths, the formula above, one row.
5. "… the footer is a paper band with an ink line above it" — the band's fill is `colors.paper`, its top border
   is `colors.ink`, and it is exactly the footer's rect.
6. "the players who joined stand on one line under the awards" — four names and four `PlayerBadge`s, same top.
7. "the 'i' on an award opens its explanation, and Escape, a tap outside or its button closes it" — all three
   closing paths.
8. "a night already under way leaves the round chips unpickable" — `RoundSegment.onChanged` null, value 5, the
   5 chip filled with `colors.focus`, a tap on "3 rounds" changes nothing.
9. "the Shape Race footer button starts the night and its first round" — a tap on `nightShapeRace` sets the
   night and opens Shape Race.
10. "a Bumper Round with nothing to start is a disabled footer button" — `onPressed` null.
11. "the header shows a back arrow only where the route can pop, and it pops" — none on the home route, one after
    Play → Party night, and it goes back to the picker; `hostTitleBar` is there too.

Rewritten in `test/night_screens_test.dart` (a rule that no longer applies, as the brief asks):

- "the picker's Party night card opens the night's start card": `find.text('Rounds')` and `nightRounds-3`'s focus
  are gone with the picker row; it now finds the header's `RoundSegment` and asserts `nightShapeRace` has the
  focus (the footer's `autofocus`), and `NightAwardCard` → `AwardTile`.
- "a seed fixes the start card's three awards": `NightAwardCard` → `AwardTile`.
- "a night left before round 1 …": read the `RoundSegment` (value 5, `onChanged` null after the taps) instead of
  the old `HostButton.fill`, and tap "3 rounds" instead of `nightRounds-3`.
- the two cat-line tests: `find.text('Rounds')` → `find.byType(RoundSegment)`.
- "the D-pad and a phone's A choose 5 rounds": Shape Race takes the focus first now, so the test walks **up** from
  the footer to the chips (shape check `findAncestorWidgetOfExactType<RoundSegment>`), presses right to
  5 rounds and A; the rest (the night starts on Shape Race with five rounds) is unchanged.

The rewritten rules, named: "the start card's round row is a heading plus two buttons" → "the round picker is
the header's segment"; "3 rounds autofocuses" → "the footer's Shape Race autofocuses" (see Question 1); "nothing
in the body is a list" → "the body's list cannot scroll" (see Question 2).

## Self-check (review-rules part A)

1. **Every host setup** — the card reads only the look, the night, the players and the settings, so the TV/PC host,
   a phone hosting, "Show on this device" and a joined phone draw the same widget; the five-device run includes
   1920x1080 (s = 2) and 640x360 (s = 2/3) with taps through the frame ("the Shape Race footer button starts the
   night"), and an older build is unaffected (no protocol, no persisted state changed).
2. **When kept state starts and ends** — the picked length starts at `NightLength.three` when the screen is
   built, ends with the screen or when a night under way supplies its own (chips then unpickable: "a night
   already under way leaves the round chips unpickable"); the three awards are drawn once per screen; the
   explanation is a route with an end (tap outside, Escape, OK: "the 'i' on an award opens its explanation…");
   nothing is timed and nothing runs with no players (the players' line is hidden then).
3. **How a new state combines** — no pause, away or waiting state is added: the only new blocker is the
   explanation route, which sits above the screen and takes the focus (its OK autofocuses) and is closed by
   Escape before the screen's own Escape shortcut can see it; the pause menu, a player away and leaving are not
   touched by this screen.
4. **Stay in the job's folder** — `git status` shows only the twelve allowed paths (five lib files, five tests
   with only `night_screens_test.dart` edited, the new test file and this report); the
   `tv_test_app/windows/flutter/generated_plugin*` files are `check.sh`'s `flutter pub get`, not an edit.
5. **Stop rather than overstep** — `round_segment.dart` (an autofocus flag) and the two arena tests' sizes are
   outside `allow:`; the first is Question 1, the second is handled inside the screen (Question 2) rather than by
   touching a file I may not change.

## Questions

1. **"3 rounds autofocus"** could not be met: `RoundSegment` has no autofocus flag and `round_segment.dart` is
   outside `allow:`. The footer's Shape Race takes the focus instead (`NightFooterButtons.autofocus: true`), so
   something is focused on entry, the chosen "3 rounds" chip shows in the focus yellow, and the directions reach
   the chips ("the D-pad and a phone's A choose 5 rounds"). Should `RoundSegment` gain an `autofocus` flag in a
   later slice (S4/S5 use the segment too)?
2. **The un-framed app.** `HostFrame` is still not above either app's navigator, so a screen moved to
   `HostFrameScreen` today lays out in frame px on the device: at 852x393 the night start's body is 245 px for
   ~292 px of content. I kept a scroll view as DESIGN rule 6's "unreachable safety net" (the body's list reports
   `maxScrollExtent == 0` at the five frame sizes), which is what makes `arena_touch_ready_test` and
   `arena_touch_solo_night_test` (852x393, outside the frame) pass; without it they overflow by 41 px. The same
   move also drops the `hostBarHeightProvider` inset `HostScreen` gave the phone's own bar. Both go away when the
   apps wire `HostFrame`; is the net the right staging answer, or should `HostFrameScreen` scale itself when it
   finds no `HostFrameInfo` above it?
3. **"Soon" is gone from the footer pair.** `NightFooterButtons` holds the two buttons the brief names; when the
   Bumper Round is off the button is disabled but no longer says why. `NightText.soon` is still there if S4 wants
   the word back (there is no room for it in the 480 px budget).
4. **Dead code left in `night_widgets.dart`** (outside `allow:`): `NightGameButtons`, `NightAwardCard`,
   `nightAwardCardWidthPx` and `nightGameButtonWidthPx` are no longer used by any lib file after this move.
5. **`test/coverage_all_test.dart` is generated** and does not list `award_tile.dart`, `night_footer_buttons.dart`
   (nor `host_frame_screen.dart`, `round_segment.dart`, `score_row.dart` from S2); it needs
   `dart run tools/coverage_imports.dart` in a job allowed to touch it.
6. **`phone_fit_option_c_test.dart` / `support/phone_fit_support.dart`** (skipped unless `PHONE_FIT=1`) measure the
   night start's old layout; its `nightShapeRace` action still exists, but its pictures and `results.json` would
   need regenerating when the fit run is next enabled.

## Hand-over

- S4 can put the scoreboard and the final scores on `HostFrameScreen` the same way: title + `RoundSegment`/
  status chip in the header, `ScoreRow`s in the body, `NightFooterButtons` in the footer (the pair is 480 frame px
  wide and already exported), and it gets the paper band and the back arrow from the scaffold.
- Note for S4/S5/S6: a screen moved to the frame today must keep its own scroll safety net (Question 2) until the
  apps put `HostFrame` above the navigator.

## Commit message

Draw the night start in the host frame, with award tiles and a footer band

- HostFrameScreen: a paper band with an ink line under the body, and the
  title bar's back arrow (hostTitleBarBack, HostText.back, shown only when
  the route can pop); the header row keeps Key('hostTitleBar').
- AwardTile: icon + name in one tile, an "i" opening the award's own line in
  a small dialog closed by a tap outside, Escape or its OK.
- NightFooterButtons: Shape Race and Bumper Round at the footer's right, one
  480 px pair (232 each), Bumper disabled with no callback, an autofocus flag.
- NightStartScreen on HostFrameScreen: the round segment in the header (3/5,
  unpickable in a night), three equal tiles, the cat line, the players on one
  line and "Pick round 1" in the body, both buttons in the footer; the fixed
  card width and the ListView shell are gone.
- Tests: a new five-device night start frame test, and night_screens_test
  moved to the segment, the tiles and the footer's autofocus.

## Status row

S3 done: HostFrameScreen's footer paper band and back arrow, AwardTile with its "i" dialog, NightFooterButtons (480 px pair), NightStartScreen on the frame at the five devices (31 new tests); night_screens_test rewritten. Open: RoundSegment autofocus (question 1), the un-framed app's scroll net and bar inset (question 2), "Soon" (3), dead night_widgets code (4), coverage_all_test (5), the fit run (6); S4 (scoreboard/final), S5 (reveal), S6 (Arena/puzzle results).

## Delete

- none
