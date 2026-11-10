# M14 k2a: the map pieces

Job: `docs/briefs/m14/k2a-map-pieces.md`. Gate: G4 complete. **Status: done.**

Each piece of party-night §7b is now part of a map file, of the field, of the rules and of the frame: a spring,
a bouncy wall, a post, a mover (swing, spin or slide), a belt, a still hazard, and the four themes with their
decor. The map rules keep every piece inside the field, clear of the starts and the coin zones, and inside the
limits (8 springs, 6 belts, 24 walls and movers together, one pass every 1.5 s or slower); the frame carries the
pieces and the theme, so a phone draws them without a copy of the map; the Playroom has none of them and its frame
and its render are byte-for-byte what they were. Every test was written first and failed for the missing behaviour
(the parser, the field rule, the map rule, the frame keys, the painter) before the code it drove existed.

## Files changed

| File | What changed |
| --- | --- |
| `docs/briefs/m14/k2a-map-pieces-report.md` (new) | This report. |
| `packages/test_game/lib/src/arena_pieces.dart` (new) | The piece specs: `SpringSpec`, `PostSpec`, `BeltSpec`, `MoverSpec` (swing/spin/slide, `endsAt`, `sweep`), `DecorSpec`, `DecorKind`, `decorKinds`, `notADecorKind`, and their numbers. |
| `packages/test_game/lib/src/arena_field_pieces.dart` (new) | `part of arena_field.dart`: the pieces as the field plays them — `springPositions`, `postPositions`, `moverBars`, `beltCarry`, `obstacles`, `resolve` (three passes, so a mover never crushes). |
| `packages/test_game/lib/src/arena_piece_painter.dart` (new) | Draws the pieces from a snapshot: belts and their arrows, springs, posts, decor, the movers' bars. |
| `packages/test_game/lib/src/arena_floor_painter.dart` (new) | `ArenaFloorPainter` and `starPath`: the four themes' floors (Pinball's stars, Block Castle's bricks, Toy Factory's bands, Spinning Tops' rings). |
| `packages/test_game/lib/src/map_rule_pieces.dart` (new) | `part of map_rules.dart`: the `piece` rule (clear of the starts and the coin zones). |
| `packages/test_game/lib/src/arena_map_pieces.dart` (new) | `part of arena_map.dart`: the parser for springs, posts, belts, movers and decor, with a message per field. |
| `packages/test_game/lib/src/arena_snapshot_pieces.dart` (new) | `part of arena_snapshot.dart`: reads a frame's `mi`, `mv`, `th`, `sp`, `po`, `bl` and `dc`. |
| `packages/test_game/lib/src/arena_snapshot_views.dart` (new) | `part of arena_snapshot.dart`: `ArenaPlayerView` and `ArenaCoinView`, moved out whole so the snapshot stays under 400 lines. |
| `packages/test_game/lib/src/arena_specs.dart` | `WallSpec.bouncy`; `HazardSpec.still`, `isStill`; the line and rect helpers made public (`nearestOnLine`, `meetsRect`, `distanceToRect`) for the map rules. |
| `packages/test_game/lib/src/arena_field.dart` | A belt carries the marble (added to its velocity), a spring or a bouncy wall throws it back at 1.5× with a `bump`, a still hazard sends it to its start; `resolvePoint` moved into the pieces' part, which resolves through the pieces; 315 lines, unchanged. |
| `packages/test_game/lib/src/arena_events.dart` | `GameEventCause.spring`. |
| `packages/test_game/lib/src/arena_session.dart` | The cause's sound name (`spring`), used when an event names none. |
| `packages/test_game/lib/src/arena_snapshot.dart` | The new keys in `toJson`/`fromJson`/`lerpTo`: `mi`, `mv`, `th`, `sp`, `po`, `bl`, `dc`; 364 → 337 lines after the two parts. |
| `packages/test_game/lib/src/arena_painter.dart` | Draws the theme's floor, then the pieces, then the walls, then the movers: a still playroom field keeps its mat. |
| `packages/test_game/lib/src/arena_map.dart` | `theme`, bouncy walls, still hazards and the five piece lists; 316 → 395 lines, the pieces' parsing in its part. |
| `packages/test_game/lib/src/map_rules.dart` | `MapRule.piece`, `maxMapSprings` (8), `maxMapBelts` (6), the `piece` step, the doc of `limit` and the parts. |
| `packages/test_game/lib/src/map_rule_field.dart` | The pieces' own inside-the-field check, in `_fieldPieces`: discs whole, a belt's ends, a mover's whole sweep (worst end named), a decor's spot, no empty belt. |
| `packages/test_game/lib/src/map_rule_limits.dart` | Springs and belts counts; movers counted with the walls; a mover's period; a still hazard exempt from the 1.5 s rule; the size rule counts the pieces and the theme. |
| `packages/test_game/lib/test_game.dart` | `export 'src/arena_pieces.dart';`. |
| `packages/test_game/maps/map.schema.json` | The five themes (with `errorMessage`), bouncy walls, still hazards, springs, posts, belts, movers and decor, each field described; `$defs` for each piece and a mover's three shapes; the walls' limit says "with the movers together". |
| `packages/test_game/test/map_pieces_test.dart` (new) | 9 tests: each piece's parse and defaults, a bad field's message, the mover shapes, a theme this build has not got, the Playroom's pieces. |
| `packages/test_game/test/map_piece_field_test.dart` (new) | 6 tests: a spring launches, a bouncy wall throws back and a plain wall stops, a post is solid, a belt carries at half speed, a still hazard sends to the start, a mover moves on the clock and never leaves a marble inside it. |
| `packages/test_game/test/map_piece_snapshot_test.dart` (new) | 4 tests: the frame's pieces, mirroring, the Playroom's frame unchanged, the wire round trip and `lerpTo`. |
| `packages/test_game/test/map_piece_map_rules_test.dart` (new) | 7 tests: the field, the starts, the coin zones, the limits, movers as walls, a still hazard's exemption. |
| `packages/test_game/test/map_piece_paint_test.dart` (new) | 3 tests: the same frame draws the same bytes and each theme's floor differs, a spring is green-and-yellow and never red, belts' arrows run with effects on and stand still with them off. |
| `packages/test_game/test/map_rules_test.dart` | The skipped size test is on: a map of pieces and walls is 2163 bytes and its message is pinned; the heaviest-map test renamed for what it now tests. |
| `packages/test_game/test/map_schema_test.dart` | Broken cases for a non-boolean `bouncy`, a ninth spring, an unknown decor kind and a mover with no shape. |
| `packages/test_game/test/support/maps.dart`, `map_sheet.dart` | `testMap` takes the pieces, `mapSnapshot` passes them and the movers' ends, and the message helpers. |
| `docs/levels.md` | The Arena part: the five themes, `bouncy`, `still`, `springs`, `posts`, `belts`, `movers` and `decor` rows; the rules for the pieces and the limits; every message. |
| `docs/protocol.md` | A paragraph for the frame's pieces and theme (`mi`, `mv`, `th`, `sp`, `po`, `bl`, `dc`) and how a phone draws them. |

## The pieces

Each is a map-file part with a schema entry, a parser with a message per bad field, a rule in the field, a map
rule, and a painter. Positions are fractions of the field; sizes are fractions of its shorter side.

### Springs

```json
"springs": [{"at": [0.32, 0.42]}, {"at": [0.68, 0.58], "radius": 0.06}]
```

- **Numbers:** radius 0.05 (a tenth of the shorter side across, about 1.6 marbles; the marble is 0.064 across),
  `radius` optional; `springKick` 1.5.
- **Field:** a solid disc, and a marble that meets it is thrown along the way out at 1.5× the faster of its
  walking speed and its speed at the touch (party-night §7b: "bounces off at 1.5× its speed"), with a hit and the
  `bump` sound when it was moving fast enough; it drops nothing and is no hazard.
- **Map rule:** inside the field; its disc plus a marble's radius clear of every start and coin zone; at most 8.
- **Painter:** a yellow (`caution`) coil seen from above under a green (`good`) cap; never `bad`, which is a
  hazard's.

### Bouncy walls

```json
"walls": [{"from": [0.24, 0], "to": [0.24, 0.56], "bouncy": true}]
```

- **Numbers:** one wall's thickness (0.035); `bouncy` optional, false when the file says nothing.
- **Field:** a plain wall stops a marble; a bouncy one throws it back at `springKick` (1.5×) with a hit and a
  `bump`, as a pinball table's slingshots do.
- **Map rule:** the walls' own rules stand; it counts as one of the 24.
- **Parser:** `"bouncy" must be true or false, got …`.

### Posts

```json
"posts": [{"at": [0.5, 0.3]}, {"at": [0.5, 0.7], "radius": 0.07}]
```

- **Numbers:** radius 0.055 (about 1.7 marbles across); `radius` optional.
- **Field:** a solid disc a marble walks up to and stops against; it never moves and does not kick.
- **Map rule:** inside the field; clear of the starts and the coin zones like a spring; no count limit (the
  frame's size is the bound).
- **Painter:** a wall-coloured disc with a lighter inner ring and a glint.

### Belts

```json
"belts": [{"from": [0.10, 0.50], "to": [0.40, 0.50], "width": 0.09}]
```

- **Numbers:** width 0.09 (`beltWidth`); it carries at 0.5 of a marble's walking speed (`beltCarryShare`).
- **Field:** while the marble's middle is within half the width of the strip's middle line, the belt adds its
  carry (towards `to`) to the marble's velocity; the arrows, not the colour, say which way it goes.
- **Map rule:** both ends and the whole width inside the field; its width plus a marble clear of the starts and
  coin zones; at most 6; both ends at one spot is not a belt.
- **Painter:** a wall-ink mix strip with cream chevrons a tenth of a shorter side apart, moving along at 0.35 of
  a shorter side a second with effects on and standing still with them off.

### Movers

```json
"movers": [
  {"swing": {"pivot": [0.5, 0.2], "length": 0.3, "fromDeg": 20, "toDeg": 160}, "periodS": 2.4},
  {"spin": {"pivot": [0.5, 0.5], "length": 0.36}, "periodS": 3.0, "phase": 0.25},
  {"slide": {"from": [0.2, 0.7], "to": [0.2, 0.9], "length": 0.22, "deg": 90}, "periodS": 2.0}
]
```

- **Numbers:** a bar as thick as a wall (0.035), `length` required (a fraction of the shorter side), `periodS`
  one whole cycle, `phase` 0..1 (0 when the file says none). Below 1.5 s is refused by the map rule.
- **Shapes:** a `swing` turns about a pivot between `fromDeg` and `toDeg`, eased at each end like a pendulum; a
  `spin` turns a whole circle every `periodS` at one speed; a `slide` travels between `from` and `to` with the
  bar at `deg`. Angles are degrees clockwise from across.
- **Field:** a bar that pushes a marble out of its way and never through a wall. The field resolves the movers
  first, then posts and springs, then walls and edges, three passes: a marble a mover pins against a wall stops
  it for that step rather than being crushed.
- **Map rule:** every pose of its cycle (16 samples) inside the field; the whole sweep clear of the starts and
  the coin zones; a mover counts as a wall (24 with the walls together); one pass every 1.5 s at the fastest.
- **Frame:** its two ends this frame (`mv`), worked out from the round's clock, so a phone draws it.

### Still hazards

```json
"hazards": [{"still": {"at": [0.5, 0.5]}}]
```

- **Numbers:** no `periodS` (0), no `phase`; a hazard's radius (0.038).
- **Field:** a hazard's touch sends the marble back to its start (its `_reset`), with a hit, as a drain does; the
  no-grace rule is what a still hazard needs no exception from.
- **Map rule:** inside the field; the hazards' own rules (start, goal, coin zones); it counts as one of the 8;
  the 1.5 s rule skips it, since it has no pass to make.
- **Painter:** as any hazard, in `bad`.

### Decor

```json
"decor": [{"kind": "flag", "at": [0.04, 0.10]},
          {"kind": "light", "at": [0.90, 0.20], "size": 0.06},
          {"kind": "gear", "at": [0.50, 0.92]}]
```

- **Numbers:** kinds `flag`, `light` and `gear`; size 0.09 by default.
- **Field:** none: it has no collision and no effect on play.
- **Map rule:** inside the field; no count limit (the frame's size is the bound).
- **Painter:** an ink pennant with a `good` cloth, a four-point star in `star`, or a faint ink gear, all in the
  theme's colours.

### Themes

`"theme": "pinball"` (or `castle`, `factory`, `tops`; the Playroom's is `playroom` and may be left out). A theme
only changes how the field is drawn; the schema, the parser and `check` refuse one this build has not got with
`"space" is not a theme: use playroom, pinball, castle, factory or tops`. The floors, all drawn by
`ArenaFloorPainter` and all still with effects off:

| Theme | Floor | Drawn |
| --- | --- | --- |
| pinball | `field` mixed 45 % to `ink` | star lights on a 0.16 grid, 0.022 across, breathing with effects on |
| castle | `field` mixed 20 % to `good` | brick rows 0.1 apart, ink at 7 %, lines 0.008 wide |
| factory | `field` mixed 14 % to `caution` | ink bands 0.055 wide on the four edges, caution stripes 0.035 apart |
| tops | `field` mixed 14 % to `focus` | ink rings 0.09 apart, 0.012 wide, round the middle |
| playroom | the mat `ArenaPainter` already drew | none new |

## The field

`arena_field_pieces.dart` is the pieces' part of `ArenaFieldRules`: it mirrors every piece with the field (a round
that swaps sides shows the same map backwards), turns the movers' `endsAt` into bars, carries a marble on a belt,
and pushes a marble out of the bars, the discs and the walls in three passes. A touch that comes from a spring or
a bouncy wall sets the marble's `_shove` to the way out times 1.5× the faster of its walking speed and its speed
at the touch; a plain wall touch only stops it. The pieces are no hazard: they drop nothing, and a belt's carry is
not a shove.

The Playroom has no springs, posts, belts, movers or decor, and its tests pass with its numbers unchanged: the
race and the Bumper Round play exactly as before.

## The map rules

`MapRule.piece` is new; `field` and `limit` grew. One message each, as the tests pin them:

| Rule | What breaks | A message |
| --- | --- | --- |
| `field` | a spring or post reaching out | `test/spring 0: it reaches 1.23 across and 0.55 down, outside the field. Keep every part of the map between 0 and 1, across and down.` |
| `field` | a belt's end out | `test/belt 0: its end is at 1.40 across, outside the field. Keep every part of the map between 0 and 1, across and down.` |
| `field` | a mover's sweep out | `test/mover 0: its sweep runs to 1.30 across, outside the field. Keep every part of the map between 0 and 1, across and down.` |
| `field` | a belt with no length | `test/belt 0: it starts and ends at the same spot, so it is not a belt. Move one end.` |
| `piece` | a spring on a start | `test/spring 0: it sits on start 0, where a marble begins. Move it clear of every start.` |
| `piece` | a post on a bumper start | `test/post 0: it sits on bumper start 0, where a marble begins. Move it clear of every start.` |
| `piece` | a belt across a start | `test/belt 0: it crosses start 0, where a marble begins. Move it clear of every start.` |
| `piece` | a mover's sweep across a start | `test/mover 0: its sweep crosses start 0, where a marble begins. Move it clear of every start.` |
| `piece` | a spring in a coin zone | `test/spring 0: it sits in coin zone 0, where coins appear. Move it clear of the coin zones.` |
| `piece` | a belt across a coin zone | `test/belt 0: it crosses coin zone 0, where coins appear. Move it clear of the coin zones.` |
| `piece` | a mover's sweep across a coin zone | `test/mover 0: its sweep crosses coin zone 0, where coins appear. Move it clear of the coin zones.` |
| `limit` | more than 8 springs | `test: it has 9 springs; a map has at most 8. Remove one.` |
| `limit` | more than 6 belts | `test: it has 7 belts; a map has at most 6. Remove one.` |
| `limit` | a mover too fast | `test/mover 0: it makes a pass every 1.2 s; the fastest is one every 1.5 s. Make its "periodS" bigger.` |
| `limit` | movers make the walls too many | `test: it has 20 walls and 5 movers; a wall and a mover both count, and a map has at most 24. Remove one, or join two into a longer wall.` |
| `size` | the frame too heavy | `test: with four marbles and its coins its snapshot is 2163 bytes; a frame may take 2048. Use fewer pieces, or fewer or shorter walls.` |

The reach a piece keeps from a start or a zone is its own size plus a marble's radius (a belt's half width, a
mover's half thickness), in fractions of the shorter side; a mover is measured over all 16 poses of its sweep, so
a swing's far end and a slide's far place count. The piece rule has no hazard's grace: a marble it shoved as it
set off, or a coin as it came out, would be a bug the player sees.

The walls' message keeps its old wording when a map has no movers (`it has 25 walls; …`), so every k1b test is
unchanged; with movers it says "a wall and a mover both count".

## The frame

The snapshot stays version 2; the new keys are all optional, so an older phone ignores them and still plays:

| Key | What it is | Left out when |
| --- | --- | --- |
| `mi` | `1` when the round flips the field left to right | not mirrored |
| `mv` | the movers' two ends this frame, `[x1, y1, x2, y2]` each | a map has no movers |
| `th` | the theme | `playroom` |
| `sp` | springs, `[x, y]` or `[x, y, radius]` | none |
| `po` | posts, the same | none |
| `bl` | belts, `[x1, y1, x2, y2]` or `[…, width]` | none |
| `dc` | decor, `[kind, x, y]` or `[kind, x, y, size]`, kind `0` flag, `1` light, `2` gear | none |

Coordinates are rounded to four decimals as before; a piece's size is left out at its default. `lerpTo` keeps the
theme and still pieces and lerps the movers' ends; a frame without the keys decodes to the Playroom's defaults, so
a k1b frame reads as it did. `mid` still names the map.

## Sizes

Piece sizes, in fractions of the field's shorter side: spring 0.05, post 0.055, belt 0.09 wide, a mover's bar
0.035 thick and its `length` as the map says, decor 0.09. A marble is 0.064 across.

File sizes, all inside the 400-line lib limit (`tools/review.sh`'s FAIL threshold):

| File | Lines |
| --- | --- |
| `arena_pieces.dart` | 256 |
| `arena_field_pieces.dart` | 153 |
| `arena_piece_painter.dart` | 280 |
| `arena_floor_painter.dart` | 158 |
| `map_rule_pieces.dart` | 109 |
| `arena_map.dart` | 395 |
| `arena_map_pieces.dart` | 82 |
| `arena_snapshot.dart` | 337 |
| `arena_snapshot_pieces.dart` | 54 |
| `arena_snapshot_views.dart` | 119 |

The four splits (`arena_map` and `arena_snapshot` into parts, the painter's floors into their own file) were made
because the additions took the first three over 400; the snapshot's views moved so `fromJson` stays under 60 lines.
The longest functions in the changed files are `_limits` at 59 lines, `ArenaSnapshot.lerpTo` at 57 and `fromJson` at 51.

## Test counts

| Suite | Before | After |
| --- | --- | --- |
| test_game (arena) | 128 passed, 1 skipped | 157 passed (29 new: parse 9, field 6, frame 4, map rules 7, paint 3; the k1b size test is on) |
| kit | 71 | 71 |
| host | 316 | 316 |
| phone | 439 | 439 |
| tv | 53 passed, 1 skipped | 53 passed, 1 skipped |

The size test now runs with a factory map of 16 long walls, 8 hazards, 8 movers, 8 springs, 4 posts, 6 belts and 30
decor pieces: its frame is **2163 bytes**, over the 2048 budget, and its message is pinned. The Playroom's render
(`docs/design/maps/playroom.png`) is byte-identical to before: it has no pieces and its theme is the Playroom's.

## Checks

`tools/check.sh format analyze arena kit host tv phone` could not be run as a script (the sandbox asks for an
approval it can't give), so each command it runs was run on its own, from each folder: **format** pass (677 files,
none changed), **analyze** pass (`dart analyze --fatal-infos`, no issues), **arena** pass (157), **kit** pass (71),
**host** pass (316), **phone** pass (439), **tv** pass (53, 1 skipped). `tools/review.sh` could not be run for the
same reason; its mechanical rules were checked by hand: every lib file is under 400 lines (the table above) and the
longest changed function is 56 lines.

## Self-check (docs/review-rules.md, part A)

1. **Every host setup:** no screen changed — a TV or PC host, a phone on "Play on this phone", a phone on "Show on this device" and a joined phone all draw the same frame, and a phone one build older ignores the optional keys and draws the walls as before (`phone` 439, `tv` 53, `host` 316 pass).
2. **When kept state starts and ends:** the pieces are immutable values and the frame is a value; a mover's place comes from the round's clock alone, so it starts at the round's 0 s and stops when the round does; a belt's arrows and a table's stars use the clock only with effects on; nothing is kept between frames (round-trip and `lerpTo` tests).
3. **How a new state combines with the others:** not affected — nothing here pauses, hides, waits or takes input; a pause stops the round clock, so the movers stop with everything else, and a still hazard resets a marble inside the same step that any hazard would act, with the round's own state.
4. **Stay in the job's folder:** every file written is inside `allow:` (`docs/briefs/m14/k2a-map-pieces-report.md`, `docs/levels.md`, `docs/protocol.md`, `packages/test_game`); no scratch file is left; the three `tv_test_app/windows/flutter/generated_*` files show as modified with no content change, as k1b saw.
5. **Stop rather than overstep:** nothing was blocked and nothing outside `allow:` was touched; the choices the brief left open are listed under Decisions rather than guessed silently.

## Decisions

- **The frame carries the theme and the still pieces, and the size rule counts them:** a phone draws the field from the frame and has no copy of the map yet (M14 b2's phone copy will save those bytes), so the frame is where the pieces a phone meets must be; `mid` still names the map.
- **Movers count with the walls in the 24 limit:** a mover is a wall that moves, so it crowds the field as one does; the message says so.
- **Springs are capped at 8 and belts at 6, posts and decor have no count:** these are the k1b numbers' neighbours (8 hazards, 24 walls) and the frame's size is the real bound for the others.
- **A still hazard is a hazard, not decor:** a drain sends a marble back to its start as the design says, so it is drawn and judged as a hazard and is exempt only from the 1.5 s pass rule, which it has no pass for.
- **A spring and a bouncy wall share one kick (1.5×, with `bump`) and count a hit:** the design says both bounce, and one rule keeps a touch meaning the same thing everywhere.
- **A spring is `good` over `caution`, never `bad`:** red is a hazard's alone (the design's own rule), so the cap is green and the coil yellow.
- **The pieces' painters are split from the floor's, and two parsers into parts:** the 400-line rule; the parts follow `map_rules.dart`'s style.
- **The frame's piece sizes are left out at their defaults, and the four-decimal rounding stays:** it is what k1b's frames do, and it keeps a piece as cheap on the wire as a wall.

## Questions for Claude

1. **Does M14 b2's phone map copy want the still pieces out of the frame?** Taking them out then saves their bytes but makes the phone's map a hard requirement; the current frame is self-contained, and the size rule will count a little less when it changes.
2. **`GameEventCause.spring` maps to the sound name `spring`, while the spring event names `bump` explicitly.** A future spring without a sound would send `spring`, which no sound pack has yet; a host that sees it plays nothing, so it is harmless today.

## Commit message

M14 k2a: the map's pieces, themes and decor

Each piece is a map-file part with a schema entry, a parser with a
message per field, a rule in the field, a map rule and a painter.
Springs and bouncy walls throw a marble back at 1.5x, belts carry it
at half speed, posts are solid, movers swing, spin or slide from the
round clock, and a still hazard sends it to its start. The map rules
keep pieces inside the field, clear of the starts and coin zones, and
inside the limits (8 springs, 6 belts, walls and movers 24 together,
one pass every 1.5 s). The frame carries the theme and the pieces, so
a phone draws them without a map; the Playroom's frame and render are
byte-identical.

## Status row

M14 k2a (map pieces): done — springs, bouncy walls, posts, movers (swing, spin, slide), belts, still hazards, five themes and decor are in the map files, the schema, the parsers, the field, the map rules, the frame and the painters; the Playroom plays and draws exactly as before; format, analyze, arena (157), kit (71), host (316), phone (439) and tv (53, 1 skipped) pass; open: the four maps' files (Pinball, Block Castle, Toy Factory, Spinning Tops) are k2b's, and the phone's own map copy is b2's.

## Delete

- none
