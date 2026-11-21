# S8p report — the game picker in the host frame, three shorter cards, nothing scrolls

## Summary

The picker is a frame screen now. `GamesScreen` builds a `HostFrameScreen` (title `HostText.playTitle`), its
body is the three game cards in one row across the stage with the playtest line under them, and its footer is the
puzzle settings button (`openPuzzleSettings`). The `ListView` and the `hostBarHeightProvider`/`hostMenuPadding`
use are gone from this screen; `gameCardWidthPx`, `gameCardMinWidthPx`, `gameCardHeightShare` and
`gamePictureHeightShare` went with them.

- **New test file (written first, seen to fail on the old code):** `test/games_screen_frame_test.dart`, four tests
  over the five sizes (12 cases).
  At the five sizes, in the frame, with four phones: the body's scroll extent is 0; the three cards are fully on
  screen, hit-testable, equal in height and in one row, each a third of the stage; the playtest line is under them
  inside the body; the settings button is in the footer band and pressable; every text is >= 20 frame px. Two more
  tests at 640x360: the smallest text is 14.667 dp, and the settings button's rect.
- **Type:** the cards' title is `ToyType.frame.button` (28) and their line and the playtest line `ToyType.frame.body`
  (22), so the smallest text is 22 frame px = **14.667 dp at 640x360** (S7 measured 10.0). The playtest line is one
  row with an ellipsis, so a wide test font can never wrap it and add a row.
- **Shorter cards:** a card is `gameCardHeightPx` 340 tall, its picture `gamePictureHeightPx` **186** at the top.
  The picture gives way to the type (DESIGN rule 3), as the brief asks. Cards + gap + line = **387** in the
  **392** body at 16:9, and the group is centred, so the tablet's 572 body is 92.5 px of room above and below.
- **Nothing scrolls:** the picker keeps the design's unreachable safety net (`SingleChildScrollView`, as the night
  start has), and the frame test asserts its `maxScrollExtent` is 0 at all five sizes rather than that no scrollable
  exists. The net moves only outside the frame (852x393 plain is 245 body against 387: 142 over), which is the
  apps' state until S9 puts the frame above the navigator; `screen_fit_test` still passes at all four looks.
- **Tests rewritten, not weakened** (both files are in `allow:`): `games_screen_test` (card width 380 -> the stage's
  third; "0.4 of the card" -> the picture's fixed band at the card's top) and `host_title_bar_test` (the picker's
  "no title bar" rule D -> the frame's 64 px header at the top and the body under it; the two `hostMenuPadding`
  widget tests now read Shape Race's list, which still uses it; the picker keeps no back arrow as the first route).
- **Tests that needed no change and pass:** `games_screen_levels_test`, `screen_fit_test`, `controller_menus_test`,
  `night_screens_test`, `look_palette_test` (it pops the picker with `hostTitleBarBack`, still present), `pause_menu_test`,
  `abandon_test`, `arena_back_test`; also `host_focus_look_test`, `host_focus_ring_test`, `game_screen_test`,
  `arena_waiting_test`, `away_card_test`, `end_night_puzzle_test`, `lobby_away_round_test`, the night frame tests
  and `host_frame_screen_test`.
- **`phone_fit_picker_join_test.dart` was not edited and still passes** (all 20 cases): it opens and measures the
  screens without pinning a layout, so it now measures the new picker. Its old picker numbers in `s7-results.json`
  are stale; S9 supersedes it.

## Measured values (frame px unless a dp value is named)

| what | 640x360 | 852x393 | 1024x768 | 1280x800 | 1920x1080 |
| --- | --- | --- | --- | --- | --- |
| frame | 960x540 | 1170.687x540 | 960x720 | 960x600 | 960x540 |
| body (frame - 64 - 84) | 392 | 392 | 572 | 452 | 392 |
| stage width (frame - 2 x 24) | 912 | 1122.687 | 912 | 912 | 912 |
| card box (w x h) | 293.33 x 340 | 363.56 x 340 | 293.33 x 340 | 293.33 x 340 | 293.33 x 340 |
| picture height | 186 | 186 | 186 | 186 | 186 |
| group (340 + 16 + 31) | 387 | 387 | 387 | 387 | 387 |
| room left above the group | 2.5 | 2.5 | 92.5 | 32.5 | 2.5 |
| smallest text | 14.667 dp (22) | 16.011 dp (22) | 23.467 dp (22) | 29.333 dp (22) | 44 (22) |

- **Card arithmetic:** a card's box is 340; the `HostCardFocus` ring takes 4 each side, so the paper is 332. Inside:
  padding 12 twice, picture 186, gap 8, title 40 (Fredoka 28's line), gap 4, line 62 (two rows of Nunito 22's 31) =
  332, 8 px spare. The card's width at a 960 stage is 293.33, so the inner width the type has is 261.33.
- **Group:** 340 card + 16 gap + 31 playtest line = 387, in 392 leaves 2.5 above and below (the group is centred).
- **Smallest text at 640x360:** 22 frame px x 0.6666666... = **14.666666666666666 dp**, over the 13.3 dp floor.
- **The settings button above the footer line (the brief's REVIEW question 8):** 48 frame px tall (the look's menu
  button, 32 dp at 640x360); its frame rect is (654, 475.5)-(936, 523.5), drawn at (436, 317)-(624, 349). The band runs
  456-540, so the button's top is 19.5 px under the band's top edge (3 px ink line + 16.5 of the 33 px left) and
  16.5 px above the frame's bottom; its right edge is 936 = the stage's right edge (960 - 24). Nothing of it is under
  the ink line.

## What changed in the code

- `lib/src/ui/games_screen.dart`: `GamesScreen` is a `HostFrameScreen`; Escape, `LobbyHold`, the touch-first
  autofocus, the three keys and the party-night destination are as they were. The `dart:math` import went;
  `host_frame_screen.dart` came in. `ShapeRaceScreen` and its level list are untouched (the brief keeps it on the
  old `HostScreen`), so `host_screen.dart`, `hostMenuPadding` and `hostBarHeightProvider` are still imported for it.
- `lib/src/ui/games_screen_widgets.dart` (220 lines): `_PickerBody` (the safety-net scroll, the centred column of
  row + line), `_GameRow` (three `Expanded` cards and two 16 px gaps), `_GameCard` (picture band on top, title and
  two-row line under it, all in the frame's type). The old `LayoutBuilder`/`Wrap`/fixed-height card is gone.
  `_LevelCard` is unchanged.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup** — A TV/PC host and a phone both draw the same frame layout; the touch-first rule keeps
   Shape Race's autofocus on a phone and the party night's on a TV (unchanged logic, unchanged key set). A joined
   phone's pad still walks the three cards: `controller_menus_test` (left reaches `pickShapeRace`) and
   `host_focus_look_test`. An older build sees the same keys and routes, since no message or route name changed.
2. **When kept state starts and ends** — The screen still holds no state of its own: `LobbyHold` opens the lobby
   music on `initState` and closes it in `dispose` (untouched), and the picker watches `partyNightProvider` so the
   night keeps hearing the roster while it is up. `games_screen_frame_test` mounts and tears the screen down at five
   sizes with no pending-timer failure; `night_screens_test` shows the night's own state still ends on its buttons.
3. **How a new state combines with the others** — The layout adds no state that pauses, hides or blocks input: the
   three cards are the same `HostCardButton`s and the footer is the same `HostButton`, so the pause menu, an away
   player and the results never meet this screen. A drop while it is up is the existing picker case
   (`lobby_away_round_test`), which passes.
4. **Stay in the job's folder** — Changed six files, all in `allow:` (the two lib files, the new test and the three
   rewritten tests, plus this report). Check: `git status --short` lists only those (plus the tree's pre-existing
   `run.log` and `tv_test_app/windows` churn, untouched).
5. **Stop rather than overstep** — Nothing outside `allow:` was needed, and the brief's contract was met as written;
   the one judgement call (the unreachable scroll safety net, the rule `screen_fit_test` needs outside the frame) is
   in the report rather than worked around.

## Hand-over

- **Where the numbers are:** the two constants `gameCardHeightPx` (340) and `gamePictureHeightPx` (186) in
  `games_screen_widgets.dart`; the frame test recomputes the type floor and the stage's third at every size.
- **Open:** the phone's own top bar (`hostBarHeightProvider`) is not read by this screen any more (decision c). Frame
  screens do not leave room for it (S3's night start does not either): wherever the apps draw that bar over the frame
  is S9's wiring decision.
- **Open:** at a device smaller than the frame (the apps' state today) the picker scrolls its safety net by 142 px at
  852x393 and by 262 at 640x360 plain; nothing is cut. It stops scrolling once S9 puts `HostFrame` above the
  navigator.
- **Watch:** the 40 and 62 px line heights the card's 340 is built on are the real Fredoka 28 and Nunito 22 metrics;
  a font or type change moves them, and `games_screen_frame_test` fails on the overflow first.
- **Next (S9):** the level list (`ShapeRaceScreen`) is still the old `HostScreen` screen, as the brief asked.

## Commit message

Draw the game picker in the host frame with shorter cards

packages/party_host/lib/src/ui/games_screen.dart builds the picker
as a HostFrameScreen: the frame's 64 px header with "Play", a body
of the three game cards (Shape Race, Arena, Party night) in one row
across the stage with the playtest line under them, and the puzzle
settings button in the footer. games_screen_widgets.dart replaces
the fixed-width, fixed-height cards with a 340 px card and a 186 px
picture, so cards and line (387) fit the 392 px body at 16:9; the
new games_screen_frame_test checks all five sizes with four phones,
and the picker and title-bar tests are rewritten to the new layout.

## Status row

S8p done: the game picker is a frame screen with three 340 px cards and a 186 px picture each, its settings button in the footer, nothing scrolling at the five sizes and the smallest text 14.667 dp at 640x360 (12 frame cases) — open: the level list stays on the old HostScreen (S9), and the phone's own top bar is no longer read by this screen.

## Delete

- none
