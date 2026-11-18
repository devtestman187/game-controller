# vf-matrix-phones — controller pad / connect screen, Pixel Tablet, 6 phone logical sizes

Worker: `vf-matrix-phones`. Scope: ONE screen (the controller's pad / connect screen, the app's
first screen after launch) of `com.thumbparty.app` on the Pixel Tablet
(`adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp`) at 6 target phone logical sizes in landscape,
via the `wm size` / `wm density` override. No code, test, protocol, map or dependency was touched.
The TV (`192.168.1.100:5555`) was not contacted. Look was left on Auto and rendered Sunny.

## Capture facts (measured around each screenshot)

- App: `com.thumbparty.app`, `am force-stop` then `am start -n com.thumbparty.app/.MainActivity`,
  screenshot taken 4.0 s after launch, `shell screencap -p /sdcard/<n>.png` then `pull` (no shell
  redirection). Each capture was preceded by `wm size` + `wm density 160` + force-stop + launch, so
  every screenshot is a fresh layout of the pad screen.
- `wm density 160` on every capture ⇒ `dp = px / (160/160) = px`. **Every px figure in this file is
  also the dp figure.** Divisor stated per record as `dp = px / 1`.
- Orientation: landscape. The display is fixed at `mDisplayRotation=ROTATION_270`
  (`settings get system accelerometer_rotation` → `1`, `user_rotation` → `0`, yet every
  `dumpsys window displays` line carries `mRotation=ROTATION_270`), so with the override the
  panel's natural orientation is the *base* size and the app sees the swapped, landscape viewport.
- `dumpsys window displays` observed per size (the `cur=`/`app=` pair is the app viewport, which
  equals the PNG size in all six cases):

| # | target | `wm size` base passed | observed `dumpsys` line (excerpt) | PNG |
|---|---|---|---|---|
| 1 | 667x375 | `375x667` | `base=375x667 160dpi cur=667x375 app=667x375` | 667x375 |
| 2 | 800x360 | `360x800` | `base=360x800 160dpi cur=800x360 app=800x360` | 800x360 |
| 3 | 844x390 | `390x844` | `base=390x844 160dpi cur=844x390 app=844x390` | 844x390 |
| 4 | 852x393 | `393x852` | `base=393x852 160dpi cur=852x393 app=852x393` | 852x393 |
| 5 | 932x430 | `430x932` | `base=430x932 160dpi cur=932x430 app=932x430` | 932x430 |
| 6 | 915x412 | `412x915` | `base=412x915 160dpi cur=915x412 app=915x412` | 915x412 |

- **Protocol deviation, measured.** The brief's literal command `wm size WxH` (landscape WxH) yields
  the *portrait* viewport H×W on this tablet, because the fixed ROTATION_270 swaps the base size.
  Worked example, size 1: `wm size 667x375` → `base=667x375 cur=375x667 … sw375dp h667dp port`, PNG
  375x667, and the app then draws its "Make the window bigger" gate instead of the pad (evidence:
  `gate-portrait-375x667.png`, measured below). Passing `wm size 375x667` → `base=375x667
  cur=667x375 … land`, PNG 667x375, pad screen. All six records below therefore use `wm size HxW`
  to obtain the requested landscape `WxH` viewport; no rotation setting was changed.
- `wm size` / `wm density` output as printed for the first override (worked example, size 1):
  `Physical size: 1600x2560` / `Override size: 667x375`; `Physical density: 320` / `Override
  density: 160`.
- No system bars in any capture: `app` equals the full display, so the pad occupies 100 % of the
  measured px (`0,0` to `W-1,H-1`). The PNG px equals the requested WxH in all six captures — no
  letterbox and no bar — so no region offset is needed and every measurement below is in the app's
  full viewport with origin (0,0).
- Screenshots (only under the temp dir):
  `vf-matrix-phones-m1-667x375.png` (667x375), `-m2-800x360.png` (800x360),
  `-m3-844x390.png` (844x390), `-m4-852x393.png` (852x393), `-m5-932x430.png` (932x430),
  `-m6-915x412.png` (915x412), and the gate evidence `gate-portrait-375x667.png` (375x667).
  Accessibility geometry (`uiautomator dump`) is preserved as `ui-m1-667x375.xml` … `ui-m6-915x412.xml`
  in the same directory. Gaps between shapes are quoted edge-to-edge (next shape's first px minus
  the previous shape's last px).
- Geometry below is from the pulled PNG (ink-outline / fill-colour pixel scans) plus
  `uiautomator dump` for touch bounds and for the pill's a11y string. Touch bounds are quoted as
  "touch" and are larger than the drawn shapes.
- Contrast: WCAG 2.x, computed from the sampled foreground and the sampled background fill; token
  names from `docs/design/look-and-sound.md` §3. Where the fill behind text is the sky gradient
  rather than one flat token, the pair is written `unmeasured` and the computed ratio against the
  sampled local fill is still given.
- Theme: **Sunny** at all six sizes. Deciding samples: the connection pill's fill reads exactly
  `#7CC8F8` = §3 Sunny `background` (Night would be `#241C5E`), and the glow centre reads exactly
  `#C4EAFF` = §3 `backgroundGlow`. Viewport corners read `#80CAF8` (size 1), `#82CBF9`
  (sizes 3–5), `#83CBF9` (sizes 2, 6) — the glow gradient. Sunny polka dots are drawn; the Night
  star field is absent (the only `#FFD23F` outside the `Y` button is absent).

---

## Record 1 — 667x375 (iPhone SE class)

**screen / form factor / theme / viewport px**
Controller pad / connect screen (the app's first screen after launch). Form factor: phone logical
viewport, landscape, on the Pixel Tablet via override. Theme: Sunny. Viewport: **667x375 px,
landscape, 667x375 dp** at density 160 (`dp = px / 1`); `Physical size: 1600x2560` /
`Override size: 375x667`; `Physical density: 320` / `Override density: 160`;
`base=375x667 cur=667x375 app=667x375`, `ROTATION_270`. No title, no back/close affordance, no
system bars.

**elements in reading order, with pixel size and position** (x,y = top-left of the drawn shape;
px = dp):

| # | element | bounds px | w x h | fill / outline / type |
|---|---|---|---|---|
| 1 | Connection pill (button) | x12–286, y6–49 | 275 x 44 | fill `#7CC8F8` = `background`; ink outline 1 px solid at x12 / x286 + 1 px AA on the horizontal edges (`#4F709F`, `#4D6F9F`); pill, r ≈ 22 |
| 2 | State dot | x28–38, y22–33 | 11 x 12 | ink `#1E1646` ring ≈2 px; core `#FFB020` = `caution`, 5 x 6 at x31–35, y25–30 |
| 3 | Label "Connecting... · tap to con…" | x56–263, y21–36 | 208 x 16 | ink on `background` = **9.12:1**; 1 line; cap 13 px; **truncated** |
| 4 | Mode control container | x295–514, y12–43 | 220 x 32 | unfilled — the sky shows through (`#A5DCFC` … `#A9DDFC`); ink outline ≈1.5 px; 1 px dividers at x368, x441 |
| 5 | Segment "D-pad" | x295–368 | 73 x 32 (touch 73 x 40) | unfilled; label x308–355, y21–36 = 48 x 16; ink on `#A5DCFC` = 11.32:1 — **`unmeasured`** (gradient, no flat token) |
| 6 | Segment "Gyro" | x368–441 | 73 x 32 (touch 74 x 40) | unfilled; label x387–422, y21–36 = 36 x 16; ink on `#A3DAFC` = 11.12:1 — **`unmeasured`** |
| 7 | Segment "Sticks" — selected | x441–514 | 73 x 32 (touch 73 x 40) | fill `#FFB020` = `caution`; label x455–501, y21–33 = 47 x 13; ink on `caution` = **9.13:1**; a11y `selected=true` |
| 8 | Stick-settings icon button | glyph x530–547, y19–36 | glyph 18 x 18; touch 48 x 48 at (515,4) | ink glyph on `background` |
| 9 | Settings icon button | glyph x578–595, y18–37 | glyph 18 x 20; touch 48 x 48 at (563,4) | ink glyph |
| 10 | Diagnostics icon button | glyph x625–644, y20–35 | glyph 20 x 16; touch 48 x 48 at (611,4) | ink glyph; touch ends x659 = 8 px from the viewport edge |
| 11 | "LB" pill | x15–138, y59–101 | 124 x 43 | `paper` `#FFF6E3`; ink outline 3 px (2 px solid `#1E1646` at y59–60 and y99–100 + 1 px AA each side); label x66–87, y73–86 = 22 x 14, ink on `paper` = **15.53:1** |
| 12 | "RB" pill | x528–652, y59–101 | 125 x 43 | same fills; label x579–601, y73–86 = 23 x 14; right edge x652 = 14 px from the viewport edge |
| 13 | Left stick disc + knob | disc x15–168, y107–260; knob x59–124, y151–216 | disc 154 x 154; knob 66 x 66 | disc `paper`, ink 3 px; knob `#69A1D1` (2.57:1 vs `paper`, no ink edge); concentric, centre (91.5,183.5) |
| 14 | "Select" pill | x273–330, y172–214 | 58 x 43 | `paper`, ink 3 px; label x281–322, y187–198 = 42 x 12 |
| 15 | "Start" pill | x336–393, y172–214 | 58 x 43 | `paper`; label x344–385, y188–199 = 42 x 12; gap Select→Start 6 px |
| 16 | "Y" button | x545–601, y111–167 | 57 x 57 | fill `#FFD23F` = `faceY`/`star`; ink 3 px; letter 11 x 13 at x568–578, y133–145; ink on `faceY` = **11.56:1** |
| 17 | "X" button | x499–555, y157–213 | 57 x 57 | fill `#2E9BF0` = `faceX`; letter 11 x 12 at x522–532, y180–191; **5.61:1** |
| 18 | "B" button | x591–648, y157–213 | 58 x 57 | fill `#FF4D5E` = `faceB`; letter 10 x 12 at x615–624, y180–191; **5.15:1** |
| 19 | "A" button | x545–601, y203–259 | 57 x 57 | fill `#2FCB74` = `faceA`; letter 13 x 12 at x567–579, y226–238; **7.88:1** |
| 20 | Right stick disc + knob | disc x399–522, y248–372; knob x435–487, y284–337 | disc 124 x 125; knob 53 x 54 | disc `paper`, ink 3 px; knob `#69A1D1`; concentric, centre (460.5,310) |
| 21 | D-pad | x161–267, y266–372 | 107 x 107 | `paper`, ink 2–3 px; arm 31 x 32; centre disc 19 px `#B0A8AC` (2.16:1 vs `paper`); 4 triangles 8–9 px `#8E8694` (3.26:1) |

Face cluster: adjacent centres 65 px apart (Y(573,139) · X(527,185) · A(573,231) · B(619.5,185)),
opposite centres 92 px. Verticals: pill bottom y49 → LB pill top y59 = 10 px; LB pill bottom y101 →
disc top y107 = 6 px; D-pad bottom y372 and right disc bottom y372 = **2 px** above the viewport
bottom.

**primary action**
Connection pill — 275 x 44 dp (275 x 44 px) at (12,6), touch 275 x 48 at (12,4); contrast ink
`#1E1646` on `#7CC8F8` = **9.12:1** (`onBackground` on `background`). The pill's own fill is
`#7CC8F8` while the sky immediately outside reads `#80CAF8` (4/255 apart on R, 2/255 on G), so the
shape is carried by the outline alone, and that outline is the thinnest on the screen (1 px solid,
no second solid row).

**secondary actions**
Mode control: 3 segments of 73 x 32 dp drawn (touch 73–74 x 40 dp — 8 dp under the 48 dp minimum
height). Icon buttons: Stick settings / Settings / Diagnostics, 48 x 48 dp touch, glyphs 18 x 18,
18 x 20, 20 x 16. Pad inputs: LB 124 x 43, RB 125 x 43, Select 58 x 43, Start 58 x 43 (all
non-clickable in the a11y tree — `clickable=false`, so no touch target is published); left stick
154 dp disc / 66 dp knob; right stick 124 dp disc / 53 dp knob; D-pad 107 x 107 with a 31 x 32 dp
arm; A, B, X, Y 57–58 dp. Knob-to-disc contrast 2.57:1 and D-pad centre-disc 2.16:1 are under
WCAG's 3:1 for a control part.

**text that wraps or truncates at this size, and how**
One truncation, no wrap: the pill label stops after "con" and ends with an ellipsis —
"Connecting... · tap to con…" — rendered 208 x 16 px, ending at x263, **22 px** before the pill's
right outline (x286); 1 line; the label's own leading "Connecting..." (source text) plus the
truncation ellipsis are both present. Nothing else wraps or clips: 4 segment/pill label runs and
4 button labels are all single-line, and the widest label (D-pad, 48 px) sits in a 73 px segment
(25 px unused).

**states covered, and states missing**
Covered: connecting/waiting (label "Connecting..." + a `caution` core in an ink ring); mode
selection with one segment marked selected; all 11 pad inputs drawn at rest.
Missing (absent, not present anywhere in this capture): connected (no `good` dot, no host name, no
session line), disconnected/error (no `bad` dot, no error text), dropped link, any pressed /
focused / disabled control state, any empty state. The visible string is
"Connecting... · tap to connect" while the pill's a11y label is "Not connected · tap to connect" —
the two disagree on the same element.

**cross-screen inconsistencies versus the other screens**
1. Outline weight is not one value: 3 px on LB/RB/Select/Start, both stick discs, the D-pad and the
   four face buttons (2 px solid + 1 px AA), but ≈1.5 px on the connection pill and the mode
   control. §3 states "outline width 3 px on menus" — the pill and the mode control are half that.
   The same 3:1 split was measured on the same screen at native density 354 as 6 px (2.7 dp) vs
   2 px (0.9 dp), so the ratio is stable but the dp value is not: 1.5 dp here against 0.9 dp there.
2. Text sizes are not one value: cap 13 px for the pill label and the segment labels (≈18 dp
   button size), cap 14 px for LB/RB, ascender 12 px for Select/Start, 12–13 px for the face
   letters at this size (they scale up to 19–20 px at 932x430) — a 2 px spread in what §3 calls
   one button size.
3. Neutrals not in §3: knob `#69A1D1` (both sticks) and D-pad triangle `#8E8694`; the D-pad
   centre disc `#B0A8AC` is exactly ink at 35 % over `paper`, i.e. §3's shadow recipe, so the disc
   cannot be distinguished from its own hard shadow at this density. No §3 token pair exists for
   these → `unmeasured`.
4. Only sub-48 dp touch target on the screen: the mode control at 40 dp high — 48 dp wide per
   segment at this size (73 px) but 8 dp short in height, and it is the screen's only
   segmented control.
5. Against the sibling tablet capture (`vf-tab-01`) on the same screen: the pill (291.5 x 43.4 dp),
   mode control (303.7 x 32.1 dp), LB/RB (132.9 x 42.9), Select/Start (69.2 / 68.7 x 42.9), icon
   touch (47.9 x 47.9) and the `caution` selected fill are the same widget sizes and tokens; this
   size is the only one of the six where the pill is narrower (275 dp) and the mode control is
   narrower (220 dp), i.e. the top bar compresses only here.

**flow stage (spec §1)**: stage 1 (launch / first run) and stage 13 (re-entry after a drop) by the
connection pill and its `caution` dot; stage 8 (in-round controls) by the pad body. Stages 2–7 and
9–12 are not represented on the controller's screen.

---

## Record 2 — 800x360 (small Android 360 dp class)

**screen / form factor / theme / viewport px**
Same screen. Phone logical viewport, landscape, on the Pixel Tablet via override. Theme: Sunny.
Viewport: **800x360 px, landscape, 800x360 dp** at density 160 (`dp = px / 1`);
`base=360x800 160dpi cur=800x360 app=800x360`, `ROTATION_270`. No title, no back affordance, no
system bars.

**elements in reading order, with pixel size and position** (px = dp):

| # | element | bounds px | w x h | fill / outline / type |
|---|---|---|---|---|
| 1 | Connection pill (button) | x12–303, y6–49 | 292 x 44 | fill `#7CC8F8` `background`; ink outline ≈1.5 px; r ≈ 22 |
| 2 | State dot | x28–38, y22–33 | 11 x 12 | ink ring; core `caution` 5 x 6 at x31–35, y25–30 |
| 3 | Label "Connecting... · tap to connect" | x56–286, y21–36 | 231 x 16 | ink on `background` = **9.12:1**; 1 line; cap 13 px; complete |
| 4 | Mode control container | x344–647, y12–43 | 304 x 32 | unfilled (sky `#ACDEFD` … `#AFE0FD`); ink ≈1.5 px; dividers 1 px at x445, x546 |
| 5 | Segment "D-pad" | x344–445 | 101 x 32 (touch 101 x 40 at (345,8)) | unfilled; label x357–429, y21–36 = 73 x 16; ink on `#ACDEFD` = 11.62:1 — **`unmeasured`** |
| 6 | Segment "Gyro" | x445–546 | 101 x 32 (touch 101 x 40) | unfilled; label x464–525, y21–36 = 62 x 16; ink on `#A8DDFC` = 11.45:1 — **`unmeasured`** |
| 7 | Segment "Sticks" — selected | x546–647 | 101 x 32 (touch 101 x 40) | fill `#FFB020` = `caution`; label x561–631, y21–33 = 71 x 13; **9.13:1**; `selected=true` |
| 8 | Stick-settings icon | glyph x663–680, y19–36 | 18 x 18; touch 48 x 48 at (648,4) | ink on `background` |
| 9 | Settings icon | glyph x711–728, y18–37 | 18 x 20; touch 48 x 48 at (696,4) | ink |
| 10 | Diagnostics icon | glyph x758–777, y20–35 | 20 x 16; touch 48 x 48 at (744,4) | ink; touch ends x792 = 8 px from the edge |
| 11 | "LB" pill | x15–147, y59–101 | 133 x 43 | `paper`; ink 3 px (2 solid + AA); label x71–91, y73–86 = 21 x 14; **15.53:1** |
| 12 | "RB" pill | x653–785, y59–101 | 133 x 43 | same; label x708–729, y73–86 = 22 x 14; right edge 14 px from the edge |
| 13 | Left stick disc + knob | disc x14–160, y106–252; knob x56–119, y148–211 | disc 147 x 147; knob 64 x 64 | `paper` + ink 3 px; knob `#69A1D1` (2.57:1 vs `paper`); concentric (87,179) |
| 14 | "Select" pill | x329–397, y169–211 | 69 x 43 | `paper`, ink 3 px; label x337–388, y184–196 = 52 x 13 |
| 15 | "Start" pill | x403–471, y169–211 | 69 x 43 | `paper`; label x414–459, y183–196 = 46 x 14; gap 6 px |
| 16 | "Y" button | x651–722, y112–182 | 72 x 71 | `#FFD23F` `faceY`; ink 3 px; letter 14 x 17 at x680–693, y139–155; **11.56:1** |
| 17 | "X" button | x593–664, y170–240 | 72 x 71 | `#2E9BF0` `faceX`; letter 14 x 16 at x622–635, y198–213; **5.61:1** |
| 18 | "B" button | x709–780, y170–240 | 72 x 71 | `#FF4D5E` `faceB`; letter 12 x 17 at x739–750, y197–213; **5.15:1** |
| 19 | "A" button | x651–722, y228–298 | 72 x 71 | `#2FCB74` `faceA`; letter 16 x 17 at x679–694, y255–271; **7.88:1** |
| 20 | Right stick disc + knob | disc x477–594, y239–356; knob x510–560, y273–323 | disc 118 x 118; knob 51 x 51 | `paper` + ink 3 px; knob `#69A1D1`; concentric (535.5,297.5) |
| 21 | D-pad | x224–323, y258–357 | 100 x 100 | `paper`, ink 2–3 px; arm 29 x 29; centre disc 18 px `#B0A8AC`; triangles 8 px `#8E8694` |

Face cluster: adjacent centres 82 px (Y(686.5,147) · X(628.5,205) · A(686.5,263) ·
B(744.5,205)), opposite 116 px. Verticals: pill bottom y49 → LB y59 = 10 px; LB y101 → disc y106
= 5 px; D-pad and right disc end y356–357 = **2–3 px** above the viewport bottom.

**primary action**
Connection pill — 292 x 44 dp at (12,6), touch 291 x 48; ink on `background` = **9.12:1**. The pill
is at its full size from this viewport up (292 x 44 at sizes 2–6), i.e. it stops growing here.

**secondary actions**
Mode control: 3 segments of 101 x 32 dp drawn, touch 101 x 40 dp (8 dp under the 48 dp minimum
height). Icon buttons 48 x 48 dp touch. Pad inputs: LB/RB 133 x 43, Select/Start 69 x 43,
left stick 147 dp disc / 64 dp knob, right stick 118 dp disc / 51 dp knob, D-pad 100 x 100 with a
29 x 29 arm, face buttons 72 x 71. Knob 2.57:1 and D-pad centre disc 2.16:1 are under 3:1.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels. Measured slack: the pill label is 231 px and ends at
x286, **16 px** before the pill's right outline; the widest segment label (D-pad, 73 px) sits in a
101 px segment (28 px unused); segment labels 62–73 px wide in 101 px segments. All labels are one
line; the pill label's cap is 13 px and its ink height (with the "g" descender) 16 px.

**states covered, and states missing**
Covered: connecting/waiting with the `caution` dot; mode selection (`Sticks` selected); all 11 pad
inputs at rest.
Missing (absent): connected, error/disconnected, dropped link, pressed/focused/disabled, empty. The
pill's a11y label still reads "Not connected · tap to connect" against the visible
"Connecting... · tap to connect".

**cross-screen inconsistencies versus the other screens**
1. Pushed to this viewport, the top bar stops changing: the pill gains 17 px of width and the mode
   control 84 px over size 1, but the icon glyphs stay 18 x 18 / 18 x 20 / 20 x 16 and their touch
   boxes 48 x 48 — so the whole 84 px of extra segment width comes from the segments alone.
2. Outline weight still splits 3 px (controls) vs ≈1.5 px (pill, mode control); §3 says 3 px.
3. The left stick disc is **smaller here (147 px) than at 667x375 (154 px)** although the viewport
   is wider — it tracks viewport height, not width. The face buttons move the other way (57 → 72
   px), so the two clusters are not driven by one factor.
4. Neutrals `#69A1D1` (knobs), `#B0A8AC` (D-pad centre disc, = ink at 35 % over `paper`), `#8E8694`
   (D-pad triangles) — no §3 token pair → `unmeasured`.
5. Mode control is the only 40-dp-high touch target; every other published target is 48 x 48.

**flow stage (spec §1)**: 1 and 13 through the connection pill and dot; 8 through the pad body.
Stages 2–7, 9–12 absent (they live on the TV).

---

## Record 3 — 844x390 (iPhone 12–16 class)

**screen / form factor / theme / viewport px**
Same screen. Phone logical viewport, landscape, on the Pixel Tablet via override. Theme: Sunny.
Viewport: **844x390 px, landscape, 844x390 dp** at density 160 (`dp = px / 1`);
`base=390x844 160dpi cur=844x390 app=844x390`, `ROTATION_270`.

**elements in reading order, with pixel size and position** (px = dp):

| # | element | bounds px | w x h | fill / outline / type |
|---|---|---|---|---|
| 1 | Connection pill | x12–303, y6–49 | 292 x 44 | `background` fill, ink ≈1.5 px |
| 2 | State dot | x28–38, y22–33 | 11 x 12 | ink ring; core `caution` 5 x 6 at (31,25) |
| 3 | Label "Connecting... · tap to connect" | x56–286, y21–36 | 231 x 16 | ink on `background` = **9.12:1**; complete |
| 4 | Mode control | x388–691, y12–43 | 304 x 32 | unfilled (sky `#A6DCFC` … `#A8DDFC`); dividers at x489, x590 |
| 5 | Segment "D-pad" | x388–489 | 101 x 32 (touch 101 x 40 at (389,8)) | label x401–473, y21–36 = 73 x 16; ink on `#ABDEFD` = 11.60:1 — **`unmeasured`** |
| 6 | Segment "Gyro" | x489–590 | 101 x 32 (touch 101 x 40) | label x508–569, y21–36 = 62 x 16; ink on `#A6DCFC` — **`unmeasured`** |
| 7 | Segment "Sticks" — selected | x590–691 | 101 x 32 (touch 101 x 40) | `caution` fill; label x605–675 = 71 x 13; **9.13:1** |
| 8 | Stick-settings icon | glyph x707–724, y19–36 | 18 x 18; touch 48 x 48 at (692,4) | ink |
| 9 | Settings icon | glyph x755–772, y18–37 | 18 x 20; touch 48 x 48 at (740,4) | ink |
| 10 | Diagnostics icon | glyph x802–821, y20–35 | 20 x 16; touch 48 x 48 at (788,4) | ink; ends x836 = 8 px from the edge |
| 11 | "LB" pill | x15–147, y59–101 | 133 x 43 | `paper`, ink 3 px; label 21 x 14 at (71,73); **15.53:1** |
| 12 | "RB" pill | x697–829, y59–101 | 133 x 43 | `paper`; label 22 x 14 at (752,73) |
| 13 | Left stick disc + knob | disc x14–178, y106–270; knob x61–131, y153–223 | disc 165 x 165; knob 71 x 71 | `paper` + ink 3 px; knob `#69A1D1`; concentric (96,188) |
| 14 | "Select" pill | x351–419, y176–218 | 69 x 43 | `paper`; label 52 x 13 at (359,191) |
| 15 | "Start" pill | x425–493, y176–218 | 69 x 43 | `paper`; label 46 x 14 at (436,191); gap 6 px |
| 16 | "Y" button | x682–759, y112–190 | 78 x 79 | `#FFD23F`; letter 15 x 18 at (713,143); **11.56:1** |
| 17 | "X" button | x618–695, y176–254 | 78 x 79 | `#2E9BF0`; letter 15 x 18 at (649,207); **5.61:1** |
| 18 | "B" button | x746–823, y176–254 | 78 x 79 | `#FF4D5E`; letter 14 x 18 at (778,207); **5.15:1** |
| 19 | "A" button | x682–759, y240–318 | 78 x 79 | `#2FCB74`; letter 18 x 18 at (712,271); **7.88:1** |
| 20 | Right stick disc + knob | disc x498–629, y256–387; knob x536–592, y294–349 | disc 132 x 132; knob 57 x 56 | `paper` + ink 3 px; knob `#69A1D1`; concentric (563.5,321.5) |
| 21 | D-pad | x234–345, y276–387 | 112 x 112 | `paper`, ink 2–3 px; arm 33 x 33; centre disc 20 px `#B0A8AC`; triangles 9–10 px `#8E8694` |

Face cluster: adjacent centres 90 px (Y(720.5,151) · X(656.5,215) · A(720.5,279) ·
B(784.5,215)), opposite 128 px. Verticals: pill→LB 10 px, LB y101 → disc y106 = 5 px, D-pad and
right disc end y387 = **2 px** above the bottom.

**primary action**
Connection pill 292 x 44 dp at (12,6), touch 291 x 48; ink on `background` = **9.12:1**.

**secondary actions**
Mode control 3 x (101 x 32) drawn, touch 101 x 40 (8 dp short of 48). Icons 48 x 48 touch. LB/RB
133 x 43, Select/Start 69 x 43, left stick 165 dp disc / 71 dp knob, right stick 132 dp disc /
57 dp knob, D-pad 112 x 112 with a 33 x 33 arm, face buttons 78 x 79.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels. Pill label 231 px with 16 px to the pill's right
outline; segment labels 62–73 px in 101 px segments; LB/RB labels 21–22 px in 133 px pills.

**states covered, and states missing**
Covered: connecting/waiting, mode selection, all 11 pad inputs at rest. Missing (absent):
connected, error, dropped link, pressed/focused/disabled, empty. Pill's visible string and its a11y
label still disagree ("Connecting..." vs "Not connected").

**cross-screen inconsistencies versus the other screens**
1. Per-height size increase over size 2: discs +18 px (147 → 165), face buttons +6 px (72 → 78),
   D-pad +12 px (100 → 112) for +30 px of viewport height; the top bar moves 0 px except the mode
   control's x position (+44 px).
2. Outline weight split 3 px vs ≈1.5 px persists; §3 says 3 px.
3. `#69A1D1`, `#B0A8AC`, `#8E8694` remain outside the §3 table → `unmeasured`.
4. Mode control is still the only sub-48 dp touch height (40 dp).
5. Left stick disc 165 px against right stick disc 132 px — a 33 px (25 %) difference between the
   two sticks, in the same screen (and 154/124 at 667x375, 188/150 at 932x430: the left disc is
   always ≈1.25 x the right).

**flow stage (spec §1)**: 1, 13 (pill + dot), 8 (pad body). 2–7 and 9–12 absent.

---

## Record 4 — 852x393 (iPhone Pro class)

**screen / form factor / theme / viewport px**
Same screen. Phone logical viewport, landscape, on the Pixel Tablet via override. Theme: Sunny.
Viewport: **852x393 px, landscape, 852x393 dp** at density 160 (`dp = px / 1`);
`base=393x852 160dpi cur=852x393 app=852x393`, `ROTATION_270`.

**elements in reading order, with pixel size and position** (px = dp):

| # | element | bounds px | w x h | fill / outline / type |
|---|---|---|---|---|
| 1 | Connection pill | x12–303, y6–49 | 292 x 44 | `background`, ink ≈1.5 px |
| 2 | State dot | x28–38, y22–33 | 11 x 12 | ink ring; core `caution` 5 x 6 at (31,25) |
| 3 | Label "Connecting... · tap to connect" | x56–286, y21–36 | 231 x 16 | ink on `background` = **9.12:1**; complete |
| 4 | Mode control | x396–699, y12–43 | 304 x 32 | unfilled; dividers at x497, x598 |
| 5 | Segment "D-pad" | x396–497 | 101 x 32 (touch 101 x 40 at (397,8)) | label 73 x 16 at (409,21); ink on `#ABDEFD` = 11.60:1 — **`unmeasured`** |
| 6 | Segment "Gyro" | x497–598 | 101 x 32 (touch 101 x 40) | label 62 x 16 at (516,21); ink on `#A5DCFC` = 11.32:1 — **`unmeasured`** |
| 7 | Segment "Sticks" — selected | x598–699 | 101 x 32 (touch 101 x 40) | `caution`; label 71 x 13 at (613,21); **9.13:1** |
| 8 | Stick-settings icon | glyph x715–732, y19–36 | 18 x 18; touch 48 x 48 at (700,4) | ink |
| 9 | Settings icon | glyph x763–780, y18–37 | 18 x 20; touch 48 x 48 at (748,4) | ink |
| 10 | Diagnostics icon | glyph x810–829, y20–35 | 20 x 16; touch 48 x 48 at (796,4) | ink; ends x844 = 8 px from the edge |
| 11 | "LB" pill | x15–147, y59–101 | 133 x 43 | `paper`, ink 3 px; label 21 x 14 at (71,73); **15.53:1** |
| 12 | "RB" pill | x705–837, y59–101 | 133 x 43 | `paper`; label 22 x 14 at (760,73) |
| 13 | Left stick disc + knob | disc x14–179, y106–271; knob x62–132, y154–224 | disc 166 x 166; knob 71 x 71 | `paper` + ink 3 px; knob `#69A1D1`; concentric (96.5,188.5) |
| 14 | "Select" pill | x355–423, y177–219 | 69 x 43 | `paper`; label 52 x 13 at (363,192) |
| 15 | "Start" pill | x429–497, y177–219 | 69 x 43 | `paper`; label 46 x 14 at (440,191); gap 6 px |
| 16 | "Y" button | x688–766, y112–190 | 79 x 79 | `#FFD23F`; letter 15 x 18 at (720,144); **11.56:1** |
| 17 | "X" button | x624–702, y177–255 | 79 x 79 | `#2E9BF0`; letter 16 x 18 at (655,208); **5.61:1** |
| 18 | "B" button | x753–831, y177–255 | 79 x 79 | `#FF4D5E`; letter 15 x 18 at (785,208); **5.15:1** |
| 19 | "A" button | x688–766, y242–320 | 79 x 79 | `#2FCB74`; letter 18 x 18 at (718,273); **7.88:1** |
| 20 | Right stick disc + knob | disc x502–635, y257–390; knob x541–597, y295–352 | disc 134 x 134; knob 57 x 58 | `paper` + ink 3 px; knob `#69A1D1`; concentric (568.5,323.5) |
| 21 | D-pad | x237–349, y278–390 | 113 x 113 | `paper`, ink 2–3 px; arm 34 x 34; centre disc 20 px `#B0A8AC`; triangles 9–10 px `#8E8694` |

Face cluster: adjacent centres 91 px (Y(727,151) · X(663,216) · A(727,281) · B(792,216)),
opposite 130 px. Verticals: pill→LB 10 px, LB y101 → disc y106 = 5 px, D-pad and right disc end
y390 = **2 px** above the bottom.

**primary action**
Connection pill 292 x 44 dp at (12,6), touch 291 x 48; ink on `background` = **9.12:1**.

**secondary actions**
Mode control 3 x (101 x 32) drawn / 101 x 40 touch. Icons 48 x 48. LB/RB 133 x 43, Select/Start
69 x 43, left stick 166 dp disc / 71 dp knob, right stick 134 dp disc / 57 dp knob, D-pad
113 x 113 with a 34 x 34 arm, face buttons 79 x 79.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels; pill label 231 px with 16 px to the pill's right
outline; widest segment label 73 px in a 101 px segment.

**states covered, and states missing**
Covered: connecting/waiting, mode selection, all 11 pad inputs at rest. Missing (absent):
connected, error, dropped link, pressed/focused/disabled, empty; a11y "Not connected" vs visible
"Connecting...".

**cross-screen inconsistencies versus the other screens**
1. +3 px of viewport height over size 3 buys +1 px of disc (165 → 166) and +1 px of face button
   (78 → 79): the cluster is sized from the leftover height and does not move in whole steps.
2. Outline weight split 3 px vs ≈1.5 px; §3 says 3 px.
3. `#69A1D1` / `#B0A8AC` / `#8E8694` outside §3 → `unmeasured`.
4. Mode control 40 dp high, the only sub-48 dp target.
5. Left disc 166 px vs right 134 px (≈1.24 x) and the D-pad's 34 px arm against the 71 px knob:
   four different "control sizes" for one pad.

**flow stage (spec §1)**: 1, 13 (pill + dot), 8 (pad body). 2–7 and 9–12 absent.

---

## Record 5 — 932x430 (iPhone Pro Max class)

**screen / form factor / theme / viewport px**
Same screen. Phone logical viewport, landscape, on the Pixel Tablet via override. Theme: Sunny.
Viewport: **932x430 px, landscape, 932x430 dp** at density 160 (`dp = px / 1`);
`base=430x932 160dpi cur=932x430 app=932x430`, `ROTATION_270`.

**elements in reading order, with pixel size and position** (px = dp):

| # | element | bounds px | w x h | fill / outline / type |
|---|---|---|---|---|
| 1 | Connection pill | x12–303, y6–49 | 292 x 44 | `background`, ink ≈1.5 px |
| 2 | State dot | x28–38, y22–33 | 11 x 12 | ink ring; core `caution` 5 x 6 at (31,25) |
| 3 | Label "Connecting... · tap to connect" | x56–286, y21–36 | 231 x 16 | ink on `background` = **9.12:1**; complete |
| 4 | Mode control | x476–779, y12–43 | 304 x 32 | unfilled; dividers at x577, x678 |
| 5 | Segment "D-pad" | x476–577 | 101 x 32 (touch 101 x 40 at (477,8)) | label 73 x 16 at (489,21); ink on `#A9DDFC` = 11.47:1 — **`unmeasured`** |
| 6 | Segment "Gyro" | x577–678 | 101 x 32 (touch 101 x 40) | label 62 x 16 at (596,21); ink on `#A3DAFC` = 11.12:1 — **`unmeasured`** |
| 7 | Segment "Sticks" — selected | x678–779 | 101 x 32 (touch 101 x 40) | `caution`; label 71 x 13 at (693,21); **9.13:1** |
| 8 | Stick-settings icon | glyph x795–812, y19–36 | 18 x 18; touch 48 x 48 at (780,4) | ink |
| 9 | Settings icon | glyph x843–860, y18–37 | 18 x 20; touch 48 x 48 at (828,4) | ink |
| 10 | Diagnostics icon | glyph x890–909, y20–35 | 20 x 16; touch 48 x 48 at (876,4) | ink; ends x924 = 8 px from the edge |
| 11 | "LB" pill | x15–147, y59–101 | 133 x 43 | `paper`, ink 3 px; label 21 x 14 at (71,74); **15.53:1** |
| 12 | "RB" pill | x785–917, y59–101 | 133 x 43 | `paper`; label 22 x 14 at (840,74) |
| 13 | Left stick disc + knob | disc x14–201, y107–293; knob x68–147, y161–240 | disc 188 x 187; knob 80 x 80 | `paper` + ink 3 px; knob `#69A1D1`; concentric (107.5,200.5) |
| 14 | "Select" pill | x395–463, y187–229 | 69 x 43 | `paper`; label 52 x 13 at (403,202) |
| 15 | "Start" pill | x469–537, y187–229 | 69 x 43 | `paper`; label 46 x 14 at (480,201); gap 6 px |
| 16 | "Y" button | x757–841, y113–197 | 85 x 85 | `#FFD23F`; letter 17 x 20 at (791,147); **11.56:1** |
| 17 | "X" button | x687–771, y183–267 | 85 x 85 | `#2E9BF0`; letter 17 x 19 at (721,217); **5.61:1** |
| 18 | "B" button | x827–910, y183–267 | 84 x 85 | `#FF4D5E`; letter 16 x 19 at (861,217); **5.15:1** |
| 19 | "A" button | x757–841, y253–337 | 85 x 85 | `#2FCB74`; letter 19 x 20 at (790,287); **7.88:1** |
| 20 | Right stick disc + knob | disc x557–706, y277–426; knob x599–663, y320–384 | disc 150 x 150; knob 65 x 65 | `paper` + ink 3 px; knob `#69A1D1`; concentric (631.5,351.5) |
| 21 | D-pad | x247–375, y299–427 | 129 x 129 | `paper`, ink 2–3 px; arm 39 x 39; centre disc 23 px `#B0A8AC`; triangles 11 px `#8E8694` |

Face cluster: adjacent centres 99 px (Y(799,155) · X(729,225) · A(799,295) · B(868.5,225)),
opposite 140 px. Verticals: pill→LB 10 px, LB y101 → disc y107 = 6 px; **the D-pad ends at y427 and
the right stick disc at y426, i.e. 2 px and 3 px above the 430 px bottom** — this is the largest of
the six and the only one where the right disc's bottom (426) and the D-pad's (427) differ by 1 px.

**primary action**
Connection pill 292 x 44 dp at (12,6), touch 291 x 48; ink on `background` = **9.12:1**.

**secondary actions**
Mode control 3 x (101 x 32) drawn / 101 x 40 touch. Icons 48 x 48. LB/RB 133 x 43, Select/Start
69 x 43, left stick 188 dp disc / 80 dp knob, right stick 150 dp disc / 65 dp knob, D-pad
129 x 129 with a 39 x 39 arm, face buttons 85 x 85.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels; pill label 231 px with 16 px to the right outline;
segment labels 62–73 px in 101 px segments; the D-pad's own labels are glyphs only (no text).

**states covered, and states missing**
Covered: connecting/waiting, mode selection, all 11 pad inputs at rest. Missing (absent):
connected, error, dropped link, pressed/focused/disabled, empty; a11y "Not connected" vs visible
"Connecting...".

**cross-screen inconsistencies versus the other screens**
1. This size has the largest pad cluster of the six (188 / 150 / 129 / 85 px) while its top bar is
   byte-identical in size to sizes 2, 3, 4 and 6 — the whole growth is absorbed by the pad.
2. Outline weight split 3 px vs ≈1.5 px; §3 says 3 px.
3. `#69A1D1` / `#B0A8AC` / `#8E8694` outside §3 → `unmeasured`.
4. Mode control 40 dp high, the only sub-48 dp target.
5. Against the sibling tablet capture at 354 dpi, the left disc here is 188 dp against 187.1 dp
   there (0.9 dp apart) and the right disc 150 dp against 150.5 dp (0.5 dp apart) — the two sticks
   converge on their tablet sizes only at this viewport.

**flow stage (spec §1)**: 1, 13 (pill + dot), 8 (pad body). 2–7 and 9–12 absent.

---

## Record 6 — 915x412 (Pixel 8/9 + Galaxy S24, 412 dp class)

**screen / form factor / theme / viewport px**
Same screen. Phone logical viewport, landscape, on the Pixel Tablet via override. Theme: Sunny.
Viewport: **915x412 px, landscape, 915x412 dp** at density 160 (`dp = px / 1`);
`base=412x915 160dpi cur=915x412 app=915x412`, `ROTATION_270`.

**elements in reading order, with pixel size and position** (px = dp):

| # | element | bounds px | w x h | fill / outline / type |
|---|---|---|---|---|
| 1 | Connection pill | x12–303, y6–49 | 292 x 44 | `background`, ink ≈1.5 px |
| 2 | State dot | x28–38, y22–33 | 11 x 12 | ink ring; core `caution` 5 x 6 at (31,25) |
| 3 | Label "Connecting... · tap to connect" | x56–286, y21–36 | 231 x 16 | ink on `background` = **9.12:1**; complete |
| 4 | Mode control | x459–762, y12–43 | 304 x 32 | unfilled; dividers at x560, x661 |
| 5 | Segment "D-pad" | x459–560 | 101 x 32 (touch 101 x 40 at (460,8)) | label 73 x 16 at (472,21); ink on `#AADEFD` = 11.58:1 — **`unmeasured`** |
| 6 | Segment "Gyro" | x560–661 | 101 x 32 (touch 101 x 40) | label 62 x 16 at (579,21); ink on `#A4DBFC` = 11.22:1 — **`unmeasured`** |
| 7 | Segment "Sticks" — selected | x661–762 | 101 x 32 (touch 101 x 40) | `caution`; label 71 x 13 at (676,21); **9.13:1** |
| 8 | Stick-settings icon | glyph x778–795, y19–36 | 18 x 18; touch 48 x 48 at (763,4) | ink |
| 9 | Settings icon | glyph x826–843, y18–37 | 18 x 20; touch 48 x 48 at (811,4) | ink |
| 10 | Diagnostics icon | glyph x873–892, y20–35 | 20 x 16; touch 48 x 48 at (859,4) | ink; ends x907 = 8 px from the edge |
| 11 | "LB" pill | x15–147, y59–101 | 133 x 43 | `paper`, ink 3 px; label 21 x 14 at (71,73); **15.53:1** |
| 12 | "RB" pill | x768–900, y59–101 | 133 x 43 | `paper`; label 22 x 14 at (823,73) |
| 13 | Left stick disc + knob | disc x15–190, y107–282; knob x65–140, y157–232 | disc 176 x 176; knob 76 x 76 | `paper` + ink 3 px; knob `#69A1D1`; concentric (102.5,194.5) |
| 14 | "Select" pill | x386–454, y182–224 | 69 x 43 | `paper`; label 53 x 13 at (394,197) |
| 15 | "Start" pill | x460–528, y182–224 | 69 x 43 | `paper`; label 45 x 14 at (472,196); gap 6 px |
| 16 | "Y" button | x742–825, y113–195 | 84 x 83 | `#FFD23F`; letter 16 x 20 at (776,144); **11.56:1** |
| 17 | "X" button | x674–756, y181–264 | 83 x 84 | `#2E9BF0`; letter 17 x 19 at (707,214); **5.61:1** |
| 18 | "B" button | x811–894, y181–264 | 84 x 84 | `#FF4D5E`; letter 15 x 19 at (845,214); **5.15:1** |
| 19 | "A" button | x742–825, y250–332 | 84 x 83 | `#2FCB74`; letter 19 x 20 at (775,282); **7.88:1** |
| 20 | Right stick disc + knob | disc x540–681, y267–409; knob x580–641, y308–368 | disc 142 x 143; knob 62 x 61 | `paper` + ink 3 px; knob `#69A1D1`; concentric (610.5,338) |
| 21 | D-pad | x255–375, y289–409 | 121 x 121 | `paper`, ink 2–3 px; arm 36 x 36; centre disc 22 px `#B0A8AC`; triangles 10 px `#8E8694` |

Face cluster: adjacent centres 97 px (Y(783.5,154) · X(715,222.5) · A(783.5,291) · B(852.5,222.5)),
opposite 137 px. Verticals: pill→LB 10 px, LB y101 → disc y107 = 6 px, D-pad and right disc end
y409 = **2 px** above the 412 px bottom.

**primary action**
Connection pill 292 x 44 dp at (12,6), touch 291 x 48; ink on `background` = **9.12:1**.

**secondary actions**
Mode control 3 x (101 x 32) drawn / 101 x 40 touch. Icons 48 x 48. LB/RB 133 x 43, Select/Start
69 x 43, left stick 176 dp disc / 76 dp knob, right stick 142 dp disc / 62 dp knob, D-pad
121 x 121 with a 36 x 36 arm, face buttons 84 x 84.

**text that wraps or truncates at this size, and how**
None. 0 wraps, 0 ellipses, 0 clipped labels; pill label 231 px with 16 px to the right outline;
segment labels 62–73 px in 101 px segments; pill label cap 13 px, ink height 16 px.

**states covered, and states missing**
Covered: connecting/waiting, mode selection, all 11 pad inputs at rest. Missing (absent):
connected, error, dropped link, pressed/focused/disabled, empty; a11y "Not connected" vs visible
"Connecting...".

**cross-screen inconsistencies versus the other screens**
1. This is the Android reference viewport of the six and its cluster sizes sit between sizes 4 and
   5 (176 vs 166 / 188 px disc), i.e. sized by height (412) not by class.
2. Outline weight split 3 px vs ≈1.5 px; §3 says 3 px.
3. `#69A1D1` / `#B0A8AC` / `#8E8694` outside §3 → `unmeasured`.
4. Mode control 40 dp high, the only sub-48 dp target; its 3 segments are 101 dp wide here against
   73 dp at 667x375.
5. Icon glyph widths are 18, 20 and 20 px (Stick settings, Settings, Diagnostics) at 48 px touch —
   three different glyph sizes in one row, unchanged across all six sizes.

**flow stage (spec §1)**: 1, 13 (pill + dot), 8 (pad body). 2–7 and 9–12 absent.

---

## Cross-size matrix (all figures px = dp; density 160)

| element | 667x375 | 800x360 | 844x390 | 852x393 | 932x430 | 915x412 |
|---|---|---|---|---|---|---|
| connection pill (drawn) | 275 x 44 at (12,6) | 292 x 44 | 292 x 44 | 292 x 44 | 292 x 44 | 292 x 44 |
| pill label | 208 x 16 — **truncated** | 231 x 16 | 231 x 16 | 231 x 16 | 231 x 16 | 231 x 16 |
| pill label right gap | 22 | 16 | 16 | 16 | 16 | 16 |
| state dot | 11 x 12 at (28,22), pixel-identical at all six | same | same | same | same | same |
| mode control (drawn) | 220 x 32 | 304 x 32 | 304 x 32 | 304 x 32 | 304 x 32 | 304 x 32 |
| segment width | 73 | 101 | 101 | 101 | 101 | 101 |
| mode control touch height | 40 | 40 | 40 | 40 | 40 | 40 |
| icon touch / glyphs | 48x48 / 18,18x20,20x16 | same | same | same | same | same |
| LB / RB pill | 124x43 / 125x43 | 133x43 | 133x43 | 133x43 | 133x43 | 133x43 |
| Select / Start | 58x43 | 69x43 | 69x43 | 69x43 | 69x43 | 69x43 |
| left disc / knob | 154 / 66 | 147 / 64 | 165 / 71 | 166 / 71 | 188 / 80 | 176 / 76 |
| right disc / knob | 124 / 53 | 118 / 51 | 132 / 57 | 134 / 57 | 150 / 65 | 142 / 62 |
| face button | 57 | 72 | 78 | 79 | 85 | 84 |
| face letter (height) | 12–13 | 16–17 | 18 | 18 | 19–20 | 19–20 |
| D-pad / arm | 107 / 31 | 100 / 29 | 112 / 33 | 113 / 34 | 129 / 39 | 121 / 36 |
| D-pad centre disc / triangle | 19 / 8–9 | 18 / 8 | 20 / 9–10 | 20 / 9–10 | 23 / 11 | 22 / 10 |
| bottom margin (D-pad, right disc) | 2 | 2–3 | 2 | 2 | 2–3 | 2 |
| right margin (last icon touch) | 8 | 8 | 8 | 8 | 8 | 8 |
| pill→mode-control gap | 9 | 41 | 85 | 93 | 173 | 156 |

Derived from the matrix: the top bar, the three pills and the icon buttons stop growing at 800 px
wide (identical from size 2 to size 6), while the stick discs, face buttons and D-pad scale with
viewport height — left disc / (H − 106) = 0.572, 0.579, 0.581, 0.578, 0.580, 0.575 across the six
sizes (0.572–0.581), where 106 px is the top bar (52 px touch) plus the LB pill (43 px) plus 11 px
of gap. The one element that is not height-driven is the face cluster at 667x375: 57 px there
against 72 px at 800x360, i.e. 15 px (21 %) smaller, although its viewport is 15 px taller than
size 2 — it is the only cluster that loses size to the narrower width.

---

## The portrait gate (extra evidence, not one of the six records)

At the literal `wm size 667x375` (which lands portrait, see "Protocol deviation") the app does not
draw the pad at all. Measured on `gate-portrait-375x667.png` (375x667 px, density 160, density
printed `160`, theme Sunny: panel `#7DC9F8` with the glow at `#A9DDFC` and the Sunny dots):

- Black unpainted bands: y0–194 (375 x 195 px) and y472–666 (375 x 195 px). Painted area:
  375 x 281 px, y193–473.
- Resize arrow glyph: 23 x 24 px at (176,266), ink.
- Title "Make the window bigger": ink run x79–295, y310–327 (217 x 18 px, cap 14 px).
- Body line 1: x22–351, y340–355 (330 x 16). Line 2: x24–350, y363–378 (327 x 16). Line 3:
  x125–248, y386–401 (124 x 16). Body text is the same ink on the same Sunny background.
- The gate is the app's own state at a 375 px-wide window: the pad screen's 21 elements are absent,
  replaced by 1 glyph, 1 title and 3 body lines. No "ignore"/"continue" affordance is drawn.

## `unmeasured` / `absent` summary

- `unmeasured`: the three mode-control labels at every size — the segment fill is the sky gradient
  (sampled `#A3DAFC`…`#AFE0FD`), which is not one flat §3 token, so no token pair names it; the
  computed ratios against the sampled local fills are 11.12:1 – 11.84:1 (all above 4.5:1).
- `unmeasured`: stick knob `#69A1D1` (2.57:1 against `paper`, 1.51:1 against `background`) — not in
  §3, and it is a control surface, not text.
- `unmeasured`: D-pad centre disc `#B0A8AC` (2.16:1 against `paper`) — equals §3's shadow recipe
  (ink at 35 %) and is also the D-pad's hard shadow, so the fill cannot be separated from the
  shadow at this density; D-pad triangles `#8E8694` (3.26:1).
- `absent` at all six sizes: connected state (no `good` dot, no host/session line), error /
  disconnected state, dropped-link state, pressed, focused and disabled control states, any empty
  state. Only "connecting" is drawn.
- `absent`: any touch target on LB, RB, Select, Start, the sticks, the D-pad and A/B/X/Y — the a11y
  tree marks them `clickable=false`, so no touch geometry is published for them.
- `absent`: a title, a back/close affordance, and any navigation on this screen.
- Sub-48 dp: the mode control's touch height is 40 dp at all six sizes (48 dp minimum); every other
  published target is 48 x 48 dp.
- Inconsistency carried by the app itself: the pill's visible string is
  "Connecting... · tap to connect" while its a11y label is "Not connected · tap to connect", at all
  six sizes.
- Failed size: none. All six target sizes captured at exactly the requested PNG px; see the reset
  line below for the display state afterwards.

## Display reset (verified after the last capture)

- `wm size reset` then `wm density reset` → `wm size` printed only `Physical size: 1600x2560`
  and `wm density` printed `Physical density: 320`; `wm density reset` had removed the tablet's
  baseline `Override density: 354`, so `wm density 354` was re-issued to put the device back to the
  state it was found in. Verified afterwards: `Physical size: 1600x2560` (no override size),
  `Physical density: 320`, `Override density: 354`, `dumpsys` `init=1600x2560 320dpi
  base=1600x2560 354dpi cur=2560x1600 app=2560x1600`. The app was left force-stopped and relaunched
  once at native, showing the pad screen. No rotation setting, no other device setting and no TV
  state was touched.
