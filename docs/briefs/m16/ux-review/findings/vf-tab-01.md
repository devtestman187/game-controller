# vf-tab-01 — controller app, Pixel Tablet, NATIVE size

Worker: `vf-tab-01`. Scope: two screens of `com.thumbparty.app` on the Pixel Tablet only.
No code, test, protocol, map or dependency was touched. No `wm size` / `wm density` change was
issued (native-size pass); the TV was not touched.

## Capture facts (measured before each screenshot)

- Device: `tangorpro` / Pixel Tablet, adb serial `adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp`.
- App: `com.thumbparty.app`, launched with `am start -n com.thumbparty.app/.MainActivity` after
  `am force-stop com.thumbparty.app`; the pad screen was captured 4.0 s after launch.
- `wm size` → `Physical size: 1600x2560` (no override).
- `wm density` → `Physical density: 320` / `Override density: 354`.
- `dumpsys window displays` → `cur=2560x1600`, `app=2560x1600`, `mDisplayRotation=ROTATION_270`.
- Viewport: **2560x1600 px, landscape, = 1157.1 x 723.2 dp**. Divisor used everywhere below:
  `dp = px / (354/160) = px / 2.2125`.
- Theme: **Sunny**. Deciding samples: all four corners `#7EC9F8` against §3 Sunny `background`
  `#7CC8F8` (Night would be `#241C5E`); the pad's glow centre reads `#C4EAFF`, exactly §3 Sunny
  `backgroundGlow`. Polka dots (Sunny) present, stars (Night) absent.
- Screenshots (only under the temp dir):
  `C:\Users\mrman\AppData\Local\Temp\ux-pilot\vf-tab-01-pad.png`,
  `C:\Users\mrman\AppData\Local\Temp\ux-pilot\vf-tab-01-settings.png`.
- Element geometry below is from the pulled PNG (ink-outline and fill-colour pixel scans); touch
  bounds quoted as "touch" are from `uiautomator dump` and are larger than the drawn shapes.
- Contrast: WCAG 2.x computed from the sampled foreground and the sampled background fill;
  token names from `docs/design/look-and-sound.md` §3.

---

## Record 1 — controller pad / connect screen

**screen / form factor / theme / viewport px**
Controller pad and connect screen (the app's first screen after launch). Form factor: tablet,
Pixel Tablet `tangorpro`, landscape (ROTATION_270). Theme: Sunny. Viewport: 2560x1600 px,
landscape, 1157.1x723.2 dp at density 354 (`dp = px / 2.2125`). No screen title and no
back/close affordance.

**elements in reading order, with pixel size and position** (bounds = the drawn shape; x,y = its
top-left; rows are ordered top-to-bottom, then left-to-right):

| # | element | bounds px | w x h px | w x h dp | fill / outline / type |
|---|---|---|---|---|---|
| 1 | Connection pill ("tap to connect") | x26–670, y14–109 | 645 x 96 | 291.5 x 43.4 | fill `#7CC8F8` = `background`; ink `#1E1646` outline 2 px (0.9 dp); full pill, r = 48 px (21.7 dp) |
| 2 | Connection state dot (ink ring) | x61–86, y49–74 | 26 x 26 | 11.8 x 11.8 | ring 6 px (2.7 dp) ink; core 12 x 12 px (5.4 dp) `#FFB020` = `caution`; centre (73,62) |
| 3 | Label "Connecting... · tap to connect" | x119–635, y47–80 | 517 x 34 | 233.7 x 15.4 | ink on `#7CC8F8` = **9.12:1** (`onBackground` on `background`); 1 line; ink height 34 px = Nunito 700 15 dp body |
| 4 | Mode segmented control (container) | x1552–2223, y26–96 | 672 x 71 | 303.7 x 32.1 | unfilled — the sky gradient shows through (`#9CD7FB` in the D-pad segment, `#98D5FB` in Gyro); ink outline 2 px (0.9 dp); dividers 2 px at x1775 and x1999 |
| 5 | Segment "D-pad" | x1552–1775 | 224 x 71 | 101.2 x 32.1 | icon 90 x 45 px at (1560,40); label 91 x 34 px at (1652,47); ink on `#9CD7FB` = 10.75:1; touch 224 x 88 px |
| 6 | Segment "Gyro" | x1776–1999 | 224 x 71 | 101.2 x 32.1 | icon 73 x 32 px at (1817,46); label 60 x 32 px at (1893,49); ink on `#98D5FB` = 10.75:1 |
| 7 | Segment "Sticks" — selected | fill x2001–2220, y29–94 | fill 220 x 66 | 99.4 x 29.8 | fill `#FFB020` = `caution`; icon 59 x 24 px at (2031,49); label 96 x 27 px at (2092,47); ink on `caution` = **9.13:1**; `selected=true` in the a11y tree |
| 8 | Stick-settings icon button | glyph x2257–2296, y42–81 | glyph 40 x 40 | 18.1 x 18.1 | ink glyph on `background`; touch x2224–2330, y9–115 = 106 x 106 px (47.9 x 47.9 dp) |
| 9 | Settings (gear) icon button | glyph x2361–2404, y40–84 | glyph 44 x 45 | 19.9 x 20.3 | ink glyph on `background`; touch x2330–2436, y9–115 = 106 x 106 px (47.9 x 47.9 dp) |
| 10 | Diagnostics icon button | glyph x2467–2511, y45–79 | glyph 45 x 35 | 20.3 x 15.8 | ink glyph on `background`; touch x2436–2542, y9–115 = 106 x 106 px (47.9 x 47.9 dp) |
| 11 | "LB" pill | x32–325, y780–874 | 294 x 95 | 132.9 x 42.9 | fill `#FFF6E3` = `paper`; ink outline 6 px (2.7 dp); r = 47.5 px; label 48 x 30 px at (156,813), ink on `paper` = **15.53:1** |
| 12 | "RB" pill | x2234–2527, y780–874 | 294 x 95 | 132.9 x 42.9 | same fills/outline; label 51 x 30 px at (2356,813) |
| 13 | Left stick (disc + knob) | disc x32–445, y886–1299 | disc 414 x 414; knob 161 x 159 | 187.1 x 187.1; 72.8 x 71.9 | disc `paper`, ink outline 6 px; knob fill `#69A1D1` (not a §3 token), no ink edge, hard shadow +3 px x / +4 px y; knob centre (240,1095) |
| 14 | "Y" face button | x2172–2359, y899–1086 | 188 x 188 | 85.0 x 85.0 | fill `#FFD23F` = `faceY`/`star`; ink outline 6 px; letter cap 44 px (19.9 dp); ink on `faceY` = **11.56:1**; centre (2265,992) |
| 15 | "X" face button | x2018–2205, y1053–1240 | 188 x 188 | 85.0 x 85.0 | fill `#2E9BF0` = `faceX`/`player1`; ink on `faceX` = **5.61:1**; centre (2112,1146) |
| 16 | "B" face button | x2327–2513, y1054–1240 | 187 x 187 | 84.5 x 84.5 | fill `#FF4D5E` = `faceB`/`bad`; ink on `faceB` = **5.15:1**; centre (2418,1146) |
| 17 | "Select" pill | x1122–1274, y1061–1155 | 153 x 95 | 69.2 x 42.9 | `paper`, ink 6 px; label 85 x 30 px at (1150,1093) |
| 18 | "Start" pill | x1286–1437, y1061–1155 | 152 x 95 | 68.7 x 42.9 | `paper`, ink 6 px; label 101 x 30 px at (1311,1094); gap Select→Start 11 px (5.0 dp) |
| 19 | "A" face button | x2173–2359, y1208–1394 | 187 x 187 | 84.5 x 84.5 | fill `#2FCB74` = `faceA`/`good`; ink on `faceA` = **7.88:1**; centre (2266,1301) |
| 20 | Right stick (disc + knob) | disc x1729–2061, y1262–1593 | disc 333 x 332; knob 126 x 124 | 150.5 x 150.1; 56.9 x 56.0 | disc `paper`, ink 6 px; knob `#69A1D1`, no ink edge; knob centre (1896,1430) |
| 21 | D-pad | x547–830, y1311–1594 | 284 x 284 | 128.4 x 128.4 | `paper`, ink 6 px; arm 100 px (45.2 dp); centre disc 54 x 54 px (24.4 dp) `#B0A8AC`; four triangles 69 x 70 px (31.2 x 31.6 dp) `#8E8694`; centre (688,1452) |

Face-button spacing: adjacent centres 218 px (98.5 dp) apart; opposite centres 306–309 px
(138.3–139.7 dp); gap between adjacent outlines 31 px (14.0 dp). Bottom margins: right disc and
D-pad end at y1593–1594, i.e. 6–7 px (2.7–3.2 dp) above the viewport bottom; left disc ends at
y1299.

**primary action**
"Connecting... · tap to connect" connection pill — 291.5 x 43.4 dp (645 x 96 px) at (26,14);
contrast ink `#1E1646` on `#7CC8F8` = **9.12:1** (`onBackground` on `background`). The pill's fill
`#7CC8F8` is 2/255 from the sky immediately outside it (`#7EC9F8`), so the shape is carried by the
2 px ink outline alone.

**secondary actions**
Mode segmented control: 3 items, 101.2 x 32.1 dp each (touch 101.2 x 39.8 dp), selected item
"Sticks" filled `caution`. Icon buttons: Stick settings, Settings, Diagnostics — each touch
47.9 x 47.9 dp. Pad inputs: LB and RB 132.9 x 42.9 dp; Select 69.2 x 42.9 dp; Start 68.7 x 42.9 dp;
left stick 187.1 dp disc / 72.8 dp knob; right stick 150.5 dp disc / 56.9 dp knob; D-pad
128.4 x 128.4 dp with a 45.2 dp arm; A, B, X, Y 84.5–85.0 dp.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels on this screen. Measured slack: connect label 517 px
inside a 641 px pill interior (124 px, 56.0 dp, unused); widest segment content 188 px of a 224 px
segment (36 px, 16.3 dp, unused). All text is on one line at cap heights 27–30 px
(12.2–13.6 dp) for pill and segment labels, 34 px (15.4 dp) ink height for the connect label, and
44 px (19.9 dp) cap height for the face letters.

**states covered, and states missing**
Covered: connecting/waiting (label "Connecting..." plus a `caution` state dot in an ink ring);
mode selection with one item marked selected; all 11 pad inputs (LB, RB, Select, Start, both
sticks, D-pad, A, B, X, Y) drawn at rest.
Missing (absent, not observed anywhere in this capture): connected state (no `good`-coloured dot,
no host name, no session line); disconnected/error state (no `bad` dot, no error text); dropped
link state; any pressed, focused or disabled control state; any empty state. The a11y label of the
pill reads "Not connected · tap to connect" while the visible string is
"Connecting... · tap to connect" — the two disagree on the same element.

**cross-screen inconsistencies versus the other screens**
1. Ink outline weights differ on one screen: 6 px (2.7 dp) on LB/RB/Select/Start, both stick
   discs, the D-pad and the four face buttons, but 2 px (0.9 dp) on the connection pill and the
   mode segmented control. §3 states "outline width 3 px on menus".
2. Label text heights differ on one screen: 30 px cap (13.6 dp) for LB/RB/Select/Start against
   27 px (12.2 dp) for the three segment labels — 3 px (1.4 dp) apart.
3. Icon glyph sizes are 45, 40, 44 and 35 px tall (20.3, 18.1, 19.9, 15.8 dp) in the same top bar.
4. Two stick discs of different size: 414 px (187.1 dp) left against 333 px (150.5 dp) right —
   81 px (36.6 dp) apart; knobs 161 px (72.8 dp) against 126 px (56.9 dp).
5. Neutrals not in §3: `#69A1D1` (both stick knobs), `#B0A8AC` (D-pad centre disc), `#8E8694`
   (D-pad triangles) — contrast against their surroundings `unmeasured` (no token pair).
6. Against Settings: the pad uses only ink `#1E1646` on tokens; Settings adds a second text colour
   `#615975` (not in §3). The selected-item fill `#FFB020` `caution` is the same on both screens.
   `#FFD23F` `star` is used as a fill only on Settings (card header bands), never on the pad.
7. The pad has no title and no back affordance; Settings has both (title 251 x 65 px,
   Back touch 47.9 x 47.9 dp).

**flow stage (spec §1)**: 1 (launch / first run) and 13 (re-entry after a drop) are represented only
by the connection pill and its `caution` dot; 8 (in-round controls) by the pad body. Stages 2–7 and
9–12 are not represented on this device's screen (host setup and selection live on the TV).

---

## Record 2 — Settings

**screen / form factor / theme / viewport px**
Settings screen, opened by tapping the gear at (2383,62); scroll position 0, content continues
below the viewport bottom. Form factor: tablet, Pixel Tablet `tangorpro`, landscape
(ROTATION_270). Theme: Sunny (same samples as above; Settings corners `#7EC9F8`). Viewport:
2560x1600 px, landscape, 1157.1x723.2 dp at density 354. Layout: one scrolling page of two
columns — left column cards at x36–1261 ("Look and sound") and x164–1133 ("You"); right column
cards at x1326–2496 ("Gyro") and x1298–2524 ("Sticks").

**elements in reading order, with pixel size and position**

Top bar:

| # | element | bounds px | w x h px | w x h dp | fill / outline / type |
|---|---|---|---|---|---|
| 1 | Back button | glyph x45–79, y45–79 | glyph 35 x 35 | 15.8 x 15.8 | ink glyph on `background`; touch x9–115, y9–115 = 106 x 106 px (47.9 x 47.9 dp) |
| 2 | Title "Settings" | x161–411, y37–101 | 251 x 65 | 113.4 x 29.4 | ink; cap 49 px (22.1 dp) + descender; ink on `#84CCF9` = **9.52:1**; Fredoka 600 32 dp per §3 title size |
| 3 | "Defaults" button | x2344–2558, y18–105 | 215 x 88 | 97.2 x 39.8 | fill `#2E9BF0` = `player1`/`faceX`; ink outline 6 px; label 140 x 55 px (63.3 x 24.9 dp) at (2380,45); ink on `player1` = **5.61:1**; right edge 2 px (0.9 dp) from the viewport edge |

Card A "Look and sound" (left column):

| # | element | bounds px | w x h px | w x h dp | fill / outline / type |
|---|---|---|---|---|---|
| 4 | Card | x36–1261, y159–1329 | 1226 x 1171 | 554.1 x 529.3 | fill `paper`; ink outline 6 px (2.7 dp) |
| 5 | Header band + title | band y166–249 | band 84 tall | 38.0 | band `#FFD23F` = `star`; title "Look and sound" 312 x 32 px (141.0 x 14.5 dp) at (493,191); ink on `star` = **11.56:1** |
| 6 | Row label "Look" | x74–156, y305–331 | 83 x 27 | 37.5 x 12.2 | ink on `paper` = **15.53:1** |
| 7 | Look segmented control | x71–552, y374–461 | 482 x 88 | 217.9 x 39.8 | ink outline 2 px (0.9 dp); 3 items 161 px wide each (72.8 dp), touch 161 x 106 px (72.8 x 47.9 dp); dividers 1–2 px |
| 8 | "Auto" — selected | fill x71–232 | item 161 x 106 | 72.8 x 47.9 | fill `#FFB020` = `caution`; ink label 84 x 27 px (38.0 x 12.2 dp) at (109,403); ink on `caution` = **9.13:1**; `selected=true` |
| 9 | "Sunny" | x232–392 | item 161 x 106 | 72.8 x 47.9 | `paper`; ink label 109 x 34 px at (258,403); ink on `paper` = 15.53:1 |
| 10 | "Night" | x392–553 | item 161 x 106 | 72.8 x 47.9 | `paper`; ink label 114 x 47 px at (426,403) |
| 11 | Caption "Auto: Sunny from 7:00 to 19:00, Night otherwise" | x72–959, y493–526 | 888 x 34 | 401.4 x 15.4 | ink on `paper` = 15.53:1; 1 line |
| 12 | Row "Effects" (on) | label x74–197, y568–594; switch x1102–1218, y601–673 | switch 117 x 73 | 52.9 x 33.0 | label ink on `paper` 15.53:1; track `#2FCB74` = `good` (103 x 59 px inner), ink thumb at right, ink outline 6 px; row touch 1156 x 204 px |
| 13 | "Effects" description | L1 x74–1016, y623–656; L2 x73–379, y679–705 | L1 943 x 34; L2 307 x 27 | 426.2 x 15.4; 138.8 x 12.2 | ink on `paper` 15.53:1; line pitch 56 px (25.3 dp); wraps after "Turn off" |
| 14 | Row "Mute" (off) | label x74–162, y795–821; switch x1102–1218, y800–872 | switch 117 x 73 | 52.9 x 33.0 | label ink; track `paper`, ink thumb at left, ink outline 6 px; row touch 1156 x 159 px |
| 15 | "Mute" description | x73–986, y851–884 | 914 x 34 | 413.1 x 15.4 | ink on `paper` 15.53:1; 1 line |
| 16 | Row "Sounds" + value | label x73–203, y929–955; value "80%" x1145–1224 | label 131 x 27; value 80 x 27 | 59.2 x 12.2; 36.2 x 12.2 | ink; value right-aligned 37 px (16.7 dp) from the card's right edge |
| 17 | "Sounds" slider | track x124–1173, y1017–1030 | track 1050 x 14 | 474.6 x 6.3 | filled `#2FCB74` `good` from x124 to x982; unfilled `#B0A8AC` (not §3; 2.16:1 vs `paper`); thumb 40 x 43 px (18.1 x 19.4 dp) centre (960,1024) = 79.6 % of the track; a11y value "80%" |
| 18 | Row "Music" + value | label x74–173, y1090–1116; value "60%" x1146–1224 | label 100 x 27; value 79 x 27 | 45.2 x 12.2; 35.7 x 12.2 | ink |
| 19 | "Music" slider | track x124–1173, y1179–1192 | 1050 x 14 | 474.6 x 6.3 | filled to x774; thumb 39 x 44 px centre (752,1186) = 59.8 %; a11y value "60%" |
| 20 | Caption "Plays on the game picker and join screen." | x74–820, y1252–1285 | 747 x 34 | 337.6 x 15.4 | ink on `paper` 15.53:1; 1 line |

Card B "Gyro" (right column):

| # | element | bounds px | w x h px | w x h dp | fill / outline / type |
|---|---|---|---|---|---|
| 21 | Card | x1326–2496, y159–928 | 1171 x 770 | 529.3 x 348.0 | `paper`; ink 6 px |
| 22 | Header band + title | band y166–249 | 84 tall | 38.0 | `#FFD23F` `star`; title "Gyro" 95 x 40 px (42.9 x 18.1 dp, includes the "y" descender; cap 32 px = 14.5 dp) at (1864,193) |
| 23 | Caption "Calibrate from the gyro mode screen (or its settings button)." | x1364–2458, y305–338 | 1095 x 34 | 494.9 x 15.4 | fg `#615975` on `paper` = 6.12:1 — **`unmeasured`** (fg not in §3); 1 line |
| 24 | Row "Sensitivity" | label x1364–1640; secondary "full at 30° of tilt" x1650–1799; value "1.00×" x2362–2457 | group 436 x 34; value 96 x 27 | 197.1 x 15.4; 43.4 x 12.2 | "Sensitivity" ink `#1E1646` (15.53:1); "full at 30° of tilt" `#615975` = **`unmeasured`** (6.12:1); "1.00×" ink 15.53:1 |
| 25 | "Sensitivity" slider | track x1414–2407, y475–488 | track 994 x 14 | 449.3 x 6.3 | filled to x1768; thumb 38 x 43 px centre (1746,482) = 33.4 %; visible value 1.00×, a11y value "33%" |
| 26 | Row "Dead zone" + "5%" | label x1365–1550, y566–592; value x2404–2458 | label 186 x 27; value 55 x 27 | 84.1 x 12.2; 24.9 x 12.2 | ink |
| 27 | "Dead zone" slider | track x1414–2407, y655–668 | 994 x 14 | 449.3 x 6.3 | filled to x1637; thumb 39 x 43 px centre (1615,661) = 20.2 %; visible 5%, a11y "20%" |
| 28 | Row "Smoothing" + "50%" | label x1364–1556, y745–778; value x2381–2458 | label 193 x 34; value 78 x 27 | 87.2 x 15.4; 35.3 x 12.2 | ink |
| 29 | "Smoothing" slider | track x1414–2407, y834–847 | 994 x 14 | 449.3 x 6.3 | filled to x1987; thumb 39 x 44 px centre (1965,840) = 55.4 %; visible 50%, a11y "56%" |

Card C "Sticks" (right column):

| # | element | bounds px | w x h px | w x h dp | fill / outline / type |
|---|---|---|---|---|---|
| 30 | Card | x1298–2524, y956–1600 | 1227 x 645 (clipped) | 554.6 x 291.1 | `paper`; ink 6 px; bottom edge below the viewport |
| 31 | Header band + title | band y963–1045 | 83 tall | 37.5 | `#FFD23F` `star`; title "Sticks" 115 x 32 px (52.0 x 14.5 dp) at (1853,988) |
| 32 | Row "Floating sticks" (off) | label x1337–1605, y1121–1149; switch x2364–2480, y1154–1226 | switch 117 x 73 | 52.9 x 33.0 | label ink on `paper`; track `paper`, ink thumb at left |
| 33 | "Floating sticks" description | L1 x1337–2317, y1152–1210; L2 x1334–1529, y1232–1258 | L1 981 x 34; L2 196 x 27 | 443.4 x 15.4; 88.6 x 12.2 | ink on `paper` 15.53:1; line pitch 80 px (36.2 dp); wraps after "of" |
| 34 | Row "Button size" | label "Button size" x1337–1600 ink; secondary "A, B, X and Y, compared with D-pad mode" x1607–2322 `#615975` = **`unmeasured`**; value "75%" x2408–2486 | group 986 x 34; value 79 x 27 | 445.6 x 15.4; 35.7 x 12.2 | ink 15.53:1 and muted 6.12:1 |
| 35 | "Button size" slider | track x1386–2435, y1411–1424 | track 1050 x 14 | 474.6 x 6.3 | filled to x1802; thumb 40 x 44 px centre (1780,1417) = 37.5 %; visible 75%, a11y "38%" |
| 36 | Row "Dead zone" + "10%" | label x1337–1499, y1502–1528; value x2410–2486 | label 163 x 27; value 77 x 27 | 73.7 x 12.2; 34.8 x 12.2 | ink |
| 37 | "Dead zone" slider (Sticks) | track x1386–2435, visible y1590–1600 | visible 1050 x 10 of 14 | 474.6 x 4.5 visible | filled `#2FCB74` from x1387 to x1630; thumb centre (1648,1597), 24 of its 43 px visible (the track's last 4 px and the thumb's last 19 px are below the viewport); (1648-1386)/1050 = 24.9 %, matching the a11y value "25%" and not the visible "10%" |

Card D "You" (left column, bottom):

| # | element | bounds px | w x h px | w x h dp | fill / outline / type |
|---|---|---|---|---|---|
| 38 | Card | x164–1133, y1356–1600 | 970 x 245 (clipped) | 438.4 x 110.3 | `paper`; ink 6 px; bottom edge below the viewport |
| 39 | Header band + title | band y1363–1446 | 84 tall | 38.0 | `#FFD23F` `star`; title "You" 70 x 31 px (31.6 x 14.0 dp) at (613,1389) |
| 40 | Label "Nickname" | x201–393, y1503–1534 | 193 x 32 | 87.2 x 14.5 | ink on `paper` 15.53:1 |
| 41 | Nickname text field | x199–975, y1560–1600 | visible 777 x 40 | 351.2 x 18.1 | `paper` fill, 6 px (2.7 dp) ink outline, rounded corners; empty (0 characters, no placeholder drawn); bottom edge below the viewport |
| 42 | Character counter "0 / 10" | x994–1099, y1596–1600 per a11y tree | 105 x 4 visible (clipped) | 47.5 x 1.8 | effectively **`absent`** from the visible area — only a 4 px sliver remains above the viewport bottom |

**primary action**
"Defaults" pill — 97.2 x 39.8 dp (215 x 88 px) at (2344,18); contrast ink `#1E1646` on `#2E9BF0`
= **5.61:1** (ink on `player1`/`faceX`). No commit/save action exists on this screen (`absent`);
each control writes its value immediately, and the only other screen-level action is Back.

**secondary actions**
Back (47.9 x 47.9 dp touch, glyph 15.8 dp); Look segmented control — 3 items of 72.8 x 47.9 dp;
three switches of 52.9 x 33.0 dp drawn (each row is the touch target, 1156 x 204 px for Effects,
1156 x 159 px for Mute, 1156 x 203 px for Floating sticks); seven sliders with 19.4 dp thumbs on
tracks of 474.6 dp (left column and Sticks card) or 449.3 dp (Gyro card); Nickname field 351.2 dp
wide.

**text that wraps or truncates at this size, and how**
Two descriptions wrap to 2 lines each:
- "Effects" description → break after "Turn off": L1 943 px (426.2 dp), L2 307 px (138.8 dp);
  line pitch 56 px (25.3 dp). L1 ends at x1016, 86 px (38.9 dp) before the switch's left edge at
  x1102, and 245 px (110.7 dp) before the card's inner right edge.
- "Floating sticks" description → break after "of": L1 981 px (443.4 dp), L2 196 px (88.6 dp);
  line pitch 80 px (36.2 dp). L1 ends at x2317, 47 px (21.2 dp) before the switch's left edge at
  x2364.
No ellipsis and no mid-word truncation anywhere in the visible area. Clipped by the viewport
bottom (not text truncation): the Sticks "Dead zone" slider and its thumb, the "You" card below its
header, the Nickname field's bottom edge, and the "0 / 10" counter (4 px sliver).

**states covered, and states missing**
Covered: Look = Auto selected, and the rendered palette is Sunny (`#7EC9F8` corners, `#C4EAFF`
glow); Effects on; Mute off; Sounds 80 %; Music 60 %; Floating sticks off; Gyro sensitivity 1.00×,
dead zone 5 %, smoothing 50 %; Sticks button size 75 %, dead zone 10 %; Nickname empty
(0 of 10 characters); scroll position 0 of a scrolling page.
Missing (absent): any error or failure state; any loading state; any disabled control; any
in-progress/saving state; a scroll indicator (none drawn); the "0 / 10" counter (a 4 px sliver
only); and every control below the viewport bottom, which this capture does not include (the page
scrolls — the Sticks "Dead zone" slider and thumb are cut at y1600).

**cross-screen inconsistencies versus the other screens**
1. Selected-item fill is the same token on both screens (`caution` `#FFB020`: pad "Sticks" segment,
   Settings "Auto") — no conflict here.
2. Outline weights: 6 px (2.7 dp) on the three cards and the Defaults pill, but 2 px (0.9 dp) on
   the Look segmented control. The pad does the same 6 px / 2 px split, and §3 states 3 px.
3. Second text colour: `#615975` appears on 3 text runs here (Gyro caption, "full at 30° of tilt",
   "A, B, X and Y, compared with D-pad mode") and on no pad text; it is not a §3 token, so all
   three pairs are `unmeasured` (6.12:1 on `paper`).
4. Card widths inside one column differ: right column Gyro 1171 px (529.3 dp) vs Sticks 1227 px
   (554.6 dp) — 56 px (25.3 dp) apart, left edges 1326 vs 1298; left column "Look and sound"
   1226 px (554.1 dp) at x36 vs "You" 970 px (438.4 dp) at x164 — 256 px (115.7 dp) narrower and
   inset 128 px (57.9 dp).
5. Column gap is 65 px (29.4 dp) at the top (1261→1326) and 165 px (74.6 dp) at the bottom
   (1133→1298) because of the two card widths above.
6. Right margin: all cards end 36 px (16.3 dp) from the viewport edge, the Defaults pill ends 2 px
   (0.9 dp) from it.
7. Type sizes: card header titles cap 31–32 px (14.0–14.5 dp); row labels and segment labels cap
   27 px (12.2 dp); description ink height 34 px (15.4 dp); screen title cap 49 px (22.1 dp). The
   pad's pill labels are cap 30 px (13.6 dp), 3 px (1.4 dp) above these row labels.
8. Accessibility values disagree with the visible values on 5 of 7 sliders, because the SeekBar
   reports its position as a percentage of the track while the label shows the setting value:
   Sensitivity a11y "33%" vs 1.00×; Gyro dead zone "20%" vs 5%; Smoothing "56%" vs 50%; Sticks
   button size "38%" vs 75%; Sticks dead zone "25%" vs 10%. Sounds "80%" vs 80% and Music "60%"
   vs 60% agree because their range is 0–100. The measured thumb positions confirm the a11y figure
   is the track fraction: 33.4 %, 20.2 %, 55.4 %, 37.5 %, 24.9 %, 79.6 %, 59.8 %.
9. Screen-reader traversal order interleaves the columns: Back → Settings → Defaults → "Look and
   sound" title → "Gyro" title → "Look" → Gyro caption → Auto → Sunny → Night → … (per the
   `uiautomator dump` node order), i.e. it does not read the left card to its end before the right
   card.

**flow stage (spec §1)**: this surface covers none of the 13 stages directly; it configures stage 8
(in-round controls — stick mode, button size, dead zones, floating sticks) and stage 7/9-11
indirectly through "Look", "Effects", "Mute", "Sounds", "Music" and the "You" nickname used from
stage 4 onward.

---

## `unmeasured` / `absent` summary

- `unmeasured`: Settings muted text `#615975` on `#FFF6E3` (Gyro caption, "full at 30° of tilt",
  "A, B, X and Y, compared with D-pad mode") — 6.12:1 computed, pair not in §3.
- `unmeasured`: pad stick-knob `#69A1D1`, D-pad centre disc `#B0A8AC`, D-pad triangles `#8E8694`,
  Settings unfilled slider track `#B0A8AC` — no §3 token pair exists for these.
- `absent`: pad connected / error / dropped-link states; pressed, focused or disabled control
  states on either screen.
- `absent`: Settings error, loading, disabled and saving states; scroll indicator; the "0 / 10"
  counter (4 px sliver only).
- Partially visible (clipped, not absent): the Sticks "Dead zone" slider (10 of 14 px of track,
  24 of 43 px of thumb) and the Nickname field's bottom edge.
- `absent`: a commit/save action on Settings.
- Screens not reached: none of the two assigned screens failed; the stick-settings panel and the
  diagnostics panel behind the other two top-bar icons were not captured (out of this brief's
  scope).
