# S7 report — the game picker and the join screen measured at the five host sizes

## Summary

Measurement only: a new test file, no lib change, no fix. `phone_fit_picker_join_test.dart` opens the game
picker and the join screen at 640x360, 852x393, 1024x768, 1280x800 and 1920x1080 with four phones, at the plain
device size and in the 960x540 frame (phone_fit_option_c_test's fit, no Thumby strip), and records 20 cases in
`s7-results.json`. All 20 ran (no env gate); no case reported an error and no text was clipped or ellipsized.

- **Way-on buttons are visible in all 20 cases.** Picker: `pickShapeRace` (the first game card); the settings
  button `openPuzzleSettings` is also on screen everywhere except at 640x360 plain, where the list has not built
  it yet. Join screen: `joinStart`.
- **Plain sizes:** both screens read 15.0 dp at every size (the phone look's 15 px body). The picker scrolls at
  640x360 by **253 dp** (content 557 in a 304 viewport) and by 4 at 852x393; the join screen's two side cards
  each scroll by **49 dp** at 640x360 (content 120 in 71) and 16 at 852x393. No screen-level scroll on the join
  screen; from 1024x768 up both fit.
- **In the 960x540 frame:** both screens fit with no scroll at every size (picker content 484 in 484 at 640x360
  and 1920x1080, 664 in 664 at 1024x768, 544 in 544 at 1280x800; side cards 120 in 120). But the smallest text
  is **10.0 dp** at 640x360 (15 frame px x 0.6667), 10.917 at 852x393, 16.0/20.0/30.0 from 1024x768 up.
- **Verdict at 640x360** (no scroll, button visible, text >= 13 dp), each screen fails in both layouts, on a
  different criterion: the plain layout fails on height (picker 253 over, sides 49 over), the frame fails on type
  (10.0 dp). Nothing fails at 1024x768 and up in either layout.
- What S8 has to change: move the screens' type to `ToyType.frame` (smallest 20 frame px = 13.3 dp at 0.667) or
  keep 15 px and give up the 960 frame; and make the picker's cards and the join screen's side cards shorter
  (details in "What S8 would have to change").

## Method

- Harness: `hostWithPlayers` (StubHome, four phones named Bartholome, Maxi, Alexandria, Chris — 10 characters,
  as option C), the same `PhoneFitSetup`/`PhoneFitCase`/`measureScreen`/`measurementJson` support as the night
  tests, real Fredoka/Nunito (`loadLookFonts`).
- **Plain layout:** the screen at the device size, devicePixelRatio 1; every number is device dp.
- **Frame layout:** the screen laid out at the frame size, `s = min(W/960, H/540)`, frame = device / s, and
  `measureScreen(..., deviceScale: s)`; scroll/content numbers are **frame px**, the smallest text is reported
  in device dp (`frame px x s`) and in frame px.
- Picker opened Home → Play. Join screen opened Home → Play → Shape Race → house puzzle (scrolled to), then all
  four phones press A, two a side: the busiest join state, just before Start. The join screen's only scrollables
  are its two side cards (`ToyCard(scrollBody: true)`); its Start/Back row does not scroll.
- Way on: the first key the case names — picker `pickShapeRace`, join `joinStart`; the picker's last way on,
  `openPuzzleSettings`, is measured by a second `measureScreen` call with that key alone (`wayOnSettings`).
- Content height is viewport + extent, so where a screen fits it is the viewport (an upper bound for the content,
  a lower bound for what it needs). `screenHeight` in the JSON is the screen's own rect.

## Games picker

| layout | size | scrolls | scroll extent | content (viewport) | way on bottom | smallest dp |
| --- | --- | --- | --- | --- | --- | --- |
| plain | 640x360 | yes | 253 | 557 (304) | 272, on screen | 15.0 |
| plain | 852x393 | yes | 4 | 341 (337) | 272, on screen; settings 344, on | 15.0 |
| plain | 1024x768 | no | 0 | 712 (712) | 272, on | 15.0 |
| plain | 1280x800 | no | 0 | 744 (744) | 272, on | 15.0 |
| plain | 1920x1080 | no | 0 | 1024 (1024) | 272, on | 15.0 |
| frame 960x540 | 640x360 (s 0.6667) | no | 0 | 484 (484) | 272, on; settings 296-344, on | 10.0 (15 frame px) |
| frame 1171x540 | 852x393 (s 0.7278) | no | 0 | 484 (484) | on; settings on | 10.917 (15 frame px) |
| frame 960x720 | 1024x768 (s 1.0667) | no | 0 | 664 (664) | on | 16.0 (15 frame px) |
| frame 960x600 | 1280x800 (s 1.3333) | no | 0 | 544 (544) | on | 20.0 (15 frame px) |
| frame 960x540 | 1920x1080 (s 2.0) | no | 0 | 484 (484) | on | 30.0 (15 frame px) |

- The 24 px label (`label24Dp`) is 24.0 dp plain at every size; in the frame 16.0 (640x360), 17.467 (852x393),
  25.6 (1024x768), 32.0 (1280x800), 48.0 (1920x1080).
- Content 557 at 640x360 plain is the row of three game cards at 640 width: each card is ~213 px wide, so its
  title and line wrap tall. At 852x393 the same content is 341 — 4 dp over the 337 viewport.
- `openPuzzleSettings` is `null` at 640x360 plain: the list builds lazily and the button is below the build
  window, so it is not in the tree until the list is scrolled. In the frame it is at 296-344 of 540.

## Join screen

| layout | size | scrolls | scroll extent | side card content (viewport) | joinStart bottom | smallest dp |
| --- | --- | --- | --- | --- | --- | --- |
| plain | 640x360 | yes (both side cards) | 49 | 120 (71) | 336, on screen | 15.0 |
| plain | 852x393 | yes (both side cards) | 16 | 120 (104) | 369, on screen | 15.0 |
| plain | 1024x768 | no | 0 | 120 (120) | 744, on screen | 15.0 |
| plain | 1280x800 | no | 0 | 120 (120) | 776, on screen | 15.0 |
| plain | 1920x1080 | no | 0 | 120 (120) | 1056, on screen | 15.0 |
| frame 960x540 | 640x360 (s 0.6667) | no | 0 | 120 (120) | 516, on screen | 10.0 (15 frame px) |
| frame 1171x540 | 852x393 (s 0.7278) | no | 0 | 120 (120) | 516, on screen | 10.917 (15 frame px) |
| frame 960x720 | 1024x768 (s 1.0667) | no | 0 | 120 (120) | 696, on screen | 16.0 (15 frame px) |
| frame 960x600 | 1280x800 (s 1.3333) | no | 0 | 120 (120) | 576, on screen | 20.0 (15 frame px) |
| frame 960x540 | 1920x1080 (s 2.0) | no | 0 | 120 (120) | 516, on screen | 30.0 (15 frame px) |

- A side card's 120 is two player rows (badge + 10-character name) and two empty-seat blocks. The card shrinks
  to its content when there is room (viewport 120 from 1024x768 up) and is cut to 71/104 at the two phone sizes.
- The screen's own column never scrolls; the Start/Back row and the format line stay on screen in all 20 cases.

## Verdicts at 640x360 (no scroll, way on visible, text >= 13 dp)

| screen | plain | frame 960x540 |
| --- | --- | --- |
| games picker | **fail**: scrolls 253 (text 15.0, button on) | **fail**: text 10.0 (no scroll, button on) |
| join screen | **fail**: side cards scroll 49 (text 15.0, button on) | **fail**: text 10.0 (no scroll, button on) |

No case at 1024x768, 1280x800 or 1920x1080 fails any of the three criteria, in either layout; plain 852x393 fails
only on the scroll (picker 4, sides 16); frame 852x393 fails only on type (10.917).

## What S8 would have to change

1. **Type.** In a 960x540 frame on a 640x360 phone the phone look's 15 px body is 10.0 dp. `ToyType.frame`
   (title 40, button 28, body 22, small 20 frame px) gives 13.3 / 14.7 / 18.7 / 26.7 dp at s 0.6667, so the
   smallest frame type clears 13 dp. Any screen left on the phone look inside the frame stays under it; keeping
   15 px and meeting 13 dp would need `s >= 0.8667`, i.e. a frame no wider than about 738 px, not 960.
2. **Picker height.** At 640x360 plain the picker is 253 dp over: three game cards in a row at 640 width. A
   full-width vertical list (or a card whose text sits beside a smaller picture) is what removes it; at 852x393
   only 4 dp is over, so the same change clears that too. In the frame the picker fits now with 15 px type; with
   20-28 px type the cards grow, so the picture/title/line sizes must be chosen to keep the list within the
   484 body (the picker should not scroll at all).
3. **Join screen height.** A side card needs 120 for two joined rows plus two empty-seat blocks, against 71 at
   640x360 plain (49 over) and 104 at 852x393 (16 over). Under the frame with 20 px type the rows get taller, so
   the card has to lose the empty-seat blocks (or draw the seats as one line) and/or the second hint line; the
   Start/Back row can stay a fixed footer, since it is on screen everywhere already.
4. **The settings button.** At 640x360 plain `openPuzzleSettings` is not built until the list scrolls; if it is a
   way on it must sit above the fold (the frame puts it at 296-344 of 540 today).

## Hand-over

- **Where the numbers are:** `docs/briefs/m16/phonehost1/s7-results.json`, one record per case (`case`,
  `layout`, `layoutSize`, `frame`, `scale`, `scrolls`, `scrollExtent`, `contentHeight`, `screenHeight`,
  `fitsNoScroll`, `smallestFontDp`, `smallestFontFramePx`, `wayOn`, `wayOnSettings`, `errors`, `clipped`).
- **Rerun without pictures:** `cd packages/party_host && flutter test test/phone_fit_picker_join_test.dart` (it
  always runs; it writes the JSON from the package folder or the repo root). `loadLookFonts` reads the fonts
  with `../toy_look/...`, so run it from the package, like the other fit tests.
- **Open:** the join screen was measured with all four phones joined (two a side). With nobody joined the
  `notJoined` line replaces the side names and the cards keep their two empty seats, which can only be tighter;
  not measured here.
- **Open:** the picker's settings button is recorded as "not built" at 640x360 plain (a lazy `ListView`), which is
  not the same as off screen; a later job that needs its rect at that size must scroll first.
- **No lib change and no fix**, as the brief asks; S8 owns the changes above.

## Self-check (review-rules.md part A, items 1–5)

1. **Every host setup** — Not affected: a test-only file; it mounts the existing harness (StubHome, four fake
   phones, the default "Show on this device" host) and adds no lib code. Test: the 20 cases in the new file.
2. **When kept state starts and ends** — The only kept state is the results list, filled per case and written once
   in `tearDownAll`; the join screen's own 16 ms timer is cancelled by its `dispose` when each test tears the tree
   down (no pending-timer failure in the run). Test: the 20 cases.
3. **How a new state combines with others** — Not affected: nothing pauses, hides or blocks input; the only state
   the tests add is four phones joining a side, the join screen's normal flow. Test: the join-screen cases.
4. **Stay in the job's folder** — Changed only `phone_fit_picker_join_test.dart`, `s7-results.json` (written by
   the test) and this report, all in `allow:`. Check: `git status --short` (plus pre-existing `run.log` and
   `tv_test_app/windows` churn, untouched).
5. **Stop rather than overstep** — Stopped at measurement: no lib edit, no support edit (the settings probe
   reuses `measureScreen`), no fix, no picture. Check: `git status --short`.

## Commit message

Measure the game picker and the join screen at the five host sizes

packages/party_host/test/phone_fit_picker_join_test.dart opens the
picker and the join screen with four phones at 640x360, 852x393,
1024x768, 1280x800 and 1920x1080, at the plain device size and in the
960x540 frame, and records scroll extents, way-on buttons, smallest
type and content heights in docs/briefs/m16/phonehost1/s7-results.json.
All 20 cases run and assert only that the screen opened and was
measured. At 640x360 the plain layout scrolls (picker 253, sides 49)
and the frame shrinks the type to 10.0 dp; every button is on screen.

## Status row

S7 done: picker and join screen measured at the five sizes in both layouts (20 cases, no errors) — open: both fail 640x360 (plain scrolls, frame type 10.0 dp), the S8 fixes above, and a join screen with nobody joined.

## Delete

- none
