# vf-matrix-tablets — controller pad / connect screen, Pixel Tablet, 4 tablet logical sizes

Worker: `vf-matrix-tablets`. Scope: ONE screen — the controller's pad / connect screen, the app's
first screen after launch — of `com.thumbparty.app` on the Pixel Tablet
(`adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp`) at 4 tablet logical sizes in landscape, via the
`wm size` / `wm density` override. No code, test, protocol, map or dependency was touched. The TV
(`192.168.1.100:5555`) was not contacted. Look was left on Auto and rendered Sunny.

## Capture facts (measured around each screenshot)

- App: `com.thumbparty.app`, `am force-stop` then `am start -n com.thumbparty.app/.MainActivity`,
  `shell screencap -p /sdcard/t<n>.png` then `pull` (no shell redirection), screenshot 4.0 s after
  launch. Every capture was preceded by `wm size` + `wm density 160` + force-stop + launch, so each
  PNG is a fresh layout of the pad screen.
- `wm density 160` on every capture ⇒ `dp = px / (160/160) = px`. **Every px figure in this file is
  also its dp figure**; each record states the divisor as `dp = px / 1`.
- Orientation: landscape, `mDisplayRotation=ROTATION_270` (unchanged, no rotation setting touched).
  Because the rotation swaps the base size, the override was issued as `wm size <H>x<W>` to obtain
  the requested landscape `<W>x<H>` viewport — the mapping the brief supplied and this capture
  confirms in all four cases below.
- `wm size` / `wm density` / `dumpsys window displays` observed per size (the `cur=`/`app=` pair is
  the app viewport, and it equals the PNG size in all four cases):

| # | target landscape | `wm size` arg passed | observed `dumpsys` line (excerpt) | PNG |
|---|---|---|---|---|
| 1 | 1133x744 | `744x1133` | `base=744x1133 160dpi cur=1133x744 app=1133x744` | 1133x744 |
| 2 | 1080x810 | `810x1080` | `base=810x1080 160dpi cur=1080x810 app=1080x810` | 1080x810 |
| 3 | 1180x820 | `820x1180` | `base=820x1180 160dpi cur=1180x820 app=1180x820` | 1180x820 |
| 4 | 1366x1024 | `1024x1366` | `base=1024x1366 160dpi cur=1366x1024 app=1366x1024` | 1366x1024 |

- `wm size` printed `Physical size: 1600x2560` + `Override size: <arg>` and `wm density` printed
  `Physical density: 320` + `Override density: 160` at each of the four captures.
- The PNG px equals the requested landscape W x H exactly in all four captures (verified on the
  pulled file) and `app` equals the full display, so the pad occupies 100 % of the measured px,
  origin (0,0), no letterbox and no system bar (top row of every PNG is app content: `#9CD7FB` in
  record 1, `#96D5FB` in record 4).
- Theme: **Sunny** at all four sizes. Deciding samples (record 1, same at the other three): viewport
  corners `#7CC8F8`–`#99D4FA` (the sky gradient's edge values, `#7CC8F8` being §3 Sunny
  `background`; Night would be `#241C5E`), the centre `#C4EAFF` = §3 Sunny `backgroundGlow`. Night's
  star field is absent: the only `#FFD23F` pixels in the frame are the Y face button's fill (4,594 px,
  bbox x961–1038 y431–508 — that button alone), so no four-pointed sparkles are drawn; Sunny's
  polka dots (§4 `ToyBackground`) are present in the sky.
- Screenshots (only under the temp dir), each matching its record:
  `C:\Users\mrman\AppData\Local\Temp\ux-pilot\vf-matrix-tablets-t1-1133x744.png` (1133x744),
  `-t2-1080x810.png` (1080x810), `-t3-1180x820.png` (1180x820), `-t4-1366x1024.png` (1366x1024),
  plus `vf-matrix-tablets-native-restored.png` (2560x1600, the post-reset check).
  Accessibility geometry (`uiautomator dump`) is preserved as `ui-tablets-t1.xml` … `ui-tablets-t4.xml`
  in the same directory.
- Geometry below is from the pulled PNG (ink-outline and fill-colour pixel scans) plus
  `uiautomator dump` for touch bounds and a11y strings. Bounds are the outer edge of the drawn ink
  outline (the hard shadow shares that edge on the bottom-right of each pad shape, so it is not
  separable from the outline at this density; the `paper`/fill interior is quoted separately where
  it matters). Gaps are quoted as (next element's first px) − (previous element's last px) − 1, i.e.
  the number of px strictly between the two shapes.
- Contrast: WCAG 2.x, computed from the sampled foreground and the sampled background fill; token
  names from `docs/design/look-and-sound.md` §3. Where the fill behind a label is the sky gradient
  rather than one flat token, the pair is written `unmeasured` and the computed ratio against the
  sampled local fill is still given.

---

## Record 1 — 1133x744 (iPad mini)

**screen / form factor / theme / viewport px**
Controller pad / connect screen (the app's first screen after launch). Form factor: tablet logical
viewport, landscape, on the Pixel Tablet via `wm size 744x1133`. Theme: Sunny. Viewport:
**1133x744 px, landscape, 1133x744 dp** at `Override density: 160` (`dp = px / 1`); `Physical size:
1600x2560`; `Physical density: 320`; `base=744x1133 cur=1133x744 app=1133x744`, `ROTATION_270`. No
title, no back/close affordance, no system bars.

**elements in reading order, with pixel size and position** (x,y = top-left of the drawn shape; rows
grouped by their parent shape, top-to-bottom then left-to-right; px = dp):

| # | element | bounds px | w x h px (= dp) | measured content |
|---|---|---|---|---|
| 1 | Connection pill (outer) | x12–303, y6–49 | 292 x 44 | fill `#7CC8F8` = `background`; ink `#1E1646` outline 1–2 px; pill, r ≈ 22 px; touch 291 x 48 at [12,4]–[303,52] |
| 2 | State dot ring | x27–39, y22–33 | 13 x 12 | ink ring 3–4 px thick |
| 3 | State dot core | x31–35, y25–30 | 5 x 6 | `#FFB020` = `caution`; `caution` on `background` = 1.00:1 (the ink ring, not the fill, carries the mark) |
| 4 | Pill label | x54–286, y21–36 | 233 x 16 | ink on `background` = **9.12:1**; cap 13 px (y21–33); 1 line; 3 x U+002E at x146–156 + U+00B7 at x163–165 |
| 5 | Mode control (outer) | x677–980, y12–43 | 304 x 32 | unfilled — the sky shows through (`#9CD7FB`…`#A8DDFC`); ink outline 1–2 px; 1 px dividers at x778 and x879; touch 303 x 40 at [678,8]–[981,48] |
| 6 | Segment D-pad icon | x690–704, y20–35 | 15 x 16 | ink glyph, 15 x 16 |
| 7 | Segment D-pad label | x715–752, y21–36 | 38 x 16 | ink on `#9CD7FB` = 10.75:1 — `unmeasured` (sky gradient, no flat token); cap 13 px |
| 8 | Segment Gyro icon | x797–811, y20–35 | 15 x 16 | ink glyph, 15 x 16 |
| 9 | Segment Gyro label | x822–858, y21–35 | 37 x 15 | ink on `#97D5FB` = 10.51:1 — `unmeasured` (sky gradient); cap 13 px |
| 10 | Segment Sticks fill (selected) | x881–979, y13–42 | 99 x 30 | `#FFB020` = `caution`, 1 px inset inside the 101 x 32 segment; right end pill-rounded |
| 11 | Segment Sticks icon | x894–907, y23–32 | 14 x 10 | ink glyph, 14 x 10 |
| 12 | Segment Sticks label | x918–964, y21–33 | 47 x 13 | ink on `caution` = **9.13:1**; cap 13 px; a11y `selected=true` |
| 13 | Icon button 1 glyph (Stick settings) | x996–1013, y19–36 | 18 x 18 | ink glyph on `background`; touch 48 x 48 at [981,4]–[1029,52] |
| 14 | Icon button 2 glyph (Settings) | x1044–1061, y18–37 | 18 x 20 | ink glyph 18 x 20; touch 48 x 48 at [1029,4]–[1077,52] |
| 15 | Icon button 3 glyph (Diagnostics) | x1091–1110, y20–35 | 20 x 16 | ink glyph 20 x 16; touch 48 x 48 at [1077,4]–[1125,52] |
| 16 | LB pill (outer) | x15–147, y373–415 | 133 x 43 | `paper` interior 126 x 36 at x18–143, y377–412; ink outline 4 px; the hard shadow shares the bottom-right edge |
| 17 | LB label | x71–91, y388–401 | 21 x 14 | ink on `paper` = **15.53:1**; cap 14 px |
| 18 | RB pill (outer) | x986–1118, y373–415 | 133 x 43 | `paper` interior 126 x 36 at x989–1114, y377–412; ink outline 4 px |
| 19 | RB label | x1041–1062, y388–401 | 22 x 14 | ink on `paper` = **15.53:1**; cap 14 px |
| 20 | Left stick (disc + knob) | x14–201, y421–607 | 188 x 187 | `paper` disc 180 x 181 at x18–197, y424–604; ink 4 px; knob fill `#69A1D1` 72 x 72 at x73–144, y480–551 with a 3–4 px `#526994` rim (outer 80 x 80) |
| 21 | Y face button (outer) | x958–1042, y427–511 | 85 x 85 | fill `#FFD23F` = `faceY`/`star` 78 x 78 at x961–1038, y431–508; ink 4 px; letter 17 x 20 at x992–1008, y461–480, ink on `faceY` = **11.56:1** |
| 22 | X face button (outer) | x888–972, y497–581 | 85 x 85 | fill `#2E9BF0` = `faceX`/`player1` 78 x 78; ink 4 px; letter 17 x 19, ink on `faceX` = **5.61:1** |
| 23 | B face button (outer) | x1028–1111, y497–581 | 84 x 85 | fill `#FF4D5E` = `faceB`/`bad` 78 x 78; ink 4 px; letter 15 x 19, ink on `faceB` = **5.15:1** |
| 24 | Select pill (outer) | x495–563, y501–543 | 69 x 43 | `paper` interior 63 x 36 at x498–560, y504–539; ink 4 px |
| 25 | Select label | x508–550, y516–528 | 43 x 13 | ink on `paper` = **15.53:1**; cap 13 px |
| 26 | Start pill (outer) | x569–637, y501–543 | 69 x 43 | `paper` interior 62 x 36 at x572–634, y504–539; 5 px gap from Select |
| 27 | Start label | x582–624, y515–528 | 43 x 14 | ink on `paper` = **15.53:1**; cap 14 px |
| 28 | A face button (outer) | x958–1042, y567–651 | 85 x 85 | fill `#2FCB74` = `faceA`/`good` 78 x 78 at x961–1038, y570–647; ink 4 px; letter 19 x 20, ink on `faceA` = **7.88:1** |
| 29 | Right stick (disc + knob) | x758–907, y591–740 | 150 x 150 | `paper` disc 143 x 143 at x761–903, y595–737; ink 4 px; knob fill `#69A1D1` 57 x 55 at x805–861, y640–694 with rim (outer 64 x 65) |
| 30 | D-pad (outer) | x247–375, y613–741 | 129 x 129 | `paper` 121 x 121 at x251–371, y617–737; ink 4 px; arm 39 px; centre disc 23 x 23 `#B0A8AC` at x300–322, y666–688; four triangles `#8E8694` 13 x 11 (up), 13 x 12 (down), 11 x 13 (left, right) |

Layout distances at this size (all gaps per the definition above): pill left edge 12 px from the
viewport's first column, 6 px from the first row; pill → mode control 373 px horizontally
(32.9 % of W); mode control right edge 152 px from the last column; last icon glyph 22 px from the
last column; the three icon glyphs are 30 and 29 px apart; LB left edge 15 px; LB bottom → left disc
top 5 px; RB right edge 14 px from the last column; Select → Start 5 px; Select+Start span
x495–637, centred on the viewport's centre column 566; D-pad left edge 247 px; D-pad bottom 2 px
above the last row; right disc bottom 3 px above the last row; A bottom 92 px above the last row;
B right edge 21 px from the last column. Face-cluster centres: Y (999,469), X (930,538),
B (1069,538), A (999,608) — adjacent centres 97.6 px apart (dx 69, dy 69), opposite centres 139 px;
outline-to-outline gap between adjacent buttons 13 px. Empty sky between the top bar (y49) and LB
(y373): 323 px (43.4 % of H).

**primary action**
"Connecting... · tap to connect" connection pill — drawn 292 x 44 px (= dp) at (12,6), touch
291 x 48 dp at [12,4]–[303,52]. Contrast ink `#1E1646` on `#7CC8F8` = **9.12:1**
(`onBackground` on `background`). The pill's fill is exactly the `background` token, so the shape is
carried by its 1–2 px ink outline alone; the label has 17 px of unused slack to the pill's right
outline. Its state mark is a 13 x 12 px ink ring at (27,22) holding a 5 x 6 px `caution` core whose
own contrast against the pill fill is **1.00:1** — the ring, not the fill, is what is visible.

**secondary actions**
Mode segmented control: 304 x 32 px (= dp) drawn, touch 303 x 40 dp; 3 segments of 101 px each, the
third ("Sticks") selected with a 99 x 30 px `caution` fill inset 1 px. Three icon buttons, each a
48 x 48 dp touch target, glyphs 18 x 18, 18 x 20 and 20 x 16 px. Pad inputs at rest, drawn sizes:
LB 133 x 43, RB 133 x 43, Select 69 x 43, Start 69 x 43, left stick 188 x 187 disc with a 72 x 72
knob, right stick 150 x 150 disc with a 57 x 55 knob, D-pad 129 x 129 with a 39 px arm, A/B/X/Y
84–85 px square. Only 7 nodes publish a touch target (the pill, the 3 mode segments, the 3 icon
buttons); the a11y tree marks LB, RB, Select, Start, the sticks, the D-pad and the face buttons
`clickable=false` (one node "A, B, X, Y" covers the whole diamond).

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels. Measured slack: pill label 233 px inside a 292 px pill
(17 px to the right outline); the segment content is 71 px at its max of a 101 px segment (right
inset 16 px in the selected segment, 26 px in the first); LB/RB labels 21–22 px in 126 px
interiors. Ink heights:
13–14 px cap on the pill, the three segment labels, LB, RB, Select and Start; 19–20 px cap on the
four face letters. All labels are one line.

**states covered, and states missing**
Covered: connecting/waiting (label "Connecting... · tap to connect" plus a `caution` dot in an ink
ring); mode selection with one of three items marked selected (`selected=true` for "Sticks"); all 11
pad inputs drawn at rest.
Missing (absent, not observed in this capture): connected state (no `good`-coloured dot, no host or
session line); disconnected/error state (no `bad` dot, no error text); dropped-link state; pressed,
focused and disabled control states; any empty state. The pill's a11y string is
"Connecting… · tap to connect" (U+2026) while the drawn string ends "Connecting..." with three
U+002E glyphs — the two differ in the ellipsis character, not in the state word.

**cross-screen inconsistencies versus the other screens**
1. Ink outline weight is not one value on this screen: 4 px on LB, RB, Select, Start, both stick
   discs, the D-pad and A/B/X/Y, but 1–2 px on the connection pill and the mode control. §3 states
   "outline width 3 px on menus"; the measured weights are 4 px and 1–2 px.
2. Two stick discs of different size: 188 x 187 against 150 x 150 (38 px, 20.2 % apart), knobs
   80 x 80 against 64 x 65 outer.
3. Three icon glyphs of three sizes in one row: 18 x 18, 18 x 20, 20 x 16 (4 px spread in height,
   2 px in width).
4. The three segment contents are not placed at one inset: content left insets 12, 18, 14 px and
   right insets 26, 21, 16 px against their 101 px segments.
5. D-pad triangles are 1 px asymmetric: 13 x 11 (up), 13 x 12 (down), 11 x 13 (left), 11 x 13
   (right).
6. Neutrals outside §3: `#69A1D1` (both stick knobs), `#526994` (their 3–4 px rim), `#B0A8AC`
   (D-pad centre disc), `#8E8694` (D-pad triangles) — contrast against their surroundings
   `unmeasured` (no token pair); computed ratios are in the summary at the end.
7. The D-pad's hard shadow is cut by the viewport edge: its ink bottom is at y741, 2 px above the
   last row, while the shadow offset is 4 px down; rows 742–743 read `#6B91BB` at x310, i.e. shadow
   reaching the final row.
8. Against the pad body, the top bar carries all of the screen's text (the pill label, 3 segment
   labels) while the 11 inputs carry 19 characters in total (LB, RB, Select, Start, A, B, X, Y); the
   screen has no title and no back affordance, unlike the app's Settings screen captured in
   `vf-tab-01`.

**flow stage (spec §1)**: 1 (launch / first run) and 13 (re-entry after a drop) are represented only
by the connection pill and its `caution` dot; 8 (in-round controls) by the pad body. Stages 2–7 and
9–12 are not represented on this device's screen (host setup and game selection live on the TV).

---

## Record 2 — 1080x810 (iPad 9 / 10.2 in)

**screen / form factor / theme / viewport px**
Controller pad / connect screen, landscape, on the Pixel Tablet via `wm size 810x1080`. Theme:
Sunny. Viewport: **1080x810 px, landscape, 1080x810 dp** at `Override density: 160`
(`dp = px / 1`); `Physical size: 1600x2560`; `base=810x1080 cur=1080x810 app=1080x810`,
`ROTATION_270`. No title, no back/close affordance, no system bars.

**elements in reading order, with pixel size and position**
All fills, ink weights, label boxes, type heights and contrast ratios are the measured values in
record 1 — every element has the same w x h here (0 px difference on all 30 boxes); only the
positions move, by +66 px in y for the pad and by −53 px in x for the right-anchored chrome.

| # | element | bounds px | w x h px (= dp) |
|---|---|---|---|
| 1 | Connection pill (outer) | x12–303, y6–49 | 292 x 44 |
| 2 | State dot ring | x27–39, y22–33 | 13 x 12 |
| 3 | State dot core | x31–35, y25–30 | 5 x 6 |
| 4 | Pill label | x54–286, y21–36 | 233 x 16 |
| 5 | Mode control (outer) | x624–927, y12–43 | 304 x 32 |
| 6 | Segment D-pad icon | x637–651, y20–35 | 15 x 16 |
| 7 | Segment D-pad label | x662–699, y21–36 | 38 x 16 |
| 8 | Segment Gyro icon | x744–758, y20–35 | 15 x 16 |
| 9 | Segment Gyro label | x769–805, y21–35 | 37 x 15 |
| 10 | Segment Sticks fill (selected) | x828–926, y13–42 | 99 x 30 |
| 11 | Segment Sticks icon | x841–854, y23–32 | 14 x 10 |
| 12 | Segment Sticks label | x865–911, y21–33 | 47 x 13 |
| 13 | Icon button 1 glyph (Stick settings) | x943–960, y19–36 | 18 x 18 |
| 14 | Icon button 2 glyph (Settings) | x991–1008, y18–37 | 18 x 20 |
| 15 | Icon button 3 glyph (Diagnostics) | x1038–1057, y20–35 | 20 x 16 |
| 16 | LB pill (outer) | x15–147, y439–481 | 133 x 43 |
| 17 | LB label | x71–91, y454–467 | 21 x 14 |
| 18 | RB pill (outer) | x933–1065, y439–481 | 133 x 43 |
| 19 | RB label | x988–1009, y454–467 | 22 x 14 |
| 20 | Left stick (disc + knob) | x14–201, y487–673 | 188 x 187 |
| 21 | Y face button (outer) | x905–989, y493–577 | 85 x 85 |
| 22 | X face button (outer) | x835–919, y563–647 | 85 x 85 |
| 23 | B face button (outer) | x975–1058, y563–647 | 84 x 85 |
| 24 | Select pill (outer) | x469–537, y567–609 | 69 x 43 |
| 25 | Select label | x482–524, y582–594 | 43 x 13 |
| 26 | Start pill (outer) | x543–611, y567–609 | 69 x 43 |
| 27 | Start label | x556–598, y581–594 | 43 x 14 |
| 28 | A face button (outer) | x905–989, y633–717 | 85 x 85 |
| 29 | Right stick (disc + knob) | x705–854, y657–806 | 150 x 150 |
| 30 | D-pad (outer) | x247–375, y679–807 | 129 x 129 |

Layout distances at this size: pill → mode control 320 px horizontally (29.6 % of W); empty sky
between the top bar (y49) and LB (y439): 389 px (48.0 % of H); D-pad bottom 2 px and right disc
bottom 3 px above the last row; B right edge 21 px from the last column; Select+Start span
x469–611, centred on 539.5. Face-cluster centres Y (946,535), X (877,604), B (1016,604), A (946,674).

**primary action**
"Connecting... · tap to connect" pill — 292 x 44 px (= dp) at (12,6), touch 291 x 48 dp;
ink on `background` = **9.12:1**. 17 px of unused slack to the right outline (identical to record 1).

**secondary actions**
Mode control 304 x 32 px at (624,12), touch 303 x 40 dp, 3 x 101 px segments, "Sticks" selected with
a 99 x 30 px `caution` fill; three 48 x 48 dp icon buttons with 18 x 18, 18 x 20 and 20 x 16 px
glyphs; LB/RB 133 x 43, Select/Start 69 x 43, left stick 188 x 187 / 72 x 72 knob, right stick
150 x 150 / 57 x 55 knob, D-pad 129 x 129 / 39 px arm, A/B/X/Y 84–85 px.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels — the text is pixel-identical to record 1 (same 233 px
pill label, same 13–14 px caps, same 19–20 px face letters), so the 810 px height and 1080 px width
change no line.

**states covered, and states missing**
Identical to record 1: connecting/waiting, mode selection, 11 inputs at rest covered;
connected, error/disconnected, dropped link, pressed/focused/disabled and empty states absent; the
a11y "…" (U+2026) versus drawn "..." (3 x U+002E) difference persists.

**cross-screen inconsistencies versus the other screens**
The eight measured inconsistencies of record 1 hold unchanged — the shape sizes and the outline
weight split (4 px against 1–2 px) are identical at this size. What changes with the viewport: the
pill → mode control gap is 320 px (373 px at 1133x744), and the empty sky band between the top bar
and LB is 389 px (323 px at 1133x744).

**flow stage (spec §1)**: 1, 13 (pill + dot); 8 (pad body); 2–7 and 9–12 absent.

---

## Record 3 — 1180x820 (iPad 10 / 11 in / Air 11 in)

**screen / form factor / theme / viewport px**
Controller pad / connect screen, landscape, on the Pixel Tablet via `wm size 820x1180`. Theme:
Sunny. Viewport: **1180x820 px, landscape, 1180x820 dp** at `Override density: 160`
(`dp = px / 1`); `Physical size: 1600x2560`; `base=820x1180 cur=1180x820 app=1180x820`,
`ROTATION_270`. No title, no back/close affordance, no system bars.

**elements in reading order, with pixel size and position**
All fills, ink weights, label boxes, type heights and contrast ratios are the measured values in
record 1; every element keeps the same w x h (0 px difference). Positions move by +76 px in y for
the pad and by +47 px in x for the right-anchored chrome.

| # | element | bounds px | w x h px (= dp) |
|---|---|---|---|
| 1 | Connection pill (outer) | x12–303, y6–49 | 292 x 44 |
| 2 | State dot ring | x27–39, y22–33 | 13 x 12 |
| 3 | State dot core | x31–35, y25–30 | 5 x 6 |
| 4 | Pill label | x54–286, y21–36 | 233 x 16 |
| 5 | Mode control (outer) | x724–1027, y12–43 | 304 x 32 |
| 6 | Segment D-pad icon | x737–751, y20–35 | 15 x 16 |
| 7 | Segment D-pad label | x762–799, y21–36 | 38 x 16 |
| 8 | Segment Gyro icon | x844–858, y20–35 | 15 x 16 |
| 9 | Segment Gyro label | x869–905, y21–35 | 37 x 15 |
| 10 | Segment Sticks fill (selected) | x928–1026, y13–42 | 99 x 30 |
| 11 | Segment Sticks icon | x941–954, y23–32 | 14 x 10 |
| 12 | Segment Sticks label | x965–1011, y21–33 | 47 x 13 |
| 13 | Icon button 1 glyph (Stick settings) | x1043–1060, y19–36 | 18 x 18 |
| 14 | Icon button 2 glyph (Settings) | x1091–1108, y18–37 | 18 x 20 |
| 15 | Icon button 3 glyph (Diagnostics) | x1138–1157, y20–35 | 20 x 16 |
| 16 | LB pill (outer) | x15–147, y449–491 | 133 x 43 |
| 17 | LB label | x71–91, y464–477 | 21 x 14 |
| 18 | RB pill (outer) | x1033–1165, y449–491 | 133 x 43 |
| 19 | RB label | x1088–1109, y464–477 | 22 x 14 |
| 20 | Left stick (disc + knob) | x14–201, y497–683 | 188 x 187 |
| 21 | Y face button (outer) | x1005–1089, y503–587 | 85 x 85 |
| 22 | X face button (outer) | x935–1019, y573–657 | 85 x 85 |
| 23 | B face button (outer) | x1075–1158, y573–657 | 84 x 85 |
| 24 | Select pill (outer) | x519–587, y577–619 | 69 x 43 |
| 25 | Select label | x532–574, y592–604 | 43 x 13 |
| 26 | Start pill (outer) | x593–661, y577–619 | 69 x 43 |
| 27 | Start label | x606–648, y591–604 | 43 x 14 |
| 28 | A face button (outer) | x1005–1089, y643–727 | 85 x 85 |
| 29 | Right stick (disc + knob) | x805–954, y667–816 | 150 x 150 |
| 30 | D-pad (outer) | x247–375, y689–817 | 129 x 129 |

Layout distances at this size: pill → mode control 420 px horizontally (35.6 % of W); empty sky
between the top bar (y49) and LB (y449): 399 px (48.7 % of H); D-pad bottom 2 px and right disc
bottom 3 px above the last row; B right edge 21 px from the last column; Select+Start span
x519–661, centred on 589.5. Face-cluster centres Y (1046,545), X (977,614), B (1116,614),
A (1046,684).

**primary action**
"Connecting... · tap to connect" pill — 292 x 44 px (= dp) at (12,6), touch 291 x 48 dp;
ink on `background` = **9.12:1**; 17 px of unused slack to the right outline.

**secondary actions**
Mode control 304 x 32 px at (724,12), touch 303 x 40 dp, 3 x 101 px segments, "Sticks" selected with
a 99 x 30 px `caution` fill; three 48 x 48 dp icon buttons with 18 x 18, 18 x 20 and 20 x 16 px
glyphs; LB/RB 133 x 43, Select/Start 69 x 43, left stick 188 x 187 / 72 x 72 knob, right stick
150 x 150 / 57 x 55 knob, D-pad 129 x 129 / 39 px arm, A/B/X/Y 84–85 px.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels; the text boxes are pixel-identical to record 1.

**states covered, and states missing**
Identical to record 1: connecting/waiting, mode selection and 11 inputs at rest covered; connected,
error/disconnected, dropped link, pressed/focused/disabled and empty states absent; a11y "…" versus
drawn "..." mismatch persists.

**cross-screen inconsistencies versus the other screens**
Same eight as record 1, unchanged in size. Viewport-dependent change: the pill → mode control gap
is 420 px (35.6 % of W) and the top-bar-to-LB band is 399 px (48.7 % of H).

**flow stage (spec §1)**: 1, 13 (pill + dot); 8 (pad body); 2–7 and 9–12 absent.

---

## Record 4 — 1366x1024 (iPad 13 in / 12.9 in)

**screen / form factor / theme / viewport px**
Controller pad / connect screen, landscape, on the Pixel Tablet via `wm size 1024x1366`. Theme:
Sunny. Viewport: **1366x1024 px, landscape, 1366x1024 dp** at `Override density: 160`
(`dp = px / 1`); `Physical size: 1600x2560`; `base=1024x1366 cur=1366x1024 app=1366x1024`,
`ROTATION_270`. No title, no back/close affordance, no system bars.

**elements in reading order, with pixel size and position**
All fills, ink weights, label boxes, type heights and contrast ratios are the measured values in
record 1; every element keeps the same w x h (0 px difference). Positions move by +280 px in y for
the pad and by +233 px in x for the right-anchored chrome.

| # | element | bounds px | w x h px (= dp) |
|---|---|---|---|
| 1 | Connection pill (outer) | x12–303, y6–49 | 292 x 44 |
| 2 | State dot ring | x27–39, y22–33 | 13 x 12 |
| 3 | State dot core | x31–35, y25–30 | 5 x 6 |
| 4 | Pill label | x54–286, y21–36 | 233 x 16 |
| 5 | Mode control (outer) | x910–1213, y12–43 | 304 x 32 |
| 6 | Segment D-pad icon | x923–937, y20–35 | 15 x 16 |
| 7 | Segment D-pad label | x948–985, y21–36 | 38 x 16 |
| 8 | Segment Gyro icon | x1030–1044, y20–35 | 15 x 16 |
| 9 | Segment Gyro label | x1055–1091, y21–35 | 37 x 15 |
| 10 | Segment Sticks fill (selected) | x1114–1212, y13–42 | 99 x 30 |
| 11 | Segment Sticks icon | x1127–1140, y23–32 | 14 x 10 |
| 12 | Segment Sticks label | x1151–1197, y21–33 | 47 x 13 |
| 13 | Icon button 1 glyph (Stick settings) | x1229–1246, y19–36 | 18 x 18 |
| 14 | Icon button 2 glyph (Settings) | x1277–1294, y18–37 | 18 x 20 |
| 15 | Icon button 3 glyph (Diagnostics) | x1324–1343, y20–35 | 20 x 16 |
| 16 | LB pill (outer) | x15–147, y653–695 | 133 x 43 |
| 17 | LB label | x71–91, y668–681 | 21 x 14 |
| 18 | RB pill (outer) | x1219–1351, y653–695 | 133 x 43 |
| 19 | RB label | x1274–1295, y668–681 | 22 x 14 |
| 20 | Left stick (disc + knob) | x14–201, y701–887 | 188 x 187 |
| 21 | Y face button (outer) | x1191–1275, y707–791 | 85 x 85 |
| 22 | X face button (outer) | x1121–1205, y777–861 | 85 x 85 |
| 23 | B face button (outer) | x1261–1344, y777–861 | 84 x 85 |
| 24 | Select pill (outer) | x612–680, y781–823 | 69 x 43 |
| 25 | Select label | x625–667, y796–808 | 43 x 13 |
| 26 | Start pill (outer) | x686–754, y781–823 | 69 x 43 |
| 27 | Start label | x699–741, y795–808 | 43 x 14 |
| 28 | A face button (outer) | x1191–1275, y847–931 | 85 x 85 |
| 29 | Right stick (disc + knob) | x991–1140, y871–1020 | 150 x 150 |
| 30 | D-pad (outer) | x247–375, y893–1021 | 129 x 129 |

Layout distances at this size: pill → mode control 606 px horizontally (44.4 % of W, its max of the
four); empty sky between the top bar (y49) and LB (y653): 603 px (58.9 % of H); D-pad bottom
2 px and right disc bottom 3 px above the last row; B right edge 21 px from the last column;
Select+Start span x612–754, centred on 682.5. Face-cluster centres Y (1232,749), X (1163,818),
B (1302,818), A (1232,888).

**primary action**
"Connecting... · tap to connect" pill — 292 x 44 px (= dp) at (12,6), touch 291 x 48 dp;
ink on `background` = **9.12:1**; 17 px of unused slack to the right outline — the 1366 px width buys
the primary action no size.

**secondary actions**
Mode control 304 x 32 px at (910,12), touch 303 x 40 dp, 3 x 101 px segments, "Sticks" selected with
a 99 x 30 px `caution` fill; three 48 x 48 dp icon buttons with 18 x 18, 18 x 20 and 20 x 16 px
glyphs; LB/RB 133 x 43, Select/Start 69 x 43, left stick 188 x 187 / 72 x 72 knob, right stick
150 x 150 / 57 x 55 knob, D-pad 129 x 129 / 39 px arm, A/B/X/Y 84–85 px.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels; text boxes pixel-identical to record 1.

**states covered, and states missing**
Identical to record 1: connecting/waiting, mode selection and 11 inputs at rest covered; connected,
error/disconnected, dropped link, pressed/focused/disabled and empty states absent; a11y "…" versus
drawn "..." mismatch persists.

**cross-screen inconsistencies versus the other screens**
Same eight as record 1, unchanged in size. The 1366x1024 viewport (max area of the four) keeps the
pad at exactly the 1133x744 dp sizes while the empty middle grows: the pill → mode control gap is 606 px (44.4 % of
W) and the top-bar-to-LB band is 603 px (58.9 % of H).

**flow stage (spec §1)**: 1, 13 (pill + dot); 8 (pad body); 2–7 and 9–12 absent.

---

## Cross-size matrix (all figures px = dp; density 160)

Positions are each element's top-left; its size is the value in the second column and is the same at
all four sizes (measured: 0 px difference on all 30 boxes).

| element | w x h px (= dp) | 1133x744 | 1080x810 | 1180x820 | 1366x1024 |
|---|---|---|---|---|---|
| Connection pill (outer) | 292 x 44 | 12,6 | 12,6 | 12,6 | 12,6 |
| State dot ring | 13 x 12 | 27,22 | 27,22 | 27,22 | 27,22 |
| State dot core | 5 x 6 | 31,25 | 31,25 | 31,25 | 31,25 |
| Pill label | 233 x 16 | 54,21 | 54,21 | 54,21 | 54,21 |
| Mode control (outer) | 304 x 32 | 677,12 | 624,12 | 724,12 | 910,12 |
| Segment D-pad icon | 15 x 16 | 690,20 | 637,20 | 737,20 | 923,20 |
| Segment D-pad label | 38 x 16 | 715,21 | 662,21 | 762,21 | 948,21 |
| Segment Gyro icon | 15 x 16 | 797,20 | 744,20 | 844,20 | 1030,20 |
| Segment Gyro label | 37 x 15 | 822,21 | 769,21 | 869,21 | 1055,21 |
| Segment Sticks fill (selected) | 99 x 30 | 881,13 | 828,13 | 928,13 | 1114,13 |
| Segment Sticks icon | 14 x 10 | 894,23 | 841,23 | 941,23 | 1127,23 |
| Segment Sticks label | 47 x 13 | 918,21 | 865,21 | 965,21 | 1151,21 |
| Icon button 1 glyph (Stick settings) | 18 x 18 | 996,19 | 943,19 | 1043,19 | 1229,19 |
| Icon button 2 glyph (Settings) | 18 x 20 | 1044,18 | 991,18 | 1091,18 | 1277,18 |
| Icon button 3 glyph (Diagnostics) | 20 x 16 | 1091,20 | 1038,20 | 1138,20 | 1324,20 |
| LB pill (outer) | 133 x 43 | 15,373 | 15,439 | 15,449 | 15,653 |
| LB label | 21 x 14 | 71,388 | 71,454 | 71,464 | 71,668 |
| RB pill (outer) | 133 x 43 | 986,373 | 933,439 | 1033,449 | 1219,653 |
| RB label | 22 x 14 | 1041,388 | 988,454 | 1088,464 | 1274,668 |
| Left stick (disc + knob) | 188 x 187 | 14,421 | 14,487 | 14,497 | 14,701 |
| Y face button (outer) | 85 x 85 | 958,427 | 905,493 | 1005,503 | 1191,707 |
| X face button (outer) | 85 x 85 | 888,497 | 835,563 | 935,573 | 1121,777 |
| B face button (outer) | 84 x 85 | 1028,497 | 975,563 | 1075,573 | 1261,777 |
| Select pill (outer) | 69 x 43 | 495,501 | 469,567 | 519,577 | 612,781 |
| Select label | 43 x 13 | 508,516 | 482,582 | 532,592 | 625,796 |
| Start pill (outer) | 69 x 43 | 569,501 | 543,567 | 593,577 | 686,781 |
| Start label | 43 x 14 | 582,515 | 556,581 | 606,591 | 699,795 |
| A face button (outer) | 85 x 85 | 958,567 | 905,633 | 1005,643 | 1191,847 |
| Right stick (disc + knob) | 150 x 150 | 758,591 | 705,657 | 805,667 | 991,871 |
| D-pad (outer) | 129 x 129 | 247,613 | 247,679 | 247,689 | 247,893 |

**Derived from the matrix.** The pad is a fixed-dp layout with four anchor groups, not a viewport
scaled layout: (a) left-anchored — pill, dot, label at x12–27, LB at x15, left disc at x14, D-pad at
x247; (b) right-anchored — mode control right edge at W−153, third icon glyph right edge at W−23,
RB right edge at W−15, right disc right edge at W−226, B right edge at W−22; (c) bottom-anchored —
LB top at H−371, left disc top at H−320, Select/Start top at H−243, right disc top at H−153, D-pad
top at H−131 and D-pad bottom at H−3, right disc bottom at H−4; (d) centred — the Select/Start pair
(69 + 5 gap + 69 = 143 px) is centred on the centre column at all four sizes: measured spans
x495–637, x469–611, x519–661, x612–754, i.e. centres 566 / 540 / 590 / 683 against (W−1)/2 =
566 / 539.5 / 589.5 / 682.5. The pad's overall footprint is therefore (W−35) x 369 px:
1098 x 369 at 1133x744 (96.9 % x 49.6 % of the viewport) and
1331 x 369 at 1366x1024 (97.4 % x 36.0 %) — the 65.9 % growth in viewport area (1133x744 →
1366x1024) is absorbed entirely by the empty middle, while every control keeps its px size.

Cross-check against the same screen captured at native density 354 by `vf-tab-01` (same device,
same screen, dpi-independent comparison): pill 291.5 x 43.4 dp, D-pad 128.4 dp, discs 187.1 and
150.5 dp, face buttons 84.5–85 dp, Select 69.2 dp — each within 1 dp of this matrix's px values,
confirming the pad is laid out in dp with no tablet-size scale factor. `vf-matrix-phones` measured
the same elements from 57 to 188 px over 360–430 px heights, so the pad's shrink-to-fit engages
below 430 px height and is at its 1:1 size from there up; at no size in this matrix does it scale.

## `unmeasured` / `absent` summary

- `unmeasured`: the D-pad and Gyro segment labels at all four sizes — the segment fill is the sky
  gradient (sampled `#97D5FB`…`#9CD7FB`), not one flat §3 token, so no token pair names them; the
  computed ratios against the sampled local fills are 10.51:1 and 10.75:1.
- `unmeasured`: stick knob fill `#69A1D1` (2.57:1 on `paper`; 2.00:1 against its own `#526994` rim)
  and the rim itself — neither is in §3, and both are control surfaces, not text.
- `unmeasured`: D-pad centre disc `#B0A8AC` (2.16:1 on `paper`) and D-pad triangles `#8E8694`
  (3.26:1 on `paper`) — not in §3.
- Below the 3:1 non-text threshold, measured: the state dot's `caution` core on the pill's
  `background` fill = **1.00:1**, so the dot reads only by its ink ring (the ring itself is `ink` on
  `background` = 9.12:1); the D-pad centre disc 2.16:1 and the triangles 3.26:1 against `paper`.
- `absent` at all four sizes: connected state (no `good` dot, no host/session line), error /
  disconnected state, dropped-link state, pressed, focused and disabled control states, and any
  empty state. Only "connecting" is drawn.
- `absent`: any touch target on LB, RB, Select, Start, both sticks, the D-pad and A/B/X/Y — the a11y
  tree marks them `clickable=false`; the face diamond publishes one 233 x 233 px node "A, B, X, Y".
- `absent`: a title, a back/close affordance and any navigation on this screen.
- Sub-48 dp touch targets: the 3 mode segments are 101 x 40 dp (40 dp high, under the 48 dp
  minimum). The pill publishes 291 x 48 dp and each icon button 48 x 48 dp.
- Inconsistency carried by the app itself: the pill's drawn string uses three U+002E while its a11y
  string uses U+2026, at all four sizes. (Unlike the phone matrix's 667x375 capture, the state word
  itself matches here: both read "Connecting".)
- Failed size: **none**. All four target sizes were captured at exactly the requested PNG px, with
  no crop, no letterbox, no system bar and no clipped element other than the D-pad's 4 px shadow
  noted in record 1.

## Display reset (verified after the last capture)

- `wm size reset` → `wm size` printed only `Physical size: 1600x2560` (no override size).
- `wm density reset` → `wm density` printed `Physical density: 320`; the reset also removed the
  tablet's baseline `Override density: 354`, so **`wm density 354` was re-issued** to restore the
  state the device was found in. Final `wm density` output: `Physical density: 320` /
  `Override density: 354`.
- Final `dumpsys window displays`: `init=1600x2560 320dpi … base=1600x2560 354dpi cur=2560x1600
  app=2560x1600` — i.e. the native 1600x2560 panel at density 354 giving the 2560x1600 landscape
  viewport.
- The app was force-stopped, relaunched once at native and captured to
  `vf-matrix-tablets-native-restored.png` (2560x1600) as the post-reset check; that PNG is
  byte-identical (SHA-256 `726C898312E1847547C9A623455A07C5242CDE082EDDACBBBD0377743C237C2D`) to
  `vf-tab-01-pad.png`, the native-density capture the earlier worker took, so the restored state
  reproduces the state the device was found in at the pixel level. No rotation setting, no other
  device setting and no TV state was touched.
