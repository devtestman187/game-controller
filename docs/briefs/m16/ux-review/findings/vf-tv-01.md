# vf-tv-01 — TV host screens (Sony BRAVIA), Sunny

Visual findings for the Thumb Party **TV host** (`com.thumbparty.tv`). Four distinct
screens captured by dpad only. No application, test, protocol, map or dependency was
changed; no device setting was changed.

## Device, viewport and measurement basis

- adb serial `192.168.1.100:5555`, app `com.thumbparty.tv`, launched
  `com.thumbparty.tv/.MainActivity` after `am force-stop`.
- `wm size` → `Physical size: 3840x2160` / `Override size: 1920x1080`
- `wm density` → `Physical density: 320`
- Viewport: **1920x1080 px = 960x540 dp**, **landscape**. Scale divisor
  `density/160 = 2`, so **dp = px / 2**. Panel is 3840x2160 at 320 dpi with a
  1920x1080 override; every number below is the override surface actually captured.
- Theme: **Sunny**. Deciding sample: background at `(4,4)` = `#80CAF8`, at `(1916,4)`
  = `#7FCAF8`, glow at `(960,8)` = `#A3DAFC`. Sunny `background` `#7CC8F8` with
  `backgroundGlow` `#C4EAFF`; Night `background` `#241C5E` is not present. Sunny's
  faint polka dots are drawn; no stars.
- Focus ring geometry (measured on "Haptic test", the Party night card and the "3
  rounds" pill): a 7–8 px (3.5–4 dp) `#FFD23F` band with a 3 px (1.5 dp) `#1E1646`
  outer edge, drawn outside the control's own ink outline. Vertical scan at x=200
  through "Haptic test": ink 190–192, `#FFD23F` 193–199, ink 200–207, `#2FCB74` from
  209; horizontal scan at y=400 through the Party night card: `#FFD23F` 1296–1303,
  ink 1304–1311, `#FFF6E3` from 1312. Control outlines are 8 px = 4 dp (the TV value
  in look-and-sound.md §3).
- Text sizes below are measured glyph ink height, not font sizes.

Capture index (screenshots under `C:\Users\mrman\AppData\Local\Temp\ux-pilot\`):

| # | Screen | File | Stage (§1) |
|---|---|---|---|
| 1 | Host shell / test bench | `tv-01-first.png` | 1, 2, 3 (pairing), 13 |
| 2 | Look and sound | `tv-06-look.png` | 2 |
| 3 | Play (game picker) | `tv-12-play.png` | 6 |
| 4 | Party night | `tv-13-party.png`, `tv-14-party-scroll.png` | 6, 11 |

Also captured, same screens in other states: `tv-02-down.png`, `tv-03-up.png`,
`tv-04-up.png`, `tv-05-right2.png`, `tv-07-look-focus.png`, `tv-09-look-restored.png`,
`tv-11-up3.png`, `tv-15-final-shell.png`.

---

## Record 1 — Host shell / test bench

**screen / form factor / theme / viewport px**
Host shell (test bench + pairing + controller list + log) / TV, landscape, lean-back /
Sunny / 1920x1080 px (960x540 dp), dp = px/2.

**elements in reading order, with pixel size and position**

1. Monitor glyph + title "Thumb Party TV": box `[96,16][928,176]` = 832x160 px
   (416x80 dp); glyph ink `[99,57][923,162]` = 825x106 px (412.5x53 dp). Ink
   `#1E1646` on background `#A4DBFC` = **11.22:1** (token pair `ink` on
   `background`).
2. "Listening on port 45780": box `[944,65][1449,127]` = 505x62 px (252.5x31 dp);
   ink `[948,80][1445,118]` = 498x39 px (249x19.5 dp). Ink on `#A6DCFC` = **11.34:1**
   (`ink` on `background`).
3. "Play" button: `[1465,48][1711,144]` = 246x96 px (**123x48 dp**); fill
   `#2FCB74` (`good`), 8 px ink outline; label + gamepad glyph ink
   `[1520,68][1689,125]` = 170x58 px (85x29 dp); glyph 40 px (20 dp) wide at
   `[1480,70]`.
4. Pill row, all 96 px (48 dp) tall, fill `#2FCB74` (`good`), 8 px ink outline,
   label ink `#1E1646` on `#2FCB74` = **7.88:1**:
   "Haptic test" `[16,192][395,288]` 379x96 (189.5x48 dp), label + icon ink
   285x74 px;
   "Latency" `[411,192][733,288]` 322x96 (161x48 dp);
   "Look and sound" `[749,192][1222,288]` 473x96 (236.5x48 dp);
   "Look test" `[1238,192][1585,288]` 347x96 (173.5x48 dp);
   "Stats" `[1601,192][1863,288]` 262x96 (131x48 dp). Gaps 16 px (8 dp).
5. Left card (paper `#FFF6E3`, 8 px ink outline, 16 px corner radius from §3) —
   "Pairing code" label `[40,328][712,408]` = 672x80 px (336x40 dp); ink
   `[43,348][355,399]` 313x52 px (156.5x26 dp).
6. Inner ScrollView `[40,416][712,801]` = 672x385 px (336x192.5 dp), scrollable,
   holding, in order:
   - code "0 4 1 4" `[40,416][354,576]` = 314x160 px (157x80 dp); digit ink
     `[43,460][349,539]` = 307x80 px (153.5x40 dp);
   - instruction paragraph `[40,576][712,762]` = 672x186 px (336x93 dp), 3 lines,
     ink per line 39 px (19.5 dp);
   - "Address for manual entry" `[40,786][575,801]` = 535x15 px (267.5x**7.5** dp) —
     clipped by the ScrollView's bottom edge at y=801;
   - "New code" `[40,529][454,657]` = 414x128 px (207x64 dp) — only reachable after
     the list scrolls; "Simulate controller" `[40,673][706,801]` = 666x128 px
     (333x64 dp), same.
7. Right card header "Controllers · 0 connected" `[776,336][1495,416]` = 719x80 px
   (359.5x40 dp); ink `[778,356][1419,395]` = 642x40 px (321x20 dp), `ink` on
   `paper` = **15.53:1**.
8. "Forget phones" button `[1495,328][1880,424]` = 385x96 px (192.5x48 dp), fill
   `good`, ink on `good` = **7.88:1**. Its top (y=328) sits 8 px above the header's
   text top (y=336), so the button is not aligned to the header baseline.
9. Controller row `[776,432][1880,634]` = 1104x202 px (552x101 dp):
   phone glyph 84x128 px region at `[776,432]`; name "Laksh" ink
   `[800,438][989,485]` = 190x48 px (95x24 dp), `ink` on `paper` = 15.53:1;
   subtitle ink `[867,517][1309,547]` = 443x31 px (221.5x15.5 dp), ending in an
   ellipsis `…` at x 1284–1309; gamepad glyph `[1311,486][1583,579]` = 273x94 px
   (136.5x47 dp); status dot ring
   `[864,580][895,611]` = 32x32 px (16x16 dp) with a 16x16 px (8 dp) `#FF4D5E`
   (`bad`) fill at `[872,588]`; "Disconnected" ink `[916,579][1189,611]` = 274x33 px
   (137x16.5 dp); row action "–" ink `[1834,535][1861,542]` = 28x8 px (14x4 dp).
10. Log card: "Log" `[40,873][384,953]` = 344x80 px (172x40 dp), ink 89x51 px;
    "Save log" `[384,865][712,961]` = 328x96 px (164x48 dp), fill `good`, label ink
    270x65 px; log viewport `[40,969][712,1040]` = 672x71 px (336x35.5 dp). Card's
    bottom ink border at y 1056–1064, so the card is inside the 1080 px viewport.

**primary action**: "Play", 123x48 dp at `[1465,48]`, label ink `#1E1646` on
`#2FCB74` = **7.88:1** (`ink` on `good`). It is the only element in the top-right
corner and the only one that starts the party flow.

**secondary actions**: "Haptic test" (189.5x48 dp), "Latency" (161x48 dp),
"Look and sound" (236.5x48 dp), "Look test" (173.5x48 dp), "Stats" (131x48 dp),
"Forget phones" (192.5x48 dp), "New code" (207x64 dp), "Simulate controller"
(333x64 dp), "Save log" (164x48 dp), and the per-row "–" control (position measured,
hit area **unmeasured**). Seven of the nine sized actions are 48 dp tall; two are
64 dp tall.

**text that wraps or truncates at this size, and how**
- The pairing instruction wraps to 3 lines in a 672 px (336 dp) box: "On the phone,
  choose "Thumb" / "Party TV (Android TV)" and / "enter this code." Each line's ink is
  39 px (19.5 dp); line pitch 62 px (31 dp).
- "Address for manual entry" is **clipped, not wrapped**: 15 px (7.5 dp) of the line
  is inside the ScrollView, whose bottom edge is y=801. The line's own ink is lighter
  than `#1E1646` at threshold 110, i.e. only the top arcs of the glyphs are inside.
- The controller subtitle **truncates with one ellipsis**: the a11y text is
  "ios · 0.14.0+835 · 192.168.1.145" (32 characters) but only 443 px (221.5 dp) is
  drawn, ending in `…` at x 1284–1309; the IP address is dropped. The row is 1104 px
  wide; right of the ellipsis sit a 273 px gamepad glyph (x 1311–1583) and the row's
  28 px "–" control (x 1834–1861) against the row's right ink border.
- The log viewport (71 px = 35.5 dp tall) clips its first visible log line mid-glyph at
  y=969 and the current line at y=1040; no scroll affordance is drawn.
- The code "0 4 1 4" is spaced with single spaces; digit ink 40 dp tall in an 80 dp box.

**states covered, and states missing (empty, error, waiting, dropped link)**
- Covered: **waiting** — header reads "Controllers · 0 connected" with no connected
  controller; **dropped link** — one remembered row "Laksh / ios · 0.14.0+835 / …"
  with an 8 dp `bad` `#FF4D5E` dot and the word "Disconnected"; remembered-phone list;
  pairing code present (`0 4 1 4`); live log with a duration column ("24.61 s").
- Missing: **empty** controller list — **absent** in this capture (the list always held
  the one remembered row; clearing it would have changed stored state); **error**
  state — **absent**; **connecting / joining-in-progress** — **absent**; **pairing
  success** confirmation — **absent**; a **scroll indicator** on the pairing card or the
  log — **absent**.
- The header count and the list disagree in kind: "0 connected" is a count while the
  single row is a remembered device, so the card shows a device and a zero at once
  with no label distinguishing "remembered" from "connected".

**cross-screen inconsistencies versus the other screens**
- The a11y text carries a double-encoded middle dot: `Controllers Â· 0 connected` and
  `ios Â· 0.14.0+835 Â· 192.168.1.145`, while the drawn glyph is `·`. A screen reader
  announces "Â" at each of those three positions; the other three captured screens
  contain no `Â` in their a11y strings.
- Three different left margins on one screen: pills start at x=16 (8 dp), cards at
  x=40 (20 dp), title at x=96 (48 dp).
- "Forget phones" is 48 dp tall; "New code" and "Simulate controller" in the adjacent
  card are 64 dp tall for the same filled-pill style.
- **Initial focus is absent** here: on first paint no control shows the 8 px
  `#FFD23F` ring, whereas the Play screen and the Party night screen both paint one at
  entry.
- Re-entry keeps the pairing card's scroll offset: after returning from Look and sound
  the card still shows "New code"/"Simulate controller" and the code "0 4 1 4" is
  scrolled out (`tv-15-final-shell.png`), so the pairing code is not visible on
  re-entry even though it is the card's purpose (stage 13).
- Body/help text is `ink` `#1E1646` here; the Party night award-card body text is
  `#615975` (ink at 70% alpha over paper).

---

## Record 2 — Look and sound (settings)

**screen / form factor / theme / viewport px**
Look and sound settings / TV, landscape / Sunny / 1920x1080 px (960x540 dp), dp = px/2.

**elements in reading order, with pixel size and position**

1. Back arrow button `[0,30][96,126]` = 96x96 px (48x48 dp, flush to x=0); arrow ink
   `[33,63][63,92]` = 31x30 px (15.5x15 dp), `#1E1646` on `#94D3FA` = **11.22:1**
   (`ink` on `background`).
2. Page title "Look and sound": ink `[135,41][920,123]` = 786x83 px (393x41.5 dp),
   `ink` on `#A4DBFC` = **11.22:1**.
3. Paper card `[48,205][1872,1080]` (8 px ink outline; card top border at y 205–212,
   fill `#FFF6E3` from y=213). Card is 1824x875 px (912x437.5 dp) and its content
   continues past the viewport bottom.
4. "Look" label: ink `[84,252][178,282]` = 95x31 px (47.5x15.5 dp), `ink` on
   `paper` = **15.53:1**.
5. Segmented control, three segments 96 px (48 dp) tall: "Auto" `[80,315][248,411]`
   168x96 px (84x48 dp) — **selected**, fill `#FFB020` (`caution`), its own ink border
   at y 323–324 and 400–401; "Sunny" `[248,315][415,411]` 167x96 px (83.5x48 dp),
   fill `paper`; "Night" `[415,315][583,411]` 168x96 px (84x48 dp), fill `paper`.
   Label ink `#1E1646` on the selected `#FFB020` = **9.13:1** (`ink` on `caution`);
   on the unselected `paper` = 15.53:1. Segment label ink: "Sunny" 125x39 px
   (62.5x19.5 dp).
6. Help line "Auto: Sunny from 7:00 to 19:00, Night otherwise": ink
   `[82,434][1097,469]` = 1016x36 px (508x18 dp), 15.53:1.
7. "Effects" switch row `[80,481][1840,641]` = 1760x160 px (880x80 dp); switch itself
   ink `[1726,527][1833,594]` = 108x68 px (**54x34 dp**), state **on**, track fill
   `#2FCB74` (`good`), ink thumb; label ink `[84,514][223,531]` = 140x18 px
   (70x9 dp) and help ink `[84,535][1472,579]` = 1389x45 px (694.5x22.5 dp) =
   `ink` on `paper` 15.53:1.
8. "Mute" switch row `[80,657][1840,817]` = 1760x160 px (880x80 dp); switch ink
   `[1726,703][1833,770]` = 108x68 px (54x34 dp), state **off**, track `paper`, ink
   thumb; label ink `[84,690][185,708]` = 102x18 px (51x9 dp); help ink
   `[84,710][1070,754]` = 987x45 px (493.5x22.5 dp).
9. "Sounds" label ink `[83,832][219,862]` = 137x31 px (68.5x15.5 dp); value "80%"
   ink rows 834–860 (27 px = 13.5 dp), right-aligned, ink x 1749–1863 (the card's
   8 px ink border at x 1864–1871 bounds the scan). Slider track rows 920–933
   (**13 px = 6.5 dp**), x 128–1790 = 1662 px (831 dp); filled portion x 128–1476 =
   1348 px (674 dp) = 81.1% of the track. Thumb `[1409,879][1505,975]` =
   96x96 px (**48x48 dp**), fill `good`.
10. "Music" label ink `[84,995][197,1020]` = 114x26 px (57x13 dp); value "60%" ink
    `[1747,1000][1863,1077]`, its bottom 3 px from the viewport edge. Music thumb
    `[1078,1037][1174,1080]` = 96x96 px nominal (**48x48 dp**), **43 px of 96
    visible** — clipped by the viewport.

**primary action**: **absent**. No affirmative or primary control is rendered: the
screen holds one Back button (`48x48 dp`, `ink` on `background` **11.22:1**), a
3-segment Look control and four settings rows. Changes take effect on the dpad press
with no confirm step (observed: a single `keyevent 19` on the focused Music slider
moved it 60% → 70%, and one `keyevent 20` moved it back to 60%).

**secondary actions**: "Auto" / "Sunny" / "Night" (84/83.5/84 x 48 dp), "Effects"
switch (54x34 dp), "Mute" switch (54x34 dp), "Sounds" slider (831 dp track, 48 dp
thumb), "Music" slider (thumb 48 dp), "Back" (48x48 dp).

**text that wraps or truncates at this size, and how**
- No line wraps and no ellipsis on this screen: the longest help line is 1389 px
  (694.5 dp) "Moving backgrounds, shading and bounces. Turn off on a slow device."
  and fits one line in the 1642 px (821 dp) column between x=84 and the switch at
  x=1726.
- The card is taller than the viewport, so content is cut, not wrapped: the Music row
  starts at y=995 and its slider thumb is cut at y=1080 (43 of 96 px visible); the
  "60%" value's ink ends at y=1077, 3 px from the edge.
- No scroll bar or scroll affordance is drawn for the 875 px-tall card.

**states covered, and states missing (empty, error, waiting, dropped link)**
- Covered: Look = Auto selected with the rule text "Auto: Sunny from 7:00 to 19:00,
  Night otherwise"; Sunny and Night available but unselected; Effects **on**; Mute
  **off**; Sounds 80%; Music 60%.
- Missing: **error** — **absent**; **empty** — **absent** (no list on this screen);
  **waiting / dropped link** — **absent** (nothing on this screen depends on a
  controller); a **save / apply confirmation** — **absent** by design (values persist
  immediately); a **disabled** switch or slider state — **absent**.
- Focus: entry paint shows **no** focus ring on any control; the first
  `keyevent 20` rings the Music slider at the bottom of the card (its ring is cut by
  the viewport), passing over Auto/Sunny/Night/Effects/Mute. A following
  `keyevent 19` on that focused slider **changed its value** (60% → 70%) instead of
  moving focus, so the up/down path from a slider back to the rows above it is
  **unmeasured**, and a `keyevent 20` returned the value to 60%
  (`tv-07-look-focus.png`, `tv-09-look-restored.png`).

**cross-screen inconsistencies versus the other screens**
- Selected-state fill here is `caution` `#FFB020`; on the Party night screen the
  selected "3 rounds" pill is filled `#FFD23F` — the same `#FFD23F` used for the focus
  ring. So "selected" is `#FFB020` on this screen and `#FFD23F` two screens later.
- Switches are 54x34 dp; no other captured screen renders a switch or any control of
  that height. Every button on screens 1, 3 and 4 is 48 dp or 64 dp tall.
- This screen renders no `#2FCB74` (`good`) filled button, while screens 1, 3 and 4
  each render at least one ("Play"/"Save log", "Puzzle settings", the round-1 game
  button); the only way out is Back at x=0, a 48x48 dp target flush to the display
  edge.
- Content left margin is x=48 for the card and x=84 for its labels (36 px = 18 dp
  inset), against 8 / 20 / 48 dp margins on screen 1.
- Entry focus is absent here, as on screen 1, but present on screens 3 and 4.

---

## Record 3 — Play (game picker)

**screen / form factor / theme / viewport px**
Play / TV, landscape / Sunny / 1920x1080 px (960x540 dp), dp = px/2.

**elements in reading order, with pixel size and position**

1. Back arrow `[0,30][96,126]` = 96x96 px (48x48 dp); arrow ink 31x30 px.
2. Page title "Play": ink `[134,41][351,129]` = 218x89 px (109x44.5 dp), `#1E1646`
   on `#93D3FA` = **10.28:1** (`ink` on `background`).
3. Three game cards, paper `#FFF6E3`, 8 px ink outline, 16 px radius, all
   576x512 px (**288x256 dp**), tops at y=205:
   "Shape Race" `[48,205][624,717]`; "Arena" `[672,205][1248,717]`;
   "Party night" `[1296,205][1872,717]`. Horizontal gaps 48 px (24 dp).
   - Card 1 title "Shape Race" ink `[82,478][372,529]` = 291x52 px (145.5x26 dp);
     description line 1 ink `[83,561][574,599]` = 492x39 px (246x19.5 dp), line 2
     ink `[83,623][573,661]` = 491x39 px; line pitch 62 px (31 dp).
   - Card 2 title "Arena" ink `[705,479][858,517]` = 154x39 px; description line 1
     ink `[708,561][1119,599]` = 412x39 px, line 2 `[707,623][1116,661]` = 410x39 px.
   - Card 3 title "Party night" ink `[1331,478][1616,529]` = 286x52 px; description
     line 1 ink `[1330,561][1768,599]` = 439x39 px, line 2 `[1330,623][1478,653]` =
     149x31 px.
   - Each card's illustration sits above its title, 300–350 px wide.
   - All card title/description ink `#1E1646` on `#FFF6E3` = **15.53:1**
     (`ink` on `paper`).
4. Card 3 carries the entry focus: 8 px `#FFD23F` ring with a 3 px ink edge traced on
   the card's outer rectangle at `[1296,205]` (`tv-12-play.png`).
5. "Puzzle settings" button `[48,765][612,893]` = 564x128 px (**282x64 dp**), fill
   `#2FCB74` (`good`), 8 px ink outline; label + icon ink `[171,795][599,864]` =
   429x70 px (214.5x35 dp); ink on `good` = **7.88:1**.
6. Caption "For playtesting: tolerances, speeds and the time limit.": ink
   `[52,924][1168,962]` = 1117x39 px (558.5x19.5 dp), `ink` on `#A9DDFC` =
   **11.47:1** (`ink` on `background`).

**primary action**: "Party night" card at `[1296,205]`, 288x256 dp, and it is the only
card carrying the entry focus ring; label ink `#1E1646` on `#FFF6E3` = **15.53:1**
(`ink` on `paper`). No card is otherwise marked primary — all three are the same
288x256 dp with the same 52 px title ink, so the only signal is the focus ring.

**secondary actions**: "Back" (48x48 dp); "Shape Race" card (288x256 dp); "Arena" card
(288x256 dp); "Puzzle settings" (282x64 dp).

**text that wraps or truncates at this size, and how**
- Card 1 truncates with an ellipsis: "Carry, turn and drop the pieces to build the
  pict…" — 2 lines inside 492 px (246 dp) of a 576 px card; the ellipsis ends line 2 at
  x=573, 115 px short of the card's right ink border (x 688–695).
- Cards 2 and 3 wrap to 2 lines with no ellipsis ("Race past walls and / hazards to
  the goal."; "3 or 5 rounds, points, / awards"). Their line 2 ink is 410 px and
  149 px.
- Card titles fit one line at 52 px ink height (26 dp); "Party night" at 286 px is the
  widest and leaves 242 px of card width unused.
- All three descriptions start at the same y (561) so the three cards' text blocks are
  aligned even though card 1's text is cut.

**states covered, and states missing (empty, error, waiting, dropped link)**
- Covered: three game entries with title, one-line description and illustration;
  keyboard focus on one card; a separate playtesting entry point below the picker.
- Missing: **empty** (no games) — **absent**; **error / unavailable game** —
  **absent**; **disabled game** (e.g. needs controllers) — **absent**, all three cards
  are enabled with the same 52 px title ink; **controller count** — **absent** on this
  screen while screen 1 reported 0 connected; **waiting** — **absent**; **dropped
  link** — **absent**.
- No "join" screen is reachable from here: the picker leads to the Party night setup
  (record 4), which is the host's next step, and player joining happens through the
  pairing code on screen 1.

**cross-screen inconsistencies versus the other screens**
- Entry focus is present here (card 3) and on screen 4, but absent on screens 1 and 2.
- Card sizes differ on every screen: 288x256 dp here (three equal cards), 300x131 dp
  and 300x142 dp for the two visible award cards on screen 4, and 912x437.5 dp for the
  single settings card on screen 2.
- Control heights here are 48 dp (Back) and 64 dp (Puzzle settings); screen 1 mixes the
  same two heights, screen 4 uses 48 and 64 dp, screen 2 uses 48 dp plus 54x34 dp
  switches.
- Selected/focus colour: the focus ring `#FFD23F` here is the same value used as the
  selected fill on screen 4 and does not appear on screen 2.
- Card description colour is `ink` `#1E1646`; the Party night award bodies use
  `#615975`.

---

## Record 4 — Party night (setup)

**screen / form factor / theme / viewport px**
Party night setup / TV, landscape / Sunny / 1920x1080 px (960x540 dp), dp = px/2.

**elements in reading order, with pixel size and position**

1. Back arrow `[0,30][96,126]` = 96x96 px (48x48 dp).
2. Page title "Party night": ink `[134,41][701,139]` = 568x99 px (284x49.5 dp),
   `#1E1646` on `#A4DBFC` = **11.22:1** (`ink` on `background`).
3. Paper card `[48,205][1872,1080]`, 8 px ink outline (top border y 205–212); inside
   it, a full-width colour band `[48,213][1872,307]` = 1824x95 px (912x47.5 dp),
   fill `#A66CFF` (`player(3)`), no ink outline of its own; centred band label
   "Party night" ink `[817,241][1099,279]` = 283x39 px (141.5x19.5 dp), `ink` on
   `player(3)` = **4.94:1**.
4. "Rounds" label ink `[99,385][259,419]` = 161x35 px (80.5x17.5 dp), `ink` on
   `paper` = **15.53:1**.
5. Round-count pills, both 128 px (64 dp) tall:
   "3 rounds" `[96,461][415,589]` = 319x128 px (**159.5x64 dp**), **selected**:
   fill `#FFD23F`, label ink `[120,490][389,559]` = 270x70 px, ink on `#FFD23F` =
   **11.56:1**; it also carries the focus ring: at y=525 the scan reads ink x 90–92,
   `#FFD23F` x 93–99, ink x 100–106, `#FFD23F` x 107+, i.e. a 3 px ink edge, a 7 px
   `#FFD23F` ring, the pill's 7 px ink border, then the `#FFD23F` fill.
   "5 rounds" `[439,461][755,589]` = 316x128 px (**158x64 dp**), fill `#2FCB74`
   (`good`), label ink `[470,490][704,559]` = 235x70 px, ink on `good` = **7.88:1**.
   Gap between pills 24 px (12 dp).
6. "The night's three awards" label ink `[98,657][725,699]` = 628x43 px
   (314x21.5 dp), 15.53:1.
7. Award card 1 "Cat Catcher": `[96,741][695,1002]` = 600x262 px (**300x131 dp**);
   header band rows 749–843 = 95 px (47.5 dp), fill `#C0DBE7`; band label ink
   `[243,777][548,809]` = 306x33 px (153x16.5 dp), `ink` on `#C0DBE7` = 11.54:1,
   token pair **unmeasured** (`#C0DBE7` is not in §3). Body: paw icon in a filled
   circle plus "Most cats shooed" ink starting `[243,913]`, colour `#615975` on
   `#FFF6E3` = **6.12:1**, token pair **unmeasured** (`#615975` = `ink` at 70% alpha
   over `paper`; R 97, G 89, B 117 each solve to alpha 0.700 ± 0.001, and §3 has no
   70%-ink token).
8. Award card 2 "Comeback": `[728,741][1327,1024]` = 600x284 px (**300x142 dp**, 11 dp
   taller than card 1 because its body wraps);
   header band fill `#FFD6A8` (**unmeasured** token pair; not in §3); band label ink
   `[897,777][1156,809]` = 260x33 px; body 2 lines, line 1 ink `[880,893][1245,929]`,
   line 2 `[889,930][1079,974]`, colour `#615975`.
9. Award card 3 "Steady Roller": in the entry state only its top ink border is inside
   the viewport, at y 1057–1064, with its `#E4CDEB` band starting y=1065 — 15 px of a
   95 px band visible. In the scrolled state (`tv-14-party-scroll.png`) its top ink
   border is at y 379–385 and its band's bottom ink border at 483–489, and it reads
   "Steady Roller" / "Fewest coins dropped" on 2 lines.
10. "The cat visits the side that's ahead." ink `[180,735][999,759]` in the scrolled
    state = 820x25 px (410x12.5 dp), with a filled pink circle icon at x 96–180.
11. "Pick round 1" label ink `[99,868][397,907]` in the scrolled state = 299x40 px
    (149.5x20 dp).
12. Round-1 game button "Shape Race" `[96,952][1016,1080]` in the scrolled state =
    920x128 px (**460x64 dp**), fill `#2FCB74` (`good`), focus ring present (3 px ink
    edge at y 950–952, 7 px `#FFD23F` at 953–959, pill ink border 960–967), bottom
    ring line at y 1079 of 1080 — the ring's outer edge sits 1 px from the viewport
    edge.

**primary action**: "Shape Race" button under "Pick round 1", 460x64 dp, ink `#1E1646`
on `#2FCB74` = **7.88:1** (`ink` on `good`) — **not visible at entry**. The entry
state's scroll offset is 678 px (award card 3's top border moves 1057 → 379 between
`tv-13-party.png` and `tv-14-party-scroll.png`), so at entry the "Pick round 1" label
sits at y = 868 + 678 = 1546, **466 px (233 dp) below the viewport bottom**. No other
affirmative control exists on the entry screen.

**secondary actions**: "Back" (48x48 dp); "3 rounds" (159.5x64 dp); "5 rounds"
(158x64 dp). The three award cards are informational, not actionable (no a11y node).

**text that wraps or truncates at this size, and how**
- "Most points in the last round" wraps to 2 lines in the 600 px (300 dp) card: line 1
  ink 366 px, line 2 191 px.
- "Fewest coins dropped" wraps to 2 lines in the same 300 dp width.
- "Most cats shooed" stays on 1 line (357 px ink).
- No ellipsis truncation on this screen; the cut is vertical, by the viewport: the
  third award card's 95 px header band is 15 px visible at entry, and the primary
  action button is 466 px below the fold at entry and 1 px from the edge once
  scrolled.
- The 912 dp-wide card carries a 300 dp award column; the two-card award row ends at
  x=1327 and the card's inner right edge is x=1864, so 537 px (268.5 dp) of card width
  is empty to the right of the award row.

**states covered, and states missing (empty, error, waiting, dropped link)**
- Covered: rounds = 3 (selected) with 5 available; all three awards with their rule
  text; the cat rule; the round-1 game choice; entry focus ring on "3 rounds"; a
  focused ring on the round-1 button after one down press.
- Missing: **waiting / no controllers** — **absent**: with screen 1 reporting
  "Controllers · 0 connected", this screen still presents "Pick round 1" and a
  playable "Shape Race" button and shows no controller count, no "connect a phone"
  copy and no disabled state; **empty** — **absent**; **error** — **absent**;
  **dropped link** — **absent**; a **scroll indicator** for the 678 px of content
  below the fold — **absent**.

**cross-screen inconsistencies versus the other screens**
- Selected fill is `#FFD23F` here and `#FFB020` (`caution`) on screen 2; `#FFD23F` is
  also the focus-ring colour, so on this screen the selected pill's fill and its focus
  ring are the same value and only the 7 px ink border separates them.
- Three card-header band colours (`#C0DBE7`, `#FFD6A8`, `#E4CDEB`) appear on the three
  award cards and none is a §3 token; the one full-width band is `#A66CFF`
  (`player(3)`). No other screen uses a coloured card header.
- Award body text is `#615975` (6.12:1) while every other body text on this device is
  `#1E1646` (15.53:1).
- The page's own title is at x=134 while the award cards begin at x=96 and the round
  pills at x=96/439 — a 38 px offset between the heading and the content column, where
  screen 1 offsets its heading by 56 px and screen 3 by 86 px.
- Like screen 2, the entry screen hides its affirmative action below the viewport; on
  screen 2 the hidden part is the last setting, here it is the primary button.
- Fixed sizes differ from the other screens' selected controls: round pills are 64 dp
  tall against 48 dp for the segmented control on screen 2 and 48 dp for the shell's
  pills.

---

## Not reached

- The lobby / round-1 "join" screen behind "Pick round 1 → Shape Race", and any
  results, round-end or re-entry-after-drop host screen: **not captured** — the brief
  capped this pass at three further distinct screens, which were the settings, the
  picker and the Party night setup.
- The "Stats" and "Latency" screens from the shell's pill row, and "Puzzle settings"
  from the picker: not captured for the same reason. Both shell pills took focus with
  `keyevent 22` (`tv-05-right2.png` shows "Look and sound" focused after two rights
  from "Haptic test", so "Latency" is one press from "Haptic test").
- No captured screen refused a dpad move: every press of `keyevent 19/20/21/22` moved
  focus or scrolled, and both below-the-fold regions (screen 2's Music row, screen 4's
  "Pick round 1") came into view on a single `keyevent 20`.
