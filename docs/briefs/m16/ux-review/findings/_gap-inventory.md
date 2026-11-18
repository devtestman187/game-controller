# M16 UX review — per-stage gap inventory

Scope: the six visual-findings files only. No ranking, no recommendation. Every claim carries a
number or a named token and its source file. Sources: `vf-tv-01` (TV, 1920x1080 px = 960x540 dp,
dp = px/2, Sunny), `vf-tab-01` (tablet at native, 2560x1600 px = 1157.1x723.2 dp, dp = px/2.2125,
Sunny), `vf-matrix-phones` (tablet at density 160, 6 sizes, px = dp), `vf-matrix-tablets` (tablet at
density 160, 4 sizes, px = dp), `vf-2dev-lifecycle` (both devices, native), `vf-2dev-round` (both
devices, native). "R1" = Record 1 in the cited file; "§n" = that file's section n.

Basis note that applies to the whole inventory: the same TV screen and the same tablet pad were
measured in more than one pass and the numbers do not agree (see **Cross-cutting 10**). Numbers from
different passes are therefore not interchangeable even where they describe the same screen.

---

## 1. Launch / first run

**Current**
Tablet paints the pad/connect screen 4.0 s after `am start`: pill 291.5x43.4 dp at (26,14), label
"Connecting... · tap to connect" 517x34 px, ink on `background` 9.12:1; 11 pad inputs, left disc
187.1 dp against right disc 150.5 dp (vf-tab-01 R1; vf-2dev-round R7). TV paints the host shell with
one 4-digit pairing code (digit ink 307x80 px in a 314x160 px box — vf-tv-01 R1; 349x141 px "1219" —
vf-2dev-lifecycle R1) on a 960x540 dp surface.

**Defects**
- Pill fill `#7CC8F8` is 2/255 from the sky outside it (`#7EC9F8`): the shape is carried by the 2 px
  ink outline alone (vf-tab-01 R1 #1).
- Visible string "Connecting..." against a11y label "Not connected · tap to connect" on the same
  element (vf-tab-01 R1 states; vf-matrix-phones R1 states; vf-2dev-lifecycle §8).
- At 667x375 the pill label truncates: "Connecting... · tap to con…" 208x16 px, ends 22 px before the
  pill's right outline (vf-matrix-phones R1 text; matrix row "pill label right gap = 22").
- Mode control touch height 40 dp at all 6 phone sizes and all 4 tablet sizes, against a 48 dp
  minimum; every other published target is 48x48 dp (vf-matrix-phones summary; vf-matrix-tablets
  summary).
- Portrait 375x667 draws no pad: "Make the window bigger" gate = 23x24 px glyph, 217x18 px title,
  3 body lines (330/327/124 px), black unpainted bands y0–194 and y472–666, no ignore/continue
  (vf-matrix-phones "The portrait gate").
- Pad has no title, no back/close affordance and no navigation (vf-tab-01 R1 cross 7; vf-matrix-tablets
  R1 #8; vf-matrix-phones summary).
- One screen, two outline weights: 6 px (2.7 dp) on the 11 inputs against 2 px (0.9 dp) on the pill and
  mode control at 354 dpi; 4 px against 1–2 px at 160 dpi; §3 states 3 px (vf-tab-01 R1 cross 1;
  vf-matrix-tablets R1 cross 1).
- TV shell: "Address for manual entry" clipped, not wrapped — 15 px (7.5 dp) of the line inside the
  ScrollView whose bottom edge is y=801 (vf-tv-01 R1 text).
- TV shell: no focus ring on first paint (initial focus absent), while the picker and Party night paint
  one at entry (vf-tv-01 R1 cross 5).
- TV shell a11y strings carry a double-encoded dot: `Controllers Â· 0 connected` (vf-tv-01 R1 cross 1).
- TV shell header reads "Controllers · 0 connected" while the card shows one remembered device row
  "Laksh / ios · 0.14.0+835 · …" with an 8 dp `bad` dot and "Disconnected" — no label distinguishes
  remembered from connected (vf-tv-01 R1 #7–9, states).

## 2. Host setup

**Current**
TV setup is three surfaces: shell (5 pills, 379 / 322 / 473 / 347 / 262 px wide, 96 px = 48 dp tall —
vf-tv-01 R1 #4), Look and sound (paper card 1824x875 px = 912x437.5 dp, top y=205 — vf-tv-01 R2),
Party night setup (band 1824x95 px `player(3)` `#A66CFF` — vf-tv-01 R4). Tablet setup is one scrolling
Settings page of 4 cards and 7 sliders: switches 52.9x33.0 dp, tracks 474.6 / 449.3 dp, `Defaults`
97.2x39.8 dp (vf-tab-01 R2). TV switches are 54x34 dp and the Sounds track 831 dp (vf-tv-01 R2).

**Defects**
- TV Look and sound: primary action absent; the only exit is Back 48x48 dp flush to x=0 (vf-tv-01 R2
  primary, cross 3).
- TV Look and sound: card 875 px tall against a 1080 px viewport — the Music thumb shows 43 of 96 px,
  the "60%" ink ends 3 px from the edge, and no scroll bar or affordance is drawn (vf-tv-01 R2 text).
- TV Look and sound focus: entry paint has no ring; the first `keyevent 20` rings Music at the card's
  bottom (ring cut by the viewport) and that press changed the value 60% → 70% instead of moving
  focus; the up/down path from a slider is `unmeasured` (vf-tv-01 R2 states/focus).
- TV: no save/apply confirmation (by design), no disabled switch or slider (vf-tv-01 R2 states).
- TV selected fill is `caution` `#FFB020` here, `#FFD23F` on Party night; `#FFD23F` is also the focus
  ring (vf-tv-01 R2 cross 1; R4 cross 1).
- Tablet Settings: 5 of 7 sliders publish an a11y value that differs from the label — Sensitivity
  "33%" vs 1.00×, Gyro dead zone "20%" vs 5%, Smoothing "56%" vs 50%, Button size "38%" vs 75%,
  Sticks dead zone "25%" vs 10% (vf-tab-01 R2 cross 8).
- Tablet Settings: Sticks dead-zone track 10 of 14 px visible, thumb 24 of 43 px; Nickname field bottom
  edge below the viewport; "0 / 10" counter a 4 px sliver (vf-tab-01 R2 #37, #41–42).
- Tablet Settings: no commit/save action; error, loading, disabled, saving and scroll-indicator states
  absent (vf-tab-01 R2 primary, states).
- Tablet Settings: card widths in one column differ — Gyro 1171 px against Sticks 1227 px; Look and
  sound 1226 px at x36 against You 970 px at x164 (vf-tab-01 R2 cross 4).
- Tablet Settings: a11y traversal interleaves the two columns (Back → Settings → Defaults → "Look and
  sound" → "Gyro" → …) (vf-tab-01 R2 cross 9).
- `#615975` muted text (3 runs on the tablet, the controller meta line on the TV) is not a §3 token;
  6.12:1 on paper, 4.16:1 on the tablet sky (vf-tab-01 R2 cross 3; vf-2dev-round §15).
- `Defaults` is the only `player1` `#2E9BF0`-filled pill on the tablet at 97.2x39.8 dp and sits 2 px
  (0.9 dp) from the viewport edge (vf-tab-01 R2 #3).
- This tablet surface covers none of the 13 stages directly; it configures stage 8 and stages 7 / 9–11
  (vf-tab-01 R2 flow-stage note).

## 3. Party join

**Current**
TV join screen "Shape Race · Fish": Left/Right headers 896x105 px each (448x52.5 dp), dashed slots
labelled "Room for 2 more", `Start` 137.5x48 dp focused, footer "Nobody has joined yet." 470x39 px
(vf-2dev-lifecycle R4). Tablet: `A Join` 78.6x78.6 dp; the TV reports `Not joined: P1 Phone 1719`
553x39 px (vf-2dev-lifecycle R4 state 2; vf-2dev-round R7). A night's Bumper round replaces that
surface with the Arena waiting card, `Code 1219` chip 276x112 px (vf-2dev-round R1).

**Defects**
- The TV join screen carries no pairing code; the code exists only on the host shell (vf-tv-01 R1) and
  on the Arena waiting card (vf-2dev-round R1 #5); a player on the join screen cannot read it
  (vf-2dev-lifecycle R4 cross 1; absent list).
- Tablet first tap of the pill targets the remembered host `DESKTOP-NSUCJ8S` and fails after 4.000000 s
  with `HTTP connection timed out … port: 45780`; the discovered row is `Thumb Party TV (Android TV)` /
  `TV · 192.168.1.100:45780` 594.4x71.9 dp (vf-2dev-lifecycle R5 #7–10, §1).
- Code entry: 4-digit field 170.8x71.4 dp; the app pairs on the 4th digit with `Pair` (69.1x32.1 dp)
  never pressed (vf-2dev-lifecycle R6).
- `Pair` 32.1 dp and `Connect` 32.1 dp against 47.9 dp for the same screen's other buttons and 48 dp
  for the TV's pills (vf-2dev-lifecycle R6 cross 2; vf-2dev-round R11 cross 2).
- Wrong-code error absent; "pairing…" progress between the 4th digit and the connected pad absent
  (vf-2dev-lifecycle R6 states).
- No QR code and no TV-side accept prompt on the path (vf-2dev-lifecycle §1).
- Joined-row badge is `player(1)` `#2E9BF0`, the same token as the Left card header it sits in
  (vf-2dev-lifecycle R4 cross 4).
- Readiness by word colour only: `good` "Ready" 1.97:1 against `#615975` "Not ready yet" 6.12:1 on
  `paper` (vf-2dev-round R1 #13, cross 2).
- `#9A919C` dashed slot outlines 2.83:1 on paper; `#615975` slot labels; `#FF9800` arrow tiles — none in
  §3, all `unmeasured` (vf-2dev-lifecycle R4 #8–9, #6).
- Disabled `Start` absent; `Start` was never activated with 0 players, so its behaviour is `unmeasured`
  (vf-2dev-lifecycle R4 primary).

## 4. Player creation / colour & accessory

**Current — not captured live.**
No colour or accessory control is drawn in any of the six files, and no nickname editor is shown on
either device. The only live player-identity surface is the tablet Settings "You" card: Nickname field
351.2 dp wide, empty (0 of 10 characters, no placeholder drawn), counter "0 / 10" clipped to a 4 px
sliver (vf-tab-01 R2 #40–42). Static sources that cover the stage: `docs/design/look-mockups/`
`m14-sunny-17-phone-settings.png` and `m14-sunny-18-phone-colour-taken.png` (mockups; named as the
phone settings and "your colour is taken" frames in `docs/briefs/m14/m1c-mockups-report.md`; not
measured in this pass).

**Defects**
- No live colour, accessory or nickname picker; the only name that appears anywhere is the
  device-derived `P1 Phone 1719`, drawn on the TV and not editable there (vf-2dev-round R1 #9;
  vf-2dev-lifecycle §9).
- The nickname field's own counter is 4 px of 4 px visible and its bottom edge is below the viewport
  (vf-tab-01 R2 #41–42).
- TV joined rows carry a number badge and no colour or accessory chip (vf-2dev-lifecycle §10 absent
  list; vf-2dev-round R7 #1).

## 5. Lobby & waiting

**Current**
TV waiting surface is the join screen footer "1 player. Press A or Start to begin." (ink
715,946–1500,999 px) — vf-2dev-lifecycle R4 state 3 — or, for a night's Bumper round, the Arena waiting
card: header band 1808x96 px `player(2)` `#FF8A1F`, `Bumper` 275x108 px selected `star`, `Code 1219`,
P1 badge 92x99 px plus "Not ready yet", `Medium` selected, "Map" heading cut at y 1034–1079
(vf-2dev-round R1). Tablet holds the connected pad: badge "1" 68x75 px, `A Join`→`A Start`,
`B Back`→`Leave` 78.6x78.6 dp (vf-2dev-round R7; vf-2dev-lifecycle §9).

**Defects**
- No `Start`/confirm control on the Arena waiting card; the round starts when the player row
  (824.5x55.5 dp counting its ring) is pressed (vf-2dev-round R1 primary, cross 1).
- The card has no empty state, no "waiting for other players" line, no map name, no ready ✓/✗ disc, no
  error or lost-link state (vf-2dev-round R1 states).
- Only one human player is ever drawn; a 2nd, 3rd or 4th joined player is absent (vf-2dev-lifecycle
  §10 absent list).
- Pill heights inside one card differ by 17 dp: mode 54 dp and `Back` 54 dp against Robo levels 37 dp
  (vf-2dev-round R1 cross 4).
- The tablet shows no player count and no other player: badge "1" and a ping only (vf-2dev-round R7
  states).
- This card is the only TV round screen that shows the code, and the Shape Race join screen shows none
  (vf-2dev-round R1 cross 5).
- The card scrolls with no indicator ("Map" heading and everything under it past y 1079) (vf-2dev-round
  R1 text).

## 6. Game selection

**Current**
TV Play picker: three `paper` cards — `Shape Race`, `Arena`, `Party night` — 576x512 px (288x256 dp) at
y=205 with 48 px gaps, entry focus ring 8 px `#FFD23F` on card 3, `Puzzle settings` 282x64 dp below
(vf-tv-01 R3). A second selection surface repeats game choice at Party night: `Pick round 1` →
`Shape Race` 460x64 dp, 466 px (233 dp) below the viewport at entry (vf-tv-01 R4 #11–12, primary).

**Defects**
- Card 1's description truncates with an ellipsis ("…pict…", ends 115 px short of the card's right ink
  border) — vf-tv-01 R3 text; vf-2dev-lifecycle R2 text records the same ellipsis after "pict".
- No card is marked primary: all three 288x256 dp with the same 52 px title ink; the focus ring is the
  only signal (vf-tv-01 R3 primary).
- No controller count on the picker while the shell reported "Controllers · 0 connected" (vf-tv-01 R3
  states).
- Empty, error/unavailable, disabled, in-progress and loading card states absent (vf-tv-01 R3 states;
  vf-2dev-lifecycle R2 states).
- `Puzzle settings` — a developer entry — is a `good` pill at bottom-left, the position the join screen
  gives `Start` (vf-2dev-lifecycle R2 cross 3).
- Party night hides its only affirmative action: at entry the "Pick round 1" label sits at y=1546,
  466 px (233 dp) below the viewport bottom; the round-1 button's ring outer edge then sits 1 px from
  the viewport edge when scrolled (vf-tv-01 R4 text, primary).
- The night's round-1 list offers `Bumper` alone on a night card — no `Race` button and no map or
  "Surprise me" choice above the fold (vf-2dev-round §1 row 1).

## 7. Round intro / countdown

**Current**
TV `Get ready 3` → `2`: `paper` card 384x625 px (192x312.5 dp) at (768,228), numeral 176x231 px
(88x115.5 dp) ink on `paper` 15.53:1, over a 1920x964 px field; the HUD band is 1920x108 px (960x54 dp)
and carries `Round 1`, `60.0 s`, `Best –` (vf-2dev-round R2). The tablet shows no countdown: its pad
reads `A OK` / `B Back` (vf-2dev-round §16 row 7, R10).

**Defects**
- HUD band grows 108 → 284 px and the field's top edge moves y 116 → 290 (174 px = 87 dp) in one frame
  when the countdown ends (vf-2dev-round R2 cross 1; §14.2).
- The countdown card is `paper` with no coloured header band, while the pause card (`star`) and the
  results card (`player(2)`) both have one (vf-2dev-round R2 cross 2).
- `Round 1` here carries no "of 3"; the scoreboard reads `Round 1 of 3`; the results card carries no
  round number at all (vf-2dev-round R2 cross 3).
- No player rows exist during the countdown (vf-2dev-round R2 states).
- No skip/confirm control and no sound/effects indicator; the skip behaviour of `23`/`66`/`108` is
  `unmeasured` (vf-2dev-round R2 primary).
- Whether the tablet's `Pause` works during the countdown is `unmeasured` (the captured pause was at
  58.1 s) — vf-2dev-round R2 secondary.
- The tablet carries no round-intro state at all (vf-2dev-round §16 row 7).

## 8. In-round controls

**Current**
Tablet: `A Dash` 78.6x78.6 dp (ink on `good` 7.88:1), centre pill `Pause` 62.4x36.6 dp, latency line
602x33 px (272.1x14.9 dp), three dashed 174x174 px face circles, no clock and no score (vf-2dev-round
R8). TV: 1920x284 px HUD (`Round 1` 190x40 px, clock 138x39 px, `Best –` 153x39 px, coin counts 0 and
24) over a 1920x790 px field; no TV control in-round (vf-2dev-round R3).

**Defects**
- The tablet carries no clock, coin count, score, round number or dash readiness: never a time, never
  the 0-vs-24 count the TV was drawing (vf-2dev-round R8 states; §14.1).
- The TV reads `Dash ready (A)` / `Dash in 0.8 s`; the pad's `A` reads only `Dash` (vf-2dev-round R8
  cross 2).
- Clock stays ink `#1E1646` at 6.6 s left and at 45.8 s; §3 reserves `bad` for the last 15 s
  (vf-2dev-round R3 cross 3; §14.5).
- `Best –` never fills across two whole rounds, beside a live clock (vf-2dev-round R3 cross 2; §14.4).
- Dashed empty face circles `#6990BB` on `background` = 1.82:1, under the 3:1 non-text bar; the same
  circle treatment stands for three different absent buttons (vf-2dev-round R8 #11, cross 3).
- `B` reads `Back` on the connected pad and is an unlabelled dashed circle in-round (vf-2dev-round R7
  cross 2; R8 #11).
- Mode control stays live in-round at 299.7x31.2 dp with `Sticks` selected and no confirmation
  (vf-2dev-round R8 cross 4).
- Paused: `Resume` is `good` on the TV card (7.88:1), `bad` on the tablet's `B` (5.15:1) and plain ink
  on a third `Resume` pill, in the same second (vf-2dev-round R9 cross 1).
- Paused: the TV dims the whole surface (scrim samples `#536265`, `#757168`, `#75510F` — none a §3
  token) while the tablet neither dims nor shows the word "Paused" (vf-2dev-round R9 states, cross 2;
  R4).
- `Quit` exists only on the TV; the phone has no leave control (vf-2dev-round R9 cross 3).
- Pause pills are 54–56 dp against 48 dp on the results card and 54 dp on the waiting card
  (vf-2dev-round R4 cross 4).
- No map name on any in-round surface, though two different maps were played (vf-2dev-round R3 states;
  §14.6).
- Pad body, measured once and reused: left disc 187.1 dp against right 150.5 dp, knobs 72.8 and 56.9 dp
  (vf-tab-01 R1 #13, #20); knob `#69A1D1` 2.57:1, D-pad centre disc `#B0A8AC` 2.16:1, triangles
  `#8E8694` 3.26:1 on `paper` — two under the 3:1 control-part bar (vf-matrix-phones R1; vf-matrix-tablets
  summary).
- The pad is a fixed-dp layout: all 30 boxes identical from 1133x744 to 1366x1024, with the 65.9 %
  viewport-area growth absorbed by empty middle (vf-matrix-tablets matrix); it shrinks only below 430 px
  height (57 px face buttons at 667x375 against 85 px at 932x430) (vf-matrix-phones matrix).
- At 667x375 the face cluster is 57 px against 72 px at 800x360 — 15 px (21 %) smaller on a viewport
  15 px taller; it is the only cluster that loses size to width (vf-matrix-phones matrix note).
- LB, RB, Select, Start, both sticks, the D-pad and A/B/X/Y publish no touch target (`clickable=false`);
  only 7 nodes on the pad have one (vf-matrix-phones summary; vf-matrix-tablets summary).

## 9. Round end

**Current**
TV: the clock reaches `0.0 s` and the results card appears over the still-live HUD and field — card
840x586 px (420x293 dp) at (540,247), header band `player(2)` `#FF8A1F` 824x95 px (vf-2dev-round R5;
§1 row 6). Tablet: nothing changes — `A OK` / `B Back` 78.6 dp with the centre pill absent
(vf-2dev-round R10).

**Defects**
- The card overlaps the HUD: its top edge y=247 sits above the HUD's bottom y=284, cutting the bottom
  8 px of the third row mid-glyph (vf-2dev-round R5 text; §14.9).
- The results card carries no round number and no map name (vf-2dev-round R5 states).
- Tie, "no winner" and "nobody scored" states absent (vf-2dev-round R5 states; §15).
- Nothing marks the round's end on the tablet; the centre pill disappears with no replacement label
  (vf-2dev-round R10 cross 2).
- Whether the phone's `A OK` presses the TV's `Next` is `unmeasured` — the card was advanced with the
  remote's `23` (vf-2dev-round R10 primary).

## 10. Results / scoreboard

**Current**
TV results card: `Robo wins!` 266x39 px ink on `player(2)` 7.08:1; rows "P1 Phone 1719 0 coins" and
"Robo 22 coins", both right-aligned to x 1329; `Next` 147.5x63 dp focused, `End night` 196.5x54.5 dp
(vf-2dev-round R5). Scoreboard: card 1798x875+ px, band `player(4)` `#14C8A0` 1784x95 px, `Round 1 of
3` → `Round 2 of 3`, rows `1 Robo ★27 +27` / `2 Phone 1719 ★0`, double-points banner 874x111 px
(vf-2dev-round R6).

**Defects**
- Rows have no alignment grid: coin icons at x 1056 and x 1023 (33 px = 16.5 dp apart) while both coin
  labels share x 1329 (vf-2dev-round R5 text).
- Card totals coins, scoreboard totals points, and no surface converts one to the other: 22 coins → +27,
  38 coins → +43 (vf-2dev-round R5 cross 1; §14.8).
- Round numbering: the HUD and the results card drew `Round 1` for both rounds while the scoreboard
  read `Round 1 of 3` then `Round 2 of 3` (vf-2dev-round §14.3; R6 cross 1).
- `+43` is `good` text on `paper` = 1.97:1, the pass's minimum text ratio (vf-2dev-round R6 #12,
  cross 2).
- The night's three awards (`Round Winner`, `Try Again`, `Big Bopper`) are never shown or tracked on the
  scoreboard that follows them (vf-2dev-round R6 states; §15).
- The scoreboard has no `End night`, no settings and no per-round history; the card continues past
  y 1080 with no scroll indicator (vf-2dev-round R6 secondary, text).
- The banner's label is 860 px inside an 874 px pill — 7 px (3.5 dp) each side, the pass's smallest
  measured label padding (vf-2dev-round R6 text).
- `player(4)` `#14C8A0` means "player 4" everywhere else and "the night's scoreboard" here
  (vf-2dev-round R6 cross 3).
- The tablet at results and at the scoreboard carries no winner, no coins, no points, no round number,
  no "OK = Next" hint and no between-rounds state (vf-2dev-round R10 states).
- The three award header bands on the setup card are `#C0DBE7`, `#FFD6A8`, `#E4CDEB`, none a §3 token
  (raw ink 11.54 / 12.27 / 11.31:1) — the same awards that never reappear (vf-tv-01 R4 #7–9;
  vf-2dev-lifecycle §10).

## 11. Next round / Play again

**Current**
TV: `Next` 147.5x63 dp counting its ring (fill 132x47.5 dp) and `End night` 196.5x54.5 dp on the
results card; on the scoreboard two round pills — `Shape Race` fill 460x48 dp inside a 474.5x63 dp ring
footprint and `Bumper Round` fill 442x48 dp — each start the next round directly (vf-2dev-round R5
primary; R6 primary).

**Defects**
- One press both picks and starts the next round: no confirm and no request for the second player's
  readiness (vf-2dev-round R6 primary; §14.10).
- Focus grows the fill, not only the ring: focused `Shape Race` 920 px against unfocused
  `Bumper Round` 884 px — 18 px inset each side (vf-2dev-round R6 primary).
- Two left edges for the pills (ring x 93, fill x 108) against the card's x 60 and the title's x 131
  (vf-2dev-round R6 cross 5).
- `Bumper Round`'s pill is cut by the viewport at y 1013–1080 (899x67 px visible) (vf-2dev-round R6
  #18).
- No "play again" for the same round type: the pills re-pick a game instead (vf-2dev-round R6 states).
- No `End night`, settings or awards control on the scoreboard at two-thirds of the night
  (vf-2dev-round R6 secondary).
- The tablet shows no next-round choice and no round number at this stage (vf-2dev-round R10; §16
  row 11).

## 12. End of night

**Current — not captured live.**
`End night` is drawn at 196.5x54.5 dp on the results card (vf-2dev-round R5 #15) but was not pressed
(vf-2dev-round §1 row 9). No end-of-night screen, awards reveal or final standings appears in any of the
six files. Static sources that cover the stage: `docs/design/look-mockups/m14-sunny-07-final-scores.png`
(final scores) and `m14-sunny-06-award.png` (award reveal); neither was measured in this pass.

**Defects**
- The awards promised on the setup card are never shown again: `Cat Catcher` / `Comeback` /
  `Steady Roller` with their rule text (vf-tv-01 R4 #6–9) and the same three cards named `Round Winner`
  / `Try Again` / `Big Bopper` in the other pass (vf-2dev-lifecycle R3 #9–13) do not appear on the
  scoreboard (vf-2dev-round R6 states).
- No end-of-night action exists on the scoreboard (vf-2dev-round R6 secondary, §15 absent list).

## 13. Re-entry after a drop

**Current**
`am force-stop` while joined: at +0.9 s the TV is the fully empty join screen (`Room for 2 more` ×2,
`Nobody has joined yet.`), unchanged at +5 s and +15 s (vf-2dev-lifecycle R4 state 4, §9 state 3).
Relaunch: the tablet goes straight to the connected pad (`Android TV · 5 ms`, badge 1, `A Join`,
`B Back`) with no code and no re-entry screen; the TV shows `Not joined: P1 Phone 1719` and the side is
not restored (vf-2dev-lifecycle §9 state 4).

**Defects**
- No dropped-link, "player left" or away indication on the TV: the slot simply disappears at +0.9 s
  (vf-2dev-lifecycle R4 state 4; §10 absent list).
- The side choice is not restored after auto-reconnect: `A` must be pressed again to rejoin Left
  (vf-2dev-lifecycle §9 state 4).
- Host away (TV HOME): the tablet keeps the joined pad at +5 / +15 / +45 s with live latency
  9 / 9 / 10 ms, `A Start` / `B Leave`, and no host-away card or dimming appears (vf-2dev-lifecycle §9
  state 5).
- Relaunch leaves no reconnected or welcome-back marker: the pad is identical to a first connect except
  the ping (vf-2dev-lifecycle §9 state 4; vf-2dev-round R7).
- The TV host keeps the pairing card's scroll offset on re-entry: `New code` and `Simulate controller`
  stay visible and the code `0 4 1 4` is scrolled out (vf-tv-01 R1 cross 6, `tv-15-final-shell.png`).
- No wrong-code or reconnecting state on the tablet; no "pairing…" progress between the 4th digit and
  the connected pad (vf-2dev-lifecycle R6 states; vf-2dev-round R11 states).
- Re-entry reproduces the pad's launch geometry at every size: 11 inputs, no title, no back affordance
  (vf-matrix-tablets R1 #8; vf-matrix-phones summary).

---

## Cross-cutting

1. **The tablet carries no round data, at any stage 7–11.** Across five tablet captures in two rounds
   the pad showed `A Dash` / `A OK`, a ping and a `Pause` / `Resume` pill; the TV showed the clock, both
   coin counts, the dash state and the winner. No clock, coin count, points, round number or winner ever
   crossed to the controller (vf-2dev-round §14.1, R8, R10).

2. **Round numbering disagreement.** HUD `Round 1` and the results card (no number) for round 2, while
   the scoreboard reads `Round 2 of 3` after the same round; the HUD and results card also omit the
   "/ 3" suffix the scoreboard uses (vf-2dev-round §14.3, R3 cross 1, R6 cross 1, R2 cross 3).

3. **Code on the shell, silence on the join screen.** The 4-digit code is drawn on the host shell
   (vf-tv-01 R1 #6) and on the Arena waiting card (`Code 1219`, 138x56 dp — vf-2dev-round R1 #5), but
   not on the Shape Race join screen (vf-2dev-lifecycle R4 cross 1) and nowhere on the tablet
   (vf-2dev-round R7 states, §15).

4. **Resume is green on the TV and red on the phone.** TV `Resume` pill (180x56 dp, `good`, 7.88:1);
   tablet `B Resume` (78.6x78.6 dp, `bad`, 5.15:1); a third `Resume` in plain ink on the centre pill
   (vf-2dev-round R9 cross 1, R4 #8).

5. **Four names for the host.** `Android TV` (pad pill, 213.3x42.5 dp — vf-2dev-round R7), `Thumb Party
   TV (Android TV)` (discovered row and TV self-title — vf-2dev-round R11 #10, vf-tv-01 R1 #1),
   `Connected to Android TV` in the same frame as that row (vf-2dev-round R11 #15, cross 1), and
   `DESKTOP-NSUCJ8S` (error text — vf-2dev-lifecycle R5 #8).

6. **`star` `#FFD23F` carries three meanings.** Focus ring (picker, Party night, join screen, scoreboard,
   pause card: 7–8 px bands — vf-tv-01 R1, R3 #4), selected fill (`3 rounds` 11.56:1, `Medium`, the
   double-points banner — vf-2dev-round R1 #4, #17; R6 #6), and the `Y` face-button fill (11.56:1 —
   vf-tab-01 R1 #14).

7. **"Selected" is two different fills.** `caution` `#FFB020` on TV Look and sound (Auto) and on the
   pad's mode segment (vf-tv-01 R2 #5; vf-tab-01 R1 #7), `#FFD23F` on Party night's `3 rounds` and the
   Arena's `Medium` (vf-tv-01 R4 #5; vf-2dev-round R1 #17).

8. **Outline weight against §3's 3 px.** 6 px (2.7 dp) vs 2 px (0.9 dp) at 354 dpi (vf-tab-01 R1 cross
   1); 4 px vs 1–2 px at 160 dpi (vf-matrix-tablets R1 cross 1); 3 px vs ≈1.5 px (vf-matrix-phones R1
   cross 1); 7–8 px (3.5–4 dp) on every TV control (vf-tv-01 R1 measurement note).

9. **Filled-pill heights across surfaces (dp).** 30 (shell pills, vf-2dev-lifecycle R1) / 32.1 (`Pair`,
   `Connect`, `Cancel` — vf-2dev-lifecycle R6) / 36.6 (centre pill — vf-2dev-round R8) / 37 (Robo
   levels — vf-2dev-round R1) / 38.9–39.8 (`Disconnect`, `Defaults` — vf-2dev-round R11; vf-tab-01 R2)
   / 42.5 (pad connection pill) / 46–48 (TV round pills, `Start`, `Next` fill) / 54–56 (waiting and
   pause cards) / 47.9 (tablet buttons) / 63–64 (`Next` with ring, `Puzzle settings`, round-1 `Shape
   Race`). §3 names one button size (vf-tab-01 R1 cross 2).

10. **The same screen measured differently in two passes** — treat these pairs as evidence-base
    differences, not as change over time:
    - TV shell: `Play` 246x96 px / pills 96 px tall (vf-tv-01 R1) against `Play` 210x60 px / pills 60 px
      tall (vf-2dev-lifecycle R1); code box 314x160 px against 349x141 px; instruction pitch 62 px
      against 45 px.
    - TV picker: cards 576x512 px, gaps 48 px, tops y=205 (vf-tv-01 R3) against 560x495 px, gaps 65 px,
      tops y=213 (vf-2dev-lifecycle R2); `Puzzle settings` 282x64 dp against 264x46 dp.
    - TV Party night: round pills 159.5x64 and 158x64 dp (vf-tv-01 R4) against 147.5x48 and 140x46 dp
      (vf-2dev-lifecycle R3); one round-1 pill (`Shape Race` 460x64 dp) against two (`Shape Race`
      442x46 dp + `Bumper Round` 460x48 dp).
    - TV award names: `Cat Catcher` / `Comeback` / `Steady Roller` with "Most cats shooed" / "Most
      points in the last round" / "Fewest coins dropped" (vf-tv-01 R4 #7–9) against `Round Winner` /
      `Try Again` / `Big Bopper` with "Most rounds won" / "Most snaps after a wrong drop" / "Most
      shoves" (vf-2dev-lifecycle R3 #9–13).
    - Tablet pad: face buttons 187–188 px, left disc 414 px, right disc 333 px, D-pad 284 px
      (vf-tab-01 R1) against 174 px, 400 px, 319 px, 270 px (vf-2dev-round R7–R8) on the same
      2560x1600 px viewport.

11. **`#615975` is the second text colour and is not a §3 token.** TV controller meta line, join-screen
    slot labels, "Not ready yet", "Robo joins you", the `Code` label; tablet Gyro caption, "full at 30°
    of tilt", "A, B, X and Y, compared with D-pad mode", connect-row subtitle, error body — 6.12:1 on
    `paper`, 4.16:1 on the tablet sky, both `unmeasured` (vf-tv-01 R1 #9; vf-tab-01 R2 cross 3;
    vf-2dev-round §15).

12. **Text and control-part contrast below its bar (measured).** `good` text on `paper` 1.97:1 ("Ready",
    `+43` — vf-2dev-round R1, R6); dashed face circles `#6990BB` 1.82:1 (vf-2dev-round R8); dashed slot
    outlines `#9A919C` 2.83:1 (vf-2dev-lifecycle R4); stick knob `#69A1D1` 2.57:1 and D-pad centre disc
    `#B0A8AC` 2.16:1 on `paper` (vf-matrix-phones R1; vf-matrix-tablets summary); state-dot `caution`
    core on `background` 1.00:1 at all four tablet sizes (vf-matrix-tablets R1 #3, summary); unfilled
    slider track `#B0A8AC` 2.16:1 (vf-tab-01 R2 #17). Ratios that pass: 4.94:1 (`ink` on `player(3)`),
    5.15:1 (`ink` on `bad`), 5.61:1 (`ink` on `faceX`), 7.08:1 (`ink` on `player(2)`), 7.79:1 (`ink` on
    `player(4)`).

13. **A11y strings disagree with what is drawn.** "Connecting..." vs "Not connected · tap to connect"
    (vf-tab-01 R1; all six phone sizes and four tablet sizes); "…" U+2026 vs three U+002E
    (vf-matrix-tablets R1 states); `Â·` double-encoded at three positions on the TV shell (vf-tv-01 R1);
    5 of 7 slider values (vf-tab-01 R2); a11y order interleaving the Settings columns (vf-tab-01 R2).

14. **Primary action position.** The shell's `Play` sits in the title row at the top-right; every other
    TV screen puts its primary pill bottom-left (`Start` at x 42, `Puzzle settings` at x 48, the round
    pills at x 93/108) — vf-2dev-lifecycle R1 cross 2.

15. **Affirmative action or content below the fold, with no scroll indicator.** TV Look and sound
    (Music row, thumb 43 of 96 px), Party night (`Pick round 1` 466 px below the viewport at entry),
    join-screen cards, scoreboard past y 1080, tablet Settings (Sticks dead zone 10 of 14 px) — vf-tv-01
    R2/R4, vf-2dev-round R6, vf-tab-01 R2.

16. **Entry focus is inconsistent.** Present on the TV picker (card 3, 8 px ring) and Party night
    (`3 rounds`); absent on the shell, on Look and sound, and on both captured tablet screens
    (vf-tv-01 R1 cross 5, R2 cross 4, R3 #4, R4 #5; vf-tab-01 R1 states).

17. **Round start has two different affordances.** Shape Race join screen: `Start` pill 137.5x48 dp.
    Arena night card: no Start at all — the round starts on the player row (824.5x55.5 dp) that reads as
    a status line (vf-2dev-lifecycle R4 #14; vf-2dev-round R1 primary, cross 1).

18. **Pause is asymmetric and leave is TV-only.** TV dims the whole surface and raises a 1004x520 px
    card; the tablet neither dims nor prints "Paused", and `Quit` (130x54 dp) has no phone counterpart
    (vf-2dev-round R4, R9 cross 2–3).

19. **No surface names a map**, though round 1 and round 2 ran on two different fields (four `bad`
    bumper discs and straight `wall` segments against a `caution`-striped border, a conveyor loop with
    `paper` arrow glyphs and four gear glyphs) — vf-2dev-round §14.6, R3 states; "Map" heading cut at
    y 1034 in R1.

20. **Two players are the maximum ever drawn.** One phone plus `Robo`; a 2nd–4th human player is absent
    in every capture (vf-2dev-lifecycle §10; vf-2dev-round R1, R6).

21. **Awards are promised on setup and never tracked.** Three award cards on the TV setup card, three
    unmeasured band colours, and no award appears on the results card or the scoreboard that follows
    (vf-tv-01 R4 #7–9; vf-2dev-round R6 states; §15).

22. **The two devices' size scales share tokens but not sizes.** Switch 54x34 dp (TV) against 52.9x33.0
    dp (tablet); slider track 831 dp against 474.6 / 449.3 dp; the tablet's own button heights split
    32.1 / 38.9 / 39.3 / 47.9 / 48.4 dp within one flow (vf-tv-01 R2; vf-tab-01 R2; vf-2dev-lifecycle
    R6; vf-2dev-round R11).

---

## Absent states per device

**TV host (`com.thumbparty.tv`, 1920x1080 px)**
- **empty** — seen on the join screen only (0 players: "Nobody has joined yet.", `Room for 2 more` ×2 —
  vf-2dev-lifecycle R4). Never seen on the shell's controller list: a stale `Disconnected` row is always
  present (vf-tv-01 R1 states).
- **error** — not seen on any captured TV screen (vf-tv-01 R1 states; vf-2dev-lifecycle R1 states).
- **waiting** — seen: "Controllers · 0 connected" with one remembered row; the Arena card's
  "Not ready yet" (vf-tv-01 R1; vf-2dev-round R1).
- **dropped** — not seen: at +0.9 s after the drop the slot is gone with no away card, toast, countdown
  or colour change, stable to +15 s (vf-2dev-lifecycle R4 state 4, §9).
- **connected** — partially: `Not joined: P1 Phone 1719` and one joined row; no "connected" label ever
  on the shell, which reports "0 connected" while showing the row (vf-2dev-lifecycle R4 state 2;
  vf-tv-01 R1 #7).
- Also absent: pairing-in-progress, pairing success, disabled `Start`, countdown skip, tie/no-winner,
  "waiting for other players", a 2nd–4th joined player, colour or accessory chip on a joined row, map
  name, disabled award, change-teams/shuffle, per-round history, end-of-night screen, scroll indicator
  on any card (vf-tv-01 R1/R2/R4; vf-2dev-lifecycle R4, §10; vf-2dev-round R1, R5, R6, §15).

**Tablet controller (`com.thumbparty.app`, 2560x1600 px)**
- **empty** — not seen anywhere (vf-tab-01 R1 states; vf-2dev-round R7–R11).
- **error** — seen once, on `Connect to a TV` only: 4.000000 s timeout against `DESKTOP-NSUCJ8S`, with
  `Try again`, `Cancel`, `Try without a TV`, `Host a game`, `Settings` (vf-2dev-lifecycle R5). Never on
  the pad, in the code panel, or at any round stage (vf-tab-01 R1 states; vf-2dev-lifecycle R6 states;
  vf-2dev-round R8, R10).
- **waiting** — seen: "Connecting... · tap to connect" with a `caution` dot (vf-tab-01 R1; vf-matrix-*
  all 10 sizes).
- **dropped** — not seen on the pad: no `bad` dot, no error text, no host-away card at +5/+15/+45 s
  (vf-tab-01 R1 states; vf-2dev-lifecycle §9 state 5; vf-2dev-round R7 states).
- **connected** — seen: `good` dot, "● Android TV · 15 ms" (pill 259.9x42.5 dp) and the 30 s
  min/avg/max line; the connect screen's ✓ row, green check disc and `Disconnect` (vf-2dev-lifecycle §9;
  vf-2dev-round R11).
- Also absent: wrong-code error, code expiry/resend/countdown, "pairing…" progress, reconnecting state,
  empty discovery list, more than one discovered host, pressed/focused/disabled control states on any
  screen, a save/commit action, the "0 / 10" counter, any score/clock/coin/round/winner, the word
  "Paused" or any dimming, a quit/leave control, the pairing code, a second player's name or colour
  (vf-tab-01 R1/R2 states and summary; vf-matrix-phones summary; vf-matrix-tablets summary;
  vf-2dev-lifecycle R6, §10; vf-2dev-round R8, R9, R10, §15).
- The pad's only other captured state is the portrait gate: 1 glyph, 1 title, 3 body lines, no
  ignore/continue (vf-matrix-phones "The portrait gate").
