# Phone fit of the party-night host screens (M16 measurement)

Measured by `packages/party_host/test/phone_fit_test.dart` (run with `PHONE_FIT=1`, or `--dart-define=PHONE_FIT=true`);
numbers in `results.json`, pictures `<screen>-<WxH>.png` here. Sunny look, real fonts, dpr 1, 4 players, 5-round night.

## How a phone hosts
- controller_app "Play here" / "Display here" embeds party_host in-app (`controller_app/lib/src/host/`), so the host
  screens are the same widgets as on the TV, drawn at the phone's logical size.
- controller_app locks **landscape** (`main.dart:21`, `gyro.dart:384`). A phone host is therefore ~640-852 x 360-393 dp;
  360x640 portrait is not reachable today (kept in the table as a stress case).
- **No global scale**: no FittedBox / Transform.scale / text-scale wrapper above the host screens; every measured text
  paints at scale 1 within 0.5. The 1040/900/860 card widths are maximums (`maxWidth`), not a scaled design frame.
  The 1280x720 "frame" is only a design reference.

## Fit table (fits = no overflow; scroll = scrolls N dp; "button under" = way-on button off screen until scrolled)
| screen | 640x360 phone | 360x640 phone | 1280x800 tablet | 1280x720 TV |
| --- | --- | --- | --- | --- |
| night start | fits; scrolls 551, button under | scrolls 300, button under | fits | fits, scrolls 70 |
| scoreboard (2 of 5) | fits; scrolls 175, buttons 27 px under | OVERFLOWS (4 rows, 8-16 px) | fits | fits |
| final scores | fits; scrolls 115, button under | OVERFLOWS (4 rows, 7-18 px) | fits | fits |
| awards reveal | fits; scrolls 15, no button | OVERFLOWS (121 px, winner row) | fits | fits |
| Arena results | fits; scrolls 71, Play again visible | OVERFLOWS (4 rows, 3-63 px) | fits | fits |
| puzzle results | fits; scrolls 86, Next visible | OVERFLOWS (188 + 17 px) | fits | fits |

Text too small: none. Smallest effective text on the 640x360 phone: 13.5 dp (the number in a player badge disc),
15 dp start-card body, 18 dp elsewhere; a 24 px label renders at 24 dp (no downscale anywhere).

## Reading it for Thumby (56 dp head + 2-line caption strip)
- Landscape phone: nothing breaks and nothing shrinks, but the night screens already use the whole 360 dp height and
  scroll; a fixed 56 dp head plus caption strip costs ~70-90 dp of a 304 dp viewport (start card/scoreboard) and must
  not cover the way-on buttons, which are already below the fold on start, scoreboard and final scores.
- Portrait 360 wide is unsupported today; if ever wanted, every row-based screen overflows.

## Caveats
- 360x640 spills were measured with 18-21 character nicknames; a real host cuts a name at 10 (`maxNicknameLength`,
  `packages/connection/lib/src/game_types.dart:79`), so those overflows are overstated (not re-measured). The 640x360
  numbers with long names are an upper bound.
- 640x360 is narrower than a real landscape phone (~852x393), so real phones fit better than this table.

## Likely fix per failing item (one line)
- Landscape: put the way-on button in a pinned bottom bar (start, scoreboard, final scores).
- Portrait rows (only if ever supported): let the name column `Flexible`/two-line and shrink the badge slot.

## Round strip on the joined phone (M16 item 1)
Captured through a widget test: `round-strip-852x393.png` and `round-strip-852x393-2x.png`
(`controller_app/test/round_strip_png_test.dart`, `ROUND_STRIP_PNG=1`). Still not seen on an emulator or device.
