# M14 m1c — a coin of its own, the four maps in play, colour on the phone (report)

The job: `docs/briefs/m14/m1c-mockups.md`, a design job from the owner's Nov 9, 2026 review, no code. Six items —
the spinning coin, a "Coins spin" frame after 10, the four maps redrawn as Bumper Round arenas (one TV frame each,
replacing the sketch), the waiting card's map pictures, the phone's colour and accessory (plus the "your colour is
taken" phone), and the captions and this report's frame table. Design sources: `docs/design/party-night.md` sections
7, 7b, 9 and 10, and `docs/design/look-and-sound.md` 1, 3 and 5b.

No PNGs are written here (no browser or JS engine in this job); Claude saves and checks them.

## Files changed

| File | What changed |
| --- | --- |
| `docs/design/mockup-parts.js` (372 lines, from 327; 45 insertions, 0 deletions) | The coin — `coinStar(cx, cy, r)` and `coin(x, y, size, {gold, spin, sparkling})` — and two more accessories, `tuft` and `crown`, in `ACCESSORIES`. No existing part's code was touched, so `look-mockups.html` still draws exactly what it drew. |
| `docs/design/mockup-maps.js` (new, 269 lines) | The Arena's maps: the field unit, the map kit parts (the moved ones and the seven new ones), the five maps, and `MAPS` with each map's name, drawing and the spots a round's marbles and coins stand on. |
| `docs/design/party-mockups.html` (469 lines, from 523; 93 insertions, 147 deletions) | `<script src="mockup-maps.js">` after the parts; `ACCESSORY` gains tuft and crown; the page's own `coin`, `field`, `hazard`, `spring`, `belt`, `goal` and the five `*Field` functions are gone (they live in the two shared files); `bumperBar` and `mapPlay` draw a whole Bumper frame; frames 8, 9 and 10 use the new maps and coin; frame 11 "Coins spin" is new; the phone's settings are rewritten (17) with a new "your colour is taken" phone (18); the four map frames replace the sketch (19–22). |
| `docs/briefs/m14/m1c-mockups-report.md` | This report. |

## The coin

```js
coin(x, y, size, { gold, spin, sparkling })   // x, y: the centre; size: a field coin's radius
```

`size` is the radius a coin has in the field; a gold coin draws itself **4/3 of it** (`r = size` otherwise), so one
number sets every part of both coins. All lengths below are in terms of `r`. It returns SVG text like every other
part.

| part | normal coin | gold coin |
| --- | --- | --- |
| face | `C.focus` (`#FFD23F`) | `#F2A200` |
| rim | `dark(face, .30)`, a disc of radius `r` under the face | same |
| face disc | radius `.74r`, `light(face, .10)`, ink edge `max(1.2, .08r)` | same |
| stamp | a ten-point star, radius `.46r` (inner points `.46` of that), `light(face, .52)`, edge `dark(face, .3)` at `.07r` | the digit "2" at `1.05r`, `light(face, .55)` with a `dark(face, .34)` outline at `.13r` |
| back (`cos < 0`) | a ring, radius `.3r`, `light(face, .42)` at `max(1.2, .11r)` | same |
| glint | an ellipse `rx .22r`, `ry .1r` at `(−.3r, −.42r)`, turned −34° | same |
| extra | none | `sparkle` at `(+.98r, −.78r)`, radius `max(3, .32r)`, `#FFF6B0` |

The outline is `max(1.5, .14·size)` and the drop shadow `max(2, .14r)`; the rim's visible thickness is the `.26r`
between the outer disc and the face.

**The turn.** `spin` is 0 to 1 of one turn: `c = cos(spin · 2π)`, and the coin is squeezed horizontally by `|c|`
about (x, y). Past a third of the face, the rim alone is what is left, and it is drawn as the rim's thickness
(`|c| < .34`): a rounded bar of half-width `max(.16r, |c|·r)`, the rim's colour, with a white highlight down it.

| spin | cos | drawn |
| --- | --- | --- |
| 0 | 1 | the full face, the star |
| 0.125 | .707 | the face at 71% of its width |
| 0.25 | 0 | the thin edge, `±.16r` |
| 0.375 | −.707 | the back at 71%, the ring |
| 0.5 | −1 | the full back, the ring |
| 0.75 | 0 | the edge again |

`sparkling` draws the whole coin at `opacity .55` — not takable yet, half see-through (design 7). With effects off
(`?fx=0`) every coin stands still, face on: the spin is forced to 0, as design 7 says.

Frame 11 ("Coins spin") draws five coins of size 52 at x 380, 550, 720, 890, 1060 (y 210) at spins 0, .125, .25,
.375, .5, and the gold coins at the same five x (y 420), so each gold coin is a 69.3 radius and its widest is 138.7
wide — 31 px clear of its neighbour; the last gold coin's sparkle reaches x 1150, inside the card that ends at 1190.
The hazard for comparison stands at (380, 592) at the same 52.

The coin is drawn in frame 10's field (five coins at spins .08, .32 sparkling, .55, .42 and a gold one at .2) and in
every top bar's per-player count (`bumperBar`), which is the Bumper Round's scoreboard and its HUD icons in one.

Two accessories joined `ACCESSORIES`, so a badge can wear all six of design 9's:

| kind | shape | numbers (× size) |
| --- | --- | --- |
| 5 tuft | a paper quiff with an ink edge, three curling points | from `(−.5, −.9)` up to `−1.55` (left) and `−1.66` (right), ending at `(.52, −.88)` |
| 6 crown | a paper zigzag band with an ink edge and one ink jewel | band `1.5` wide, `.74` tall from `−1.16`, points at `.34/.68/0` |

## The map kit (new file)

A map is drawn in **field units**: a 16 × 9 field, centred in whatever box it is given, so one drawing serves the
254 × 74 picture on a waiting-card map card (unit 8.2 px) and the 1280 × 664 play area of a TV frame (unit 73.8 px).

```js
arenaBox(x, y, w, h)              // → { u, ox, oy }: the unit and the field's top-left
at(b, a, c)                       // → [px, py]: field units to pixels
```

The parts (all take pixels; every part scales its own numbers from the size it is given):

| part | signature | what it draws |
| --- | --- | --- |
| field | `field(x, y, w, h, color, {dots})` | the ground, with an ink dot pattern unless `dots: false` |
| hazard | `hazard(cx, cy, r)` | the red round bumper with its white ring — unchanged from m1b |
| spring | `spring(cx, cy, r)` | a yellow coil under a green cap, two windings showing below it |
| belt | `belt(x, y, w, h, dir)` / `beltAt(cx, cy, len, th, deg, dir)` | a conveyor strip with cream arrows, at any angle |
| goal | `goal(x, y, s)` | the race finish — the Playroom's only |
| post | `post(cx, cy, r, color = '#A8B4D6')` | a round pillar: a castle tower, a factory column, a lane post |
| flipper | `flipper(px, py, len, deg)` | a rounded bar from its hinge `(px, py)` at `deg`; the hinge disc is paper |
| gate | `gate(cx, cy, len, deg, open = 0)` | a portcullis bar sliding along a dashed track; `open` 0 shuts, 1 slides aside |
| cannonball | `cannonball(cx, cy, r)` | a dark ball in a **red** rim — a hazard |
| crate | `crate(cx, cy, s)` | a crate with a **red**-and-white warning stripe; `s` is its half-side |
| top | `top(cx, cy, r)` | a **red** spinning top with a white ring, its stem and motion arcs |
| — | `wallRect(b, a, c, w, h, color, o)`, `gear`, `pennant`, `chevron`, `track(b, a, c, a2, u)` | scenery: walls in field units, painted gears, tower flags, the pinball table's lane arrows, a hazard's dashed travel |

`stripeFill(a, b, deg, size)` (in the maps file) is a two-colour stripe pattern, sized in pixels so it scales with
the field.

Red is the colour of everything that makes you drop a coin, and only that: the bumpers, the drain, the cannonballs,
the crates, the tops. Springs are yellow and green, belts grey with cream arrows, posts chrome, gates pale — checked
part by part in the code.

## The five maps

Each is `(x, y, w, h)` and draws itself into that box; `MAPS` holds `{ name, draw, spots }`, where a spot is a field
unit pair and a marble's also names its player and its coin count.

- **Playroom** (`playroomMap`, `{goal: false}` to drop the finish): m1b's field, with the race goal unless asked not
  to. It is the one map that keeps a finish, because Shape Race still runs on it.
- **Pinball** (`pinballMap`): a table with a rounded top, painted rays, chrome rails, four star lights, lane
  chevrons; three pop bumpers (springs) in a triangle; two slingshots above two flippers at 18° and 162°; the drain
  between them a still hazard; four posts and three top lanes where the gold coin sits.
- **Block Castle** (`castleMap`): a crenellated outer wall in two tones with four corner towers and flags, a lawn
  courtyard, a keep of block walls with four gates at four open angles (`open` .55, .2, .8, .35), and three
  cannonballs on dashed tracks.
- **Toy Factory** (`factoryMap`): a striped yellow-and-black edge, three painted gears, a loop of four belts (two
  level, two upright, arrows round the loop), a press between its rails with travel arrows, two crates on tracks,
  four columns.
- **Spinning Tops** (`topsMap`): a round rug with three rings, a dashed orbit, eight tops on it with motion lines,
  and a carousel of four walls on a hub post, turned 15°.

A map's `spots` are the round's marbles and coins as drawn on that map — three or four marbles (each wearing its
accessory in `mapPlay`), three or four coins with their spins, and a gold coin on every map.

## The frames, numbered afresh

22 frames. m1's and m1b's tables stay as history; this is the numbering to use now. Old 11–17 move as noted.

| # | Size | What it shows |
| --- | --- | --- |
| 1 | TV | The game picker with three cards; Party night focused. Unchanged. |
| 2 | TV | The night's start card. Unchanged. |
| 3 | TV | Shape Race in a night, the "+2" beside the snapped sun, the cat's shadow and paw. Unchanged (m1b). |
| 4 | TV | The scoreboard after a round: badges with their accessories, a **star** and the total, the round's "+7". Unchanged (m1b). |
| 5 | TV | The same before the last round, with "Last round: double points!". Unchanged. |
| 6 | TV | An award reveal. Unchanged. |
| 7 | TV | The final scoreboard. Unchanged. |
| 8 | TV | The **Arena's waiting card**: the Playroom behind, dimmed; Bumper focused, Race; the code; Mia ✓, Dad ✓, Sam ✗; the map cards **Playroom, Pinball, Block Castle, Toy Factory, Spinning Tops** — each the new map's own picture, drawn once and scaled — and "Surprise me". |
| 9 | TV | The same card with **Robo**: its level buttons, and the map cards **Pinball, Block Castle, Surprise me** (Robo's rows take the room; two pictures show of the five, the rest below the fold as before). |
| 10 | TV | The **Bumper Round** on the Playroom: five field coins at different spins (one sparkling, half see-through), a gold coin stamped "2" with its sparkle, a coin just dropped and its arrow, the shove, the dizzy marble's stars; three marbles wearing ears, antenna and bow; the top bar — "Bumper Round", Playroom, "0:14" in the warning colour, each player's badge with a **coin** icon and count, "A: dash". |
| 11 | TV | **Coins spin** (new): a card "Coins spin" with **Coin** at spins 0, 1/8, 1/4, 3/8, 1/2, **Gold coin, worth 2** at the same five, and **Hazard** beside them for comparison. The caption says the coin turns once every 1.2 s, each at its own phase, and that with effects off every coin stands still, face on. |
| 12 | Phone | A joined phone's result in a night (was 11). |
| 13 | TV | The best times board (was 12). |
| 14 | TV | A results card with "New record!" (was 13). |
| 15 | TV | Picture complete! (was 14). |
| 16 | TV | The results card with the photo (was 15). |
| 17 | Phone | The **settings**, rewritten (was 16): the nickname "Mia" with its caret and "3 / 10" and Save; **Colour**, six big round buttons (`C.p`: blue, orange, violet, teal, pink, yellow), the chosen blue **ringed**; **Accessory**, six round buttons showing ears, antenna, bow, cap, tuft and crown, the chosen ears ringed; the **preview** of the worker and the marble in blue wearing ears; "Shows next time you join." |
| 18 | Phone | **Your colour is taken** (new): a joined phone's pad screen, dimmed, with the line "Blue is taken tonight, you're Teal" in a teal card over it, a teal disc beside it, and the strip above: badge 1 in teal, "1 / 4", "0:42", "4 marbles". |
| 19 | TV | **Pinball in play** (new): the table in full, three marbles with accessories, five coins of which one gold and one sparkling; the top bar with the clock "0:42" and coin counts 4 / 2 / 1. |
| 20 | TV | **Block Castle in play** (new): the castle, four marbles, four coins of which two gold, the clock "0:31". |
| 21 | TV | **Toy Factory in play** (new): the floor, three marbles, four coins of which one gold, the clock "0:12" in the warning colour. |
| 22 | TV | **Spinning Tops in play** (new): the rug, three marbles, four coins of which one gold, the clock "0:48". |

The old 17 (the 2 × 2 sketch of the four maps) is gone: 19–22 replace it, one full frame per map.

## Decided while drawing

- **"the scoreboard and HUD icons"**: the top bar of a Bumper frame carries both — each player's badge, the coin
  icon and their count — so frames 10 and 19–22 use the coin there. The night scoreboard (frames 4, 5 and 7) keeps
  its **star**, because the number on those rows is night points, not coins; a coin there would say the total is
  coins. If the owner wants the coin on those rows too, it is a one-line change.
- **Frame 9** shows two of the five map pictures, not all: Robo's rows and its level buttons take the room, and the
  card says "two of the map cards show, the rest below" since m1b. Frame 8 shows all five in the brief's order.
- **Effects off**: coins stand still and face on (design 7), so `?fx=0` shows every coin at spin 0; frame 11's
  caption says so rather than promising a turn that the effects switch removes.
- **The chosen accessory is ringed too**, thinner than the chosen colour's ring. The brief rings only the colour, but
  without a ring the settings cannot show which of the six accessories is chosen; the preview alone is too small to
  read at a glance.
- **The Playroom keeps its race goal** in frames 8 and 9 (both draw `playroomMap` behind the card, and that map is
  also Shape Race's). Playroom is the only map with a finish; the four new maps have none, as the owner asked.
- **Spot positions are illustrative**, not a frame of a simulation: each map's `spots` were placed so no marble or
  coin sits on a wall, a belt, a crate or a gate.
- **The maps are drawn once and centred** (`arenaBox`), so a waiting card's picture and a frame's play area are the
  same drawing at two units (8.2 px and 73.8 px) — no second drawing to keep in step.
- **Hazards are unchanged** (the red ringed bumper stays the still hazard's look); the cannonball, the crate and the
  top are new hazard shapes that all carry red, so red alone still means "drops a coin".

## Self-check (`docs/review-rules.md` part A)

4. **Stay in the job's folder.** Only the four files in `allow:` changed — `git status --short` lists
   `mockup-parts.js`, `mockup-maps.js` (new) and `party-mockups.html` beside the report, plus three
   `tv_test_app/windows/flutter/generated_*` files that were already modified before this job and were not touched.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:` and no rule blocked a rule; the one unclear
   phrase ("the scoreboard and HUD icons") had a defensible answer inside the brief's own look, so it is decided
   above and asked as question 1 rather than left undone.

## Checks run

- `wc -l`: `mockup-parts.js` 372, `mockup-maps.js` 269, `party-mockups.html` 469 — all under the brief's 900.
- Balanced text (`tr -cd | wc -c`): `party-mockups.html` 555/555 `()`, 462/462 `{}`, 98 backticks (even);
  `mockup-parts.js` 332/332, 708/708, 180; `mockup-maps.js` 281/281, 477/477, 118.
- No leftovers: `grep` finds no `pinballField`, `factoryField`, `topsField`, `castleField` or `playroomField`
  anywhere; the page's only `field(`/`hazard(` calls are frame 10's, which resolve to `mockup-maps.js`.
- Every call in the page and in `mockup-maps.js` resolves to a function defined in one of the three files
  (`grep -oE '\b[a-z_]\w*\('` against each file's `function` lines); `mapPlay` passes `coin(...at(b, a, c), …)`
  and `marbles` spots as four-element rows, checked against the `MAPS` table.
- Geometry re-derived by hand from the code's own constants (there is no browser or JS engine here): the coin
  widths per spin, the coin frame's 170 px spacing against a 138.7 gold coin, the map unit (664/9 = 73.78) and the
  card unit (min(254/16, 74/9) = 8.2), and the phone rows above.
- `git diff --numstat`: `mockup-parts.js` 45/0 (nothing deleted, so no existing part's output can change);
  `party-mockups.html` 93/147.
- `look-mockups.html` is untouched: it draws no accessory and no coin, and the parts file only gained the coin and
  two `ACCESSORIES` entries.

## Questions and suggestions

1. The night scoreboard's rows (frames 4, 5 and 7) keep a star; should the coin replace it there too, even though the
   number is night points?
2. Frame 9 still shows two map cards of five. Is that fine for the Robo card, or should the four new pictures all
   fit (smaller cards) so every map is visible before a round?
3. The chosen accessory carries a ring as well as the chosen colour — keep it, or does the owner want the ring to
   mean "colour" only?
4. The Playroom behind the waiting card shows its race finish flag. Give it `{goal: false}` there, so the card shows
   a map with no finish like the other four?
5. The coin's yellow is `C.focus`, the same yellow as the focus ring, and a gold coin's `#F2A200` is close to player
   5's `#F2C200`. At 26 px and up they read differently (rim, stamp, sparkle), but if the owner ever mistakes one for
   the other, one step darker (`dark(C.focus, .08)`) would separate the coin from the focus ring.
6. `mockup-parts.js` is now 372 lines, near the guidelines' 400-line hard mark. If the coin grows again, the next
   split is probably the phone's parts (`pad`, `faces`, `phone`, `toggle`).
7. The maps' `spots` are the page's own rather than the Arena's simulated positions; if the design wants the frames
   to look exactly like a real round, the maps job will have real positions to copy.

## Commit message

```
design: M14 mock-ups — a coin that spins, four arena maps, colour

mockup-parts.js gains coin(x, y, size, {gold, spin, sparkling}): a chunky toy coin
with a thick rim, a stamped star and a glint, its width scaled by |cos| with the
edge at 1/4; a gold coin is 4/3 as big and stamped "2". Tuft and crown join the
accessories, so a badge can wear all six.
mockup-maps.js draws the five maps once in 16 x 9 field units with the new parts
(spring, post, flipper, gate, belt, cannonball, crate, top), so one drawing serves
a waiting-card picture and a whole TV frame.
party-mockups.html: frame 11 shows the coin at five spins; 17 and 18 are the phone's
colour and accessory; 19-22 are the four maps in play, and the sketch frame is gone.
```

## Status row

M14 m1c done: the coin part and its spin frame, the five maps drawn once in `mockup-maps.js` and the four new maps in play (frames 19–22), the waiting cards' map pictures, and the phone's colour, accessory and "your colour is taken" phones (17–18); open: the owner's OK, answers to questions 1–4, and Claude saves the m14-* PNGs (no browser here).

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted, with one fix by hand. `mockup-maps.js` declared a top-level `function top(...)`, which clashes with the
browser's own `window.top`: the whole file failed to load ("Identifier 'top' has already been declared") and every
map frame and map card came out blank. Renamed `spinningTop`; Claude then checked every frame of the page in
headless Chrome for console errors (none) and re-saved all 22 frames in Sunny and Night. M13's 22 frames are still
byte-identical. Looked at the coin strip, the Bumper Round, the four maps in play, the settings and the "taken"
line: they follow the design. A lesson for later briefs: a page script's top-level names must not shadow browser
globals (`top`, `name`, `status`, `parent`, `self`).
