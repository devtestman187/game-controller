# M14 k2b: the four Bumper arenas — report

Gate: G4 (complete). The four maps are Bumper-only map files in `packages/test_game/maps/`, listed in
`index.json` after the Playroom, rendered to `docs/design/maps/<id>.png`. No `lib/` file changed.

## Files changed

- `packages/test_game/maps/pinball.json` — new Bumper-only map: Pinball (theme `pinball`).
- `packages/test_game/maps/block-castle.json` — new Bumper-only map: Block Castle (theme `castle`).
- `packages/test_game/maps/toy-factory.json` — new Bumper-only map: Toy Factory (theme `factory`).
- `packages/test_game/maps/spinning-tops.json` — new Bumper-only map: Spinning Tops (theme `tops`).
- `packages/test_game/maps/index.json` — lists `playroom, pinball, block-castle, toy-factory, spinning-tops`, in that order.
- `packages/test_game/test/four_maps_test.dart` — new tests: the five-map library passes every rule; each map's starts are
  fair by MapGrid path length (prints the numbers); each new map has no race and four starts.
- `packages/test_game/test/map_render_test.dart` — the render test now draws every map twice and compares, before writing
  `docs/design/maps/<id>.png`; so every map's render is checked deterministic, not just the Playroom's.
- `docs/design/maps/pinball.png`, `block-castle.png`, `toy-factory.png`, `spinning-tops.png` — renders written by that
  test (playroom.png is re-rendered by the same run and is unchanged).

## The four maps

Path lengths are in map units (the field is 160 × 90; 1 unit ≈ 1/90 of the shorter side). Each start is a row; each column
is one coin zone in the map file's order. A length is the shortest MapGrid path from the start to the nearest of the three
spots the zone holds a coin on (`spotsIn`, `coinDiameter`, 3 coins).

### Pinball (`pinball.json`, theme `pinball`)
Line: "A toy pinball table: pop bumpers, slingshots, flippers and a drain."
Pieces: 4 walls (2 chrome rails, 2 bouncy slingshot walls), 3 springs (pop bumpers), 4 posts (top lanes), 2 swing movers
(flippers), 1 still hazard (the drain), 4 lights. Starts `(0.17,0.20) (0.17,0.80) (0.83,0.20) (0.83,0.80)`; 4 coin zones
in the corner lanes. Render: `docs/design/maps/pinball.png` (54,348 bytes).

| start | zone 0 | zone 1 | zone 2 | zone 3 | mean | nearest |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 25.3 | 131.3 | 74.9 | 177.4 | 102.2 | 25.3 |
| 1 | 79.5 | 185.5 | 27.6 | 137.1 | 107.4 | 27.6 |
| 2 | 131.3 | 25.3 | 180.9 | 71.4 | 102.2 | 25.3 |
| 3 | 185.5 | 79.5 | 133.6 | 31.1 | 107.4 | 31.1 |

Mean spread: 102.2 → 107.4, ×1.051 (5.1%), well inside the 15% rule.

### Block Castle (`block-castle.json`, theme `castle`)
Line: "A castle of toy blocks: towers, a lawn courtyard and a keep with gates."
Pieces: 16 walls (8 crenellated outer-wall segments with a gate in each side, 8 keep segments), 4 posts (corner towers),
4 slide movers (the keep's gates, opening in turn), 3 hazards (cannonballs), 4 flags. Starts `(0.075,0.10) (0.075,0.90)
(0.925,0.10) (0.925,0.90)`; 6 coin zones: four courtyard corners and two between the keep's gates. Render:
`docs/design/maps/block-castle.png` (39,416 bytes).

| start | zone 0 | zone 1 | zone 2 | zone 3 | zone 4 | zone 5 | mean | nearest |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 61.1 | 126.7 | 64.5 | 156.7 | 89.9 | 102.5 | 100.2 | 61.1 |
| 1 | 66.8 | 159.0 | 58.8 | 130.2 | 95.6 | 119.8 | 105.0 | 58.8 |
| 2 | 129.0 | 70.3 | 159.0 | 68.0 | 106.0 | 85.2 | 102.9 | 68.0 |
| 3 | 167.0 | 76.0 | 137.1 | 62.2 | 116.4 | 91.0 | 108.3 | 62.2 |

Mean spread: 100.2 → 108.3, ×1.081 (8.1%).

### Toy Factory (`toy-factory.json`, theme `factory`)
Line: "A workshop floor: a belt loop, a stamping press and sliding crates."
Pieces: 2 walls (the press's columns), 4 belts (one loop round the floor), 1 slide mover (the press), 2 hazards (sliding
crates), 4 posts (columns), 3 gears. Starts `(0.10,0.22) (0.10,0.78) (0.90,0.22) (0.90,0.78)`; 4 coin zones beside the
belts, never on them. Render: `docs/design/maps/toy-factory.png` (52,619 bytes).

| start | zone 0 | zone 1 | zone 2 | zone 3 | mean | nearest |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 26.5 | 116.4 | 68.0 | 157.8 | 92.2 | 26.5 |
| 1 | 76.0 | 165.9 | 18.4 | 108.3 | 92.2 | 18.4 |
| 2 | 121.0 | 30.0 | 162.4 | 71.4 | 96.2 | 30.0 |
| 3 | 170.5 | 79.5 | 112.9 | 21.9 | 96.2 | 21.9 |

Mean spread: 92.2 → 96.2, ×1.043 (4.3%).

### Spinning Tops (`spinning-tops.json`, theme `tops`)
Line: "A round rug with a ring of spinning tops and a carousel in the middle."
Pieces: 8 orbit hazards (the ring of tops, 22.5° apart), 1 post (the carousel's pin), 2 spin movers (the carousel's cross
of four arms), 0 walls. Starts `(0.14,0.22) (0.14,0.78) (0.86,0.22) (0.86,0.78)`; 4 coin zones in the quarters between
the arms, just beyond their sweep. Render: `docs/design/maps/spinning-tops.png` (133,612 bytes).

| start | zone 0 | zone 1 | zone 2 | zone 3 | mean | nearest |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 23.0 | 77.2 | 64.5 | 118.7 | 70.8 | 23.0 |
| 1 | 72.6 | 126.7 | 31.1 | 85.2 | 78.9 | 31.1 |
| 2 | 79.5 | 25.3 | 121.0 | 66.8 | 73.2 | 25.3 |
| 3 | 129.0 | 74.9 | 87.6 | 33.4 | 81.2 | 33.4 |

Mean spread: 70.8 → 81.2, ×1.147 (14.7%), inside 15% but the closest to the line; the top-left spot scan and the open
floor's Manhattan paths make it slightly uneven. If a later change moves a zone, re-read this row.

## Decisions (low-usage mode: the safest choice that fits the design and mock-ups)

- **Fairness read per start, over all coin zones.** The literal "each start to each zone within 15%" is geometrically
  impossible for spread-out zones: under the MapGrid's Manhattan metric, four starts at a rectangle's corners are equally
  far from a point only at the rectangle's centre (equating the x and y terms forces x and y to the midpoints), so all
  zones would have to sit on one spot. The test therefore asserts each start's **mean** path over all zones is within 15%
  of every other start's, and prints every zone's number above so the owner can see the per-zone spread too.
- **Starts inset from the corners, in mirror pairs.** Every map's four starts are the same inset corners (or point-mirror
  pairs), so path lengths pair exactly where walls are symmetric and differ only where the theme's pieces are one-sided
  (Pinball's flippers/rails, the Factory's press); all four are measured.
- **Block Castle's axes.** Walls and movers are axis-aligned bars only, so the mock-up's rounded outline became straight
  crenellated segments, and its gates became slide movers that slide along the wall line rather than swinging into the
  courtyard (a swing's sweep would cross the keep's coin zones). The keep's coin zones sit between the four gates so the
  court is risked, as section 7b asks.
- **Pinball's flippers swing ±10°, not the mock-up's 18°/162°.** The piece rule keeps a mover's sweep clear of starts and
  coin zones; ±10° keeps the tips off the bottom corner zones while still flinging up the table.
- **Pinball's slingshots are short horizontal bouncy walls.** Diagonal bars cannot be written (walls are axis-aligned
  rects); the two bars sit above the flippers at the mock-up's height.
- **Spinning Tops' carousel is two spin movers and its tops are orbit hazards.** The piece model has no "cross" mover, so
  two perpendicular spin bars at the same period make the four arms; orbit hazards with a small radius draw the tops.
  Their coin zones sit just outside the carousel's sweep (the piece rule's clearance), not at the mock-up's inner dots.
- **Coin-zone placement favours fairness and the piece rule over the mock-up's exact coin dots.** The mock-ups show the
  look; the fair set is mirror-symmetric and clear of every spring, post, belt and mover sweep, and each zone holds three
  coins.
- **Render determinism is checked for every map.** The render test now captures each map twice and compares before
  writing its PNG; this costs one extra capture per map but is the brief's "renders deterministic" over the whole library.

## Checks

- `tools/check.sh format analyze arena` — PASS format, PASS analyze, PASS arena (160 tests, 11 s). Before the maps
  existed the new tests failed (missing files); the logs during the work showed the Castle post/zone clearance and the
  fairness tuning, both fixed.
- `tools/review.sh` — `review: 0 fail, 0 note`.
- Renders: the arena run wrote all five PNGs (`map_render_test`), each over 2,000 bytes; the four new ones are listed
  above. No `lib/` file changed, so the 400-line/60-line limits are untouched.
- No scratch file left: only the files under `allow:` were written.

## Self-check (docs/review-rules.md part A, 1–5)

1. **Every host setup** — not affected: the maps are data consumed by `ArenaMap.parse`/`checkMap` and drawn from the
   snapshot plus the shipped map; no host, phone or protocol code changed. `four_maps_test` parses and checks all five
   maps, and `map_render_test` draws each in Sunny and Night.
2. **When kept state starts and ends** — not affected: no timer, slot or cache is added. Coin spots are recomputed from
   `MapGrid.spotsIn` and are deterministic; `four_maps_test` asserts each zone yields three spots and a path to each.
3. **How a new state combines with the others** — not affected: no pause, hide or input state is added. The new maps have
   no `race` section, so the race state stays `null` and only the existing Bumper Round state applies; asserted by
   `four_maps_test` ("no race section, four starts").
4. **Stay in the job's folder** — done: the only writes are `docs/briefs/m14/k2b-four-maps-report.md`,
   `docs/design/maps/*.png`, `packages/test_game/maps/*` and `packages/test_game/test/*`, all inside `allow:`.
5. **Stop rather than overstep** — no file outside `allow:` was needed. The one literal rule that cannot be met (per-zone
   15% fairness for spread zones) is reported under Decisions with its numbers instead of being silently weakened; the
   low-usage instruction asked for a safe decision rather than a stop.

## Questions

1. Is the per-start mean-over-zones reading of the fairness rule the intended one? A strict per-zone reading would force
   every coin zone onto the field's centre point (see Decisions), losing the mock-ups' spread.
2. Block Castle has six coin zones (four courtyard corners, two between the keep's gates): is that the wanted reading of
   "coins in the courtyard corners, gold coins inside the keep"?
3. Pinball's flippers swing ±10° instead of the mock-up's 18°/162°, to keep their sweep off the coin zones: acceptable?

## Commit message

Add Pinball, Block Castle, Toy Factory and Spinning Tops maps

Four Bumper-only map files, each with its mock-up's theme and pieces and its own play:
Pinball's pop bumpers, slingshots, flippers and drain; Block Castle's towers,
courtyard, keep and four gates; Toy Factory's belt loop, press and crates;
Spinning Tops' ring of tops and central carousel.
They follow the Playroom in maps/index.json, pass every map rule, and render to
docs/design/maps/<id>.png. A new test checks every start's mean MapGrid path to
the coin zones is within 15%, and the render test now proves every map twice.

## Status row

M14 k2b done: Pinball, Block Castle, Toy Factory and Spinning Tops are Bumper-only maps that pass every map rule and
render to docs/design/maps/; the owner's review of those renders is open.

## Delete

- none
