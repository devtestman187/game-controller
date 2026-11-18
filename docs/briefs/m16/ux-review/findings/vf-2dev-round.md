# vf-2dev-round — in-round and results, TV host + tablet controller

Worker: `vf-2dev-round`. Scope: the **in-round and results** flow of a Thumb Party night
between the TV host (`com.thumbparty.tv`, serial `192.168.1.100:5555`) and the tablet
controller (`com.thumbparty.app`, serial
`adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp`). Theme: **Sunny** (afternoon). No code,
test, protocol, map or dependency was touched. No `wm size` / `wm density` was issued on
either device — both stayed at their native settings — and no device or app setting was
changed. The keyguard/lockscreen was not touched: the tablet was already unlocked with a
30-minute timeout and was only driven with `input tap` inside the app.

**Outcome in one line.** A **Bumper Round** (the Arena's 60 s timed game) was played twice
inside one 3-round party night, on two different (unnamed) maps: the TV carried every state
(Arena waiting card → `Get ready 3-2-1` countdown → in-round HUD + field → `Paused` card →
`Robo wins!` results card → `Round 2 of 3` scoreboard), while the tablet showed **none of the
round's data** — it went `A OK / B Back` (waiting) → `A Dash` with a `Pause` pill (in-round) →
`Resume` pill with `B Resume` (paused) → `A OK / B Back` with the centre pill **absent**
(results), never a coin count, never the clock, never a score.

---

## 0. Devices, captures and measurement basis

| Item | TV host | Tablet controller |
|---|---|---|
| Serial | `192.168.1.100:5555` | `adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp` |
| `wm size` | `Physical size: 3840x2160` / `Override size: 1920x1080` | `Physical size: 1600x2560` (no override) |
| `wm density` | `Physical density: 320` | `Physical density: 320` / `Override density: 354` |
| `dumpsys window displays` | `init=3840x2160 320dpi base=1920x1080 320dpi cur=1920x1080 app=1920x1080` | `init=1600x2560 320dpi base=1600x2560 354dpi cur=2560x1600 app=2560x1600` |
| Viewport used below | **1920x1080 px, landscape = 960x540 dp**, `dp = px / 2` | **2560x1600 px, landscape (ROTATION_270) = 1157.1x723.2 dp**, `dp = px / 2.2125` |
| Theme samples | corners `#9CD5FA` (top) / `#7FCAF8` (bottom), glow centre `#C4EAFF`, Sunny polka dots present, no Night stars → **Sunny** | corners `#9AD5FA` / `#7DC9F8`, centre `#C4EAFF`, same dots → **Sunny** |

Capture protocol per spec §4: `adb shell screencap -p /sdcard/<name>.png` then `adb pull`
(two steps, no shell redirection); PNGs read with the image tool; every box below comes from a
pixel scan of the pulled PNG (colour masks per §3 token, ink `#1E1646`); contrast is WCAG 2.x
on the sampled pixels; token names are from `docs/design/look-and-sound.md` §3. Flutter
exposes no `uiautomator` semantics for the TV widgets and only one node for the tablet pad, so
**all hit boxes are `unmeasured`** and only drawn shapes are reported.

Screenshots (all under `C:\Users\mrman\AppData\Local\Temp\ux-pilot\`):

| file | device | screen / state |
|---|---|---|
| `r9-tv-wait.png`, `r4-tv.png`, `r5-tv.png`, `r17-tv-wait2.png` | TV | Arena waiting card, Bumper-only night, 1 phone joined, not ready |
| `r18-tv-focusrow.png` | TV | same card, focus ring on the player row |
| `r19-tv-count.png` | TV | round intro countdown, `Get ready 3` |
| `r10-tv-start.png` | TV | round intro countdown, `Get ready 2` |
| `r11-tv-inround.png`, `r12-tv-mid.png` | TV | in-round Bumper HUD + field |
| `r20-tv-pause.png` | TV | `Paused` card over the dimmed field |
| `r21-tv-resumed.png` | TV | resumed, clock at 57.0 s (same layout as in-round) |
| `r13-tv-last15.png`, `r14-tv-results.png`, `r23-tv-results2.png` | TV | results card `Robo wins!` (round 1: 0 / 22; round 2: 0 / 38) |
| `r22-tv-last.png` | TV | round 2 at `0.0 s`, results card appearing |
| `r15-tv-next.png`, `r16-tv-score-down.png`, `r24-tv-score2.png` | TV | night scoreboard, next-round pills |
| `r0-tab.png` | tablet | connected pad, not joined (`A Join`) |
| `r10-tab-start.png`, `r11-tab-inround.png` | tablet | in-round pad (`A Dash`) |
| `r20-tab-pause.png` | tablet | paused pad (`Resume`) |
| `r14-tab-results.png`, `r23-tab-results2.png` | tablet | pad at the results card |
| `r15-tab-next.png`, `r24-tab-score2.png` | tablet | pad at the scoreboard |
| `r25-tab-connect.png` | tablet | `Connect to a TV`, **connected** state |
| `r26-tv-wait3.png`, `r27-tv-back.png`, `r27-tab-back.png` | both | state left behind: TV back on the `Round 2 of 3` scoreboard, tablet on the connected pad |

---

## 1. What was reached

| # | State | TV | Tablet | What was on screen |
|---|---|---|---|---|
| 1 | Round 1 is a Bumper Round | **yes** | — | Host shell → `Play` → `Party night` (already set to `3 rounds`) → `Pick round 1` (**Bumper Round**, focused) → the Arena waiting card. A night's card offers **`Bumper` alone** — no `Race` button, and no map or `Surprise me` choice above the fold (a `Map` heading sits at the viewport's bottom edge). |
| 2 | Join | **yes** | **yes** | Tablet already paired (see §2). `A` on the tablet moved P1 into the card (`P1 Phone 1719`, `Not ready yet`). |
| 3 | Ready + start | **yes** | **yes** | TV focus `Bumper` → `20` → `Back` → `20` → **player row (star ring)** → `23` → the round starts: `Get ready 3` … `2` … `1` over the field. |
| 4 | In-round | **yes** | **yes** | HUD `Round 1 / 60.0 s / Best –` + two player rows; four marbles, coin zones, bumpers, walls. Tablet: `A Dash`, centre pill `Pause`. |
| 5 | Pause (in-round control) | **yes** | **yes** | Tablet `Pause` → TV `Paused` card (`Quit` / `Resume`), field dimmed, clock held at 58.1 s. Tablet: centre pill `Resume`, `B Resume`. |
| 6 | Clock runs out | **yes** | **yes** | At `0.0 s` the results card appears over the field. |
| 7 | Results card | **yes** | **yes (empty)** | TV `Robo wins!`, `P1 Phone 1719 0 coins`, `Robo 22 coins`, `Next` / `End night`. Tablet shows only `A OK` / `B Back` — no score at all. |
| 8 | Next round / play again | **yes** | **yes (empty)** | `Next` → night scoreboard `Round 1 of 3`, rows `1 Robo ★27 +27`, `2 Phone 1719 ★0`, next-round pills `Shape Race` and `Bumper Round`. After the second Bumper Round the same screen reads `Round 2 of 3` with a `★ Last round: double points! ★` banner and `Robo ★70 +43`. |
| 9 | End of night | **not reached** | **not reached** | Out of this brief's scope; `End night` was drawn but not pressed. |
| 10 | Drop / away during a round | **not reached** | **not reached** | Out of this brief's scope. |

Round played: **Bumper Round** (Arena, `bumperRoundS = 60`). Round 1 and round 2 were both
Bumper Rounds; round 1 ran on one map and round 2 on a different map (one with a
`caution`-striped hazard border, a conveyor loop with `paper` arrow glyphs and four gear
glyphs) — **no surface names the map**, so both map ids are `unmeasured`. Robo was the only
opponent (a solo night), on `Easy`.

---

## 2. Connect evidence (step 2)

The tablet was **already paired** to this TV when the pass began (same device session as
`vf-2dev-lifecycle`), so no code had to be typed to run the round. The link was verified, not
assumed, and the code was read off the TV twice, live:

- TV Arena waiting card, round 1 at ~15:46 and round 2 at ~15:53: chip **`Code 1219`** both
  times (Record 1, element 3). That chip renders `host.pairingCode`, so it is the current code,
  not a remembered one.
- TV card listed the tablet as `P1 Phone 1719`, `Not ready yet` → the link was up.
- Tablet pill read `● Android TV · 68 ms` at 15:45 and `· 8…18 ms` through the night.
- Tablet `Connect to a TV` (Record 11) listed **one** discovered host, `Thumb Party TV
  (Android TV)` / `TV · 192.168.1.100:45780`, with a **✓** instead of a `>`, status
  `● Connected · 11 ms`, and the right pane `Connected to Android TV`.

So the discovery row, the port (`45780`) and the live code are all confirmed; the only part of
the step-2 ritual not re-performed is the four-digit entry itself, because breaking a working
link mid-night would have cost the in-round capture. Typing the code is documented end to end
in `vf-2dev-lifecycle.md` §7 with the same code, `1219`.

---

## 3. Record 1 — TV Arena waiting card (a night's Bumper Round)

**screen / form factor / theme / viewport px**
The Arena's waiting card, the screen a party night's Bumper Round opens on. Form factor: TV,
Sony BRAVIA `BRAVIA_VH1`. Theme: **Sunny** — corners `#9CD5FA` / `#7FCAF8` against §3 Sunny
`background` `#7CC8F8` (Night `#241C5E`), glow centre `#C4EAFF`, Sunny dots present. Viewport:
**1920x1080 px, landscape = 960x540 dp** at density 320 (`dp = px / 2`). One `paper` card runs
from y 48 past the viewport bottom (paper found to y 1079); the screen scrolls inside the card.

**elements in reading order** (a pill's bounds are its ink edge; its fill is 7 px / 3.5 dp inside)

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Card (ink edge) | 48,48–1871,1080+ | 1824 x 1032+ | 912 x 516+ | `paper` `#FFF6E3`, ink edge 7 px |
| 2 | Header band | 56,56–1863,152 | 1808 x 96 | 904 x 48 | `player(2)` `#FF8A1F` |
| 3 | Band label "Arena" | 882,86–1035,123 | 154 x 38 | 77 x 19 | ink on `player(2)` = **7.08:1** |
| 4 | `Bumper` mode pill — selected | 106,202–380,309 (fill 114,210–372,302) | 275 x 108 | 137.5 x 54 | `star` `#FFD23F` fill, ink edge 7 px; label ink on `star` = **11.56:1** |
| 5 | `Code 1219` chip | 1548,200–1823,311 | 276 x 112 | 138 x 56 | `paper`, ink edge 7 px; "Code" `#615975` 1578–1648, "1219" ink 1698–1796 |
| 6 | `Back` pill | 106,362–378,469 (fill 114,370–371,462) | 273 x 108 | 136.5 x 54 | `good` `#2FCB74`, ink edge 7 px |
| 7 | Line "Press A when you're ready." | 777,397–1460,447 | 684 x 51 | 342 x 25.5 | ink on `paper` = **15.53:1** |
| 8 | P1 badge "1" | 106,540–197,638 | 92 x 99 | 46 x 49.5 | `player(1)` `#2E9BF0`, ink edge 7 px |
| 9 | "P1 Phone 1719" | 219,576–561,614 | 343 x 39 | 171.5 x 19.5 | ink on `paper` |
| 10 | "Not ready yet" | 1537,580–1814,616 | 278 x 37 | 139 x 18.5 | `#615975` on `paper` — **not a §3 token, `unmeasured`** (raw 6.12:1) |
| 11 | Robo badge | 104,711–184,790 | 81 x 80 | 40.5 x 40 | `player(2)` `#FF8A1F`, ink edge 7 px |
| 12 | "Robo" | 205,731–334,769 | 130 x 39 | 65 x 19.5 | ink on `paper` |
| 13 | "Ready" (Robo) | 1699,734–1821,771 | 123 x 38 | 61.5 x 19 | `good` on `paper` — **not a §3 pair, `unmeasured`** (raw 1.97:1) |
| 14 | "Robo joins you" | 100,821–398,859 | 299 x 39 | 149.5 x 19.5 | `#615975` on `paper` — `unmeasured` |
| 15 | "Robo:" label | 100,913–235,951 | 136 x 39 | 68 x 19.5 | ink on `paper` |
| 16 | `Easy` pill | 274,896–443,969 (fill 280,902–437,963) | 170 x 74 | 85 x 37 | `good`, ink edge 6 px |
| 17 | `Medium` pill — selected | 483,896–713,969 (fill 489,902–707,963) | 231 x 74 | 115.5 x 37 | `star` fill, ink edge 6 px |
| 18 | `Hard` pill | 752,896–923,969 (fill 758,902–917,963) | 172 x 74 | 86 x 37 | `good`, ink edge 6 px |
| 19 | "Map" heading | 99,1034–202,1079+ | 104 x 46+ | 52 x 23+ | ink on `paper`, cut by the viewport |

**state B — focus moved onto the player row (`r18-tv-focusrow.png`)**
The P1 row gains a `star` focus ring at **175,540–1823,650** (1649 x 111 px = 824.5 x 55.5 dp),
7 px (3.5 dp) thick, drawn outside the row's 8 px ink edge; inside it the row reads
548–642 in y (95 px = 47.5 dp). No other box moved by more than 1 px: `Back` and `Bumper` lose
their ring, nothing resizes. Focus order tested with the remote: `Bumper` → `Back` → player row
(two `20` presses), so the mode pill is the first stop and the row is the third.

**primary action**
`Back` is the only action pill on a *TV* host (137.5 x 54 dp at 106,362; ink on `good` = 7.88:1).
The control that actually starts the round is the **player row**, 1649 x 111 px (824.5 x 55.5 dp)
counting its focus ring — pressing it readies P1 and, because Robo is already `Ready`, the round
starts on that press. Row text is ink on `paper` = 15.53:1. This is a **night card, so it has no
`Start` button**: on a TV the round begins from a row that reads like a status line, not a
button (see "states missing").

**secondary actions**
`Bumper` mode pill (137.5 x 54 dp, `star` = selected); the `Code 1219` chip (138 x 56 dp, not
pressable); `Easy` / `Medium` / `Hard` (85 / 115.5 / 86 x 37 dp, 6 px ink edges, 8 px = 4 dp
apart: 437→483, 713→752); the map cards below the viewport fold.

**text that wraps or truncates at this size, and how**
No ellipsis and no wrap on the card. Single lines: "Arena" 154 px, "Press A when you're ready."
684 px inside the card's 1808 px border, "P1 Phone 1719" 343 px, "Not ready yet" 278 px
right-aligned to x 1814, "Robo joins you" 299 px. The only clipped element is the "Map" heading
and everything under it: the card continues past y 1080 and the screen scrolls, with no scroll
indicator drawn.

**states covered, and states missing**
Covered: one phone joined and not ready; Robo present and `Ready`; a selected mode (`star`
fill); a selected Robo level (`Medium`, `star` fill); a live pairing code; focus on a pill and on
a row. Missing (**absent**): an empty state for this card (it always lists at least one player
once a round opens — the 0-player wording `Nobody has joined yet.` belongs to the Shape Race join
screen, not here); a visible `Start` / confirm control; any map name; a ready ✓/✗ disc (the card
uses the words "Ready"/"Not ready yet" instead, and the words are `good`/`#615975`); a
"waiting for other players" line; an error or lost-link state.

**cross-screen inconsistencies versus the other screens**
1. **No `Start`.** Every other TV round screen puts a start pill bottom-left (the Shape Race join
   screen's `Start`, 137.5 x 48 dp); a night's Arena card starts on a player row press instead.
2. Row readiness is carried by **word colour only** — `good` "Ready" (1.97:1 on paper) versus
   `#615975` "Not ready yet" (6.12:1). Neither is a §3 text pair, and the two words differ in
   contrast by 3x.
3. `Medium`'s selected fill is `star`, the same token the focus ring and the scoreboard's
   double-points banner use — one token, three meanings on three screens.
4. Pill sizes on one screen: mode 137.5 x 54 dp, `Back` 136.5 x 54 dp, but the Robo levels
   85–115.5 x 37 dp — a 17 dp height step inside the same card.
5. The card is the only TV screen in this pass that shows the pairing code alongside a running
   night; the Shape Race join screen (`vf-2dev-lifecycle` Record 4) shows none.

---

## 4. Record 2 — TV round intro / countdown

**screen / form factor / theme / viewport px**
`Get ready` countdown over the round's field, entered from the waiting card. Form factor: TV,
landscape. Theme: **Sunny** (HUD `paper` `#FFF6E3`, badge `star`, sky `background` gone from the
field). Viewport: **1920x1080 px = 960x540 dp** at density 320.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | HUD band (one row only) | 0,0–1919,107 (edge 108–115) | 1920 x 108 | 960 x 54 | `paper`, ink edge 8 px |
| 2 | "Round 1" | 35,38–625,77 (three words in one band) | 591 x 40 | 295.5 x 20 | ink on `paper` = **15.53:1** |
| 3 | Field top edge / hazard border | 0,116–1919,1079 | 1920 x 964 | 960 x 482 | `field` `#A9DCFB` shaded, `caution` `#FFB020` stripe at 123+ |
| 4 | `Get ready` card | 768,228–1151,852 (paper 776,236–1143,843) | 384 x 625 | 192 x 312.5 | `paper`, ink edge 7 px |
| 5 | Label "Get ready" | 835,280–1085,331 | 251 x 52 | 125.5 x 26 | ink on `paper` = 15.53:1 |
| 6 | Count numeral "3" | 872,469–1047,699 | 176 x 231 | 88 x 115.5 | ink on `paper` |
| 7 | Bumper discs (2 visible) | e.g. 545,241–595,290 / 1248,247–1298,297 | 50 x 49 | 25 x 24.5 | `bad` `#FF4D5E` with a `paper` ring 47 x 47 inside |
| 8 | Conveyor walls (arrows) | e.g. 1257,439–1622,760 | 366 x 322 | 183 x 161 | `wall` `#7F8FD1` with `paper` arrow glyphs 44 x 56 |

**primary action**
There is **no button** on this screen: it is a 3-second auto-advancing countdown. The card
(192 x 312.5 dp) is the only interactive-looking object and it is not focusable; the numeral is
88 x 115.5 dp of ink on paper (15.53:1). Pressing `23`/`66`/`108` here was **not** tested — the
brief's start press was consumed by the waiting card, so any skip/confirm behaviour of the
countdown is `unmeasured`.

**secondary actions**
Absent. No pause, skip, back or settings affordance is drawn over the field in this state, and the
remote's `4` was not pressed. Whether the tablet's `Pause` pill works during the countdown is
`unmeasured`: the pause that was captured came 4 s after the countdown ended (clock at 58.1 s).

**text that wraps or truncates at this size, and how**
No wrap, no ellipsis. The HUD's three labels share one 40 px band that is 591 px wide (x 35–625):
"Round 1", the clock and "Best –" on one baseline, at the same pitches measured in-round
(190 / 138 / 153 px with 54 px gaps, Record 3). The card's label is one line of 251 px inside the
368 px card.

**states covered, and states missing**
Covered: numeral `3` and numeral `2` (`r10-tv-start.png`, 176 x 231 px each in the same box); the
clock at `60.0 s`; the field behind the card. Missing (**absent**): the two player rows (they do
not exist during the countdown — the HUD stores only the round line), any "Round 1 of 3" night
context, a skip control, and a sound/effects indicator.

**cross-screen inconsistencies versus the other screens**
1. **The HUD is 108 px (54 dp) tall here and 284 px (142 dp) tall in-round** — the two player
   rows appear only when the countdown ends, so the field's top edge jumps from y 116 to y 290
   (174 px = 87 dp) in one frame.
2. The countdown card is `paper` with an ink edge and **no coloured header band**; the pause card
   and the results card both have one (`star`, `player(2)`).
3. `Round 1` appears here with no "of 3" suffix, on the scoreboard as `Round 1 of 3`, and the
   results card carries no round number at all.

---

## 5. Record 3 — TV in-round Bumper

**screen / form factor / theme / viewport px**
The Bumper Round as played: HUD band plus the Arena field. Form factor: TV, landscape. Theme:
**Sunny** — HUD `paper` `#FFF6E3`, field `#A9DCFB`→`#89CEF9` (§3 `field` `#A9DCFB`; Night `field`
is `#2A2270`), corners `#7FCAF8` = `background`. Viewport: **1920x1080 px = 960x540 dp** at
density 320. Two frames measured: 45.8 s left (`r11-tv-inround.png`) and 6.6 s left
(`r12-tv-mid.png`); the HUD geometry is identical in both.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | HUD band | 0,0–1919,284 (edge 284–289) | 1920 x 284 | 960 x 142 | `paper`, ink edge 6 px |
| 2 | "Round 1" | 35,38–224,77 | 190 x 40 | 95 x 20 | ink on `paper` = 15.53:1 |
| 3 | Clock "45.8 s" | 278,39–415,77 | 138 x 39 | 69 x 19.5 | ink on `paper` = 15.53:1 (in the last 15 s, at 6.6 s left: still ink `#1E1646`, **not** `bad`) |
| 4 | "Best –" | 469,39–621,77 | 153 x 39 | 76.5 x 19.5 | ink on `paper`; the value stayed `–` in every frame of both rounds |
| 5 | Row 1 marker dot | 35,137–56,158 | 22 x 22 | 11 x 11 | `player(1)` `#2E9BF0` |
| 6 | "P1 Phone 1719" | 75,129–413,167 | 339 x 39 | 169.5 x 19.5 | ink on `paper` |
| 7 | Coin icon + count "0" | 459,131–531,164 | 73 x 34 | 36.5 x 17 | `star` disc, ink glyphs |
| 8 | Status dot + "Dash ready (A)" | dot 578,137–598,158; label ends 923,170 | 21 x 22 (dot) | 10.5 x 11 (dot) | `good` dot; label ink on `paper` |
| 9 | Row 2 marker (Robo glyph) | 34,225–57,245 | 24 x 21 | 12 x 10.5 | `player(2)` `#FF8A1F` |
| 10 | "Robo" | 75,217–315,255 | 241 x 39 | 120.5 x 19.5 | ink on `paper` |
| 11 | Coin icon + count "2" | 390,221–462,250 | 73 x 30 | 36.5 x 15 | `star` disc, ink glyphs |
| 12 | "Dash in 0.8 s" | 363,220–625,250 | 263 x 31 | 131.5 x 15.5 | ink on `paper` (moving countdown) |
| 13 | Field | 0,290–1919,1079 | 1920 x 790 | 960 x 395 | `field` `#A9DCFB` with the toy shader's darker edges |
| 14 | Wall segments (5) | 897,634 11x446; 455,295 11x444; 1339,791 10x289; 1339,295 10x286; 571,854 202x11 | 10–11 px thick | 5–5.5 px thick | `wall` `#7F8FD1`, ink edge + hard shadow |
| 15 | Bumper discs (4 visible) | 1099,934 50x49; 1477,578 50x48; 657,736 50x48; 335,963 50x48 | 50 x 49 | 25 x 24.5 | `bad` `#FF4D5E` with a `paper` ring 38 x 38 at 0.55 R |
| 16 | Coins | e.g. 1023,646 (gold disc) | ~38 diameter | ~19 | `star` face, darker rim, ink outline |
| 17 | P1 marble + count badge | marble 157,407 67x75; badge 157,349 70x49 | 70 x 49 (badge) | 35 x 24.5 | `player(1)` body, `paper` count pill above |
| 18 | Robo marble + count badge | marble 1192,482 65x62; badge 1189,412 71x48 | 71 x 48 (badge) | 35.5 x 24 | `player(2)` body, `paper` count pill above |

**primary action**
The screen has **no on-TV action**: the round is driven entirely from the phone. The nearest thing
to an action is the A prompt inside row 1 — "Dash ready (A)", 349 x 39 px (174.5 x 19.5 dp) of ink
on `paper` at 15.53:1 — which names the phone's button, not a TV control. Every TV focus ring is
absent in-round: `23`/`66`/`108`/`4` are not drawn anywhere as a hint.

**secondary actions**
Absent on the TV. No pause, restart, leave or settings control is drawn during a round; the
`Pause` control exists only on the tablet (Record 8). The `Best –` field is a readout with no
value in this mode.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis in either frame. Every HUD label is one line: 190 / 138 / 153 px on row 1,
339 / 73 px plus a 349 px status run on row 2, 241 / 73 / 263 px on row 3. The longest line is "P1 Phone 1719" at
339 px (169.5 dp) inside the 1920 px band. The marble count pills hold one or two digits; at
`24` coins (round 1, 6.6 s left) the pill is still 70–71 px wide, so two digits fit without
resizing. The `Best –` en dash is a placeholder, not a truncation.

**states covered, and states missing**
Covered: 60 s clock counting down (45.8 s, 6.6 s, 0.0 s); a per-player coin count that grows
(0 vs 2, then 0 vs 24, then 0 vs 38); the dash ready / dash-in countdown pair; `Robo` as the
second player; bumpers, walls, coins and two marbles. Missing (**absent**): the clock's last-15 s
`bad` state (the digits stayed ink `#1E1646` at 6.6 s left — Record 8 shows the same absence of a
warning on the phone); a "Round 1 of 3" night label; a paused overlay on the TV (it exists —
Record 5); any night points total (the HUD shows coins only, while the scoreboard awards
points); a map name; a "player away" state.

**cross-screen inconsistencies versus the other screens**
1. **`Round 1` again.** The night's **second** Bumper Round also drew `Round 1` in this band
   (`r22-tv-last.png`, `r23-tv-results2.png`), while the scoreboard it fed said `Round 2 of 3`.
   Two different round numbers for the same round on two screens.
2. **`Best –` never fills.** It is the same `Best` field the Shape Race HUD uses for a finish
   time (`arena_hud_widgets.dart`: `Best ${best…} s (P…)`); a timed round produces no finish time,
   so it reads `–` for a whole round, directly beside a live clock.
3. The clock is ink in the last 15 s while `look-and-sound.md` §3 reserves `bad` for "the last
   15 s" of a clock — the sampled 6.6 s frame is `#1E1646`, not `#FF4D5E`.
4. The HUD uses two left gutters: 35 px for "Round 1" and for the row markers (34–35), and 75 px
   for both row labels.
5. The field draws no `background` sky at all (the `field` token fills the viewport), so this is
   the only TV screen in the pass where the Sunny sky is not visible; the theme can only be read
   from the `paper` band and the `field` value.

---

## 6. Record 4 — TV `Paused` card

**screen / form factor / theme / viewport px**
The pause card, raised from the tablet's `Pause` pill 1.9 s into the night's second Bumper Round
(clock held at 58.1 s). Form factor: TV, landscape. Theme: **Sunny, dimmed** — the whole field and
HUD sit behind a dark scrim: the field samples `#536265` and `#757168` where the undimmed frames
sample `#A2DAFC`–`#89CEF9`, and the `caution` hazard stripe samples `#75510F` against `#FFB020`.
The card itself is undimmed `paper`. Neither scrim value is a §3 token → **`unmeasured`**.
Viewport: **1920x1080 px = 960x540 dp** at density 320.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Dim scrim over HUD + field | 0,0–1919,1079 | — | — | sampled `#536265` / `#757168` / `#75510F` — `unmeasured` |
| 2 | Pause card | 458,280–1461,799 (paper 466,392–1453,791) | 1004 x 520 | 502 x 260 | `paper`, ink edge 7 px |
| 3 | Header band | 466,288–1453,382 | 988 x 95 | 494 x 47.5 | `star` `#FFD23F` |
| 4 | Label "Paused" | 870,316–1049,354 | 180 x 39 | 90 x 19.5 | ink on `star` = **11.56:1** |
| 5 | P1 badge "1" | 492,470–615,603 | 124 x 134 | 62 x 67 | `player(1)` `#2E9BF0`, ink edge |
| 6 | Line "P1 can resume, with Start or Resume." | 646,529–1426,564 | 781 x 36 | 390.5 x 18 | ink on `paper` = **15.53:1** |
| 7 | `Quit` pill | 635,651–894,758 (fill 643,659–886,750) | 260 x 108 | 130 x 54 | `good`, ink edge 7 px |
| 8 | `Resume` pill — focused | 932,649–1291,760 (fill 940,657–1283,752) | 360 x 112 | 180 x 56 | `good`, ink edge 7 px, `star` ring 925,642–1298,767 |
| 9 | Dimmed HUD row 1 behind | 35,38–621,77 | — | — | ink at reduced contrast over the scrim |

**primary action**
`Resume` — focused pill 180 x 56 dp (360 x 112 px fill+edge), `good` `#2FCB74`, ink edge 7 px
(3.5 dp), `star` focus ring 374 x 126 px (187 x 63 dp, 7 px / 3.5 dp thick). Label ink on `good`
= **7.88:1**. Its ring is the only `star` on the card, so the default choice is unambiguous.

**secondary actions**
`Quit` (130 x 54 dp, ink on `good` 7.88:1) sits left of `Resume` with a 38 px (19 dp) gap
(894 → 932). Both pills are 54–56 dp tall — matching the waiting card's 54 dp and above the
results card's 48 dp.

**text that wraps or truncates at this size, and how**
No wrap, no ellipsis. "Paused" is one line of 180 px; the sentence is one line of 781 px
(390.5 dp) inside the 988 px band width — 207 px of slack, so it would take a longer player name
before it wrapped. The two button labels are one line each (260 px and 360 px pills).

**states covered, and states missing**
Covered: paused with one human player; the paused clock (`58.1 s`, unchanged for the whole
pause); a dimmed background; a focused default action. Missing (**absent**): a per-player pause
reason, a "waiting for P1" state, a resume countdown, a settings or leave-without-quit option, an
explicit "the round is paused, nothing is lost" line, and any indication on the card of which
round or which map is paused.

**cross-screen inconsistencies versus the other screens**
1. The word for the same action differs across three surfaces: the card says **`Resume`**, the
   line says **`Start or Resume`**, and the tablet's B button says **`Resume`** while its A says
   **`OK`** (Record 9).
2. This is the only dimmed state in the pass; every other card is drawn over an undimmed field,
   and the scrim is not a §3 token.
3. `Paused` uses a `star` header band; the waiting card's band is `player(2)` and the results
   card's is `player(2)` — three cards, two band colours, no rule visible.
4. 54–56 dp pill heights here match the waiting card's 54 dp and exceed the results card's 48 dp.

---

## 7. Record 5 — TV results card (`Robo wins!`)

**screen / form factor / theme / viewport px**
The Bumper Round's results card, shown at `0.0 s` when the clock runs out. Form factor: TV,
landscape. Theme: **Sunny** (card `paper`, band `player(2)` `#FF8A1F`, sky `#7FCAF8` at the
corners). Viewport: **1920x1080 px = 960x540 dp** at density 320. The card is drawn **over** the
still-running HUD and field — nothing is cleared behind it.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | HUD band, still live behind | 0,0–1919,284 | 1920 x 284 | 960 x 142 | `paper`; clock reads `0.0 s` |
| 2 | Results card | 540,247–1379,832 (paper 548,359–1371,824) | 840 x 586 | 420 x 293 | `paper`, ink edge 7 px |
| 3 | Header band | 548,255–1371,349 | 824 x 95 | 412 x 47.5 | `player(2)` `#FF8A1F` |
| 4 | Label "Robo wins!" | 827,283–1092,321 | 266 x 39 | 133 x 19.5 | ink on `player(2)` = **7.08:1** |
| 5 | Row 1 badge "1" | 591,426–681,525 | 91 x 100 | 45.5 x 50 | `player(1)` `#2E9BF0` |
| 6 | Row 1 name run (badge digit + "P1 Phone 1719") | 583,420–1045,529 | 463 x 110 | 231.5 x 55 | ink on `paper` = 15.53:1 |
| 7 | Coin icon, row 1 | 1056,445–1128,518 | 73 x 74 | 36.5 x 37 | `star` disc with a white `$` |
| 8 | "0 coins" | 1156,463–1329,501 | 174 x 39 | 87 x 19.5 | ink on `paper` |
| 9 | Row 2 badge (Robo) | 596,554–675,632 | 80 x 79 | 40 x 39.5 | `player(2)` `#FF8A1F` |
| 10 | Row 2 name run (badge + "Robo" + crown) | 588,546–924,639 | 337 x 94 | 168.5 x 47 | ink on `paper` |
| 11 | Crown glyph | 851,588–914,615 | 64 x 28 | 32 x 14 | `star` |
| 12 | Coin icon, row 2 | 1023,557–1095,630 | 73 x 74 | 36.5 x 37 | `star` disc with a white `$` |
| 13 | "22 coins" | 1122,575–1329,613 | 208 x 39 | 104 x 19.5 | ink on `paper` |
| 14 | `Next` pill — focused | 586,675–880,800 (fill 601,690–865,785) | 295 x 126 | 147.5 x 63 | `good`, ink edge 7 px, `star` ring 7 px |
| 15 | `End night` pill | 912,683–1304,791 (fill 920,691–1296,783) | 393 x 109 | 196.5 x 54.5 | `good`, ink edge 7 px |

**primary action**
`Next` — focused pill 147.5 x 63 dp counting the ring (295 x 126 px), fill `good` at
601,690–865,785 (264 x 95 px = 132 x 47.5 dp), ink edge 7 px, `star` ring 7 px outside it. Ink on
`good` = **7.88:1**. It is the card's left-to-right first button and the only one with a ring.

**secondary actions**
`End night` (196.5 x 54.5 dp, ink on `good` 7.88:1), 32 px (16 dp) right of `Next`'s ring.
The card itself is not scrollable and has no close/back affordance: `End night` is the only exit
other than `Next`.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis. "Robo wins!" is one line of 266 px centred in the 824 px band. The two
rows are one line each; "0 coins" and "22 coins" are right-aligned to the **same** x 1329 but
their coin icons are **not** in a column — row 1's icon sits at x 1056 and row 2's at x 1023
(a 33 px / 16.5 dp offset), because each icon follows its name's length. The card clips the HUD
behind it: its top edge is at y 247 while the HUD's third row runs to y 255, so the bottom 8 px of
"Robo 22 Dash ready (A)" are cut mid-glyph.

**states covered, and states missing**
Covered: a decisive win by the only opponent (`Robo wins!`); per-player coin counts (0 and 22, then
0 and 38 in round 2); a focused `Next`; an `End night`; the clock at `0.0 s` behind the card.
Missing (**absent**): any night points on the card (the scoreboard shows `+27` / `+43`, the card
shows coins only); a round number; a map name; a tie state; a "no winner" / "nobody scored" state;
per-player place numbers (1st/2nd) — the rows are listed in winner-first order with no ordinal;
a "play again" button (only `Next`, which goes to the scoreboard).

**cross-screen inconsistencies versus the other screens**
1. **Coins here, points there.** The card totals coins; the scoreboard it leads to totals points
   (`Robo ★27 +27` after a 22-coin round, `+43` after a 38-coin round). No surface converts one
   into the other.
2. The card's rows have **no alignment grid**: names, crowns and coin icons all start at different
   x per row, where the scoreboard puts every score in one right-hand column.
3. `Next` is 48 dp tall (fill) with a 63 dp ring footprint; the results card is the only place a
   focus ring enlarges the visual footprint by 16 dp in each direction.
4. The card overlaps and clips the HUD rather than replacing it; every other card in the pass
   (waiting, pause) is drawn over a scrimmed or clear field with its own margins.

---

## 8. Record 6 — TV night scoreboard (`Round 1 of 3` / `Round 2 of 3`)

**screen / form factor / theme / viewport px**
`Next` on the results card opens the night's scoreboard. Two frames measured: after round 1
(`r15-tv-next.png`) and after round 2 (`r24-tv-score2.png`); the second adds the double-points
banner and taller content. Form factor: TV, landscape. Theme: **Sunny** (corners `#7FCAF8`,
`paper` card, `player(4)` band). Viewport: **1920x1080 px = 960x540 dp** at density 320.

**elements in reading order (after round 2)**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Title "Party night" | 131,41–700,146 | 569 x 106 | 284.5 x 53 | ink on `background` = **9.12:1** |
| 2 | Back arrow | 33,63–63,92 | 31 x 30 | 15.5 x 15 | ink glyph |
| 3 | Scoreboard card | 60,205–1858,1080+ (paper 68,317–1851,1079) | 1798 x 875+ | 899 x 437+ | `paper`, ink edge 7 px |
| 4 | Header band | 68,213–1851,307 | 1784 x 95 | 892 x 47.5 | `player(4)` `#14C8A0` |
| 5 | Band label "Round 2 of 3" | 802,242–1118,280 | 317 x 39 | 158.5 x 19.5 | ink on `player(4)` = **7.79:1** |
| 6 | Banner "★ Last round: double points! ★" | 523,357–1396,467 | 874 x 111 | 437 x 55.5 | `star` fill, ink edge 7 px |
| 7 | Banner label | 530,360–1389,469 | 860 x 110 | 430 x 55 | ink on `star` = 11.56:1 |
| 8 | Rank "1" | 447,581–467,619 | 21 x 39 | 10.5 x 19.5 | ink on `paper` |
| 9 | Robo badge | 332,560–411,639 | 80 x 80 | 40 x 40 | `player(2)` `#FF8A1F` |
| 10 | "Robo" | 490,581–570,619 | 81 x 39 | 40.5 x 19.5 | ink on `paper` |
| 11 | Star + points "70" | star 1524,579–1566,619; "70" 1591,581–1649,619 | 42 x 40 / 59 x 39 | 21 x 20 / 29.5 x 19.5 | `star` glyph, ink digits |
| 12 | "+43" (this round) | 1721,582–1810,619 | 90 x 38 | 45 x 19 | `good` on `paper` — **not a §3 pair, `unmeasured`** (raw 1.97:1) |
| 13 | Rank "2" | 447,728–467,766 | 21 x 39 | 10.5 x 19.5 | ink on `paper` |
| 14 | Phone badge "1" | 326,692–418,791 | 92 x 99 | 46 x 49.5 | `player(1)` `#2E9BF0` |
| 15 | "Phone 1719" | 490,728–719,766 | 230 x 39 | 115 x 19.5 | ink on `paper` |
| 16 | Star + points "0" | star 1554,725–1597,766; "0" 1622,729–1649,766 | 43 x 41 / 28 x 38 | 21.5 x 20.5 / 14 x 19 | `star` glyph, ink digit |
| 17 | `Shape Race` next-round pill — focused | 93,852–1042,977 (fill 108,867–1027,962) | 949 x 126 | 474.5 x 63 | `good`, ink edge 7 px, `star` ring 7 px |
| 18 | `Bumper Round` next-round pill | 118,1013–1017,1080+ (fill 126,1021–1009,1079+) | 899 x 67+ | 449.5 x 33+ | `good`, ink edge 8 px; cut by the viewport |

**primary action**
The screen's action is a **round pill**, not a single confirm: `Shape Race` (focused,
474.5 x 63 dp with its ring; fill 920 x 96 px = 460 x 48 dp, ink on `good` 7.88:1) and
`Bumper Round` (fill 884 x 96 px = 442 x 48 dp) both start the next round directly, with no
second confirm. The focused pill's green fill measures **920 px (460 dp)** against the unfocused
one's **884 px (442 dp)** in the same frame — an 18 px inset on each side, i.e. the focus
treatment grows the pill, not just its ring.

**secondary actions**
The other round pill; the back arrow (15.5 x 15 dp glyph, `unmeasured` as a target); nothing else
— the rows are read-only, and there is no `End night`, `Settings` or `Awards` control on this
screen even though the night is two-thirds done.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis. The band label is one line of 317 px. The banner's label is **860 px
inside an 874 px pill — 7 px (3.5 dp) of padding on each side**, the smallest horizontal label
padding measured in the pass. Row labels are one line each (81 px, 230 px); the numbers are one
line. `Bumper Round` is one line in an 884 px pill. The card continues past y 1080 with no scroll
indicator.

**states covered, and states missing**
Covered: 2 players ranked with cumulative points; a per-round delta (`+43`); a double-points
banner for the last round; two next-round choices with focus; the round counter
(`Round 1 of 3` → `Round 2 of 3`). Missing (**absent**): the awards the night promises
(`Round Winner`, `Try Again`, `Big Bopper` appear on the setup screen only and are not shown or
tracked here); an end-of-night action; a per-round history; a tie state; any indication of which
map was just played; a "Play again" for the same round type (the pills re-pick a game instead).

**cross-screen inconsistencies versus the other screens**
1. **Round number vs the HUD.** This screen said `Round 2 of 3` while the round it had just
   scored was drawn as `Round 1` in the HUD and on the results card.
2. `+43` is `good` text at **1.97:1** on paper — the lowest text contrast measured in the pass,
   below the 6.12:1 of `#615975` and far below the 15.53:1 of the row labels it sits beside.
3. The band is `player(4)` `#14C8A0` — a colour that means "player 4" everywhere else and here
   means "the night's scoreboard".
4. This is the only screen with a **banner inside the card** (`star`, 437 x 55.5 dp) and the only
   one that uses a `star` fill for a message rather than a selection.
5. Two left edges for the pills (ring at x 93, fill at x 108) against the card's x 60 and the
   title's x 131 — the same three-way misalignment as the Shape Race join screen
   (`vf-2dev-lifecycle` Record 4, point 5).

---

## 9. Record 7 — Tablet pad, connected and not joined

**screen / form factor / theme / viewport px**
The controller pad before the player joins a round. Form factor: tablet, Pixel Tablet
`tangorpro`, landscape (ROTATION_270). Theme: **Sunny** — sky corners `#9AD5FA` / `#7DC9F8`
(§3 `background` `#7CC8F8`), glow centre `#C4EAFF`, dots present. Viewport:
**2560x1600 px = 1157.1x723.2 dp** at density 354 (`dp = px / 2.2125`).

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Player badge "1" | 29,37–96,111 | 68 x 75 | 30.7 x 33.9 | `player(1)`, ink edge |
| 2 | Connection pill "● Android TV · 68 ms" | 118,15–589,108 | 472 x 94 | 213.3 x 42.5 | `background` fill, ink edge 8 px, `good` dot |
| 3 | Latency line "30 s: min 10 · avg 23 · max 85 ms" | 589,35–1190,94 (glyph band 48–80) | 602 x 33 | 272.1 x 14.9 | ink on `background` = **9.12:1** |
| 4 | Mode control `D-pad / Gyro / Sticks` | 1560,27–2223,96 | 663 x 69 | 299.7 x 31.2 | ink edges; `Sticks` selected |
| 5 | `Sticks` selected fill | 2001,29–2220,94 | 220 x 66 | 99.4 x 29.8 | `caution` `#FFB020`, label ink = **9.13:1** |
| 6 | Icon buttons (sliders, gear, diagnostics) | 2257,41–2510,83 | 254 x 43 | 114.8 x 19.4 | ink glyphs |
| 7 | Left stick disc + knob | 39,893–439,1293 | 400 x 400 | 180.8 x 180.8 | `paper` disc, ink edge 6 px |
| 8 | Centre pill `Start` | 1293,1068–1431,1149 | 138 x 81 | 62.4 x 36.6 | `paper`, ink edge 6 px |
| 9 | D-pad | 554,1318–824,1587 | 270 x 269 | 122.0 x 121.6 | `paper`, ink edge 6 px |
| 10 | Right stick disc + knob | 1736,1269–2055,1587 | 319 x 318 | 144.2 x 143.7 | `paper`, ink edge 6 px |
| 11 | `A` `Join` | 2179,1214–2352,1387 | 174 x 174 | 78.6 x 78.6 | `good`; letter + label |
| 12 | `B` `Back` | 2333,1060–2506,1233 | 174 x 174 | 78.6 x 78.6 | `bad` `#FF4D5E`; ink on `bad` = **5.15:1** |
| 13 | `Y`, `X` — empty | Y 2179,906–2352,1079; X 2025,1060–2198,1233 | 174 x 174 | 78.6 x 78.6 | dashed outline only, no fill, no glyph, no label |
| 14 | `Select`, `LB`, `RB` — absent | — | — | — | not drawn in the connected states |

**primary action**
`A` (78.6 x 78.6 dp) reads `Join` here, then `OK` once the waiting card takes the pad, then `Dash`
in-round (Record 8): ink on `good` = **7.88:1**. The centre pill (`Start`, 62.4 x 36.6 dp) is the
only other labelled control and it sends Start to the host.

**secondary actions**
`B` (`Back`, 78.6 dp, ink on `bad` 5.15:1); the mode control (299.7 x 31.2 dp, three segments);
three 47.9 x 47.9 dp icon buttons; the two sticks (180.8 and 143.7 dp discs) and the D-pad
(122 x 121.6 dp); the centre `Start` pill.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis. The connection label is one line inside a 472 px pill; the latency line
is one line of 602 px (272.1 dp) running to x 1190, 370 px clear of the mode control at 1560.
Face labels are two lines each (letter over word) inside 174 px circles. "Android TV" is
truncated **semantically, not visually**: the host is `Thumb Party TV (Android TV)` on the TV and
on the connect screen's row.

**states covered, and states missing**
Covered: connected with a live ping; not joined (`A Join` / `B Back`); a `good` state dot;
`Y`/`X` present as empty dashed circles; the mode control with `Sticks` selected. Missing
(**absent**): the pairing code anywhere on the pad (it is drawn only on the TV's host shell and the
Arena waiting card); any host name beyond "Android TV"; an error/disconnected state on the pad; a
pressed state; a second player's colour or name.

**cross-screen inconsistencies versus the other screens**
1. The centre pill reads `Start` here, `Pause` in-round, `Resume` when paused, and is **absent** at
   the results and scoreboard — one position, four behaviours, and the label is the only clue.
2. `Y` and `X` are drawn as dashed empty circles with no label in the connected state; in-round the
   same treatment spreads to `B` (Record 8), so a player who learned `B = Back` loses it mid-round.
3. The pad's own name for the host is `Android TV`; the TV's card and the connect screen call it
   `Thumb Party TV (Android TV)`.
4. Sizes here (42.5 dp pill, 78.6 dp face buttons, 29.8 dp segments) share the §3 tokens with the
   TV's 48–56 dp pills but sit on a different scale, as expected for a hand-held surface.

---

## 10. Record 8 — Tablet pad, in-round

**screen / form factor / theme / viewport px**
The pad while a Bumper Round runs. Form factor: tablet, landscape. Theme: **Sunny** (sky
`#9AD5FA`→`#7DC9F8`, centre `#C4EAFF`). Viewport: **2560x1600 px = 1157.1x723.2 dp** at density
354.

**elements in reading order** (the top bar is unchanged from Record 7 except the ping)

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Player badge "1" | 29,37–96,111 | 68 x 75 | 30.7 x 33.9 | `player(1)` |
| 2 | Connection pill "● Android TV · 18 ms" | 118,15–589,108 | 472 x 94 | 213.3 x 42.5 | `background`, ink edge 8 px, `good` dot |
| 3 | Latency line "30 s: min 9 · avg 18 · max 89 ms" | 589,35–1190,94 | 602 x 33 | 272.1 x 14.9 | ink on `background` = 9.12:1 |
| 4 | Mode control + `Sticks` selected | 1560,27–2223,96; fill 2001,29–2220,94 | 663 x 69 | 299.7 x 31.2 | `caution` fill, ink label 9.13:1 |
| 5 | Icon buttons | 2257,41–2510,83 | 254 x 43 | 114.8 x 19.4 | ink glyphs |
| 6 | Left stick | 39,893–439,1293 | 400 x 400 | 180.8 x 180.8 | `paper` disc, ink edge 6 px |
| 7 | Centre pill `Pause` | 1293,1068–1431,1149 (label 1305,1094–1419,1123) | 138 x 81 | 62.4 x 36.6 | `paper`, ink edge 6 px; label 52 x 13.6 dp, ink on `paper` 15.53:1 |
| 8 | D-pad | 554,1318–824,1587 | 270 x 269 | 122.0 x 121.6 | `paper` |
| 9 | Right stick | 1736,1269–2055,1587 | 319 x 318 | 144.2 x 143.7 | `paper` |
| 10 | `A` `Dash` | 2179,1214–2352,1387 | 174 x 174 | 78.6 x 78.6 | `good`; "A" 2237,1262–2296,1330 (60 x 69 px = 27.1 x 31.2 dp for both lines) |
| 11 | `Y`, `X`, `B` — empty dashed circles | Y 2179,906–2352,1079; X 2025,1060–2198,1233; B 2333,1060–2506,1233 | 174 x 174 each | 78.6 x 78.6 | dashes sampled `#6990BB` on `background` = **1.82:1** — **not a §3 token, `unmeasured`** |
| 12 | `Select`, `LB`, `RB` — absent | — | — | — | not drawn in-round |

**primary action**
`A` now reads **`Dash`** — 78.6 x 78.6 dp of `good` `#2FCB74` with ink edges, label ink on `good`
= **7.88:1**. It is the only filled face button in the frame; the other three are dashed rings.
The change from `OK` (Record 7) to `Dash` is the pad's **only** in-round signal that the round has
started.

**secondary actions**
`Pause` (62.4 x 36.6 dp) is the only other labelled control; the mode control, three icon buttons,
two sticks and the D-pad are unchanged and still live. `B` is gone as a button and reappears as an
unlabelled dashed circle.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis anywhere. The ping label is one line; the latency line is one line of
602 px; "Pause" is one line of 115 px inside its 138 px pill (11.5 px padding each side); the `A`
face stacks two lines ("A" over "Dash") inside 174 px.

**states covered, and states missing**
Covered: an in-round pad with a single action (`Dash`); a live ping and min/avg/max latency
updated through the round; `Pause` reachable; three empty dashed face circles. Missing
(**absent**): **the clock** (no time-left readout anywhere on the pad); **the coin count or any
score** (the TV showed 0 vs 24 at this moment); **who is winning**; the round number; a dash
cooldown/progress indicator (the TV showed `Dash ready (A)` / `Dash in 0.8 s`, the pad showed
nothing); a haptic or colour cue that a dash fired; a "last 15 s" warning.

**cross-screen inconsistencies versus the other screens**
1. **The controller carries no score.** Across the whole in-round state the tablet showed the A
   button and a ping — never the 60 s clock, never the 0-vs-24 coin count that the TV was
   rendering. The player holding the tablet cannot tell the score or the time without looking up.
2. The TV's HUD says `Dash ready (A)` while the pad's button says `Dash` with no ready/not-ready
   state — the readiness is on the TV, the action on the phone.
3. Dashed empty circles at 1.82:1 are the lowest-contrast control outlines in the pass, below the
   3:1 WCAG non-text threshold; the same circles are used for three different absent buttons.
4. The mode control stays live in-round (299.7 x 31.2 dp) with no confirmation, so a mis-tap
   during a round switches the pad between `D-pad`/`Gyro`/`Sticks`.

---

## 11. Record 9 — Tablet pad, paused

**screen / form factor / theme / viewport px**
The pad while the TV shows the `Paused` card (Record 4). Form factor: tablet, landscape. Theme:
**Sunny**, undimmed — the pad does not dim with the TV (sky `#9AD5FA`→`#7DC9F8`). Viewport:
**2560x1600 px = 1157.1x723.2 dp** at density 354.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Player badge "1" | 29,37–96,111 | 68 x 75 | 30.7 x 33.9 | `player(1)` |
| 2 | Connection pill "● Android TV · 13 ms" | 118,15–589,108 | 472 x 94 | 213.3 x 42.5 | `background`, `good` dot |
| 3 | Latency line "30 s: min 11 · avg 19 · max 83 ms" | 589,35–1190,94 | 602 x 33 | 272.1 x 14.9 | ink on `background` |
| 4 | Mode control + `Sticks` | 1560,27–2223,96 | 663 x 69 | 299.7 x 31.2 | `caution` selected |
| 5 | Icons | 2257,41–2510,83 | 254 x 43 | 114.8 x 19.4 | ink glyphs |
| 6 | Left stick, D-pad, right stick | 39,893; 554,1318; 1736,1269 | as Record 8 | as Record 8 | `paper` |
| 7 | Centre pill `Resume` | 1293,1068–1431,1149 (label 1304,1097–1419,1119) | 138 x 81 | 62.4 x 36.6 | `paper`; label 116 x 23 px = 52.4 x 10.4 dp |
| 8 | `A` `OK` | 2179,1214–2352,1387 | 174 x 174 | 78.6 x 78.6 | `good` |
| 9 | `B` `Resume` | 2333,1060–2506,1233 | 174 x 174 | 78.6 x 78.6 | `bad` `#FF4D5E` — **a resume action painted in the "wrong/hazard" colour** |
| 10 | `Y`, `X` — empty dashed circles | 2179,906; 2025,1060 | 174 x 174 | 78.6 x 78.6 | `#6990BB` dashes |

**primary action**
`B` — labelled `Resume`, 78.6 x 78.6 dp of `bad` `#FF4D5E` with ink label (ink on `bad` =
**5.15:1**). The TV's own card offers `Resume` in `good`; **the same action is `bad`-red on the
phone and `good`-green on the TV in the same second.** `A` (`OK`) is the passive alternative, and
the centre `Resume` pill is a third path.

**secondary actions**
`A` `OK` (78.6 dp, 7.88:1); the centre `Resume` pill (62.4 x 36.6 dp, 15.53:1); the mode control;
two sticks; the D-pad.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis. `Resume` in the centre pill measured 116 x 23 px (52.4 x 10.4 dp), one
line, inside a 138 px pill — 11 px of padding each side. The `B` face stacks `B` over `Resume`,
where every other face label is a single short word (`Join`, `Back`, `Dash`, `OK`, `Leave`).

**states covered, and states missing**
Covered: a paused pad with three routes to resume (`A OK`, `B Resume`, centre pill); a live ping
that keeps updating while paused; the same dashed `Y`/`X`. Missing (**absent**): any dimming or
"Paused" word **on the pad itself** — the pad looks like a slightly re-labelled in-round pad, so
nothing on the touch surface says the round is stopped; a quit/leave choice (the TV's `Quit` has
no phone equivalent); a `Start`-equivalent resume (the phone's Start pill reads `Resume`, so
"Start or Resume" on the TV maps to one pill on the phone, not two).

**cross-screen inconsistencies versus the other screens**
1. **Colour clash on one action:** `Resume` is `good` on the TV card, `bad` on the phone's B, and
   plain ink on the phone's centre pill.
2. The TV dims its whole screen for the pause; the phone does not dim at all — two different
   signals for the same state.
3. `Quit` exists only on the TV (a phone thumb has no equivalent), so a controller-only player
   cannot leave the round from the controller.
4. The word count for one action is three: `Resume` (B), `Resume` (pill), `OK` (A) on the phone,
   plus `Start or Resume` in the TV's sentence.

---

## 12. Record 10 — Tablet pad at the results card and the scoreboard

**screen / form factor / theme / viewport px**
The pad while the TV shows the `Robo wins!` card (Record 5) and, unchanged, while it shows the
night scoreboard (Record 6). Form factor: tablet, landscape. Theme: **Sunny** (sky
`#9AD5FA`→`#7DC9F8`). Viewport: **2560x1600 px = 1157.1x723.2 dp** at density 354.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Player badge "1" | 29,37–96,111 | 68 x 75 | 30.7 x 33.9 | `player(1)` |
| 2 | Connection pill "● Android TV · 16 ms" | 118,15–589,108 | 472 x 94 | 213.3 x 42.5 | `background`, `good` dot |
| 3 | Latency line "30 s: min 6 · avg 20 · max 43 ms" | 589,35–1190,94 | 602 x 33 | 272.1 x 14.9 | ink on `background` |
| 4 | Mode control + `Sticks` | 1560,27–2223,96 | 663 x 69 | 299.7 x 31.2 | `caution` selected |
| 5 | Icons | 2257,41–2510,83 | 254 x 43 | 114.8 x 19.4 | ink glyphs |
| 6 | Left stick, D-pad, right stick | 39,893; 554,1318; 1736,1269 | as Record 8 | as Record 8 | `paper` |
| 7 | Centre pill — **absent** | — | — | — | no `paper` shape between x 1200–1500, y 1000–1250 |
| 8 | `A` `OK` | 2179,1214–2352,1387 | 174 x 174 | 78.6 x 78.6 | `good` |
| 9 | `B` `Back` | 2333,1060–2506,1233 | 174 x 174 | 78.6 x 78.6 | `bad` |
| 10 | `Y`, `X` — empty dashed circles | 2179,906; 2025,1060 | 174 x 174 | 78.6 x 78.6 | `#6990BB` dashes |

**primary action**
`A` `OK` (78.6 x 78.6 dp, ink on `good` 7.88:1) is the label the app gives a confirm while the
results card is up; the TV's card was advanced with the remote's `23` instead, so whether a tap on
the phone's `A` presses `Next` is `unmeasured`.

**secondary actions**
`B` `Back` (78.6 dp, 5.15:1); the mode control; two sticks; the D-pad. No other control appears.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis. The pad carries **no new text at all** in this state: the score, the
winner, the coin counts and the round number that the TV is showing produce no label, badge or
line on the tablet.

**states covered, and states missing**
Covered: a pad with two labelled buttons and no centre pill; a live ping through the results and
through the scoreboard. Missing (**absent**): the winner (`Robo wins!`); the coin counts
(`0 coins` / `22 coins`); the night points (`★27` / `★70`); the round number; an "OK = Next" hint;
a "between rounds" or "waiting for the host" state; a personal result of any kind.

**cross-screen inconsistencies versus the other screens**
1. **The result exists only on the TV.** The controller that played the round shows the same
   `A OK / B Back` pad it shows between rounds, before a round, and on the scoreboard — the result
   is invisible from the hand-held half of the pair.
2. The centre pill disappears exactly when a confirm becomes available (`Next` is waiting on the
   TV), so the one control that looked like "the main button" is the one that vanishes.
3. `OK` on the phone, the remote's `23` on the TV, and `Next` on the card: three names for the same
   press.

---

## 13. Record 11 — Tablet `Connect to a TV`, connected state

**screen / form factor / theme / viewport px**
The connect screen with a **live** link to the TV, reached by tapping the connection pill on the
pad. This is a state `vf-2dev-lifecycle` did not capture (that pass only saw the error state).
Form factor: tablet, landscape. Theme: **Sunny** — corners `#7DC9F8` (§3 `background`
`#7CC8F8`), dots present. Viewport: **2560x1600 px = 1157.1x723.2 dp** at density 354.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Back arrow | 45,46–78,78 | 34 x 33 | 15.4 x 14.9 | ink glyph on background |
| 2 | Title "Connect to a TV" | 162,39–668,87 | 507 x 49 | 229.1 x 22.1 | ink on `background` = 9.12:1 |
| 3 | Status "● Connected · 11 ms" | 2056,48–2433,74 | 378 x 27 | 170.8 x 12.2 | ink on `background` |
| 4 | Diagnostics icon | 2468,45–2510,79 | 43 x 35 | 19.4 x 15.8 | ink glyph |
| 5 | Label "Games on this Wi-Fi" | 38,180–408,205 | 371 x 26 | 167.7 x 11.8 | ink on `background` = 9.12:1 |
| 6 | Refresh button | 1315,177–1350,212 | 35 x 35 | 15.8 x 15.8 | ink glyph |
| 7 | Left pane | 36,248–1385,1465 | 1349 x 1217 | 609.7 x 550.1 | `paper`, ink edge 8 px |
| 8 | Discovered host row | 53,266–1368,425 (paper 60,273–1361,417) | 1315 x 159 | 594.4 x 71.9 | `paper`, ink edge 8 px |
| 9 | Monitor glyph | 78,316–150,375 | 72 x 59 | 32.5 x 26.7 | ink on `paper` |
| 10 | Row title "Thumb Party TV (Android TV)" | 182,300–779,339 | 598 x 40 | 270.3 x 18.1 | ink on `paper` = 15.53:1 |
| 11 | Row subtitle "TV · 192.168.1.100:45780" | 181,342–654,388 | 473 x 47 | 213.8 x 21.2 | `#615975` on `paper` — `unmeasured` (raw 6.12:1) |
| 12 | Row state ✓ | 1298,324–1342,367 | 44 x 43 | 19.9 x 19.4 | ink circle with a tick (this screen's connected marker) |
| 13 | Pane divider | 1421,0–1422,1600 | 2 x 1600 | 0.9 x 723.2 | ink hairline |
| 14 | Right-pane check disc | 1955,632–2027,704 | 73 x 73 | 33 x 33 | `good` `#2FCB74` |
| 15 | "Connected to Android TV" | 1738,746–2243,777 | 506 x 32 | 228.7 x 14.5 | ink on `background` = 9.12:1 |
| 16 | "Ping 11 ms" | 1893,805–2091,838 | 199 x 34 | 89.9 x 15.4 | ink on `background` |
| 17 | "Last 30 s: min 7 · avg 18 · max 91 ms" | 1659,860–2325,893 | 667 x 34 | 301.5 x 15.4 | ink on `background` |
| 18 | "Go back to use the controller." | not found in the ink mask | — | — | `#615975` on `background` — `unmeasured` |
| 19 | `Disconnect` | 1836,1003–2146,1089 (fill 1844,1011–2138,1081) | 310 x 86 | 140.1 x 38.9 | `good`, ink edge 8 px |
| 20 | Address field "Or type the address" | 42,1479–1086,1575 | 1044 x 96 | 471.9 x 43.4 | `paper`, ink edge 8 px |
| 21 | `Connect` | 1120,1486–1375,1573 (fill 1128,1494–1367,1564) | 255 x 87 | 115.3 x 39.3 | `good`, ink edge 8 px |

**primary action**
`Disconnect` — `good` pill 140.1 x 38.9 dp, ink edge 8 px, ink on `good` = **7.88:1**. The screen
has **no connect action** in this state (the host is already connected); the only other button is
the address field's `Connect` (115.3 x 39.3 dp).

**secondary actions**
`Connect` beside the address field; the refresh glyph (15.8 dp); the back arrow; the diagnostics
glyph; and the discovered row itself, which now carries a ✓ instead of the `>` chevron it shows
when unselected.

**text that wraps or truncates at this size, and how**
No wrap and no ellipsis. The row is one title line (598 px) plus one subtitle line (473 px). The
right pane's three lines are 506 / 199 / 667 px, each one line, centred on x ≈ 1980. The longest
line in the pane, "Last 30 s: min 7 · avg 18 · max 91 ms", is 667 px inside the 1139 px right pane.
The address field's placeholder is one line. The window is split at x 1421, so the left pane takes
55.5 % of the width.

**states covered, and states missing**
Covered: a connected state with a ✓ row, a green check, a ping, a 30 s min/avg/max and the
`Disconnect` action; `Connected` in the top-right status; a live ping of 11 ms. Missing
(**absent**): any pairing-code prompt (`Disconnect` is the only route to one); a "reconnecting"
state; a list of more than one host; the TV's own name repeated consistently (`Connected to
Android TV` here, `Thumb Party TV (Android TV)` on the row above it, in the same frame); a
latency history or graph.

**cross-screen inconsistencies versus the other screens**
1. **Two names for the same host inside one screen:** the row says `Thumb Party TV (Android TV)`
   and the pane below says `Connected to Android TV`.
2. This screen's `Disconnect` (38.9 dp) and `Connect` (39.3 dp) are shorter than the pad's face
   buttons (78.6 dp) and taller than the `Pair`/`Cancel` of the code panel
   (`vf-2dev-lifecycle` Record 6: 32.1 dp) — three button heights for one flow.
3. The ✓ that means "this host is the connected one" is a plain ink circle-tick drawn on the
   `paper` row, while the pane's "connected" marker is a `good` disc — two connected glyphs, two
   colours, one state.

---

## 14. In-round / results observations

1. **The round is one-way information.** Over five tablet captures across the two rounds the pad
   showed `A Dash`/`A OK`, a ping and a `Pause`/`Resume` pill; the TV showed the clock, both coin
   counts, the dash state and the winner. Nothing in the round's data crossed back to the
   controller.
2. **The HUD's player rows appear only after the countdown.** The band grew from 108 px to 284 px
   and the field's top edge moved 174 px (87 dp) between `Get ready 2` and the first in-round
   frame.
3. **`Round 1` was drawn for two different rounds.** Round 1 (`45.8 s`, results `0 / 22`) and
   round 2 (`58.1 s`, results `0 / 38`) both carried `Round 1` in the HUD and on the results card;
   the scoreboard between them read `Round 1 of 3` and then `Round 2 of 3`.
4. **`Best –` never filled** in either round — the field belongs to a finish-time record that a
   60 s timed round never produces.
5. **The clock never turned `bad`.** At 6.6 s left the digits sampled `#1E1646` on `paper`, the
   same as at 45.8 s and at 60.0 s.
6. **Two different maps were played and neither was named.** Round 1's field: open blue field,
   four bumpers, straight `wall` segments. Round 2's field: `caution`-striped hazard border, a
   conveyor loop with paper arrows, four gear glyphs. No surface showed a map name before, during
   or after either round.
7. **The pause is asymmetric.** The TV dims everything and shows a card; the phone neither dims nor
   says "Paused", and offers the same action in two colours (`good` on the TV, `bad` on the phone).
8. **Coins on the results card, points on the scoreboard.** 22 coins → `+27`; 38 coins → `+43`.
   Neither number is shown anywhere during the round.
9. **The results card overlaps the HUD.** Its top edge (y 247) sits above the HUD band's bottom
   (y 284) and clips the third row mid-glyph.
10. **Next round starts on one press.** On the scoreboard a round pill both chooses and starts the
    round (no confirm), and a second player's readiness is not requested — the night went straight
    from `Round 2 of 3` into the next round's waiting card on a single `23`.

---

## 15. Measurement notes (what is not a number)

**`unmeasured` (no §3 token pair, or no measurable box):**
- `#615975` — "Not ready yet", "Robo joins you" (TV waiting card), the `Code` label, the connect
  row's subtitle, "Go back to use the controller.". Raw on `paper` **6.12:1**, on the tablet sky
  **4.16:1**.
- `#6990BB` — the dashed empty face circles (Y/X/B). Raw on `background` **1.82:1**. Not a §3
  token; the circles have no label.
- `good` text on `paper` — "Ready" on the waiting card (1.97:1) and `+43` on the scoreboard
  (1.97:1). Both tokens exist, but this **foreground/background pair** is not in the table.
- The pause scrim — sampled `#536265`, `#757168`, `#75510F`, `#0E0A20`; no §3 entry.
- The map names for both Bumper Rounds; the map id behind each field.
- The clock's `bad` state: measured as **not** present, but the exact rule that would turn it
  `bad` was not exercised beyond 6.6 s.
- TV hit boxes (Flutter exposes no `uiautomator` semantics on the TV) and the tablet pad's hit
  boxes beyond its single semantic node (`Player 1`) — all press targets are `unmeasured`; only
  drawn shapes are given.
- Corner radii, shadow offsets and the font sizes behind the measured ink heights.

**`absent` (drawn nowhere in the captures):**
- A `Start`/confirm control on a TV Arena waiting card.
- The score, clock, coin count or `Paused` word on the tablet, in any state.
- A pairing code on the tablet and on the TV's in-round screens (it exists on the waiting card and
  the host shell only).
- A map name on any round surface.
- The clock's `bad` colour in the last 15 s.
- A tie, "no winner", or "nobody scored" results state.
- The night's three awards (`Round Winner`, `Try Again`, `Big Bopper`) on the scoreboard that is
  meant to track them.
- An `End night`, `Settings` or per-round history control on the scoreboard.
- A `Quit`/leave control on the tablet's paused pad.
- A wrong-code, connecting or reconnecting state on this pass's connect screen.

---

## 16. Flow-stage map (spec §1)

| stage | TV | tablet |
|---|---|---|
| 3 Party join | Arena waiting card, `P1 Phone 1719` / `Not ready yet` (Record 1) | connected pad, `A Join` → `A OK` (Record 7) |
| 5 Lobby & waiting | the same card with a focused player row | the same pad |
| 7 Round intro / countdown | `Get ready 3` / `2` (Record 2) | `A OK`, `B Back` (Record 7/10) |
| 8 In-round controls | HUD + field, no TV control (Record 3) | `A Dash`, `Pause` (Record 8) |
| 8 In-round controls (paused) | `Paused` card, `Quit`/`Resume` (Record 4) | `Resume` pill, `B Resume` (Record 9) |
| 9 Round end | clock `0.0 s`, card appears (Record 5) | nothing (Record 10) |
| 10 Results / scoreboard | `Robo wins!` card (Record 5) | nothing (Record 10) |
| 11 Next round / Play again | `Round N of 3` scoreboard with two round pills (Record 6) | nothing (Record 10) |
| 6 Game selection | reached only as the round-1 picker before the night started | — |
| 1, 2, 4, 12, 13 | not reached in this pass (1–2 covered by `vf-2dev-lifecycle`; 12 and 13 out of scope) | not reached |
