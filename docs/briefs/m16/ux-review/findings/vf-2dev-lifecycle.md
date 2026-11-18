# vf-2dev-lifecycle — connection lifecycle, TV host + tablet controller

Worker: `vf-2dev-lifecycle`. Scope: the connection lifecycle between the TV host
(`com.thumbparty.tv`, serial `192.168.1.100:5555`) and the tablet controller
(`com.thumbparty.app`, serial `adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp`), states 1–5
of the brief. Theme: Sunny (afternoon). No code, test, protocol, map or dependency was
touched. No `wm size` / `wm density` change was issued on either device. No device or app
setting was changed; Wi-Fi was not touched. The tablet's keyguard/lockscreen setting was not
changed by this worker (the owner unlocked the device and extended its screen timeout; this
worker only used `am start` / `am force-stop` on the app and `input` taps on the app UI).

**Outcome in one line.** All five states were captured on both devices. The TV path to the
join screen is host shell → `Play` picker → `Party night` setup → `Pick round 1` → `Shape
Race` → puzzle `Fish` → join screen. The tablet reaches that host by **auto-discovery of
"Thumb Party TV (Android TV)" on the Wi-Fi list plus a manual 4-digit code** (the TV's
`Pairing code` `1219`); it then auto-reconnects on relaunch with no re-entry screen and no
second code. A `force-stop` drop leaves **no away/dropped state on the TV** — the slot is
cleared and the screen returns to its empty state within 0.9 s. Backgrounding the TV with
HOME leaves **no host-away card on the tablet** at 5 s, 15 s or 45 s: the pill keeps showing a
live latency and the pad stays in its joined state.

---

## 0. Devices, captures and measurement basis

| Item | TV host | Tablet controller |
|---|---|---|
| Serial | `192.168.1.100:5555` | `adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp` |
| `wm size` | `Physical size: 3840x2160` / `Override size: 1920x1080` | `Physical size: 1600x2560` (no override) |
| `wm density` | `Physical density: 320` | `Physical density: 320` / `Override density: 354` |
| `dumpsys window displays` | `init=3840x2160 320dpi base=1920x1080 320dpi cur=1920x1080 app=1920x1080` | `real 2560 x 1600, rotation 3 (ROTATION_270), density 354` |
| Viewport used below | **1920x1080 px, landscape = 960x540 dp**, `dp = px / 2` | **2560x1600 px, landscape = 1157.1x723.2 dp**, `dp = px / 2.2125` |
| Theme samples | corners `#80CAF8`, `#81CAF8`, `#88CEF9` vs §3 Sunny `background` `#7CC8F8`; Sunny polka dots present, Night stars absent → **Sunny** | corner/sky `#A2DAFC`…`#7CC8F8` gradient with the same Sunny dots; pill fills `#7CC8F8` → **Sunny** |

Capture protocol per spec §4: `adb shell screencap -p /sdcard/<name>.png` then `adb pull`;
PNGs read with the image tool; element boxes from pixel scans of the pulled PNGs (colour masks
per §3 token, ink `#1E1646`); contrast = WCAG 2.x on the sampled pixels; token names from
`docs/design/look-and-sound.md` §3. Where a hit box came from `uiautomator dump` it is marked
"touch"; Flutter's custom-painted pad exposes only one semantic node ("Player 1" at
`[27,9][100,115]`), so the pad is measured from pixels.

Screenshots (all under `C:\Users\mrman\AppData\Local\Temp\ux-pilot\`):

| file | screen / state |
|---|---|
| `lc-tv-02.png` | host shell, pairing code 1219 |
| `lc-tv-06.png` | Play / game picker |
| `lc-tv-07.png` | Party night setup, top |
| `lc-tv-08.png` | Party night setup, scrolled to "Pick round 1" |
| `lc-tv-09.png`, `lc-tv-12.png` | Shape Race puzzle picker (round 1) |
| `lc-tv-join.png` | join screen, 0 players (state 1) |
| `lc-tv-joined0.png` | join screen, 1 connected, not joined |
| `lc-tv-joined1.png`, `lc-tv-rejoined.png` | join screen, 1 player joined on Left |
| `lc-tv-reentry.png` | join screen after controller relaunch ("Not joined: P1 Phone 1719") |
| `lc-tv-dropped1.png`, `lc-tv-dropped2.png`, `lc-tv-dropfast1.png` | join screen 0.9 / 5 / 15 s after the drop |
| `lc-tv-home.png`, `lc-tv-back.png` | TV on the launcher during host-away, and restored |
| `lc-tab-40.png` | tablet pad, "Connecting… · tap to connect" |
| `lc-tab-41.png` | tablet "Connect to a TV" (discovery list + error card) |
| `lc-tab-42.png` | tablet code entry ("Enter the code shown on Android TV") |
| `lc-tab-43.png` | tablet connected, not joined |
| `lc-tab-44.png`, `lc-tab-46.png` | tablet connected and joined |
| `lc-tab-45.png`, `lc-tab-47.png` | tablet after relaunch — auto-reconnected, not re-joined |
| `lc-tab-away1.png`, `lc-tab-away2.png`, `lc-tab-away3.png` | tablet at 5 / 15 / 45 s after TV HOME |
| `lc-tab-back.png` | tablet after the TV returned |

---

## 1. Connection lifecycle — what was reached

Capture note: the tablet pass started with the device behind a secure keyguard inside the
Google hub-mode dream (`cmd lock_settings is-user-secure` → `true`, `isKeyguardShowing=true`,
`mShowingDream=true`; `input tap/swipe/motionevent`, `wm dismiss-keyguard`, `am start` and
`am stopservice` of the dream all left the keyguard up), so states 2–5 were initially
`blocked: secure keyguard`. The owner then unlocked the device and extended its screen
timeout; nothing in the keyguard or lockscreen settings was changed by this worker. All five
states below were captured after that, and the whole sequence was re-run (a second and third
force-stop, a second relaunch) to confirm the drop and re-entry results reproduce.

| # | State (brief) | Reached | What was on screen |
|---|---|---|---|
| 1 | TV join screen with code | **yes (TV)** | Path: shell "Pairing code 1219" → `Play` → `Shape Race`/`Arena`/`Party night` picker → `Party night` → `3 rounds` → `Pick round 1` → `Shape Race` → easy puzzle `Fish` → **"Shape Race · Fish"** join screen. The join screen carries **no code**; `1219` is only on the host shell (Record 1). |
| 2 | Tablet connects | **yes (both)** | Tablet: `Connect to a TV`, discovery row "Thumb Party TV (Android TV) / TV · 192.168.1.100:45780", then code entry → connected pad (`Android TV · 15 ms`). TV: "Not joined: P1 Phone 1719" while connected, then the player on **Left** and "1 player. Press A or Start to begin." after A. |
| 3 | Drop (`am force-stop com.thumbparty.app`) | **yes (both)** | TV at +0.9 s: fully empty join screen — slot cleared, "Nobody has joined yet.", no away card, no notice. Stable at +15 s. |
| 4 | Re-entry (relaunch controller) | **yes (both)** | Tablet: launches straight into the connected pad (`Android TV · 5 ms`), no code, no re-entry screen — **auto-reconnect**. TV: "Not joined: P1 Phone 1719"; the side is not restored; A must be pressed again to rejoin. |
| 5 | Host away (TV HOME) | **yes (both)** | Tablet at +5/+15/+45 s: unchanged joined pad (`Android TV · 9…10 ms`, A `Start`, B `Leave`) — **no host-away or waiting card**. TV: launcher; restored with `am start` and unchanged ("1 player…"). |

**Connect mechanism observed.** Two steps, both on the tablet:
1. **Auto-discovery.** The tablet's `Connect to a TV` screen lists "Games on this Wi-Fi" with one
   entry: "Thumb Party TV (Android TV)" / "TV · 192.168.1.100:45780" (a search-again control
   sits at its top-right). The host shell's `Listening on port 45780` matches the port shown.
2. **Manual 4-digit code.** Tapping the discovered row opens "Enter the code shown on Android
   TV" with a 4-digit field; the code typed was `1219`, the value the TV shell displayed. The
   shell's own instruction agrees: *On the phone, choose "Thumb Party TV (Android TV)" and enter
   this code.* No QR code and no TV-side accept prompt exist anywhere on the path.

The tablet's "tap to connect" pill did **not** connect to the TV by itself: its first attempt
went to a remembered host `DESKTOP-NSUCJ8S` and failed after 4.000000 s with "HTTP connection
timed out … host: fe80::8bb3:2e04:8dd9:a030%25wlan0, port: 45780" (Record 5, error card). The
TV was reached only through the discovered list row.

---

## 2. Record 1 — TV host shell

**screen / form factor / theme / viewport px**
Host shell of the TV app, first screen after launch. Form factor: TV, Sony BRAVIA `BRAVIA_VH1`
(panel 3840x2160, override 1920x1080). Theme: **Sunny** — corner sample `#80CAF8` against §3
Sunny `background` `#7CC8F8` (Night `#241C5E`); Sunny polka dots present. Viewport:
**1920x1080 px, landscape = 960x540 dp** at density 320 (`dp = px / 2`).

**elements in reading order** (x,y = top-left of the drawn shape; a pill's bounds are its fill;
its ink edge is `+8 px` / `4 dp` outside that)

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Monitor glyph | 19,72–76,119 | 58 x 48 | 29 x 24 | ink `#1E1646` on background |
| 2 | Title "Thumb Party TV" | 100,57–923,162 | 824 x 106 | 412 x 53 | ink on background |
| 3 | Subtitle "Listening on port 45780" | 948,80–1440,118 | 493 x 39 | 246.5 x 19.5 | ink on background |
| 4 | `Play` pill (primary) | 1483,66–1692,125 | 210 x 60 | 105 x 30 | `good` `#2FCB74`, ink edge 8 px / 4 dp; icon+label 1500–1685 (186 x 45) |
| 5 | `Haptic test` pill | 34,210–376,269 | 343 x 60 | 171.5 x 30 | `good`; label 64–345 x, 224–258 y |
| 6 | `Latency` pill | 429,210–714,269 | 286 x 60 | 143 x 30 | `good` |
| 7 | `Look and sound` pill | 767,210–1203,269 | 437 x 60 | 218.5 x 30 | `good` |
| 8 | `Look test` pill | 1256,210–1566,269 | 311 x 60 | 155.5 x 30 | `good` |
| 9 | `Stats` pill | 1619,210–1844,269 | 226 x 60 | 113 x 30 | `good` |
| 10 | Pairing-code card | 24,312–727,815 | 704 x 504 | 352 x 252 | `paper` `#FFF6E3`, ink edge 8 px |
| 11 | "Pairing code" heading | 45,348–355,399 | 311 x 52 | 155.5 x 26 | ink on `paper` |
| 12 | Code "1219" | 60,460–408,600 | 349 x 141 | 174.5 x 70.5 | ink on `paper` |
| 13 | Instruction, 3 lines | 42,610–671,745 | 630 x 136 | 315 x 68 | ink on `paper` |
| 14 | Controllers card | 760,312–1895,1055 | 1136 x 744 | 568 x 372 | `paper`, ink edge 8 px |
| 15 | "Controllers · 0 connected" | 778,356–1419,395 | 642 x 40 | 321 x 20 | ink on `paper` |
| 16 | `Forget phones` pill | 1512,346–1861,405 | 350 x 60 | 175 x 30 | `good`, ink edge 8 px |
| 17 | Controller entry row | 784,440–1871,625 | 1088 x 186 | 544 x 93 | `paper` with ink edge 8 px |
| 18 | "Laksh" (controller name) | 860,432–1200,485 | 341 x 54 | 170.5 x 27 | ink on `paper` |
| 19 | "ios · 0.14.0+835 · …" (meta) | 867,505–1270,560 | 404 x 56 | 202 x 28 | `#615975` on `paper` — **not a §3 token, unmeasured** |
| 20 | Pad diagram (D-pad, shoulders, X/Y/B/A) | 1240,432–1570,579 | 331 x 148 | 165.5 x 74 | ink on `paper` |
| 21 | State dot + "Disconnected" | 860,566–1500,633 | 641 x 68 | 320.5 x 34 | ink on `paper`; dot `bad` `#FF4D5E` at 866–900 x |
| 22 | `−` remove control | 1834,535–1860,542 | 27 x 8 | 13.5 x 4 | ink on `paper` |
| 23 | Log card | 24,849–727,1055 | 704 x 207 | 352 x 103.5 | `paper`, ink edge 8 px |
| 24 | "Log" heading | 44,894–131,944 | 88 x 51 | 44 x 25.5 | ink on `paper` |
| 25 | `Save log` pill | 402,883–693,942 | 292 x 60 | 146 x 30 | `good`, ink edge 8 px |
| 26 | "24.61 s" | 42,969–187,1025 | 146 x 57 | 73 x 28.5 | ink on `paper` |

**primary action**
`Play` — pill 105 x 30 dp (210 x 60 px), fill `good` `#2FCB74`, ink edge 8 px (4 dp), label
ink on `good` = **7.88:1** (`ink` on `good`). Its icon+label group is 186 x 45 px
(93 x 22.5 dp). Focus in this capture is not on `Play`; `lc-tv-05.png` shows `Play` focused
with a `star` `#FFD23F` ring around the pill.

**secondary actions**
`Haptic test` (171.5 x 30 dp), `Latency` (143 x 30 dp), `Look and sound` (218.5 x 30 dp),
`Look test` (155.5 x 30 dp), `Stats` (113 x 30 dp) — 5 pills 60 px (30 dp) tall, 53 px
(26.5 dp) gaps between neighbours (376→429, 714→767, 1203→1256, 1566→1619); `Forget phones`
(175 x 30 dp) at the controllers card's top-right; `Save log` (146 x 30 dp) in the log card.
All five top pills and both card actions are `good` with ink edges and ink labels at
**7.88:1**.

**text that wraps or truncates at this size, and how**
1 truncation: the controller meta line reads `ios · 0.14.0+835 · …` — an ellipsis truncates
after the third field inside the 404 px (202 dp) run, before the pad diagram. The instruction
under "Pairing code" wraps to 3 lines inside a 630 px (315 dp) column at line pitches of
45 px (22.5 dp); no hyphenation and no clipping. Title, subtitle and all five pill labels are
single lines.

**states covered, and states missing**
Covered: 0 controllers connected; one known controller `Disconnected` with a `bad`-coloured
dot; a typed code (`1219`); the listening port; a log duration. Missing (absent): connecting,
connected, pairing-in-progress, error, dropped-link-after-connection, and an empty controller
list (a stale row is always present here).

**cross-screen inconsistencies versus the other screens**
1. The shell's pills are 60 px (30 dp) tall; the join screen's `Start`/`Back` are 96 px
   (48 dp) tall (Record 4) — 36 px (18 dp) apart.
2. The shell's `Play` sits in the title row; every other screen puts its primary pill at the
   bottom-left (join screen `Start`, picker `Puzzle settings`, party-night round pills).
3. The shell alone carries the pairing code; the join screen does not repeat it (Record 4).
4. `#615975` appears here on the controller meta line and is not in §3.

---

## 3. Record 2 — TV Play / game picker

**screen / form factor / theme / viewport px**
`Play` — game picker, reached from the shell's primary action. Form factor: TV, landscape.
Theme: **Sunny** (corners `#80CAF8`, dots present). Viewport: **1920x1080 px = 960x540 dp**
at density 320.

**elements in reading order**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Back arrow | 33,63–63,92 | 31 x 30 | 15.5 x 15 | ink glyph on background |
| 2 | Title "Play" | 134,41–351,146 | 218 x 106 | 109 x 53 | ink on background |
| 3 | Card 1 `Shape Race` | 56,213–615,707 | 560 x 495 | 280 x 247.5 | `paper` `#FFF6E3`, ink edge 8 px |
| 4 | Card 1 icon | 247,283–411,394 | 165 x 112 | 82.5 x 56 | `faceB`, `#FF8A1F`, `faceA` fills |
| 5 | Card 1 title "Shape Race" | 82,478–372,529 | 291 x 52 | 145.5 x 26 | ink on `paper` |
| 6 | Card 1 body (2 lines) | 83,560–610,650 | 528 x 91 | 264 x 45.5 | ink on `paper` |
| 7 | Card 2 `Arena` | 680,213–1239,707 | 560 x 495 | 280 x 247.5 | `paper`, ink edge 8 px |
| 8 | Card 2 icon | 884,280–1041,398 | 158 x 119 | 79 x 59.5 | `faceX`, `good`/`tray` fills |
| 9 | Card 2 title "Arena" | 705,479–857,517 | 153 x 39 | 76.5 x 19.5 | ink on `paper` |
| 10 | Card 2 body (2 lines) | 708,560–1239,650 | 532 x 91 | 266 x 45.5 | ink on `paper` |
| 11 | Card 3 `Party night` — focused | 1304,213–1863,707 (ring 1296,205–1871,715) | 560 x 495 | 280 x 247.5 | `paper`, ink edge 8 px, `star` focus ring 8 px |
| 12 | Card 3 icon (crown + 3 badges) | 1531,254–1636,329 | 106 x 76 | 53 x 38 | `star`, `player1`, `good` |
| 13 | Card 3 title "Party night" | 1331,480–1616,529 | 286 x 50 | 143 x 25 | ink on `paper` |
| 14 | Card 3 body (2 lines) | 1331,550–1860,660 | 530 x 111 | 265 x 55.5 | ink on `paper` |
| 15 | Developer note | 52,924–1168,954 | 1117 x 31 | 558.5 x 15.5 | ink on background |
| 16 | `Puzzle settings` pill | 66,783–593,874 | 528 x 92 | 264 x 46 | `good`, ink edge 8 px |

**primary action**
The screen's action is a card, not a pill: the focused card is `Party night` (280 x 247.5 dp
= 560 x 495 px), carried by an 8 px (4 dp) `star` ring outside an 8 px ink edge. Card text is
ink on `paper` = **15.53:1**. The only pill, `Puzzle settings` (264 x 46 dp), is ink on `good`
= **7.88:1**.

**secondary actions**
`Shape Race` and `Arena` cards (each 280 x 247.5 dp); the back arrow (15.5 x 15 dp glyph, no
touch box exposed); the `Puzzle settings` pill (264 x 46 dp). Card gaps: 615→680 and
1239→1304, 65 px (32.5 dp) each.

**text that wraps or truncates at this size, and how**
2 truncations, one per game-card body: card 1 ends `…build the pict…` (ellipsis after "pict")
in line 2 of 2; card 2 fits in 2 lines ending "to the goal." with no ellipsis. Card 3 wraps
to 2 lines ("3 or 5 rounds, points," / "awards") with no ellipsis. Card 1's body is 528 px
wide and clipped at the card's 610 px interior edge. Card titles never wrap. The developer
note is one line of 1117 px (558.5 dp).

**states covered, and states missing**
Covered: three game choices; one focused card (`star` ring); one pill action. Missing
(absent): disabled/locked game, in-progress badge, empty list, error, loading, and any
selection count ("3 or 5 rounds" is body copy, not a state).

**cross-screen inconsistencies versus the other screens**
1. Focus shapes differ: a `star` ring around a whole card here, a `star` ring around a pill
   on the party-night and join screens.
2. The picker is the only screen with three equal columns; the shell has a two-column grid
   and the join screen two side-by-side cards.
3. `Puzzle settings` is an in-flow pill at the bottom-left, the same place the join screen puts
   `Start`, but it is a developer action.
4. Truncation exists only here, in two card bodies.

---

## 4. Record 3 — TV Party night setup (two scroll positions)

**screen / form factor / theme / viewport px**
`Party night` setup, reached from the picker. Two frames: top (`lc-tv-07.png`) and scrolled to
"Pick round 1" (`lc-tv-08.png`). Form factor: TV, landscape. Theme: **Sunny** (corner
`#81CAF8`, dots present). Viewport: **1920x1080 px = 960x540 dp** at density 320. One
`paper` card runs from y 213 past the viewport bottom (paper found to y 1079); the screen
scrolls inside the card.

**elements in reading order — frame A (top)**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Back arrow | 33,63–63,92 | 31 x 30 | 15.5 x 15 | ink on background |
| 2 | Title "Party night" | 134,41–700,146 | 567 x 106 | 283.5 x 53 | ink on background |
| 3 | Card header band | 56,213–1863,307 | 1808 x 95 | 904 x 47.5 | `player(3)` `#A66CFF`, ink edges 8 px |
| 4 | Band label "Party night" | 818,241–1102,292 | 285 x 52 | 142.5 x 26 | ink on `#A66CFF` = **4.94:1** |
| 5 | "Rounds" label | 99,385–280,424 | 182 x 40 | 91 x 20 | ink on `paper` |
| 6 | `3 rounds` pill — focused/selected | 108,465–415,590 (ring 93,462–417,587) | 295 x 96 | 147.5 x 48 | `star` `#FFD23F` fill, ink edge 8 px, `star` ring 8 px |
| 7 | `5 rounds` pill | 457,479–736,570 | 280 x 92 | 140 x 46 | `good`, ink edge 8 px |
| 8 | "The night's three awards" label | 98,657–725,700 | 628 x 44 | 314 x 22 | ink on `paper` |
| 9 | Award card 1 header "Round Winner" | 104,700–687,851 | 584 x 152 | 292 x 76 | `#C0DBE7` header, ink edge 8 px |
| 10 | Award card 1 body "Most rounds won" | 104,853–687,994 | 584 x 142 | 292 x 71 | `paper`; `player(1)` disc 128,885–213,970 |
| 11 | Award card 2 header "Try Again" | 736,700–1319,851 | 584 x 152 | 292 x 76 | `#FFD6A8` header |
| 12 | Award card 2 body "Most snaps after a wrong drop" | 736,853–1319,1015 | 584 x 163 | 292 x 81.5 | `paper`; `player(2)` disc 760,896–845,981 |
| 13 | Award card 3 header "Big Bopper" | 104,1015–1079 (cut by the viewport) | — | — | `#E4CDEB` header |

**elements in frame B (scrolled; `lc-tv-08.png`)**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Award card 3 header "Big Bopper" | 104,256–687,351 | 584 x 96 | 292 x 48 | `#E4CDEB`, ink label 259–532 x, 284–335 y |
| 2 | Award card 3 body "Most shoves" | 104,360–687,501 | 584 x 142 | 292 x 71 | `paper`; purple `#A66CFF` disc |
| 3 | Cat rule "The cat visits the side that's ahead." | 104,565–1112,635 | 1009 x 71 | 504.5 x 35.5 | ink on `paper`, after a `player(5)` `#FF5C8A` paw disc 104,567–176,639 |
| 4 | "Pick round 1" label | 99,716–397,755 | 299 x 40 | 149.5 x 20 | ink on `paper` |
| 5 | `Shape Race` round pill | 114,818–997,909 | 884 x 92 | 442 x 46 | `good`, ink edge 8 px |
| 6 | `Bumper Round` round pill — focused | 96,968–1015,1063 (ring 81,953–1030,1078) | 920 x 96 | 460 x 48 | `good`, ink edge 8 px, `star` ring 8 px |

**primary action**
`Start the night` is **absent** from both frames: no such label or pill is drawn between the
header band and the round-1 list, and the card continues past the viewport in both scroll
positions. The focused control in frame B is `Bumper Round` (460 x 48 dp), ink on `good` =
**7.88:1**; in frame A it is `3 rounds` (147.5 x 48 dp), ink on `star` = **11.63:1**.

**secondary actions**
`5 rounds` (140 x 46 dp); the three award cards are read-only in both frames (no focus ring,
no pressable affordance); `Shape Race` and `Bumper Round` round pills (442 x 46, 460 x 48 dp).
Focus is drawn with the same 8 px `star` ring on two different control types.

**text that wraps or truncates at this size, and how**
No ellipsis on this screen. Wraps: award body 2 wraps to 2 lines ("Most snaps after a" /
"wrong drop") at a 45 px (22.5 dp) line pitch; the `#C0DBE7` label "Round Winner" is one
line. The longest line in a card is the cat rule, 1009 px (504.5 dp) in an 1808 px card
(904 dp), leaving 799 px (399.5 dp) unused. All pill labels are single-line.

**states covered, and states missing**
Covered: a selected round count (`3 rounds`, `star` fill + ring) against an unselected
`5 rounds` (`good`); three award cards; round-1 choice with two options, one focused; a
scrolled continuation. Missing (absent): a start/confirm control, a disabled award, a
change-teams or shuffle control on this screen, an error, a loading state.

**cross-screen inconsistencies versus the other screens**
1. Header bands use four different fills: `player(3)` `#A66CFF`, `#C0DBE7`, `#FFD6A8`,
   `#E4CDEB`. Only `#A66CFF` is a §3 token; the other three are `unmeasured` as token pairs
   (raw ink contrasts 11.54:1, 12.27:1, 11.31:1).
2. `star` is a selected fill here and only a focus ring on the picker and the join screen.
3. The night band is 95 px (47.5 dp) tall; the picker's cards have no band.
4. Round pills are 46–48 dp tall, matching the join screen's `Start`/`Back` (46–48 dp) and
   differing from the shell's 30 dp pills.

---

## 5. Record 4 — TV join screen ("Shape Race · Fish"), four measured states

**screen / form factor / theme / viewport px**
Shape Race's round-start / join screen, reached by `Party night` → `Pick round 1` →
`Shape Race` → easy puzzle `Fish` (the same screen is Shape Race's own start screen; it
carries no party-night chrome). Form factor: TV, landscape. Theme: **Sunny** (corner
`#80CAF8`; dots present). Viewport: **1920x1080 px = 960x540 dp** at density 320.

**elements in reading order (state 1: 0 players, `lc-tv-join.png`)**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Back arrow | 33,63–63,92 | 31 x 30 | 15.5 x 15 | ink glyph on background |
| 2 | Title "Shape Race · Fish" | 131,41–996,145 | 866 x 105 | 433 x 52.5 | ink on background |
| 3 | Instruction line 1 | 51,225–1696,275 | 1646 x 51 | 823 x 25.5 | ink on background |
| 4 | Instruction line 2 "or Start begins." | 50,275–440,340 | 391 x 66 | 195.5 x 33 | ink on background |
| 5 | Hint chip "Start on a phone: pause · Back: leave" | 440,275–1160,345 | 721 x 71 | 360.5 x 35.5 | `background` `#7CC8F8` fill, light `#B7E2FC` rim, **no ink edge**; label 499,309–1138,338 |
| 6 | Left card header | 48,397–943,501 | 896 x 105 | 448 x 52.5 | `player(1)` `#2E9BF0`, ink edge 8 px, "Left" ink 487–590 x, 433–472 y, `#FF9800` arrow tile 355–420 x |
| 7 | Left card body | 48,501–943,855 | 896 x 355 | 448 x 177.5 | `paper`, ink edge 8 px |
| 8 | Left dashed slot 1 + "Room for 2 more" | 80,551–911,700 | 832 x 150 | 416 x 75 | dashed `#9A919C` edges, label `#615975` 1 line centred |
| 9 | Left dashed slot 2 (unlabelled) | 80,700–911,745 | 832 x 46 | 416 x 23 | dashed `#9A919C`, no text |
| 10 | Right card header | 976,397–1871,501 | 896 x 105 | 448 x 52.5 | `player(2)` `#FF8A1F`, ink edge 8 px, "Right" ink 1318–1446 x, 433–484 y, `#FF9800` arrow tile 1467–1513 x |
| 11 | Right card body | 976,501–1871,855 | 896 x 355 | 448 x 177.5 | `paper`, ink edge 8 px |
| 12 | Right dashed slot 1 + "Room for 2 more" | 1008,551–1839,700 | 832 x 150 | 416 x 75 | dashed `#9A919C`; label `#615975` |
| 13 | Right dashed slot 2 (unlabelled) | 1008,700–1839,745 | 832 x 46 | 416 x 23 | dashed `#9A919C` |
| 14 | `Start` pill — focused | 42,902–353,1033 (fill 60,920–335,1015) | 275 x 96 | 137.5 x 48 | `good` `#2FCB74`, ink edge 8 px, `star` ring 8 px; label 112–302 x, 949–989 y |
| 15 | `Back` pill | 383,914–654,1021 (fill 391,922–646,1013) | 256 x 92 | 128 x 46 | `good`, ink edge 8 px; label 431–640 x, 940–1000 y |
| 16 | "Nobody has joined yet." | 717,952–1186,990 | 470 x 39 | 235 x 19.5 | ink on background |

**state 2: 1 controller connected, not joined (`lc-tv-joined0.png`)**
Identical to state 1 except one new line between the cards and the action row:
`Not joined: P1 Phone 1719` — ink 52,833–604,871 (553 x 39 px = 276.5 x 19.5 dp). Footer and
both cards stay empty; `Start` stays focused.

**state 3: 1 player joined on Left (`lc-tv-joined1.png`)**
Left card: player badge `#2E9BF0` at 82,547–173,645 (92 x 99 px = 41.6 x 44.7 dp, digit "1" in
ink) with the name `P1 Phone 1719` ink 180,553–545,621; the second slot becomes dashed
`80,641–911,751` labelled `Room for 1 more` (label ink 324,689–668,719). Right card unchanged
(`Room for 2 more`). Footer changes to `1 player. Press A or Start to begin.`
(ink 715,946–1500,999). `Start` stays focused.

**state 4: after a drop (`lc-tv-dropfast1.png`, +0.9 s)**
Exactly state 1 again: both cards fully empty (`Room for 2 more` ×2), no `Not joined:` line,
footer `Nobody has joined yet.`. No away card, no toast, no countdown, no colour change; the
same frame is stable at +5 s and +15 s.

**primary action**
`Start` — focused pill 137.5 x 48 dp (275 x 96 px fill; 312 x 132 px with ring), fill `good`,
ink edge 8 px (4 dp), `star` focus ring 8 px (4 dp). Label ink on `good` = **7.88:1**. No
OK/Enter press was sent on this screen, so the effect of activating `Start` with 0 players was
not observed.

**secondary actions**
`Back` (128 x 46 dp, ink on `good` 7.88:1). The side cards are not focusable: no `star` ring
on either, and the instruction puts side choice on the phone. Dashed slots are placeholders.

**text that wraps or truncates at this size, and how**
No ellipsis. The instruction is 2 lines: line 1 runs 1646 px (823 dp) of the 1920 px viewport
and ends after "…Then A"; line 2 is "or Start begins."; line pitch 50 px (25 dp). The hint
chip label is 1 line of 640 px (320 dp) inside the 721 px chip. `Room for 2 more` /
`Room for 1 more` are 1 line each. The `Not joined:` line is 1 line of 553 px (276.5 dp).

**states covered, and states missing**
Covered: empty (0 players); connected-but-not-joined; one player joined to a side; back to
empty after a drop; focus on `Start` in every state. Missing (absent): any dropped-link or
"player away" indication; a second/third/fourth joined player; a colour chip or accessory on
the joined row; a countdown; an error; a disabled `Start`; the pairing code.

**cross-screen inconsistencies versus the other screens**
1. **This screen carries no code.** The shell prints `Pairing code 1219`; this screen only
   says "Press A on your phone to join". A player who is on this screen cannot read the code;
   going back to it means Back → round picker → Party night → Play → shell.
2. The hint chip is the only pill on any captured TV screen with `background` as its fill and
   no ink edge (`ink` on `background` = 9.12:1).
3. `#615975` (slot labels) and `#9A919C` (dashed slots) are outside §3 → `unmeasured` as token
   pairs (raw 6.12:1 and 2.83:1); `#FF9800` arrow tiles are also outside §3.
4. A joined player is drawn as a `player(1)`-coloured badge with the caption "P1 Phone 1719",
   but the side headers already use `player(1)`/`player(2)` as their fills, so the badge's
   colour and the side's colour are the same token at two meanings.
5. Three left edges coexist here: `Start`'s ring at x 42, the left card at x 48, the title at
   x 131.

---

## 6. Record 5 — Tablet "Connect to a TV"

**screen / form factor / theme / viewport px**
The tablet's connect screen, reached by tapping the "Connecting… · tap to connect" pill. Form
factor: tablet, Pixel Tablet `tangorpro`, landscape (ROTATION_270). Theme: **Sunny** (sky
`#7CC8F8`→`#A2DAFC`, dots present). Viewport: **2560x1600 px = 1157.1x723.2 dp** at density
354 (`dp = px / 2.2125`).

**elements in reading order** (bounds marked "touch" are from `uiautomator dump`; the rest are
drawn-shape scans)

| # | element | bounds px | w x h px | w x h dp | notes |
|---|---|---|---|---|---|
| 1 | Back button | 9,9–115,115 | 106 x 106 | 47.9 x 47.9 | touch |
| 2 | Title "Connect to a TV" | 162,39–668,87 | 507 x 49 | 229.1 x 22.1 | ink on background |
| 3 | Status "Not connected" | 2172,34–2436,90 | 264 x 56 | 119.3 x 25.3 | touch |
| 4 | Diagnostics button | 2436,9–2542,115 | 106 x 106 | 47.9 x 47.9 | touch |
| 5 | "Games on this Wi-Fi" | 35,167–1279,222 | 1244 x 55 | 562.3 x 24.9 | touch |
| 6 | Search again button | 1279,142–1386,248 | 107 x 106 | 48.4 x 47.9 | touch |
| 7 | Discovered host row | 53,266–1368,425 | 1315 x 159 | 594.4 x 71.9 | touch; reads "Thumb Party TV (Android TV)" / "TV · 192.168.1.100:45780" with a `>` chevron |
| 8 | Error card text 1 | 1459,568–2525,754 | 1066 x 186 | 481.8 x 84.1 | "Couldn't reach Thumb Party TV (DESKTOP-NSUCJ8S). Check that the TV app is open and that the phone is on the same Wi-Fi." |
| 9 | Error card text 2 | 1459,762–2525,873 | 1066 x 111 | 481.8 x 50.2 | "HTTP connection timed out after 0:00:04.000000, host: fe80::8bb3:2e04:8dd9:a030%25wlan0, port: 45780" |
| 10 | `Try again` | 1712,891–2008,997 | 296 x 106 | 133.8 x 47.9 | touch |
| 11 | `Cancel` | 2026,891–2271,997 | 245 x 106 | 110.7 x 47.9 | touch |
| 12 | `Try without a TV` | 1526,1032–2026,1139 | 500 x 107 | 226.0 x 48.4 | touch |
| 13 | `Host a game` | 2044,1032–2457,1139 | 413 x 107 | 186.7 x 48.4 | touch |
| 14 | `Settings` | 1826,1156–2157,1262 | 331 x 106 | 149.6 x 47.9 | touch |
| 15 | Address field "Or type the address" | 35,1472–1093,1582 | 1058 x 110 | 478.2 x 49.7 | touch |
| 16 | `Connect` | 1110,1476–1386,1582 | 276 x 106 | 124.7 x 47.9 | touch |

**primary action**
`Try again` (133.8 x 47.9 dp, `good` fill) is the first action under the error text; the
discovered host row (594.4 x 71.9 dp) is the action that actually connects. Contrasts: row
title ink on `paper` = **15.53:1**; `good` button labels ink on `good` = **7.88:1**; the
`Not connected` status ink on background = **9.12:1**; the error body text is `#615975` on the
sky — not a §3 token, **unmeasured** (raw 6.12:1 on `paper`, on this lighter sky it samples
lower).

**secondary actions**
`Cancel`, `Try without a TV`, `Host a game`, `Settings`, `Search again`, the address field +
`Connect`, and the back button. The screen is two panes split at x≈1390: discovery left, error
and fallbacks right.

**text that wraps or truncates at this size, and how**
The error sentence wraps to 3 lines in a 481.8 dp column; the technical line wraps to 2 lines.
The host row is 1 title line + 1 subtitle line. No ellipsis anywhere on this screen. The
`DESKTOP-NSUCJ8S` host name in the error text does **not** match the discovered row's name
(`Thumb Party TV (Android TV)`) — the error refers to a different, remembered host.

**states covered, and states missing**
Covered: discovery list with 1 host; an error state with a 4.000000 s timeout and the failing
IPv6 link-local host; the "not connected" status; fallbacks (try again, cancel, try without a
TV, host a game, settings); manual address entry. Missing (absent): a connecting/spinner
state, an empty discovery list, a success state on this screen, and any explanation of why
the pill's remembered host differs from the discovered one.

**cross-screen inconsistencies versus the other screens**
1. The status chip reads `Not connected`, the pill on the pad read `Connecting…`, and the
   error names a host the list does not show — three different notions of "what we are trying
   to reach" inside one flow.
2. This screen's `#615975` error body is outside §3, and so is the pad's muted text.
3. Buttons here are 47.9 dp tall; the pad's face buttons are 78.6 dp and its pills 36.6 dp.

---

## 7. Record 6 — Tablet code entry ("Enter the code shown on Android TV")

**screen / form factor / theme / viewport px**
Same connect screen with the code panel open and Gboard raised; the keyboard covers
y≈760–1600, so only the top 760 px of the app is visible. Form factor: tablet, landscape.
Theme: **Sunny**. Viewport: **2560x1600 px = 1157.1x723.2 dp** at density 354.

**elements in reading order (visible part)**

| # | element | bounds px | w x h px | w x h dp | fill |
|---|---|---|---|---|---|
| 1 | Back | 9,9–115,115 | 106 x 106 | 47.9 x 47.9 | icon button |
| 2 | Title "Connect to a TV" | 170,39–668,87 | 499 x 49 | 225.5 x 22.1 | ink on background |
| 3 | Status "Enter code" + diagnostics | 2172,34–2542,115 | 370 x 81 | 167.2 x 36.6 | ink on background |
| 4 | "Games on this Wi-Fi" | 35,167–1279,222 | 1244 x 55 | 562.3 x 24.9 | label |
| 5 | Search again | 1279,142–1386,248 | 107 x 106 | 48.4 x 47.9 | icon button |
| 6 | Selected host row | 42,255–1378,632 (row paper 60,273–1360,417) | 1337 x 378 | 604.3 x 170.8 | `paper`, `>` replaced by a ✓ check |
| 7 | Heading "Enter the code shown on Android TV" | 1380,230–2357,330 | 978 x 101 | 442.0 x 45.7 | ink on background |
| 8 | 4-digit field | 1803,345–2180,502 (ink edge 1794,336–2188,511) | 378 x 158 | 170.8 x 71.4 | `paper`, ink edge 8 px, four `0` placeholders + caret |
| 9 | `Pair` | 1784,548–1936,618 | 153 x 71 | 69.1 x 32.1 | `good`, ink edge 8 px |
| 10 | `Cancel` | 1990,548–2199,618 | 210 x 71 | 94.9 x 32.1 | `paper`, ink edge 8 px |
| 11 | Address field | 42,647–1085,742 | 1044 x 96 | 471.9 x 43.4 | `paper`, ink edge 8 px |
| 12 | `Connect` | 1128,662–1367,732 | 240 x 71 | 108.5 x 32.1 | `good`, ink edge 8 px |
| 13 | Gboard panel | 0,760–2560,1600 | 2560 x 841 | 1157.1 x 380.1 | system keyboard: digit row + 1–9,0 pad, `⌫`, `✓` |

**primary action**
`Pair` — `good` pill 69.1 x 32.1 dp, ink edge 8 px, label ink on `good` = **7.88:1**. The
code was typed with `input keyevent 8 9 8 16` (1-2-1-9) into the focused field; the app
**paired on the fourth digit by itself** — `Pair` was never tapped — and the field/code panel
was replaced by the connected pad (`lc-tab-43.png`). No second code was ever requested.

**secondary actions**
`Cancel` (94.9 x 32.1 dp), the address field + `Connect` (108.5 x 32.1 dp), search again, and
the keyboard's own `⌫`/`✓`. The selected row carries a `✓` check that the unselected row did not.

**text that wraps or truncates at this size, and how**
The heading is 1 line of 978 px (442 dp) — it fits with 1 757 px of the right pane unused. The
host row is 1 title + 1 subtitle line, as before. The keyboard hides the lower app content
entirely (no scroll indicator). No ellipsis.

**states covered, and states missing**
Covered: host selected; code field empty (four `0` placeholders + caret); `Pair`/`Cancel`;
keyboard raised; auto-submit on the fourth digit (the panel closed and the pad appeared
without `Pair` being pressed). Missing (absent): a wrong-code error state (not exercised), a
resend/refresh code affordance, a countdown or expiry on the code, any hint that the code is
on the TV's home screen rather than on the join screen the TV was showing, and any
"pairing…" progress state between the fourth digit and the connected pad.

**cross-screen inconsistencies versus the other screens**
1. The TV says "Start on a phone: pause · Back: leave" and "Press A on your phone to join";
   the tablet asks for a 4-digit code at this moment — the TV never shows that code while its
   join screen is up.
2. `Pair` (32.1 dp) and `Connect` (32.1 dp) are shorter than every other tablet button
   (47.9 dp) and shorter than the TV's 48 dp pills.

---

## 8. Record 7 — Tablet pad: connecting, connected-not-joined, connected-joined

**screen / form factor / theme / viewport px**
The controller pad, the tablet's default screen. Form factor: tablet, Pixel Tablet
`tangorpro`, landscape (ROTATION_270). Theme: **Sunny** (sky `#7CC8F8`→`#A2DAFC` with dots).
Viewport: **2560x1600 px = 1157.1x723.2 dp** at density 354.

**elements in reading order — state A: connecting (`lc-tab-40.png`)**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Connection pill "Connecting… · tap to connect" | 26,14–669,107 (ink edge 27,15–670,108) | 644 x 94 | 291.1 x 42.5 | `background` `#7CC8F8` fill, ink edge 8 px; label 120,47–634,80 (515 x 34) |
| 2 | State dot | ring 61,49–86,74; `caution` core 68,56–79,67 | core 12 x 12 | 5.4 x 5.4 | `caution` `#FFB020` core in a 6 px ink ring |
| 3 | Mode control `D-pad · Gyro · Sticks` | 1560,27–2222,96 | 663 x 70 | 299.7 x 31.6 | ink edge; `Sticks` selected with a `caution` fill |
| 4 | Stick-settings / Settings / Diagnostics icons | 2257,41–2510,83 | 254 x 43 | 114.8 x 19.4 | ink glyphs |
| 5 | `LB` / `RB` pills | 39,786–318,867 / 2241,786–2520,867 | 280 x 82 | 126.6 x 37.1 | `paper`, ink edge 6 px |
| 6 | Left stick disc + knob | 39,893–438,1292 | 400 x 400 | 180.8 x 180.8 | `paper` disc, ink edge 6 px; knob ~#69A1D1 |
| 7 | Select / Start pills | 1129,1068–1266,1148 / 1293,1068–1430,1148 | 138 x 81 | 62.4 x 36.6 | `paper`, ink edge 6 px |
| 8 | D-pad | 554,1318–823,1586 | 270 x 269 | 122.0 x 121.6 | `paper`, ink edge 6 px |
| 9 | `Y` / `X` / `B` / `A` buttons | Y 2179,906 / X 2025,1060 / B 2333,1060 / A 2179,1214 | 174 x 174 each | 78.6 x 78.6 | `faceY` `#FFD23F`, `faceX` `#2E9BF0`, `faceB` `#FF4D5E`, `faceA` `#2FCB74`; ink edges 6 px |
| 10 | Right stick disc + knob | 1736,1269–2054,1587 | 319 x 319 | 144.2 x 144.2 | `paper` disc, ink edge 6 px |

**state B: connected, not joined (`lc-tab-43.png`)**

| # | element | bounds px | w x h px | w x h dp | fill / outline |
|---|---|---|---|---|---|
| 1 | Player badge "1" | 29,37–96,111 (fill) | 68 x 75 | 30.7 x 33.9 | `player(1)` `#2E9BF0`; digit ink 56,66–90,100 (35 x 35) |
| 2 | Connection pill "● Android TV · 15 ms" | 118,15–692,108 (ink edge) | 575 x 94 | 259.9 x 42.5 | `background` fill, ink edge 8 px; label 152,47–552,74 (401 x 28); `good` dot |
| 3 | Latency line "30 s: min 15 · avg 15 · max 15 ms" | 710,40–1560,83 | 851 x 44 | 384.6 x 19.9 | ink on background |
| 4 | Mode control (unchanged) | 1560,27–2222,96 | 663 x 70 | 299.7 x 31.6 | as state A |
| 5 | Icons (unchanged) | 2257,41–2510,83 | 254 x 43 | 114.8 x 19.4 | as state A |
| 6 | `Y` and `X` — **absent as fills** | Y ~2179,906–2352,1079; X ~2025,1060–2198,1233 | 174 x 174 (outlines only) | 78.6 x 78.6 | dashed ink circles, no fill, no glyph |
| 7 | `A` `Join` | 2179,1214–2352,1387 | 174 x 174 | 78.6 x 78.6 | `good`; letter "A" + label "Join" |
| 8 | `B` `Back` | 2333,1060–2506,1233 | 174 x 174 | 78.6 x 78.6 | `bad`; letter "B" + label "Back" |
| 9 | `Select`, `LB`, `RB` — **absent** | — | — | — | not drawn in the connected states |
| 10 | Left stick, D-pad, right stick, `Start` | as state A (39,893; 554,1318; 1736,1269; 1293,1068) | — | — | unchanged |

**state C: connected and joined on Left (`lc-tab-44.png`)**
As state B, with the two-action labels changed: `A` = **`Start`**, `B` = **`Leave`**; the pill
read `Android TV · 22 ms` (dot `good`). No other box moved by more than 1 px.

**primary action**
State A: the connection pill itself (291.1 x 42.5 dp) — the only tappable route to a host;
label ink on `background` = **9.12:1**. State B/C: `A` (78.6 x 78.6 dp) — in B it reads
`Join`, in C `Start`; ink on `faceA`/`good` = **7.88:1**. `B` (`Back`/`Leave`) is ink on
`bad` = **5.15:1**; `X` ink on `faceX` = **5.61:1**; `Y` ink on `faceY` = **11.63:1**.

**secondary actions**
Mode control (3 segments, 299.7 x 31.6 dp); three icon buttons (47.9 x 47.9 dp touch each);
`LB`/`RB` (126.6 x 37.1 dp) and `Select`/`Start` (62.4 x 36.6 dp) — all of these are **absent**
in the connected states B and C, where only `Start`, the sticks, the D-pad and `A`/`B` remain;
`Y`/`X` are replaced by dashed empty circles.

**text that wraps or truncates at this size, and how**
No wraps and no ellipses on this screen. The connecting label is 1 line of 515 px (232.7 dp)
inside the 644 px pill (129 px, 58.3 dp, of free space); the connected label is 1 line of
401 px (181.3 dp) inside 575 px. The latency line is 1 line of 851 px (384.6 dp). The button
labels are 2 lines each (letter + word) inside 174 px (78.6 dp) circles.

**states covered, and states missing**
Covered: connecting/waiting with a `caution` dot; connected with a `good` dot and latency
min/avg/max; connected-and-joined (A `Start`, B `Leave`); connected-not-joined (A `Join`,
B `Back`); a silent reconnected state after relaunch (state 4 in §1, same layout as B with a
live latency). Missing (absent): an error/disconnected state on the pad itself (`bad` dot or
error text), a host-away/waiting card (never appeared — §9), a "player away" state, a pressed
or disabled control state, and any name for the host other than "Android TV".

**cross-screen inconsistencies versus the other screens**
1. The pad's own name for the host is `Android TV`, the TV calls itself `Thumb Party TV
   (Android TV)` on the connect screen, and the error text calls a third host
   `DESKTOP-NSUCJ8S`.
2. `X` and `Y` exist only while not joined; in the joined state they are empty dashed circles
   with no label and no explanation.
3. The pad's pills (36.6–42.5 dp) and face buttons (78.6 dp) are on a different size scale
   from the TV's 30–48 dp pills — as expected for a hand-held surface, but the two apps share
   the same §3 button tokens.

---

## 9. Lifecycle observations (states 2–5)

**State 2 — connect.** Discovery listed exactly one host. Tapping the "tap to connect" pill
first attempted `DESKTOP-NSUCJ8S` and failed in 4.000000 s; tapping the discovered
`Thumb Party TV (Android TV)` row opened the code panel; `1219` paired on the first attempt.
The TV then showed `Not joined: P1 Phone 1719` (connected, side not chosen). Pressing `A` on
the tablet moved the player into the **Left** card and changed the TV footer to
`1 player. Press A or Start to begin.`; the tablet changed `A` from `Join` to `Start` and `B`
from `Back` to `Leave`. The TV's joined row shows the tablet's own identity string,
`P1 Phone 1719` (player number + device name + number), not a name typed anywhere on the TV.

**State 3 — drop.** `am force-stop com.thumbparty.app` while the player was joined on Left.
At +0.9 s the TV already showed the fully empty join screen (`Nobody has joined yet.`, both
cards `Room for 2 more`); the same frame at +5 s and +15 s. **No away card, no "player left"
message, no colour change, no countdown** was produced: the slot simply disappears.

**State 4 — re-entry.** `am start` of the controller 15 s after the force-stop went straight
to the connected pad (`Android TV · 5 ms`, badge 1, `A Join`, `B Back`) with **no code, no
re-entry screen, no "welcome back"**. The TV showed `Not joined: P1 Phone 1719` — the
connection was restored but the **side choice was not**; the player had to press `A` again to
rejoin Left. A second relaunch reproduced the same auto-reconnect.

**State 5 — host away.** With the player joined, `input keyevent 3` (HOME) on the TV. The
tablet was captured at +5 s, +15 s and +45 s: the pad remained in its joined state in all
three (`Android TV · 9 ms`, then `9 ms`, then `10 ms`; min/avg/max advanced 5/14/20 →
5/13/20 → 9/14/21), `A Start`, `B Leave` — **no host-away card, no waiting card, no dimming**.
The host app keeps serving while backgrounded, and the controller therefore has nothing to
report. On `am start -n com.thumbparty.tv/.MainActivity` the TV returned to the same joined
join screen (`1 player. Press A or Start to begin.`), and the tablet stayed on the joined pad.

---

## 10. `unmeasured` and `absent`

**`unmeasured` (no §3 token pair):**
- `#615975` — TV controller meta line, TV slot labels, tablet error body.
  Raw on `paper` 6.12:1.
- `#9A919C` — TV dashed slot outlines. Raw on `paper` 2.83:1.
- `#C0DBE7`, `#FFD6A8`, `#E4CDEB` — award-card header bands. Raw ink contrasts 11.54:1,
  12.27:1, 11.31:1.
- `#FF9800` — join screen arrow tiles (not in §3).
- `#69A1D1`, `#B0A8AC`, `#8E8694` — stick knobs and D-pad shading (carried over from
  `vf-tab-01`; not in §3).
- Touch boxes on the TV: Flutter exposes no `uiautomator` semantics for the TV widgets, so all
  TV hit boxes are `unmeasured`; only drawn shapes are reported. The tablet's pad is a single
  semantic node (`Player 1`), so the tablet's pad hit boxes are also `unmeasured` beyond that
  node; the connect/code screens do expose per-button touch bounds (given above).
- Corner radii and shadow offsets: not measured.
- The exact font sizes behind the measured ink heights: not measured (ink heights are given
  in px/dp).

**`absent` (state or element not present in the captures):**
- A pairing code on the TV join screen (it exists only on the host shell).
- A "Start the night" / confirm control on the party-night setup.
- Any away/dropped/"player left" indication on the TV after a drop.
- Any host-away/waiting card on the tablet after the TV is backgrounded.
- A wrong-code error state on the tablet.
- A colour or accessory chip on the TV's joined player row.
- A second, third or fourth joined player.
- A countdown, disabled `Start`, or error state on the join screen.
- Any QR code or TV-side accept prompt.

---

## 11. Flow-stage map (spec §1)

| stage | TV | tablet |
|---|---|---|
| 1 Launch / first run | — | connecting pad (state A) |
| 2 Host setup | host shell, Play picker, Party night setup (Records 1–3) | connect screen, code entry (Records 5–6) |
| 3 Party join | join screen, 0 → connected → 1 joined (Record 4) | connected pad, `A Join` → `A Start` (Record 7) |
| 5 Lobby & waiting | join screen "1 player. Press A or Start to begin." | connected pad |
| 13 Re-entry after a drop | empty join screen, then `Not joined: P1 Phone 1719` | auto-reconnect to the joined pad |
| 4, 6–12 | not reached (no round started) | not reached |

The round was never started, so stages 6–12 (in-round controls, round end, results, next
round, end of night) are not represented on either device in this pass.
