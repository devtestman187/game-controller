# night-report — the night footer's labels and the six-player start names

## Summary

The night footer's pair is now sized by its labels instead of by a 232 px share, and the start card
re-flows five or six player names onto two rows of three. Five sizes checked with the real fonts.

- **Footer before:** both buttons 232 px; label room 232 - 48 padding - 28 icon - 8 gap = **148 px**.
  "Shape Race" measures **147.5 px** (fitted by half a pixel); "Bumper Round" **187.0 px**, cut by 39.
- **Footer after:** each button is its own content's width, measured with `TextPainter` at the look's
  button type (Fredoka 600, 28 frame px) merged with the screen's default text style and the frame's text
  scaler, then ceiled, with 1 px of slack (`nightFooterButtonSlackPx`). Shape Race **233 px** (room 149),
  Bumper Round **272 px** (room 188). Pair **521 px** = 233 + 16 gap + 272, in a budget raised from 480
  to **640 px**; at a 960-wide frame the footer band has 912 px, so the pair leaves **391 px** beside it
  (was 432 at 480 px).
- **Names before:** six on one row, room 912/6 - 12 - 48 - 8 = **84 px** each; the six 10-character
  names measure **110.0–121.5 px** in this build, so all six were ellipsised.
- **Names after:** five or six players stand as **two rows of three**: 304 px a slot, **236 px** a name
  at 960-wide frames; at 852x393 (1122.7 px stage) 374.2 px a slot, **306.2 px** a name. Four players
  keep one row: 228 px a slot, **160 px** a name (longest 121.5, was 126 px per s9m).
- **Layout rule, not a tuned number:** at most four to a line (160 px each, widest name 121.5 px), and
  three columns once there are more (`nightStartNamesOneLineMax`, `nightStartNamesSplitColumns`).
- **New test** `test/night_labels_fit_test.dart`, 11 cases: at each of the five sizes, both footer
  labels' `TextPainter` width <= their paragraph's own max width and `didExceedMaxLines` false, the pair
  inside `nightFooterButtonsWidthPx`; with the six s9m names, each name whole by the same two measures,
  no `Scrollable`, both buttons on screen, no exception, every `Text` >= 20 frame px; plus one test
  that the six stand on two lines and fit a third of the stage.
- **Measurement detail:** a `TextPainter` of `ToyType.frame.button` alone measured "Shape Race" at
  146 px against the 147.5 the button's own paragraph wants (the screen's default style adds a little),
  which cut it by 1.5 px; the width now merges `DefaultTextStyle.of(context)` with the look's button
  type and passes `MediaQuery.textScalerOf(context)`, so the measured width is the drawn one.
- **Name widths vs s9m:** the same `nameWidthPx` helper now gives Alexandria 111.5, Nightshade 117.4,
  Bartholome 121.5, Maximilian 111.2, Dragonfire 110.0, Strawberry 116.0 px (s9m: 113–124). The gap is
  ~2.5 px, most likely a different font build; either way all six fit 236 px.
- **Checks:** `tools/check.sh format analyze host` PASS (format 4 s, analyze 10 s, host 78 s);
  `tools/review.sh` 0 fail, 0 note. Tests run: the new file, `night_start_frame_test`,
  `night_start_noscroll_test`, `night_scoreboard_frame_test`, `arena_results_frame_test`
  (123 together), `night_screens_test`, `night_round_test`, `lobby_music_test`,
  `end_night_puzzle_test`, `phone_fit_matrix_test` (120 together), then the whole host suite via the
  check script.
- **No new strings**; the text floor (20 frame px), the 52 px bar and `ToyType.frame` are unchanged.

## Files changed

- `lib/src/ui/night_footer_buttons.dart` — `nightFooterButtonWidthPx` (equal shares) replaced by
  `nightFooterButtonWidthFor(context, label)`, which measures the label at the button type and adds the
  padding, the icon's room and 1 px slack; the pair is its content's width; the budget
  `nightFooterButtonsWidthPx` rose 480 -> 640 with the footer band's 912 px in its doc.
- `lib/src/ui/night_start_names.dart` (new) — `NightStartNames`: the joined players, one row for up to
  four and rows of three after that, with `nightStartNamesOneLineMax`, `nightStartNamesSplitColumns`,
  `nightStartNameGapPx`; moved out of the start screen.
- `lib/src/ui/night_start_screen.dart` — draws `NightStartNames` instead of the private `_PlayersLine`;
  its doc says one line up to four, two rows of three after that.
- `test/night_labels_fit_test.dart` (new) — the tests above.

## Computed values

| Measure (frame px) | Before | After |
| --- | --- | --- |
| Shape Race button / label room | 232 / 148 (label 147.5) | 233 / 149 |
| Bumper Round button / label room | 232 / 148 (label 187.0) | 272 / 188 |
| Footer pair / budget / band | 480 / 480 / 912 | 521 / 640 / 912 |
| Six names: slot / name room | 152 / 84 | 304 / 236 |
| Four names: slot / name room | 228 / 160 (s9m: 126) | 228 / 160 |

At 852x393 the stage is 1122.7 px: the footer pair is the same 521 px and a name column is 374.2 px
(name room 306.2). Both labels measure 147.5 and 187.0 px with the font engine; the button width adds
48 px padding, the 28 px icon, the 8 px gap and the 1 px slack, and ceils.

## Method

The new test mounts `NightStartScreen` in `hostFrameBuilder` (both host apps' frame) at the five sizes,
joins `matrixFourNames` or `matrixSixNames` (s9m's ten-character names) through `phoneInfo`, and reads
each label's and name's `RenderParagraph`: its `constraints.maxWidth` is the room it was given, its
`text` measured by a `TextPainter` is what it wants, and `didExceedMaxLines` is the cut. Footer and
button widths are layout px, which the frame lays out in frame px before the `FittedBox` scales them.

## Self-check (review-rules.md part A, items 1–5)

1. **Every host setup:** the change is inside `HostFrameScreen`'s footer and card, which a TV/PC host, a
   phone on "Play on this phone" and "Show on this device" all draw through `HostFrame`; joined phones
   draw no host screen and the protocol is untouched, so an older peer is unaffected
   (`night_labels_fit_test` at the five sizes; the whole host suite green).
2. **When kept state starts and ends:** nothing is held; the widths and the rows are computed from the
   labels and the player count on every build, and with no players the names row is absent
   (`night_labels_fit_test`, `night_start_noscroll_test` with 4 and 6 players).
3. **How a new state combines:** nothing pauses, hides, waits or blocks input; not affected.
4. **Stay in the job's folder:** only the four allow-listed files were written, plus this report
   (`tools/review.sh` reports 0 findings over the diff).
5. **Stop rather than overstep:** no file outside `allow:` was needed; `night_scoreboard_screen_test.dart`
   in the brief does not exist in the package. The removed public const `nightFooterButtonWidthPx` had
   no caller (grepped the workspace).

## Questions

1. s9m's name widths (113–124 px) differ from this build's (110.0–121.5 px) for the same helper; should
   s9m's computed values be corrected, or is a font-build difference expected on Windows?
2. Five players stand as 3 + 2 rows (the split rule is "three a line once there are more than four");
   is that wanted, or should five stand on one row with a narrower slot?
3. The puzzle results' "Change teams" label (outside this job's files) still ellipsises at the
   960-wide frames; the footer fix here does not reach it.

## Hand-over

- `night_labels_fit_test.dart` is the gate for these two fits; run it with the matrix after any change
  to the footer, the button type or the start card's names.
- The fit is computed from content (label widths, player count), so a longer label or a seventh player
  widens or re-flows rather than clipping; the budget constant is the only hand-set limit and the test
  asserts the pair stays inside it.
- Open: "Change teams" on the puzzle results at 960-wide frames.

## Commit message

Size the night footer by its labels and re-flow six start names

The footer's two buttons take their content's width, measured with
TextPainter at the look's button type plus icon and padding, so "Bumper
Round" (187 px, was 39 px over its 148 px room) is drawn whole; the pair
is 521 px in a budget raised from 480 to 640, leaving 391 px of the 912 px
band for Thumby's corner. The night start draws up to four names on
one row and five or six as two rows of three, giving each six-player name
236 px instead of 84, so the ten-character nicknames are whole. New test
checks both fits at the five sizes with the real fonts.

## Status row

M16 phonehost3 night: the night footer's labels are whole (content-sized pair, 521 px in a 640 px budget) and six 10-character start names are whole as two rows of three (236 px each); format, analyze and the host suite green. Open: "Change teams" on the puzzle results still ellipsises at 960-wide frames, and s9m's name widths read ~2.5 px wide of this build's.

## Delete

- none
