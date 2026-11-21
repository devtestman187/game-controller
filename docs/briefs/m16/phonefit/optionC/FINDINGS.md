# Option C: the host in a 960x540 design frame, scaled to the device (M16 measurement)

Measured by `packages/party_host/test/phone_fit_option_c_test.dart` (`PHONE_FIT=1`, or
`--dart-define=PHONE_FIT=true`); numbers in `results.json`, pictures `<screen>-<WxH>.png` and
`<screen>-<WxH>-thumby.png` here. Sunny look, real Fredoka and Nunito, four phones with nicknames of at most 10
characters (Bartholome, Maxi, Alexandria, Chris); the scoreboard and final scores are measured again with six
(Nightshade, Zed), as `<screen>-6p`.

## Method (what "a design frame" means here)

For a device W x H the test takes `s = min(W/960, H/540)`, lays the host out at the frame size (W/s x H/s,
devicePixelRatio 1) and saves the picture at pixelRatio `s`. That is the same picture as a `Transform.scale(s)` over
a 960x540 host, without a transform in the tree. Where the device is not 16:9 the frame grows past 960x540 the other
way: 852x393 gives a 1171x540 frame (extra width), 1280x800 a 960x600 frame and 1024x768 a 960x720 frame (extra
height). That extra is layout room.

- Scroll and content heights are in **frame px**; the device dp are frame px x `s`.
- **smallest dp** is the smallest type on the screen in device dp (frame font px x `s`).
- **unused %** is the share of the frame's pixels equal to its most common colour, read from the rendered frame
  picture (not from the widgets). The colour is the look's paper **#fff6e3** in all 80 cases, so unused % is the
  paper the screen leaves empty; the sky, outlines and cards' borders count as used.
- "button under" = the screen's way-on button is not wholly on screen without scrolling.
- The Thumby variant reserves the bottom 60 frame px (the host lays out in the frame less 60) and the saved picture
  draws a placeholder there: a 56x56 box for the head and a 12 px caption strip beside it.

Frame sizes and scale: 640x360 -> 960x540, s 0.6667; 852x393 -> 1171x540, s 0.7278; 1024x768 -> 960x720, s 1.0667;
1280x800 -> 960x600, s 1.3333; 1920x1080 -> 960x540, s 2.

## Fit (fits = no overflow and no scrolling)

| screen | 640x360 | 852x393 | 1024x768 | 1280x800 | 1920x1080 |
| --- | --- | --- | --- | --- | --- |
| night start | scroll 250, button under | scroll 250, button under | scroll 70, button on | scroll 190, button under | scroll 250, button under |
| scoreboard (2 of 5) | fits | fits | fits | fits | fits |
| final scores | fits | fits | fits | fits | fits |
| awards reveal | fits (no button) | fits | fits | fits | fits |
| Arena results | fits | fits | fits | fits | fits |
| puzzle results | fits | fits | fits | fits | fits |
| scoreboard, 6 players | scroll 107, button under | scroll 107, button under | fits | scroll 47, button on | scroll 107, button under |
| final scores, 6 players | scroll 47, button under | scroll 47, button under | fits | fits | scroll 47, button under |

No overflow was reported in any of the 80 cases (`errors` empty everywhere).

## Type and unused area (smallest dp / unused %)

| screen | 640x360 | 852x393 | 1024x768 | 1280x800 | 1920x1080 |
| --- | --- | --- | --- | --- | --- |
| night start | 10.0 / 60.5 | 10.9 / 53.2 | 16.0 / 64.4 | 20.0 / 63.3 | 30.0 / 60.5 |
| scoreboard (2 of 5) | 12.0 / 56.3 | 13.1 / 46.1 | 19.2 / 42.2 | 24.0 / 50.6 | 36.0 / 56.3 |
| final scores | 12.0 / 22.3 | 13.1 / 18.3 | 19.2 / 16.7 | 24.0 / 20.1 | 36.0 / 22.3 |
| awards reveal | 9.0 / 13.2 | 9.8 / 10.8 | 14.4 / 9.9 | 18.0 / 11.9 | 27.0 / 13.2 |
| Arena results | 12.0 / 29.6 | 13.1 / 24.3 | 19.2 / 22.2 | 24.0 / 26.7 | 36.0 / 29.6 |
| puzzle results | 9.0 / 43.8 | 9.8 / 35.9 | 14.4 / 32.9 | 18.0 / 39.4 | 27.0 / 43.8 |
| scoreboard, 6 players | 12.0 / 65.4 | 13.1 / 53.6 | 19.2 / 56.2 | 24.0 / 64.7 | 36.0 / 65.4 |
| final scores, 6 players | 12.0 / 29.3 | 13.1 / 23.9 | 19.2 / 22.9 | 24.0 / 27.5 | 36.0 / 29.3 |

The smallest type at 640x360 is 9.0 dp (a badge's number, 13.5 frame px x 0.6667) and 10.0 dp on the start card;
at 852x393, 9.8 and 10.9 dp. Nothing shrinks below 14.4 dp from 1024x768 up.

## Thumby: the same frames with the bottom 60 frame px reserved

Layout = frame height less 60 (960x480 at 640x360 and 1920x1080, 1171x480 at 852x393, 960x660 at 1024x768,
960x540 at 1280x800).

| screen | 640x360 | 852x393 | 1024x768 | 1280x800 | 1920x1080 |
| --- | --- | --- | --- | --- | --- |
| night start | scroll 310, button under | scroll 310, button under | scroll 130, button under | scroll 250, button under | scroll 310, button under |
| scoreboard (2 of 5) | scroll 55 | scroll 55 | fits | fits | scroll 55 |
| final scores | fits | fits | fits | fits | fits |
| awards reveal | fits | fits | fits | fits | fits |
| Arena results | fits | fits | fits | fits | fits |
| puzzle results | fits | fits | fits | fits | fits |
| scoreboard, 6 players | scroll 167 | scroll 167 | fits | scroll 107 | scroll 167 |
| final scores, 6 players | scroll 107 | scroll 107 | fits | scroll 47 | scroll 107 |

Still fitting with the strip: the awards reveal, the Arena's and the puzzle's results on every device; the final
scores on every device; the four-player scoreboard on the tablet-shaped frames (1024x768, 1280x800). The start card
fits nowhere with the strip; the six-player rows fit only on the 1024x768 frame.

## What each screen needs to fit 960x540 with no scroll (measured, not designed here)

- **night start**: content 734 in a 540 frame, 194 px too tall (26% of the frame). The round picker and the three
  award tiles with their explanations are the height; the awards as one row of icon + name, and the round picker in
  the header, would remove it.
- **scoreboard, 4 players**: fits (484 in 540) — nothing needed.
- **scoreboard, 6 players**: content 591, 51 px too tall, and the way-on button (Shape Race) goes under with it; a
  one-line score row (points beside the name, no badge block) recovers it.
- **final scores, 4 players**: fits (484) — nothing needed.
- **final scores, 6 players**: content 531 against a 484 viewport, 47 px too tall; the Back to games button is the
  part below the fold, so a pinned footer bar for it is enough.
- **awards reveal**: fits (319) — nothing needed.
- **Arena results**: fits (431) — nothing needed.
- **puzzle results**: fits (446) — nothing needed.

## Caveats

- The numbers are the frame's: a 960x540 frame on a 640x360 phone is a 0.667 downscale, so every type size in the
  Type table times the device's `s` is what a player reads; 9-10 dp at the bottom of the range is below a phone's
  comfortable size, and no layout change fixes that (only a smaller design frame or a bigger minimum type does).
- The unused % is one colour's share (the paper). It says how much empty paper a screen has, not how cramped it is:
  the start card is 60% paper and still 194 px too tall.
- The reveal is read before its award timer moves on (brief pf1's way), so its 319 px is the first award only.
- Widget tests, real fonts, one frame each; no emulator or device was used.
