# Option C: one host layout in a 960x540 design frame (M16 design note)

Direction decided by the owner on Nov 20. Inputs: `../FINDINGS.md` (today's screens measured in this frame),
`docs/briefs/m17/ux-review/PROPOSAL-v2.md` section 2 (Thumby S/M/L), `docs/briefs/m16/ux-review/PROPOSAL.md`
("Thumby integration"). Pictures: `mockups.html` (all screens x 3 shapes, or one with
`#screen=start&shape=852x393`) and the PNGs beside it (`<screen>-<WxH>.png`). No app code is changed by this note.

## 1. Rules

1. **One layout per screen**, drawn for a *stage* of at least 960x540 frame px, never per device.
2. **Frame and scale**: `s = min(W/960, H/540)`, frame = (W/s, H/s). 640x360 -> 960x540 (s .667); 852x393 ->
   1171x540 (s .728); 1024x768 -> 960x720 (s 1.067); 1280x800 -> 960x600; 1920x1080 -> 960x540 (s 2).
3. **Minimum text 20 frame px** (13.3 dp at 640x360, 14.6 dp at 852x393, 21 dp at 1024x768). Today the floor is 9 dp
   (FINDINGS "Type").
4. **Cards fill the stage width** (stage minus a 24 px gutter). No `maxWidth` card floating in sky. Inside a wide
   card, content is grouped: a score row is `rank, badge, name, bar, points, delta`, and the bar (width = points)
   takes the slack, so a name is never far from its score and the width is used, not empty.
5. **Header / body / footer.** Header 64 px (title left, round or state chip right). Footer 84 px, *always on screen*,
   holds the way-on button(s); the body is the only flexing region and is the only part that may contain a list.
   Way-on buttons never live in the body.
6. **No scrolling on any host screen** at the supported players (max 6) and 20 px text. If a screen does not fit,
   the screen is redesigned, not scrolled (the existing `ListView`s stay only as an unreachable safety net).
7. **Thumby gets the extra dimension** (section 3) and never causes scrolling; the stage is always >= 960x540
   after he has taken his room, so the screens in section 4 are valid with Thumby on or off. With Thumby off the
   stage simply takes his room.
8. Colour, fonts, badge accessories, stickers unchanged (Sunny look; Night via the same tokens). Text on fills is ink.

## 2. Frame math

```
s      = min(W/960, H/540)
Wf, Hf = W/s, H/s                       // layout size, devicePixelRatio 1 inside
extraW = Wf - 960,  extraH = Hf - 540   // at most one is non-zero
```
Shapes: 16:9 gives (0,0); 19.5:9 phones (852x393, 2400x1080) give extraW 211 to 240; 4:3 gives extraH 180; 16:10
gives extraH 60. Ultra-wide (21:9) gives extraW 300: Thumby's column is capped at 240 and the stage takes the other 60.

## 3. Thumby placement rule (sizes from PROPOSAL-v2 section 2, but expressed in the frame)

| extra | Thumby spot | size | caption |
| --- | --- | --- | --- |
| `extraW >= 120` | **side column** on the right, full height | column = min(extraW, 240); head 96, bubble below | bubble, up to 4 lines at 20 px |
| else `extraH >= 120` | **bottom strip**, full width | strip = min(extraH, 180); head 104 at left | bubble beside him, 24 px, 2 lines |
| else (16:9, 16:10) | **corner**: head 60 at the left end of the *footer bar*, caption bubble to its right (330 px, 2 lines at 20 px) | footer's reserved 430 px left slot | bubble |

The corner sits inside the footer, which already exists, so it covers nothing and needs no scroll. The footer's right
side keeps up to two buttons (<= 480 px); that is the budget at 960 wide. If Thumby is hidden (beat 4, in-round) or off,
the slot is released. Thumby never covers text, buttons, the crown or "+3". Beat 4 hides him on game screens (no change).

## 4. Per-screen changes (problem measured -> fix)

| screen | measured problem (FINDINGS) | redesign |
| --- | --- | --- |
| **night start** | content 734 in 540, button below the fold, 10 dp text, 60% paper | Round picker (3 / 5 rounds) moves into the header as a two-chip segment. The three awards become one row of three equal tiles, icon + name only (Best Helper, Comeback, Try Again), an "i" on each opens the explanation on tap (a small popover, so no text is lost). Player names on one line below. Shape Race and Bumper Round are the footer's two buttons. Height 392 body, no scroll. |
| **scoreboard** | 6 players: 51 px too tall, the way-on button below the fold; badge block + wide empty card | One-line rows 52 px: rank, 38 px badge, name, points bar, star + total, +delta. 6 rows = 312 fit the 392 body. "Round 2 of 5" and the last-round banner are the header chip. Shape Race / Bumper Round in the footer. |
| **final scores** | 6 players 47 px too tall, "Back to games" under the fold | Same row as the scoreboard with a **podium feel**: rank discs gold / silver / bronze for 1-3, the winner's row taller (58 px badge, 32 px type, gold wash) with the crown on the badge, confetti on the sky. 4 and 6 players both fit. "Back to games" is the footer. |
| **awards reveal** | fits; 9 dp text; no button | Same card shape, full width: big 190 badge with crown on the left, award name (52), winner name (40), reason line (26) on the right. Footer: three progress dots and a Skip (new: Thumby's long lines need a skip). Timers unchanged. |
| **Arena results** | fits (431); fixed 640 card in sky | Full-width card, the same bar-row as the scoreboard with coins; the winner's row gold wash; Robo is a row with a "bot" tag and no badge number. Next in the footer. |
| **puzzle results** | fits (446); 9 dp text; 44% paper | Full-width card: the finished picture left, headline + stars + per-player pieces right (names 24 px, pieces 20 px). Play again / Back to games in the footer. Only rules 3-5 applied. |

Thumby on each (spot per section 3): start: greeting and "pick a game"; scoreboard: the leader line (beat 6);
final: ceremony caption and winner's name; reveal: the award line (beat 7); Arena: the round synopsis (beat 5);
puzzle: how well the team did. All are one bubble, 2 to 4 lines, no layout dependency on the line's length.

## 5. Code this implies (all in `packages/party_host/lib/src/ui/` unless said)

- **One scaler at the host root**: a `HostFrame` widget above the `Navigator` (the host's `MaterialApp.builder`, see
  `packages/party_host/lib/party_host.dart` where the `ToyLookScope` wraps it): computes `s` from `MediaQuery.size`, lays the
  child out at `(W/s, H/s)` and scales it (`FittedBox`/`Transform.scale` with `MediaQuery` overridden to the frame size and
  `devicePixelRatio` adjusted). It provides `HostFrameInfo` (frame, stage rect, Thumby mode) via an inherited widget. Hit-testing,
  focus ring size and the TV d-pad are unaffected (same widget tree; only a transform).
- **Delete the fixed card widths**: `arenaResultsWidthPx = 640` (`arena_results.dart:18`, used at `:104`),
  `nightRevealCardWidthPx = 860` (`night_reveal_screen.dart:33`, `night_reveal_widgets.dart:30`), `nightScoreCardWidthPx = 900`
  (`night_scoreboard_screen.dart:29`, `night_scoreboard_widgets.dart:46`), `nightStartCardWidthPx = 1040`
  (`night_start_screen.dart:22`, `:97`). Cards take the stage width.
- **Type**: `toy_look` `ToyType.phone` is 32/18/15 px and `ToyType.tv` 56/28/22 (`toy_type.dart:13-18`). In the frame there is one size
  set; the host uses a new `ToyType.frame` (title 40, button 28, body 22, small 20 = the floor). `ToyLook.build`'s `tv` flag
  (`toy_look.dart:36-40`) stays for the controller phone pad; the host picks `frame` when it is inside `HostFrame`. The 13.5 px badge number
  (FINDINGS: 9 dp) becomes badge diameter x .5, minimum 20.
- **Screens**: new `HostScreen` scaffold (header, flexing body, footer; replaces the `ListView` + `hostMenuPadding` shells at
  `night_start_screen.dart:90-100` and `night_scoreboard_screen.dart:105-116`). New small widgets: `ScoreRow` (bar row, shared by scoreboard,
  final, Arena), `AwardTile` (icon + name + "i" popover), `RoundSegment` (header chips). `hostBarHeightProvider` goes away
  where the footer carries the buttons.
- **Thumby slot**: `ThumbySlot` reads `HostFrameInfo` and draws the corner / side / strip (M17 fills it; M16 can ship it empty, and
  the stage then takes the room). No change to `sound.dart`.
- **Tests**: `phone_fit_option_c_test.dart` becomes the guard: for each of the 5 devices x 8 cases assert no scroll, buttons on
  screen, smallest text >= 20 frame px, with and without the Thumby room.

## 6. Risks

- 20 px floor in a 960x540 frame is 13.3 dp on 640x360 (a small phone). It is the owner's floor; below it needs a bigger floor or smaller frame.
- Six rows at 52 px plus a 64 px header and 84 px footer leave ~40 px of slack at 540; nicknames of 10 chars fit a 190 px name column
  at 26 px ("Alexandria", "Nightshade" measured by eye in the mockups, **not** by the font engine: re-measure in Flutter).
- The side column on wide phones makes the stage 960 wide, so a 1171 frame is not fully used for content when Thumby is on; with
  Thumby off the cards fill all 1171. Both are intended; the bars absorb the width.
- A global scaler also scales the pad-style overlays and the d-pad focus ring; check TV (1920x1080, s 2) visually.
- Controller-side screens (phones as pads) are not in scope; they are fixed-dp and unaffected.
- The "i" popover and the Skip button are new interactions; the TV remote needs focus order (header -> body -> footer).

## 7. Open questions for the owner

1. Is 20 frame px (13.3 dp at 640x360) the true floor, or should small phones get 22 (14.7 dp)?
2. Awards details on "i" tap: acceptable that the explanation is hidden by default on the start card? (On a TV it could be shown, but that is a second layout.)
3. Final scores: podium feel = gold/silver/bronze discs + a taller winner row. Or a real 3-step podium graphic (needs ~120 px and moves the 4th to 6th place into a short list)?
4. Reveal gets a Skip button and progress dots. OK, or keep it button-less until Thumby arrives?
5. With Thumby *off*, should the cards fill 1171 px wide frames (as drawn in rule 4), or stay 960 wide and centred?
6. Do we adopt `HostFrame` for the TV too (s = 2 at 1920x1080), or keep the TV at the current unscaled look?
