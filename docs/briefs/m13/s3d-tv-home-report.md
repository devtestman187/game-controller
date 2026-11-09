# M13 3d — the TV's home in the toy look: report

The TV app now draws as the TV draws it: every screen the home leads to is in
the look, the panels are paper with the ink edge, statuses are a dot in the
look's tokens beside ink words, and the player-facing words of the TV app live
in one `TvText`. The home keeps its layout, in two columns at 960 × 540 with the
controllers in the wider one, and stacks and scrolls at 700 × 500.

## Files changed

- `tv_test_app/lib/main.dart` — the window title comes from `TvText.name`.
- `tv_test_app/lib/src/tv_text.dart` — **new** (179 lines): `abstract final class
  TvText`, the player-facing words of the TV app, grouped by screen, with a
  comment on each group; texts the host already says are not copied here.
- `tv_test_app/lib/src/ui/status_line.dart` — **new** (79 lines): `StatusLine`, a
  dot filled with a status token and edged in ink, beside the words in ink body
  type. The dot is `StatusLine.dotSize` (16) and its edge is the look's
  `outlineWidth`.
- `tv_test_app/lib/src/ui/home/panel.dart` — the panel is paper with the ink
  edge, `cardCorner` corners, `space12` padding, its title in `type.button` ink
  (one line, ellipsised) and its body in ink `type.body` through a
  `DefaultTextStyle`, so nothing inside reads the theme.
- `tv_test_app/lib/src/ui/home/home_screen.dart` — the header is one `Wrap`;
  the wide layout gives the controllers 8/13 of the row (the pairing panel and
  the log share the rest, 7:3 high); the narrow home's list heights are in
  `ToySizes` steps; every text from `TvText`/`HostText`; no `app_info`, protocol
  or toy-look import of its own.
- `tv_test_app/lib/src/ui/home/pairing_panel.dart` — the code in `type.clock`
  ink with tabular figures, the instructions and addresses in ink/inkSoft, the
  discovery and sound checks as `StatusLine`s, the simulated phones' states as
  dots in the tokens, and the build line (`Version … · protocol v…`) at the
  panel's bottom.
- `tv_test_app/lib/src/ui/home/controllers_panel.dart` — one paper tile per
  controller (`cardCorner`, ink edge, `space8`/`space4` padding), a `ToyBadge`
  or a platform icon, the input picture, the state as a `StatusLine`, then the
  ping figures in tabular figures.
- `tv_test_app/lib/src/ui/home/log_panel.dart` — `LogPanel.lineStyle` holds the
  one style the look can't name: the platform's monospace at the body's size, in
  ink; the panel scrolls unfocused so the remote skips it.
- `tv_test_app/lib/src/ui/input_visualizer.dart` — the picture is drawn in the
  look: paper pieces with the ink edge, held controls in the focus yellow, a
  held A/B/X/Y in its face token, every letter in ink.
- `tv_test_app/lib/src/ui/haptic_panel_screen.dart` — the events, the steppers
  and the last press sit on one sheet of `ToyCard` paper; "Sounds are off" is a
  `bad` dot line; the small stepper buttons are paper with the ink edge and the
  focus yellow when lit.
- `tv_test_app/lib/src/ui/latency_screen.dart` — one `ToyCard` per controller;
  the verdict is a `StatusLine` (`good` within target, `caution` above,
  `inkSoft` not measured); the figures keep their keys.
- `tv_test_app/lib/src/ui/shader_spike_screen.dart` — the background is the
  palette's, the words are `TvText` on the background, the stress button is in
  the look's colours. Its rows' colours are the spike's own (below).
- `tv_test_app/lib/src/debug_start.dart` — the waiting screen's words in the
  look's title type on the background.
- `tv_test_app/test/support/pump_app.dart` — the tests run the TV look, as
  `main.dart` does (`toyTvProvider` true), and take a `clock` for the palette.
- `tv_test_app/test/home_look_test.dart` — **new**: the panel's paper, edge and
  title; each controller state's dot; the network and sound checks and "No
  network connection"; the pairing code's type and ink; the log's style; the
  title on the background.
- `tv_test_app/test/input_visualizer_look_test.dart` — **new**: a held A/B/X/Y
  takes its face token, everything else is paper.
- `tv_test_app/test/tv_fit_test.dart` — **new**: the home at 960 × 540 in Sunny
  and in Night (no overflow, the title whole, both controller names whole and
  inside the controllers panel, the header's buttons in at most two rows, the
  build line in the pairing panel), the narrow home at 700 × 500, and the haptic
  test, the latency screen and the Look test at 960 × 540.
- `tv_test_app/test/haptic_panel_test.dart` — the steppers test scrolls each
  button into view before pressing it (the sheet is taller in the look); no text
  or value changed.
- `tv_test_app/test/_measure_test.dart` — a scratch measurement, to delete (see
  the end).

## The colour audit (rule 4)

```
$ grep -rn "Colors\.\|Color(0x\|colorScheme\|scheme\.\|textTheme" tv_test_app/lib
lib/src/ui/shader_spike_rows.dart:117:      Color(playerColors[index % playerColors.length]),
```

That is the whole list: every other read of a Material colour in the TV app is
gone. The one hit is kept on purpose:

- `shader_spike_rows.dart:117` — `Color(playerColors[index % playerColors.length])`
  gives each shape one of the protocol's six player colours. They are the
  spike's test subject: the shader row and the fallback row must show the same
  colours, so they must not come from the palette. `tools/review.sh` already
  exempts this form. Nothing else in `toy_gallery.dart` or the spike needed an
  exemption: `toy_gallery.dart` is unchanged and was already all look.

## The words

`TvText` (`tv_test_app/lib/src/tv_text.dart`, 179 lines) holds the TV app's own
words, grouped by screen: the header, the controllers panel, the pairing panel,
discovery, the sounds, the log, the latency screen, the haptic test, the Look
test and the one line the debug start shows. Texts the host already says are
not copied: the app takes them from `HostText`.

Merged pairs (one text where there were two, same words):

- `HostText.playTitle`, `HostText.lookAndSound` and `HostText.stats` — the
  header's three button labels were literals here and are `HostText`'s.
- `HostText.dash` — the seven `'–'` placeholders (controllers panel, latency
  screen).
- `HostText.gamepadValues` — the tilt line and the sticks line were two
  literals in the tile; the host already says exactly these.
- `HostText.less`/`more`/`lessOf`/`moreOf` — the stepper buttons.
- `TvText.soundsOff` — the pairing panel and the haptic panel each had their
  own copy of "Sounds are off: …".
- `TvText.saveLog` — the log panel and the latency screen each had their own.
- `TvText.waitingForCode` — the controller's state and a simulated phone's.

The pinned texts the tests read are unchanged word for word. One text changed
shape rather than words: the header's build line lost its three leading spaces
when it moved into the pairing panel (`'   Version …'` → `'Version …'`); the
existing test reads it with `textContaining('Version 0.')` and still passes.

## The home at 960 × 540 (measured, Sunny)

```
HEADER         8,8        944 x 136
  run 1        title (416.2 wide, its intrinsic width: whole), status (252.2), Play (123)
  run 2        Haptic test (190) Latency (161) Look and sound (237) Look test (173) Stats (131)
               = 892 of labels, 924 with the 8 px gaps, in 944
PAIRING        8,152      360 x 260.4   (its content scrolls; the build line is at y 1075)
LOG            8,420.4    360 x 111.6
CONTROLLERS  376,152      576 x 380
  tile 0     388,216      552 x 172     iPhone 3F1C, whole (name box 132.7 wide, not cut)
  tile 1     388,396      552 x 101     Pixel, whole (51.9 wide, not cut), bottom 497 < 532
```

The header's arrangement, in a sentence: one wrapping row of the title, the
host's status and then the six buttons in their order, with the buttons compact
below 1100 px so that at 960 × 540 the first run takes the title, the status and
Play and the second takes the other five — two button rows, and the order the
remote walks unchanged.

The pairing panel's content is about 1090 px tall in a 260 px panel: it scrolls
(the remote scrolls a focused button into view, the tests use `ensureVisible`),
and the version and protocol are at its bottom.

At 700 × 500 the home stacks (header, pairing panel, controllers, log) in one
scrolling list; the panels' heights are 380 and 240 px, and the fitting test
scrolls to each of them and finds no overflow.

## The statuses

Never coloured words. Each is a `StatusLine`: a dot filled with the token,
edged in the look's ink, and ink body text beside it.

| Where | State | Token |
| --- | --- | --- |
| Controller tile | Connected / Waiting for code / Disconnected | good / focus / bad |
| Pairing panel, discovery | starting / advertising / failed | focus / good / bad |
| Pairing panel, sounds | off / loading / some loaded / all loaded | bad / focus / caution / good |
| Pairing panel, address | "No network connection" | bad |
| Pairing panel, simulated phones | connected / connecting, waiting, pairing / reconnecting / failed / off | good / focus / caution / bad / inkSoft |
| Latency screen | within the 50 ms target / above / not measured | good / caution / inkSoft |
| Haptic panel | "Sounds are off: …" | bad |

Text on the background (the header, the haptic and latency app bars, the Look
test's words, the debug start's waiting screen) is `onBackground`; text on paper
is ink or `inkSoft`, which the panel's `DefaultTextStyle` and `ToyCard` give.

## Tests

Counts, before → after (`tools/check.sh format analyze look host phone tv`):

| Suite | Before | After |
| --- | --- | --- |
| tv | 36 + 1 skipped | 51 + 1 skipped (50 once `_measure_test.dart` is deleted) |
| look | 88 | 88 |
| host | 197 | 197 |
| phone | 403 | 403 |

The new tests, each written before the code it covers:

- `home_look_test.dart` (6): the panel's paper, ink edge of `outlineWidth`,
  `cardCorner` radius and `type.button` ink title; each of Connected / Waiting
  for code / Disconnected as a dot in good / focus / bad beside ink text; the
  discovery and sound checks, and "No network connection" as bad with ink words;
  the pairing code in `type.clock` ink; the log's line style (ink, monospace, the
  body's size); a tile per controller on paper.
- `input_visualizer_look_test.dart` (2): each held face button takes its token
  (`faceA`, `faceB`, `faceX`, `faceY`) and is paper at rest; the picture builds
  in the look and hands its painter the look.
- `tv_fit_test.dart` (6): the home at 960 × 540 in Sunny and Night — no
  exception, the title's `TextPainter` width not over its box, both controller
  names whole (`didExceedMaxLines` false) and inside the controllers panel, at
  most two button rows in the header, the build line in the pairing panel; the
  narrow home at 700 × 500; the haptic test, the latency screen and the Look
  test at 960 × 540 with no overflow.

The earlier failing runs are in the session: `home_look_test` failed to compile
against the old home (`StatusLine` did not exist and the log had no
`lineStyle`), `tv_fit_test` failed on the old header's three rows and on the
narrow home's stacking, and the input picture's test names a painter that takes
a look, which the old one did not.

Pinned colours or texts that changed in existing tests: none. `haptic_panel_test`
changed how it presses the steppers (scroll into view first) because the sheet
is taller in the look; the values it asserts ('80%', '200 ms', '100%',
'Natural') and the texts are the same.

## Rules check (part A self-check)

1. **Every host setup.** The change is TV-side only: the TV app's screens, no
   protocol, no host service, no phone. A PC host runs the same widget tests
   (`flutter test` runs the Windows platform paths, `Platform.isWindows` adds
   the firewall note); a phone on Play or Show is untouched (phone suite, 403
   tests, unchanged); a joined phone sees the same frames; an older build sees
   no new message.
2. **When kept state starts and ends.** No new state: `_intensity`/`_duration`
   in the haptic panel start at 100% and Natural and end with the screen; the
   palette is still worked out by `LookPaletteNotifier` at the set moments; the
   stepper buttons stay enabled at their limits so there is no disabled focus.
3. **How a new state combines with the others.** None added: the screens keep
   their autofocus ("New code" at home, Play in the Look test, Save log on the
   latency screen, Hit in the haptic test) and the log stays out of the focus
   ring, as before; the tests' remote walk still presses all seven header and
   panel buttons.
4. **Stay in the job's folder.** Only `docs/briefs/m13/s3d-tv-home-report.md`,
   `tv_test_app/lib` and `tv_test_app/test` were written.
5. **Stop rather than overstep.** Nothing outside the folder was needed; two
   judgement calls (the controller statuses' count, the controllers panel's
   title) are written up below rather than guessed at further.

## Questions and suggestions

1. **Four statuses, three states.** The brief names Connected `good`, Waiting
   for code `focus`, reconnecting `caution` and gone `bad` for the controllers.
   `ControllerInfo.state` has only connected, pairing and disconnected, so a
   tile shows three; reconnecting exists only as a `ClientSnapshot.status` of a
   simulated phone, which now has the caution dot. If a real controller should
   show reconnecting, the host would need to say so (a fourth state or a flag):
   your call.
2. **The controllers panel's title** ("Controllers · 1 connected") shares its row
   with "Forget phones" and has 359 px of the panel's 576: it fits by about 18 px
   at the TV's type, so a longer count would ellipsise. If that worries you, the
   button could go above the title or the panel could take 9/13 of the row.
3. **The build line** sits at the bottom of the scrolling pairing panel (y 1075
   in a 260 px panel): a tester has to scroll to read the version. It could go
   under the code instead, at the cost of pushing the code down.
4. **The haptic sheet's sound line** is plain inkSoft text with an ellipsis, not
   a status dot: the 200 px cells have no room for a dot and "Sound: success.wav"
   at the TV's body size. Wider cells (3 a row) would let it be a status.
5. **`shader_spike_rows.dart` keeps `Color(playerColors[…])`** as the brief
   allows; if the spike should follow the palette instead, its rows would no
   longer show six distinct player colours.
6. `tools/review.sh` still notes 10 bare numbers in these files (drawing shares
   in the input picture, the ×100 percentages, the snackbar's 8 s). They are the
   "UI spacing is bare numbers" item already in `docs/project-notes.md`.

## Commit message

```
TV home in the toy look: paper panels, status dots, two-row header

Panels are paper with the ink edge and an ink title; every status is a
dot in the look's tokens beside ink words, never coloured text.
The header is one wrapping row: title, status, six buttons in order,
with the controllers in the wider column so two tiles show whole at
960 x 540; the version moved into the pairing panel, and 700 x 500
still stacks and scrolls.
The input picture, the haptic test, the latency screen and the Look
test are in the look, and the TV app's words live in TvText.
```

## Status row

**M13 3d (TV home)** — done: the TV's home, haptic test, latency and Look-test
screens draw in the look with their words in `TvText`, the header keeps to two
button rows in their order, and the controllers panel shows two tiles whole at
960 × 540 and at 700 × 500 the home stacks and scrolls. Open: a controller tile
has no reconnecting state to show (see question 1), and the controllers panel's
title fits by about 18 px (question 2).

## Delete

- tv_test_app/test/_measure_test.dart

## Claude's review (Nov 8, 2026)

Accepted, with one change, test-first:

- **The ping column** was a fixed 126 px. At the TV's 22 px body type, "max 140 ms" broke after "140" (seen on Claude's render at 960 × 540 and at 1280 × 720). The column is now `_latencyWidthShare` (6) times the body type's size, which is 132 px on the TV. tv_fit_test checks that each ping figure is one line. At 7 times, the Pixel tile's "Waiting for code" wrapped instead; 6 fits both.

Seen by Claude at 960 × 540, Sunny and Night, and at 1280 × 720, in the TV look with the real fonts. The title is whole, the header is two rows, both tiles are whole, and the pairing code is in view at the top.

Answers to the questions:
1. **Three controller states** are right: the brief named a reconnecting state the host doesn't have. No new state.
2. **The panel title's spare room** of 18 px is fine at the sample's count.
3. **The build line** at the bottom of the pairing panel is fine: testers find it by scrolling. The manual address also sits below the code at 960 × 540, so device tests should check that the remote can reach it (step 9).
4. **The haptic sound line** as plain text is fine.
5. **The spike's player colours** stay.
6. **Bare numbers** are a known item.

Counts after the review: look 88, host 197, phone 403, tv 50 (+1 skipped).
