# S8j report — the join screen in the host frame, short side cards, nothing scrolls

## Summary

The join screen is a frame screen now: `JoinScreen` builds a `HostFrameScreen` whose title is the game and the
puzzle, whose header chip is the pairing code, whose body is the hint, the two side cards, the players-watching
line and the format line, and whose footer is Start (`joinStart`, the focus node, the remote's OK) and Back
(`joinBack`). The sides are short cards: a 28 px band and two 52 px seats, so no side has a scrollable and the
screen holds no `Scrollable` at all at the five sizes. `hostBarHeightProvider`, the "tight" mode and
`scrollBody` are gone from this screen; the sides moved to the new part file `join_side_panel.dart`.

- **New test file (written first, seen to fail on the old code):** `test/join_screen_frame_test.dart`, 17 tests =
  15 size x players cases (five sizes; 0, 4 and 6 phones) plus the smallest-text and 10-character-name cases at
  640x360. Each case: no `Scrollable`, body = frame - 148, sides/`joinFormat`/`notJoined` in the body,
  `joinStart`/`joinBack` in the footer band and hit-testable, `joinCode` in the header, every text >= 20 frame px.
- **Numbers:** a side card is **144** frame px (28 band + 12 headroom + 2 x 52 seats); the body is
  392 / 392 / 572 / 452 / 392. With six phones the sides row gets 209 / 209 / 389 / 269 / 209 px and the card is
  drawn at its top, so nothing is squeezed and nothing scrolls.
- **Six players** are four joined (two a side) and two on the `notJoined` line: `maxPerSide` stays 2 because
  `MatchFormat.of` and Shape Race stop at four players. A side's budget for three seats is 28 + 12 + 3 x 52 = 196,
  which the 392 body holds (open question in Hand-over).
- **Type:** the smallest text is 20 frame px = **13.333 dp at 640x360**, over the 13.3 floor (S7 measured 10.0).
- **Tests rewritten, not weakened:** `join_screen_test` (the side-colour test reads the new 28 px band, key
  `sideHeader-<side>`, not `ToyCard.header`), `host_title_bar_test` (the join screen's frame header is at the top
  of its own screen when unframed; the phone's bar over it is controller_app's test), `screen_fit_test` (framed
  per-look join test; the cards-over-the-round test starts from the join screen), `host_menu_fit_test` (no
  `Scrollable` under `JoinScreen` at 852x393) and `host_app.dart` (`soloRound` settles before tapping Start).
- **Untouched and passing:** `phone_fit_picker_join_test.dart` (20 cases), `lobby_music_test`, `night_round_test`,
  `pause_menu_test`, `puzzle_results_test`, `host_bar_test` and the rest of `controller_app/test`.
- **One judgement call:** `puzzle_continue_test` (not in `allow:`) pumps the join screen unframed at 852x393, where
  a frame body is 245 px against the 392 the design gives it. The body now draws at `_frameBodyFloorPx` (392) and
  scales down when a host gives it less, instead of overflowing; that test is untouched and passes.

## Measured values (frame px unless a dp value is named)

| what | 640x360 | 852x393 | 1024x768 | 1280x800 | 1920x1080 |
| --- | --- | --- | --- | --- | --- |
| frame | 960x540 | 1170.687x540 | 960x720 | 960x600 | 960x540 |
| body (frame - 64 - 84) | 392 | 392 | 572 | 452 | 392 |
| side card (28 + 12 + 2 x 52) | 144 | 144 | 144 | 144 | 144 |
| sides row, 6 phones | 209 | 209 | 389 | 269 | 209 |
| sides row, 0 or 4 phones | 240 | 240 | 420 | 300 | 240 |
| smallest text | 13.333 dp (20) | 14.556 dp (20) | 21.333 dp (20) | 26.667 dp (20) | 40 (20) |

- **Card arithmetic:** band 28 (`_sideHeaderPx`) + headroom 12 (`_seatHeadroomPx`, the badge's accessory room) +
  two seats of 52 (`scoreRowHeightPx`; `scoreRowBadgePx` 38 in each, the name ellipsised at 190), so the card is
  the same 144 at every size and every player count: empty seats keep two slots on a side.
- **The hint** wraps to two 40 px lines at 640x360 and 852x393 (sides start 96 / 97 px under the body's top) and
  is one line from 1024x768 up; the format line is 40 (button 28's line) and the `notJoined` line 31 (body 22's).
- **Smallest text at 640x360:** 20 frame px x 0.6666666... = **13.333333333333334 dp**, over the 13.3 dp floor.
  Measured in `join_screen_frame_test`'s "640x360: the join screen's smallest text is 13.3 dp".

## What changed in the code

- `lib/src/ui/join_screen.dart` (366 lines, was 377): `HostFrameScreen` with the title, the `_JoinCode` chip, the
  `_JoinBody` body and the `_JoinButtons` footer; `_frameBodyFloorPx` 392; the key handler (A, Escape),
  `ControlsClaim`, the 16 ms sync timer, `_pickSide` and the pick-then-start flow are unchanged.
- `lib/src/ui/join_screen_widgets.dart` (208 lines): `_JoinBody` (hint, 16 gap, sides, `notJoined` line, 8 gaps,
  format line; the floor guard), `_JoinButtons` (Start with the focus node, Back), `_FormatLine` (key `joinFormat`
  under the cards), `_JoinHint`, `_NotJoined`, `_JoinCode` as they were.
- `lib/src/ui/join_side_panel.dart` (new, 276 lines): `_Sides` (two `Expanded` panels, keys `side-left`/
  `side-right`, 16 gap), `_SidePanel` (`ToyCard` with zero padding, touch target), `_SideHeader` (28 px band, key
  `sideHeader-<side>`, the side's colour), `_PlayerRow` (52 px, badge 38, name ellipsised, "(you)", away rows at
  0.45), `_EmptySeat` (52 px dashed seat, "Room for N more" on the first) and `EmptySeatPainter` moved over.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup** — A TV/PC host and a phone draw the same frame: the header title, the code chip, the short
   sides and the footer buttons. On a phone the own player's panel is tappable (`onPick` is null on a TV, so the
   panels there are not); the pad's A and Start begin and B goes back with the focus node on Start, and the
   keyboard's Space/Escape are as before. An older build sees the same keys, routes and `joinLayout`/
   `joinedLayout` messages. Tests: `join_screen_frame_test` (five sizes x 0/4/6 phones), `join_screen_test`
   (18 tests: focus, remote OK, tap, away row, "(you)"), `screen_fit_test` (21, four looks).
2. **When kept state starts and ends** — The screen keeps only its 16 ms sync timer: started in `initState`,
   cancelled in `dispose`; nothing new is held. Each frame test mounts and tears the screen down at a size with no
   pending-timer failure. Tests: the 17 cases in `join_screen_frame_test`, `lobby_music_test`.
3. **How a new state combines with the others** — No round is up yet, so the pause menu, "Get ready" and the
   results never meet this screen; an away player keeps their seat, dimmed (0.45) and out of the `notJoined` line,
   and the footer is never inside a scrollable (DESIGN rule 5). Tests: `join_screen_test` (away row, "(you)",
   10-character name), `join_screen_frame_test` with six phones (two watching on `notJoined`), `pause_menu_test`.
4. **Stay in the job's folder** — Changed ten files, all in `allow:`: the two lib files and the new part file, the
   new frame test and three rewritten party_host tests, two controller_app test files, and this report. `git status
   --short` also lists the suites' own churn (`run.log`, the six `site/shots` PNGs the shots test rewrites, the
   `tv_test_app/windows` generated files), which I did not touch.
5. **Stop rather than overstep** — `puzzle_continue_test` is not in `allow:` and its unframed 852x393 pump broke on
   the frame-only body; instead of editing it, the body scales down below the design's 392 px floor. That is the
   one judgement call here and is stated rather than hidden.

## Hand-over

- **Where the numbers are:** `join_side_panel.dart`'s `_sideHeaderPx` 28, `_seatHeadroomPx` 12, with
  `scoreRowHeightPx` 52, `scoreRowBadgePx` 38, `scoreRowNameWidthPx` 190; `join_screen.dart`'s `_frameBodyFloorPx`
  392, `_hintGapPx` 16, `_lineGapPx` 8. `join_screen_frame_test` recomputes body = frame - 148 and the 13.3 dp
  floor at every size.
- **Open:** six phones still join two a side (four joined, two watching). `maxPerSide` is 2 because
  `MatchFormat.of` has no six-player format and Shape Race seats four; the card's 196 px budget for three seats
  fits the 392 body, so raising it is a format/game decision, not a layout one.
- **Open:** the body's floor guard (draw at 392, scale down when a host gives less) only runs outside the frame —
  today that is the unframed test pump; once the frame sits above the navigator in both apps it never runs.
- **Watch:** the hint's two 40 px lines are what puts the sides at 96/97 px and leaves 209 for the sides row with
  six phones; a longer hint or a taller format line shrinks that, and `join_screen_frame_test` fails on the
  containment first (then on the 52 px seat).
- **Open:** the phone's own top bar is not read by this screen any more; where it is drawn over the frame is S9's
  wiring decision (S8p's report says the same for the picker).

## Commit message

Draw the join screen in the host frame with short side cards

packages/party_host/lib/src/ui/join_screen.dart builds JoinScreen as a
HostFrameScreen: title and pairing code in the header, the hint, two side
cards, the "not joined" line and the format line in the body, Start and
Back in the footer. join_side_panel.dart holds the sides, a 28 px band
and two 52 px seats, so nothing scrolls at the five sizes; the new
join_screen_frame_test checks all 15 size and players cases.

## Status row

S8j done: the join screen is a frame screen with 144 px side cards (28 px band, 12 px headroom, two 52 px seats), Start and Back in the footer, nothing scrolling at the five sizes with 0, 4 and 6 phones, and the smallest text 13.333 dp at 640x360 (17 cases) — open: six phones join two a side (four joined, two on the notJoined line, `maxPerSide` 2 is MatchFormat's cap), and the body scales down only outside the frame.

## Delete

- none
