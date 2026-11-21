# oc1 — option C: a 960x540 design frame scaled to the device (measurement only)

## Summary

Method: the host lays out in frame px (view = W/s x H/s, s = min(W/960, H/540), dpr 1) and the picture is taken at
pixelRatio s, which is the same picture as a `Transform.scale(s)` over a 960x540 host. 8 screens (the 6 of pf1 plus
the six-player scoreboard and final), 5 devices, each full frame and with the Thumby strip: 80 cases, all run, no
overflow in any of them, 80 PNGs and `results.json` written.

| frame (device) | start | scoreboard | final | reveal | Arena | puzzle | 6p scoreboard | 6p final |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 960x540 (640x360) | scroll 250, button under | fits | fits | fits | fits | fits | scroll 107, button under | scroll 47, button under |
| 1171x540 (852x393) | scroll 250, button under | fits | fits | fits | fits | fits | scroll 107, button under | scroll 47, button under |
| 960x720 (1024x768) | scroll 70, button on | fits | fits | fits | fits | fits | fits | fits |
| 960x600 (1280x800) | scroll 190, button under | fits | fits | fits | fits | fits | scroll 47, button on | fits |
| 960x540 (1920x1080) | scroll 250, button under | fits | fits | fits | fits | fits | scroll 107, button under | scroll 47, button under |

- Fits at the exact design frame: scoreboard, final scores, awards reveal, Arena results, puzzle results (4 players).
  Fails: night start (734 px of content in a 540 frame), six-player scoreboard (591) and six-player final (531), the
  last two with the way-on button under the fold.
- Smallest type, in device dp: 640x360 9.0 (start card 10.0), 852x393 9.8 (10.9), 1024x768 14.4 (16.0),
  1280x800 18.0 (20.0), 1920x1080 27.0 (30.0). 9-10 dp on a phone is the price of the 0.667 downscale.
- Unused area (share of frame pixels equal to the most common colour, read from the rendered frame; that colour is
  the look's paper #fff6e3 in all 80 cases): 10-66%. Lowest on the awards reveal (9.9-14.9%), highest on the
  six-player scoreboard (53.6-66.3%) and the start card (53.2-64.7%). Empty paper and cramped rows go together
  here: the start card is 60% paper and still 194 px too tall.
- Thumby (bottom 60 frame px reserved): with the strip the awards reveal, the Arena and puzzle results and the
  four-player final scores still fit on all five devices; the four-player scoreboard only on 1024x768 and
  1280x800; the six-player rows only on 1024x768; the start card on none.
- Turns used: about 30 messages, of which 4 were reruns of the measurement.

## What was measured and how

The six pf1 screens are opened exactly as pf1 opens them (shared code, see below): start card, scoreboard after 2 of
5 rounds, final scores, the awards' reveal, the Arena's and the puzzle's round results. The two extra screens are
the same scoreboard and final with a six-phone roster. Data: 4 players (Bartholome, Maxi, Alexandria, Chris — at
most 10 characters, what `maxNicknameLength` keeps), five-round night, three awards, Sunny look (midday clock), real
Fredoka and Nunito. Six players: the same plus Nightshade and Zed, with points p5 = 2 and p6 = 0.

Per case the test records: the frame size and scale, the layout size (frame less the strip), errors and overflows,
each scrollable's extent and viewport (frame px), the content height (viewport + extent), `fitsNoScroll` (no error,
extent <= 0.5), the way-on button's rect and whether it is whole on screen, the smallest font in device dp, the 24 px
label rendering, clipped texts, every scale above 1, the dominant colour and the share of frame pixels in it.

Computed frame sizes and scales (what the report and FINDINGS use):

| device | s = min(W/960, H/540) | frame (W/s x H/s) | layout with strip |
| --- | --- | --- | --- |
| 640x360 | 0.6667 | 960x540 | 960x480 |
| 852x393 | 0.72778 | 1170.69x540 | 1170.69x480 |
| 1024x768 | 1.06667 | 960x720 | 960x660 |
| 1280x800 | 1.33333 | 960x600 | 960x540 |
| 1920x1080 | 2.0 | 960x540 | 960x480 |

(The 852x393 frame is 1170.69 wide; it is named 1171x540 in the files.) Device dp values are frame px x s:
15 x 0.6667 = 10.0, 13.5 x 0.6667 = 9.0, 15 x 0.72778 = 10.917, 13.5 x 0.72778 = 9.825, 15 x 1.06667 = 16.0,
15 x 1.33333 = 20.0, 15 x 2 = 30.0.

PNG sizes were checked: `night-final-1920x1080.png` is 1920x1080, `night-final-852x393.png` is 852x393, and the
Thumby picture is the same device size with the strip inside it.

## What changed

- `packages/party_host/test/support/phone_fit_support.dart` (new, 382 lines) — the fit tests' shared code: the
  `PhoneFitCase`/`PhoneFitSetup` types, `nightScreens` (the six screens and how to open them), the host mount and
  night helpers, the drawing walk, the measurement record and its helpers, and the PNG save. It is the pf1 code
  moved here, plus `deviceScale` (a frame's scale applied to every font dp) and the scroll/fit helpers.
- `packages/party_host/test/phone_fit_test.dart` (67 lines, was 359) — pf1 now imports the shared code; same cases,
  same results file and PNG names, same JSON keys and order. It was not run in this job, because a pf1 run writes
  `docs/briefs/m16/phonefit/results.json` and the PNGs beside it, which this job may not change.
- `packages/party_host/test/phone_fit_option_c_test.dart` (new, 254 lines) — the option C measurement: skipped
  unless `PHONE_FIT=1` (or `--dart-define=PHONE_FIT=true`), five devices x eight screens x full/Thumby, the frame
  layout, the picture at the device scale, the Thumby strip, the dominant-colour reading and the records.
- `docs/briefs/m16/phonefit/optionC/FINDINGS.md` — the fit, type/unused and Thumby tables, one line per screen on
  what it needs to fit 960x540, and the caveats.
- `docs/briefs/m16/phonefit/optionC/*.png` (80 pictures) and `results.json` — written by the test, not by hand.

## Decisions

1. **Frame layout instead of a transform.** The host is laid out at the frame size and the picture is taken at
   pixelRatio `s`, which is the same pixels as a `Transform.scale(s)` wrapper and keeps the measurement honest
   about how a real wrapper would draw (nothing in the tree reports a scale, so every text's dp is frame px x `s`).
2. **Layout room, not letterbox.** The frame is W/s x H/s, so a device that is not 16:9 gets a taller or wider
   frame (1024x768 -> 960x720, 852x393 -> 1171x540). The alternative, a fixed 960x540 with bars, was not measured.
3. **The Thumby strip is 60 frame px** and the host lays out in the frame less that. The strip is drawn into the
   saved picture only (a 56x56 head box, a 12 px caption strip, the paper strip under it), so no host code learns
   about it; the empty area is measured from the host's own pixels, before the strip is drawn.
4. **Six players only for the scoreboard and the final scores** — the only screens that list the roster. The reveal
   keeps four, because its awards are computed from a round's stats.
5. **One dominant colour, read from the frame-sized picture** (`ImageByteFormat.rawRgba`, counted per pixel): the
   share is of frame px, not device px, as the brief words it; the colours differ only by the scale's antialiasing.
6. **Fit = no error and a vertical scroll extent of 0.5 px or less**; horizontal scrollables are reported but do not
   decide the fit (there are none in these screens).
7. **Type sizes are rounded to 3 decimals** and frame names to whole px (`_sizeName`), so the results file has no
   `8.999999999999773`. Whole frame px are only in the names; the layout uses the exact size.
8. **The pf1 test was moved onto the shared file** rather than duplicating its 350 lines; its JSON keys, order and
   case names are unchanged, so a later pf1 run writes the same file as before.

## Questions and suggestions (for Claude; nothing acted on)

1. With `s = min(W/960, H/540)` a 640x360 phone draws body type at 10 dp and a badge number at 9 dp. Is a minimum
   type (a floor on `s`, or a different frame height) wanted before the layout work starts?
2. The frame grows with the device's aspect (1024x768 gives 960x720). If the intent is a strict 16:9 frame with
   bars, the fit table changes for 1024x768 (bars, and only the 960x540 numbers apply); say if that is measured
   next.
3. `unusedPct` counts one colour. If the intent is "how much of the screen is not content", a second metric (the
   share of the most common 8 colours, or a paper/border/ink split) would say more.
4. The next layout job (not started here) is small: the start card needs 194 frame px (734 in 540), the six-player
   scoreboard 51 and the six-player final 47, of which the last is the way-on button alone.

## Hand-over

- The measurement is reproducible: `cd packages/party_host && PHONE_FIT=1 flutter test test/phone_fit_option_c_test.dart`
  (or `--dart-define=PHONE_FIT=true`); it rewrites the 80 pictures and `results.json` in this folder.
- pf1's own measurement and pictures are untouched; its test now lives on the shared support file and is skipped in
  the normal suite, like before.
- Open: the start card's and the six-player rows' layout (a later brief), a decision on the type floor, and the
  option C findings' effect on the pf1 conclusions (option C makes five screens fit that pf1 saw scrolling).
- Self-check (review-rules A): host setup is `pumpHost` with the frame size and one fake per phone, restored per
  test; kept state is the night in `appContainer`, started inside each test; the two tests share only the support
  helpers, no global state; only the files in `allow:` were written; nothing was staged or committed.

## Commit message

M16 phonefit: measure a 960x540 design frame on five devices

The host is laid out at the 960x540 frame (W/s x H/s, s = min(W/960, H/540)) and drawn at pixelRatio s, so the
pictures are what a Transform.scale wrapper would show. Five devices x eight screens, each full and with the
Thumby's 60 px strip reserved: 80 cases, results.json and 80 PNGs, plus FINDINGS.md with the fit, type and unused
tables. Only the night start (194 px too tall), the six-player scoreboard (51) and final (47) need layout room at
960x540; a 640x360 phone reads type at 9-10 dp. The pf1 open/measure/PNG code moved to
test/support/phone_fit_support.dart and both tests use it; no lib change.

## Status row

M16 phonefit option C: measured — 960x540 frame on 5 devices x 8 screens x full/Thumby (80 cases, no overflow),
FINDINGS + results.json + PNGs in docs/briefs/m16/phonefit/optionC; open: layout room for the start card (-194 px)
and the six-player rows (-51/-47), and a decision on a type floor (9-10 dp at 640x360).

## Delete

- docs/briefs/m16/phonefit/optionC/summary.dart
