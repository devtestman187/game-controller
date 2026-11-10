# M14 m1b — the mock-ups' fixes and the finish celebration (report)

The job: `docs/briefs/m14/m1b-mockups.md`, a design job, no code. Five items — frame 3's "+2" and the cat's shadow,
springs drawn as springs, the badges wearing the accessory, two new TV frames for the finish celebration, and the
reports and captions brought up to date. No PNGs are written here (no browser); Claude saves them.

One numbering note: the brief's "frame 15's Pinball" is m1's maps frame, which is now 17, because the two new
celebration frames take 14 and 15 (the nickname moves to 16).

## Files changed

- `docs/design/mockup-parts.js` — one new part, `accessory(kind, x, y, size, color)`, and nothing else: the existing
  parts' output is unchanged, so `look-mockups.html` draws exactly what it drew.
- `docs/design/party-mockups.html` — frame 3, the springs, every badge, the row spacing the accessories needed, the two
  new frames after frame 13, and three captions.
- `docs/briefs/m14/m1-mockups-report.md` — the frame table (row 3, the two new rows 14 and 15, the old 14 and 15 moved
  to 16 and 17), the frame count, and the three "Decided while drawing" bullets the fixes contradict.

## The accessory part

```js
accessory(kind, x, y, size, color = T.paper)   // kind: 'ears' | 'antenna' | 'bow' | 'cap'
```

`size` is the radius of the badge disc the accessory sits on; `x, y` its centre. The fourth argument is the only one
a caller passes; the fifth is the body's colour, used by the ears only (the app draws them in the player's colour).
It returns SVG text, like every other part, and draws on top of the disc: ink and paper only.

The shares are `packages/toy_look/lib/src/toy_accessory.dart`'s, so a mock-up badge wears what the app's badge wears:

| kind | shape | numbers (× size) |
| --- | --- | --- |
| 1 ears | two discs of the body colour, an ink arc on the outer half | centres (±.7, −.9), radius .34 |
| 2 antenna | an ink stalk and a paper ball | stalk from −.95 to −1.55, ball at −1.62, radius .18 |
| 3 bow | two paper triangles and a paper knot, ink edges | (.55,−1)(.1,−1.25)(.25,−.8) and (.55,−1)(1,−1.2)(1.05,−.78), knot at (.55,−1) radius .1 |
| 4 cap | a paper dome with an ink edge and a brim | dome from (∓.85,−.55) through (0,−1.9), brim (.52,−.78) to (1.28,−.56), radius .1 |

Edges are `max(1.5, size * .16)`; the antenna's stalk is `max(2, size * .12)`. The topmost reach decides the row
spacing below: ears −1.24·size, bow −1.25, antenna −1.88 (ball and its edge), cap −1.9.

`party-mockups.html` maps the badge's number to the kind and draws both, in one place:

```js
const ACCESSORY = { 1: 'ears', 2: 'antenna', 3: 'bow', 4: 'cap' };
const playerBadge = (cx, cy, r, n, color) => badge(cx, cy, r, n, color) + accessory(ACCESSORY[n], cx, cy, r, color);
```

Every badge on the page goes through `playerBadge` (grep: `badge(` appears only inside it), so frame 3's HUD, the
scoreboard rows, the joined rows, the award's winners, the Bumper Round's top bar, the phone's result and the
nickname's preview all wear the accessory and keep the number. Robo keeps no badge (design 7a: no number), so no
accessory either.

## Frame 3, Shape Race in a night

The board is `boardSide(30, 92, 590, 588)` on the left and `boardSide(660, 92, 590, 588)` on the right, which gives
tray 117.6 tall, gap 17.64, `by` 227.24, board height `bh` 452.76 and the picture's left edge (`ox`) at 71.45 (left)
and 701.45 (right).

- **The "+2"** now sits beside the sun it was scored for: the sun is piece 2, placed at board (.84, .08), so it spans
  x 451.8–542.3 and y 263.5–354.0 on the left board. The pill is `(330, 268, 100, 48)` and its star `(434, 264, 15)`,
  i.e. the star's right point stops 1.3 px short of the sun's edge at 451.8 and the pill sits 22 px further left, at
  the sun's top third. It
  clears the placed crown (ends at x 288.8) by 41 px and the hill being carried (starts at y 390.2) by 74 px, so
  nothing is covered. It no longer sits by the tray (it was at 470, 170, above both boards).
- **The cat's shadow** is on the piece it goes for: on the right board only the canopy is placed, so the tray holds the
  trunk (680–697.3), the sun (721.3–793.8) and the triangle (817.8–930.5), each between y 109.6 and 191.9. The shadow
  is `catShadow(c.ox + .38 * c.bh, c.by - .17 * c.bh, c.bh * .06)` — centre (873.5, 150.3), radius 27.2 — which is the
  triangle's slot (its centre is 874.2, 150.8), about a quarter of its width. A little never touches a placed piece:
  the shadow is on a loose piece in the tray, not on a board outline (it was at the board's bottom right, radius 136).
- **The paw** moved from (1276, 560) to (1276, 176), the right board's top right corner: at the edge, clipped by the
  frame, so the cat reads as just out of sight above the piece it is after. It overlaps the board's right border by
  14 px, which is the point ("at the edge").

## Springs and hazards

The old `spring()` drew a red disc — the Arena's hazard colour. It is now `hazard()` (the same drawing, name and
comment changed; strokes still scale with the radius so it reads on a 270×112 map card and in a 1280×720 round), and
`spring()` is new: a green cap disc over a yellow coil — a yellow ellipse under the cap with two short ink windings
showing below it, seen from above (design 7b). Red is now used for hazards only.

| where | draws |
| --- | --- |
| Playroom field (frames 8, 9, 10 behind the card) | 4 hazards |
| Pinball field (frames 8, 9 cards; frame 17) | 7 springs in two clusters, and 2 hazards (the spinners' weights) |
| Toy Factory | belts, crates, no springs |
| Spinning Tops | 8 hazards (the red tops) |
| Block Castle | 2 springs |
| Bumper Round (frame 10) | 4 hazards |

Frames 8 and 9 draw the maps as cards, so their springs and hazards are the same parts at the card's size.

## The badges' spacing

Adding an accessory above each disc needs headroom, so rows that used to be badge-only moved. Everything below is a
consequence of the accessory's topmost reach, not a redesign:

| frame | before | now | why |
| --- | --- | --- | --- |
| 4, 5 (scoreboard) | badge radius 27 | 26 | Dad's antenna over Sam's bow in frame 5: 1.5 px → 4.6 px |
| 6 (award) | 288 and 362, radius 28 | 288 and 388, radius 24 | Ada's cap reached 21.8 px into Dad's antenna ball |
| 7 (final) | rows 92 apart, button at 548 | rows 104 apart, button at 558 | Dad's antenna crossed the winner band's bottom edge |
| 8 (waiting) | joined rows 246 / 300 / 354, radius 24, "Map" 414, cards 432 / 556 | 246 / 318 / 390, radius 22, "Map" 440, cards 458 / 578 | Sam's bow over Dad's antenna ball; Surprise me 602 → 624, its star 636 → 658 |
| 10 (Bumper) | HUD badges at y 28 | y 30, counts at 39 | a cap needs 28.5 px above its centre in a 56 px bar |
| phone result | badge 100, texts 108, standings every 26 | 104 / 112 / every 34 | ears were 2.9 px under the header; Sam's bow over Dad's ball |
| 13 (new record) | second row 356 | 372 | Right's antenna over Left's disc |

Frames 1, 2, 12, 14, 15 and the nickname frame needed no move (the nickname's preview badge is at 293 in a 54 px
card: its ears clear the card's edge by 5.9 px).

Frame 9 (the card with Robo) shares `joinedRow`, so Mia's row stays at 236 and only its badge changes (22, with her
ears); Robo's head, its level buttons and the three cards at 486 are where they were. The maps frame, now 17, keeps
its four 560×270 sketches and only the parts inside them changed: Pinball's clusters and Block Castle's two springs
are green and yellow now, everything else in it that was red is a hazard.

## The two new frames (after frame 13, so 1–13 keep their numbers)

**14, "Picture complete!"** — one board, solo, Tree finished: `(300, 110, 680, 500)`, so tray 100, gap 15, board 385
and the picture at `ox` 424.4. No card.
- The picture is drawn by a new `picture(x, y, h, pop)` from `PIECES` (the same pieces `boardSide` places), with
  `pop` scaling pieces about their centres: the trunk at 110% and the sun at 105%, the other two at 100% — two pieces
  mid-pop, one at 110%.
- `rim(ox, top, 385)` draws the four pieces at 106% in `#FFE9A8` behind them: a blurred glow with effects on, a still
  band at 55% with them off. Where pieces meet, each piece's 106% covers the seam, so only the picture's outer outline
  glows.
- `starRing(300, 110, 680, 500, 14)` puts 14 stars on the board's own edge, in three rings 14, 26 and 38 px outside it
  (distance to the edge measured along each star's direction, so the corner stars sit outside the corner), sized
  8 / 12 / 16 — all outside the board, none over the picture.
- `confettiOutside(300, 110, 680, 500)` clips the page's 14 confetti pieces with an even-odd path that removes exactly
  the board's rect: confetti falls round the board, never over the picture.
- `worker(ox + .42 * 385, top + .86 * 385, 28.9, ..., 'happy')` at (586, 556): between the trunk (ends 544) and the
  hill (starts 655), arms up, shadow at 585 — on the board's foot.
- With effects off, `picture` leaves every piece at 100% and the rim becomes the still band; the stars and confetti
  are the same in both.

**15, "the results card with the photo"** — an empty board `(250, 40, 780, 640)` dimmed by ink at 50%, then a card
`(330, 90, 620, 540)` headed "Done! 0:58".
- `photo(470, 400, 240, 250, -3)`: an ink shadow offset (5, 7), a cream frame with a 4 px ink edge and a board-coloured
  mat (`pad` 14.4), the finished Tree inside at 188.6 tall, the whole group rotated 3° about its centre. The picture is
  centred by the ink's own bounds (.06 to 1.12 of the picture's height), so it sits 5.6 px inside the mat on each side.
- Beside it: "4/4" with its star (642, 280), the "New record!" chip `(612, 306, 300, 62)` with two sparkles, "Play
  again" `(612, 400, 300, 72)` in the focus state, and "Back" `(662, 505, 200, 56)`.
- The photo (350–590 wide after the tilt, 275–525 tall) clears the text column (from 612) by 16 px.

## Captions

- Frame 3: what the "+2" is beside and that the cat only ever goes for a loose piece (the brief's parenthetical "A
  little never touches a placed piece" read as a typo; the caption says the same thing in words).
- Frame 14 and 15: new captions, including what changes with effects off.
- The maps frame: "a spring is a yellow coil under a green cap, a hazard is the red round bumper, a belt is a strip
  with arrows".
- The scoreboard: "the badge (colour, number and the player's accessory)".

## Self-check (docs/review-rules.md part A, items 4 and 5)

4. **Stay in the job's folder.** Only the three files above were written (`git status --short`); the three
   `tv_test_app/windows/flutter/generated_*` files were already modified in the working tree and were not touched.
5. **Stop rather than overstep.** No design decision had to be made: section 3a and 7b say what the celebration frames
   and the spring look like; the only judgement calls are sizes, listed under Questions.

## Checks run

- `wc -l`: `mockup-parts.js` 327, `party-mockups.html` 523 — under the brief's 900; `look-mockups.html` untouched.
- Balanced text: `tr -cd` counts on `party-mockups.html` give 607/607 parentheses, 579/579 braces, 132 backticks
  (66 template literals); `mockup-parts.js` gives 280/280 and 623/623.
- `git diff -U1 -- docs/design/party-mockups.html` read in full (every change above is in it); `git diff --stat
  docs/design/mockup-parts.js` is 24 insertions and no deletions, so no existing part's output can have changed.
- Geometry re-derived by hand for every row, badge and frame above (there is no JS engine or browser here to render;
  the numbers in this report are what the page computes, from the code's own constants).
- `git status --short`: the three allowed files plus the three pre-existing generated ones.

## Questions and suggestions

1. Frame 6's two winner badges are 24 instead of 28 so Ada's cap clears Dad's antenna; is the smaller badge fine, or
   would you rather the two winners sat side by side?
2. The row spacing changes in frames 4–8, 10, 11 and 13 are the accessory's headroom; if you'd rather keep m1's
   spacing exactly, the accessories could be drawn smaller on those badges (the app does not shrink them).
3. The spring's green is `C.good`, the same green as the goal pad and the ✓. If the owner reads that green as "good"
   rather than "spring", the cap could take a neutral green instead.
4. In Pinball the two spinners' weights are drawn as hazards (red); they were red before and red stays a hazard. If
   they are meant to be springs, they should turn green/yellow — the maps job should decide.
5. Frame 14's worker stands on the board between the trunk and the hill; the design says he cheers but not where. Is
   the board's foot (a little lower) better?
6. `docs/briefs/m14/m1-mockups.md` and this job both touch the same page and the m1 report's commit message still says
   "fifteen frames". If m1 and m1b land in one commit, use this job's message, not that one.

## Commit message

```
design: M14 mock-ups — springs, accessories, the finish celebration

A spring is a yellow coil under a green cap; red stays the Arena's hazard (Playroom, the
Bumper Round, the tops and Pinball's spinner weights), and Pinball's and Block Castle's
springs turn green.
accessory(kind, x, y, size, color) joins mockup-parts.js from toy_accessory.dart's shares;
every badge keeps its number and wears ears, antenna, bow or cap, with the row spacing
that needs; frame 3's "+2" sits beside the snapped sun, the cat's shadow on the tray
triangle, the paw at the edge.
Two new TV frames after 13: the celebration, then the results card with the photo (maps 17).
```

## Status row

M14 m1b done: party-mockups.html's springs, badges with the accessory and frame 3 fixed, plus the two finish-celebration frames (now 17, nickname 16, maps 17); open: the owner's OK, the spinners' and spring's colours (questions 3 and 4), and Claude saves the m14-* PNGs (no browser here).

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted. Claude saved all seventeen frames in Sunny and Night (docs/design/look-mockups/m14-*.png, 34 pictures) and
re-checked that `look-mockups.html` still draws M13's 22 frames byte for byte the same. Looked at every changed
frame: the "+2" beside the snapped sun, the cat's shadow and paw at the right side's tray, springs green with a
yellow coil, every badge wearing its accessory, the celebration (stars, confetti round the board, the glow, the
cheering worker) and the results card with the framed photo. Sent to the owner for the OK the screen jobs wait on.
