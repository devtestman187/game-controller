# S9m report — the phone-fit matrix: eight host screens x 4 and 6 players x five sizes

## Summary

Tests only, no lib change. `test/phone_fit_matrix_test.dart` measures the eight moved host screens — night start,
scoreboard between rounds, final scores, awards reveal, Arena results, puzzle results, game picker, join screen — with
four and six phones at 640x360, 852x393, 1024x768, 1280x800 and 1920x1080, each screen laid out inside `HostFrame`
itself (both host apps' `hostFrameBuilder`), with the real Fredoka/Nunito fonts. 81 tests: 80 matrix cases and the
name-fit check. **All pass on the tip; no case fails.**

Every case asserts the owner's decision (Nov 20): nothing scrolls, every way-on button the screen has is wholly on
screen, no overflow error, and the smallest text is at least 20 frame px (13.33 dp at 640x360).

- **No scrolling in any case.** No case has a scrollable with room to scroll. The game picker keeps only its guard
  `ListView` (maxScrollExtent 0, viewport 392/452/572 frame px); the other seven screens have none.
- **Way-on buttons are whole on screen in all 80 cases**, named per screen in the table below.
- **Smallest text at 640x360:** 13.333 dp (20 frame px) on the scoreboard, final scores, puzzle results and join
  screen; 14.667 dp (22 px) on the night start, Arena results and picker; 15.6 dp (23.4 px) on the reveal.
- **No overflow errors** (`FlutterError` and `tester.takeException()` empty in all 80 cases).
- **Name fit:** the six 10-character names measure 113.0–124.0 px in the score row's 22 px type against the 190 px
  column, and the final scoreboard draws all six whole (the winner's row at 32 px included).
- **The 6-player variants where the round seats fewer:** Shape Race seats two a side, so the puzzle-results 6-player
  case plays 2v2 (4 joined of 6) and the join screen shows 4 joined of 6, per the brief ("use the most it takes").
  The Arena and every night screen take all six.
- **Two findings outside the gate's criteria** (clipping is not an overflow error and was not asserted): with six
  players the night start card shortens every nickname to an 84 px slot (4 players: 126 px, all names fit); and the
  footer label "Bumper Round" is ellipsised (187 wanted in 148 px) at every size, along with "Change teams" on the
  puzzle results at the 960-wide frames (144 in 129.4 px) and the picker's one-line playtest hint (by design).

## Method

- 80 cases = 8 screens x 2 rosters x 5 sizes, in `test/support/phone_fit_matrix_support.dart`; the shared measurement
  is `phone_fit_support.dart`'s `measureScreen`/`measurementJson`, and the scale is the frame's own
  (`HostFrameInfo.of(root).scale`), not a hand-made `min(W/960, H/540)`, so the measured dp are the device's.
- Rosters: Alexandria, Nightshade, Bartholome, Maximilian (4 players), plus Dragonfire and Strawberry (6 players) —
  all 10 characters. Points 7/5/3/1 (+2/0) give the score rows an order.
- Openers copy the app's route into each screen: Home → Play → Party night (start, scoreboard, final); the reveal
  under a night already played; `ArenaResults` over the harness with a Bumper Round result; the house puzzle's
  join screen for the join screen and, played to its end, for the puzzle results; Home → Play for the picker.
- Each case's record (in `s9-matrix.json`, written only with `PHONE_FIT=1` and only by a complete 80-case run) has
  the shared JSON plus `frame`, `frameScale`, `root`, `rootFrame`, `smallestFontFramePx`, `scrollExtent`, `buttons`
  (found/onScreen/top/bottom per key) and the full scrollable list.
- The name-fit test opens the final scores at 640x360 with the six names and reads each row's `RenderParagraph`
  (`didExceedMaxLines` false) plus `TextPainter` widths in the score row's type.

## Worst case per screen

The values are the same for 4 and 6 players except where noted. "Smallest" is at 640x360, the tightest scale
(s = 0.6667, so 20 frame px = 13.333 dp).

| Screen | Smallest, 640x360 | Scroll, all sizes | Way-on buttons (all whole on screen) | Note |
| --- | --- | --- | --- | --- |
| night start | 14.667 dp / 22 px | none | `nightShapeRace`, `nightBumper` | 6p names ellipsised to 84 px each |
| scoreboard between rounds | 13.333 dp / 20 px | none | `nightShapeRace`, `nightBumper` | |
| final scores | 13.333 dp / 20 px | none | `nightBackToGames` | 6 names drawn whole |
| awards reveal | 15.6 dp / 23.4 px | none | none (COMMON: no Skip, no dots) | |
| Arena results | 14.667 dp / 22 px | none | `arenaAgain`, `arenaChangeMode` | |
| puzzle results | 13.333 dp / 20 px | none | `nextPuzzle`, `rematch`, `resultsBack`, `changeTeams` | 6p case is 2v2 (4 players) |
| game picker | 14.667 dp / 22 px | guard list only, extent 0 | `pickShapeRace`, `pickArena`, `pickPartyNight`, `openPuzzleSettings` | |
| join screen | 13.333 dp / 20 px | none | `joinStart`, `joinBack` | 6p: 4 joined, 2 watching |

The worst text anywhere is 20 frame px (13.333 dp at 640x360), exactly DESIGN rule 3's floor and over the 13 dp
owner floor. No screen scrolls at any size; the picker's guard list never has an extent.

## Cases that fail

None. All 80 matrix cases passed every assertion on the tip, so nothing is marked `skip:` and nothing is left
failing. The name-fit test also passes.

## Screen widths at 1920x1080

Every screen's own rect (the screen widget root) is the full device, and inside the frame it is the frame:

| Size | Frame | Root (device px) | Root (frame px) |
| --- | --- | --- | --- |
| 640x360 | 960x540, s 0.6667 | 640x360 | 960x540 |
| 852x393 | 1170.7x540, s 0.7278 | 852x393 | 1170.7x540 |
| 1024x768 | 960x720, s 1.0667 | 1024x768 | 960x720 |
| 1280x800 | 960x600, s 1.3333 | 1280x800 | 960x600 |
| 1920x1080 (the TV) | 960x540, s 2 | 1920x1080 | 960x540 |

At 1920x1080 all eight screens are **1920x1080 device px = 960x540 frame px**: 1920 wide on the TV, 960 frame px,
for every screen and both rosters. At 852x393 the screen is 1170.7 frame px wide (the phone's spare width), so the
fixed 190 px name column and the footer buttons sit in a wider stage there — that is why the "Change teams" label
fits at 852x393 and is ellipsised at the 960-wide frames.

## Computed values

- Frame scales: 0.6666667 (640x360), 0.7277778 (852x393), 1.0666667 (1024x768), 1.3333333 (1280x800), 2.0
  (1920x1080).
- Smallest dp at 640x360 = frame px x 0.6666667: 20 -> 13.333, 22 -> 14.667, 23.4 -> 15.6.
- Smallest frame px over the 80 cases: 20.0 (40 cases), 22.0 (30), 23.4 (10 — the reveal).
- Name widths at 22 px (the score row's type), against the 190 px column: Alexandria 114.0, Nightshade 120.0,
  Bartholome 124.0, Maximilian 114.0, Dragonfire 113.0, Strawberry 119.0; the winner's 32 px row draws Alexandria
  whole (114 x 32/22 = 165.8 < 190).
- Night footer buttons sit at top 316 / bottom 348 device px at 640x360; the puzzle results' compact controls at
  173.6 / 197.6; the picker's first card at 44 / 271. All inside 0..360.
- Six-player night start: each name gets 84 px; intrinsic widths 113–124 px, so all six are ellipsised. Four-player
  slots are 126 px and all four names fit.

## Self-check (review-rules.md part A, items 1–5)

1. **Every host setup:** no lib change. The screens are measured inside `HostFrame`, the one layout both host apps
   draw on a TV/PC, a phone on "Play on this phone" and "Show on this device"; joined phones draw no host screen.
   Shown by all 80 matrix cases (`test/phone_fit_matrix_test.dart`).
2. **When kept state starts and ends:** the change adds no kept state. The test's only held thing is the
   `FlutterError.onError` hook, restored in a `finally` after every case (shown by the suite running 80 cases in a
   row with errors empty in each).
3. **How a new state combines:** nothing new pauses, hides, waits or blocks input (no lib change); not affected.
4. **Stay in the job's folder:** only the four allow-listed files were written (this report, the test, its support
   file, `s9-matrix.json`); no other file changed.
5. **Stop rather than overstep:** no file outside `allow:` was needed. The 6-player cases the round cannot seat use
   the most it takes, as the brief says. One deviation is raised as a question below (the `PHONE_FIT` switch).

## Questions

1. The results writer accepts `--dart-define=PHONE_FIT=true` as well as `PHONE_FIT=1`, because this job's sandbox
   cannot set an environment variable for one command; that is the switch `phone_fit_option_c_test.dart` already
   documents as the same one. Is that acceptable for "only when PHONE_FIT=1 is set"?
2. Should the 6-player night-start nickname truncation (every name ellipsised into 84 px, at every size) become a
   gate criterion? It passes today's rules but reads badly with six 10-character names.
3. Should "Bumper Round" (187 wanted in 148 px on the night footer) and "Change teams" (144 in 129.4 px at 960-wide
   frames) be exempt by design? Both are ellipsised today and were left unasserted, as the brief names overflow
   errors, not label clipping.

## Hand-over

- This file is the final gate: any later host-screen layout change should run `test/phone_fit_matrix_test.dart`; a
  green run plus `PHONE_FIT=1` refreshes `s9-matrix.json`.
- The older `phone_fit_option_c_test.dart` and `phone_fit_picker_join_test.dart` stay in the suite; the matrix
  supersedes them in the report only, per the brief.
- Open: the six-player start-card name truncation and the two ellipsised labels are findings for a later owner
  decision, not gate failures.

## Commit message

Add the phone-fit matrix: eight host screens, 4 and 6 players

Test-only: a new matrix test draws the night start, scoreboard, final
scores, reveal, Arena and puzzle results, picker and join screen inside
HostFrame at the five sizes with four and six 10-character players, and
asserts no scroll, every way-on button whole on screen, no overflow and
20 frame px of type (DESIGN rules 3 and 6). It also measures the six
names against the 190 px score row with the real fonts. All 80 cases
pass; results go to s9-matrix.json only on a complete PHONE_FIT=1 run.

## Status row

M16 phonehost2 S9m: the phone-fit matrix is in and green — 8 host screens x 4/6 players x 5 sizes, no scroll, buttons whole on screen, no overflow, smallest 20 frame px (13.33 dp at 640x360), six 10-character names fit the 190 px row; open: the 6-player night start ellipsises every nickname (84 px slot) and the "Bumper Round"/"Change teams" labels truncate at 960 frame width.

## Delete

- none
