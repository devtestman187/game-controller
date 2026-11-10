# Making a level

A level is data, not code: one file in its game's folder, listed in that folder's `index.json`. Both games use one level kit: `tools/level.sh` makes, checks and renders a level of any kind. This page has the parts every kind of level shares, then the guides to Shape Race puzzles and to the Arena's maps.

## The level file

A level file is JSON. Every kind of level starts with the same header:

| Field | What it is |
| --- | --- |
| `$schema` | Points the editor at the kind's schema file next to the levels (`puzzle.schema.json` for a puzzle, `map.schema.json` for a map), so VS Code completes the fields and underlines a mistake as you type. The app ignores it. |
| `format` | The file format's version, `1` today. A missing `format` means 1; a file with a higher number than the app knows is refused with a message saying to update the app, rather than loaded wrong: "This puzzle is format 2; this build reads format 1. Update the app, or save the puzzle in format 1." A map's file says the same with "map" in its place. |
| `id` | The file's name without `.json`, and its line in `index.json`. |

The rest of the fields belong to the kind: [below](#shape-race-puzzles) for a puzzle, [further down](#arena-maps) for a map.

## The folder and index.json

Each kind has a folder of level files (`packages/puzzle_game/puzzles` for puzzles, `packages/test_game/maps` for maps). A file is a level when its name doesn't start with `_`: `_template.json` is what `new` copies, and the kind's schema file is not a level either. Every level is listed in `index.json`, in the order the players see them, and every line there has its file:

```json
{"puzzles": ["house", "rocket", "tree", "sun"]}
{"maps": ["playroom"]}
```

An id is unique across kinds, so the two games can't both have a level called `sun`. `check` reports a listed id with no file, a file no line lists, and an id used by two kinds.

## The template

`new` copies `_template.json`, so a new level starts as a valid file with every field in place, its notes telling you the workflow. Edit the pieces of the copy; the template itself never changes as you work.

## Colours

Where a kind gives pieces a `color`, it is a named token or `"#RRGGBB"`. A puzzle's tokens are [in its section](#colour-tokens). A map colours nothing itself: it names a `theme`, and the theme's look comes from the code.

## The workflow

```bash
tools/level.sh new puzzle cat-face --level easy --name "Cat Face"   # file from the template, id in index.json
# edit packages/puzzle_game/puzzles/cat-face.json
tools/level.sh check cat-face        # the rules; no id checks every kind's library
tools/level.sh render cat-face       # writes docs/design/puzzles/cat-face.png
# look at the picture: start in the tray, finished picture, Sunny and Night
# commit the level file, its line in index.json and its render
```

`tools/level.sh check` with an id finds the kind by where the file is: the level's own folder says which game's rule book to run. A map's commands are the same, [below](#the-workflow-1).

## Reading a check message

`check` prints one line per rule the level breaks. A line names the level (and the part, `sun/window`) and says what to change:

```
sun: an Easy puzzle has 4 to 5 pieces, this one has 6. Add or remove a piece, or make it Medium.
```

In the code the same thing is a `LevelIssue` from `game_kit`: the level's id, the part's id when the problem is one piece, which rule (`PuzzleRule`) and the message. Anything that has to know a level's problems — the app, a test, `check` — reads that one list, so a message is worded once.

## Shape Race puzzles

A puzzle is one file in [`packages/puzzle_game/puzzles/`](../packages/puzzle_game/puzzles), listed in `index.json`. The app loads the whole library from those files, so a new picture needs no Dart change. This section has what a file's fields mean, the rules the library keeps, and the commands that carry a puzzle from nothing to a picture to commit.

### The board and its coordinates

Board units: the board is **80 wide and 72 high**, `(0, 0)` at its top left, x to the right and y downwards. The board sits in the game's 160 × 90 field, with room round it for the players' dots.

```
(0,0) x ──────────────▶
  ┌──────────────────────────────┐
y │                              │
│ │         80 × 72 board        │
▼ │                              │
  └──────────────────────────────┘
            y 72 at the bottom
```

A piece's `at` is where its outline's **origin** goes on the board. The origin is the shape's `(0, 0)`, the point the players' dot pushes and the piece turns about, so it must lie strictly inside the shape: draw the points round it, not from a corner.

### The file

```json
{
  "$schema": "puzzle.schema.json",
  "format": 1,
  "id": "sun",
  "name": "Sun",
  "level": "easy",
  "notes": "Anything for the next developer; the app ignores it.",
  "pieces": [ … ]
}
```

`$schema`, `format` and `id` are [the header every level shares](#the-level-file). The puzzle's own fields:

| Field | What it is |
| --- | --- |
| `name` | What the players read in the puzzle list. |
| `level` | `"easy"` or `"medium"`: which list it is in and which rules below it keeps. Hard is not used yet, so a file may not say `"hard"`: the schema, the parser and `check` refuse it, as `tools/level.sh new puzzle` does. |
| `notes` | Optional, free text, ignored by the app. |
| `pieces` | The pieces, in drawing order (below). |

### A piece

```json
{"id": "roof", "shape": {"polygon": [[-20, 8], [20, 8], [0, -14]]}, "color": "red", "at": [40, 20], "rotated": true}
```

| Field | What it is |
| --- | --- |
| `id` | The piece's name in `check`'s messages and in the code; unique in the puzzle. |
| `shape` | `{"circle": radius}`, `{"rect": [width, height]}`, `{"regular": [corners, radius]}` (first corner straight up) or `{"polygon": [[x, y], …]}` with at least 3 corners, all around the origin. |
| `color` | A colour token (`"red"`, `"sky"`, `"silver"`) or `"#RRGGBB"`. |
| `at` | Where the origin goes on the board: `[x, y]`. |
| `angle` | Optional: the angle the piece belongs at, in degrees clockwise, when the shape is drawn sideways. Default 0. |
| `rotated` | Optional: the piece starts at a random angle, so it must be turned before it fits. Every puzzle has at least 2; an Easy one exactly 2. |
| `big` | Optional: a big piece, which two players carry together. Medium has 1 or 2. |
| `kind` | Optional: pieces of one kind are interchangeable, so they must have the same shape and size (the boat's two waves). |

Pieces are drawn in the order they are written: a later piece lies over an earlier one (a window over a wall).

#### Turning and symmetry

A piece needs turning when `rotated` is set. Every puzzle in the library starts at least 2 pieces turned, and an Easy one no more than 2. A circle doesn't count, since it can't be turned. A square comes back onto itself every quarter turn, a rectangle every half turn, a regular polygon every `360° / corners`, a circle at any angle (so a circle can't be turned and must not be `rotated`). The app snaps a piece onto its outline by the nearest look-alike angle, so a circle with `rotated` would be unfair, and `check` says so.

### Rules by level

| | Easy | Medium |
| --- | --- | --- |
| Pieces | 4 to 5 | 6 to 8 |
| Turned pieces (`rotated`, not circles) | exactly 2 | at least 2 |
| Big pieces (`big`) | any | 1 or 2 |
| Pieces of one shape and size | none | at most one pair |

Every puzzle, whatever its level, also keeps these: each piece's outline lies on the board; the pieces fit the tray on one board and on the split screen, at every one of the tray's starts (seeds 0 to 199), where no piece may leave the tray or overlap another; every piece stands out from the board in Sunny and Night; two pieces of one puzzle are told apart unless they share a shape; the finished picture spans at least 60% of the board's width or height, so it reads as one picture rather than a few pieces in a corner. `tools/level.sh check` prints every rule the file breaks, one line each, with a message saying what to change. The rules themselves live in [`puzzle_rules.dart`](../packages/puzzle_game/lib/src/puzzle_rules.dart) and its parts.

#### Fitting the tray

The tray beside the board is **54 wide and 72 high**. At the start the pieces are laid in it in rows, tallest first, each at its starting angle. So the biggest piece and the next row together have to fit in 72 units of height, and a row's pieces in 54 of width. Some things that help:

- A big piece that is wider than tall fits better than a round one of the same span: the tray's rows stack downwards. The redrawn sun's rays are 50 × 38, not 48 × 48.
- A turned piece takes the room of its widest angle, so a long bar that starts turned needs more room than one that doesn't.
- Pieces may share a centre (the sun's face sits on its rays); the later one is drawn on top.
- The picture must still span 60% of the board's width or height. If the tray and the span pull against each other, make the big piece wider and shorter rather than smaller.

`check` lays the tray out at every start from seed 0 to 199, not just one: a turned piece's random angles decide its box, so a piece that fits at one start can crowd the tray at another. The message names the piece and the start that first shows it.

### Colour tokens

A `color` is a token or `"#RRGGBB"`. Every token stands out from the board in both looks (Sunny and Night), which a test proves for the whole table.

![The colour tokens with their names and hex codes](design/puzzles/colours.png)

| Token | Hex | Sunny | Night |
| --- | --- | --- | --- |
| `red` | #C0392B | 0.441 | 0.321 |
| `orange` | #E9762B | 0.299 | 0.437 |
| `yellow` | #F2C200 | 0.177 | 0.575 |
| `green` | #27AE60 | 0.330 | 0.415 |
| `sky` | #85C1E9 | 0.213 | 0.451 |
| `blue` | #2E86C1 | 0.396 | 0.267 |
| `purple` | #A66CFF | 0.386 | 0.332 |
| `brown` | #8E5B3A | 0.440 | 0.265 |
| `slate` | #546E7A | 0.441 | 0.213 |
| `silver` | #9FB8CE | 0.204 | 0.440 |
| `steel` | #7EA6C9 | 0.271 | 0.376 |
| `sand` | #B3A285 | 0.238 | 0.416 |

The two numbers are the OKLab distance from the board in each look; a piece is seen when it keeps 0.15 or more. A colour the table has no name for is written as a hex code, and `check` asks for more distance if it sits too close to the board.

### Before you commit

Run the full puzzle and phone tests too:

```bash
tools/check.sh puzzle phone
```

`check` is the whole rule book; the phone tests only make sure its numbers still match the phones. Three of its rules are the ones a new picture most often breaks:

- **At least 2 turned pieces** (an Easy puzzle exactly 2; circles don't count).
- **Big enough to see on a phone:** every piece is at least 8.5 mm across on the narrowest phone (`narrowestPhoneSafeArea`, 640 × 356 px), on either side and at every start from 1 to 21. A thin bar or a small dot is the usual failure; 14 × 4 passes where 12 × 3 doesn't. `controller_app/test/puzzle_size_test.dart` checks that no real phone draws smaller than that one.
- **The tray at every start:** over the starts 0 to 199, no two pieces' boxes overlap and none leaves the tray.

The puzzle tests also redraw `docs/design/m13-puzzles.png` and `m13-puzzles-night.png`, the sheets of every puzzle; commit them with the puzzle.

Then commit the puzzle file, its line in `index.json`, its render and anything else the picture needed. `new` makes an Easy 4-piece picture that already passes `check`; edit it from there. Files whose names start with `_` are never puzzles (`_template.json` is what `new` copies), and `check` checks the whole library when given no id, so a broken neighbour is caught too.

## Arena maps

A map is one file in [`packages/test_game/maps/`](../packages/test_game/maps), listed in `index.json`: the field an Arena mode plays on. The app loads the whole library from those files (`ArenaMapLibrary.load`), so a new arena needs no Dart change. The Playroom, today's field, is the first map. This section has what a file's fields mean, the two modes' needs, the rules every map keeps, and the commands that carry a map from nothing to a picture to commit.

### The field and its coordinates

A map file writes **fractions of the field**: `0` to `1` across and down, `(0, 0)` at the top left, x to the right and y downwards. The field is 16:9 and 90 units high (160 wide) in the units the rules measure in, so a size is a fraction of the shorter side:

```
(0,0) 0 ─────────────────────▶ 1 across
  ┌────────────────────────────────┐ 0
  │                                │ │
  │        160 × 90 field          │ │   a marble is 5.76 units across
  │     (mapFieldSize, 16:9)       │ │   (0.064 of 90), a wall is
  │                                │ │   3.15 units thick, a hazard
  └────────────────────────────────┘ 1   3.42 units across
```

Positions are fractions, so the field plays the same in any window. Sizes and speeds are fractions of its shorter side, as the game measures everything (`ArenaFieldRules`).

### The file

```json
{
  "$schema": "map.schema.json",
  "format": 1,
  "id": "playroom",
  "name": "Playroom",
  "line": "The first arena: walls, four bumpers and a goal to race for.",
  "notes": "Anything for the next developer; the app ignores it.",
  "theme": "playroom",
  "walls": [{"from": [0.24, 0], "to": [0.24, 0.56]}],
  "hazards": [{"slide": {"from": [0.355, 0.08], "to": [0.355, 0.62]}, "periodS": 3.2}],
  "race": {"start": [0.07, 0.5], "goal": [0.86, 0.38, 0.97, 0.62], "swapSides": true},
  "bumper": {"starts": [[0.1, 0.2], [0.1, 0.8], [0.88, 0.18], [0.88, 0.82]], "coins": [[0.06, 0.06, 0.2, 0.26]]}
}
```

`$schema`, `format` and `id` are [the header every level shares](#the-level-file). The map's own fields; `name` and `line` are read in every file, and everything else may be left out:

| Field | What it is |
| --- | --- |
| `name` | What the players read in the map picker. |
| `line` | One line about the map, for the picker's card. |
| `notes` | Optional, free text, ignored by the app. |
| `theme` | The floor's look, `"playroom"` when the file says none: `"playroom"`, `"pinball"`, `"castle"`, `"factory"` or `"tops"`. A theme only changes how the field is drawn; it never changes the play. The schema, the parser and `check` refuse a theme this build has not got. |
| `walls` | The walls, each `{"from": [x, y], "to": [x, y], "bouncy": true}`: an axis-aligned block `ArenaFieldRules.wallThickness` thick round the line between the two ends. A wall with both ends at one spot is not a wall; a `bouncy` one (the default false) kicks a marble back at 1.5 times its speed, as a pinball table's slingshots do. |
| `hazards` | The hazards: `{"slide": {"from": …, "to": …}}` back and forth between two points, `{"orbit": {"centre": …, "radius": …}}` round a circle (`radius` a fraction of the shorter side), each with `periodS` (one full cycle) and optional `phase` (where in the cycle it starts, 0 to 1); or `{"still": {"at": …}}` for a hazard that never moves (a drain), which sends a marble back to its start and has no period or phase. |
| `springs` | The springs, each `{"at": [x, y], "radius": …}`: a green cap over a yellow coil, never red, since red means a hazard. A marble that hits one bounces off at 1.5 times its speed, with `bump`; it is not a hazard and drops nothing. `radius` (a fraction of the shorter side) is 0.05 when the file says none. |
| `posts` | The posts, each `{"at": [x, y], "radius": …}`: a solid round pillar a marble bounces off, a castle's tower or a factory's column. `radius` is 0.055 when the file says none. |
| `belts` | The belts, each `{"from": [x, y], "to": [x, y], "width": …}`: a strip a marble standing on is carried along at half its walking speed, towards the `to` end. `width` is 0.09 when the file says none, and a belt with both ends at one spot is not a belt. |
| `movers` | The movers, walls that move on a timer: `{"swing": {"pivot": …, "length": …, "fromDeg": …, "toDeg": …}}` about a pivot between two angles (a flipper), `{"spin": {"pivot": …, "length": …}}` steadily round one (a carousel), or `{"slide": {"from": …, "to": …, "length": …, "deg": …}}` between two places (a gate, a press), each with `periodS` and optional `phase`. A mover pushes a marble out of its way and never through another wall; a mover that pins one against a wall stops for that step rather than crush it. |
| `decor` | The scenery drawn round the play, each `{"kind": "flag", "at": [x, y], "size": …}`: a `"flag"`, a `"light"` or a `"gear"`, in the theme's own colours. It has no collision and no effect on play, and `size` is 0.09 when the file says none. |
| `race` | The Shape Race's part: `start` (where the first player starts), `goal` (the pad, `[left, top, right, bottom]`) and `swapSides` (whether every round flips the field left to right, as the race does today). The other three starts sit above and below `start` at `startSpacing` (0.14 of the height), so a map's start needs room for four. |
| `bumper` | The Bumper Round's part: `starts` (four spots) and `coins` (one or more rects a coin may appear in). |

A map needs `race`, or `bumper`, or both: a map with neither is refused with a message saying to add one, since no mode could play it. A map with only `bumper` is a Bumper Round arena with no finish (M14 k2's four). A game built with no map plays the Playroom, and `maps/playroom.json` parses to `ArenaMap.playroom` exactly, so the field in code and the file cannot drift.

### The two modes' needs

| | Shape Race | Bumper Round |
| --- | --- | --- |
| What it uses | `start` (four slots), `goal`, `swapSides` | `starts` (exactly four), `coins` |
| The start | clear of walls: a marble begins on it, not touching one | the same, four of them, at least 3 marbles apart |
| Getting there | a way from every start to the goal, and back the other way in a round that swaps sides | a way from every start to every coin zone |
| Hazards | no hazard's whole path reaches a start, or the part of the goal a marble's centre must reach; a hazard guarding the goal's rim is good design, and the Playroom does it on purpose | no hazard's whole path reaches a start |
| Coin zones | — | clear of walls, room for 3 coins together, and every start can get there |

### The rules

`check` runs the same rule book over a map, in `map_rules.dart` and its parts. Besides the two modes' needs, every map keeps these:

- **Everything inside the field.** Every wall, hazard, spring, post, belt, mover's sweep, decoration, start, goal and coin zone lies between 0 and 1, across and down. A belt with both ends at one spot, or a mover with no length, is no piece at all.
- **The pieces keep clear of the starts and the coin zones.** A spring, a post or a belt never sits on a start, where a marble begins, or in a coin zone, where the Bumper Round's coins appear, and a mover's sweep never crosses either: a piece there would shove a marble as it set off or a coin as it came out, and these pieces have no hazard's grace.
- **Every route a marble needs is wide enough.** Each start to the goal, and each start to each coin zone, passes only gaps at least **1.6 marbles** wide between the walls' faces (9.2 units), so none gets stuck: the Playroom's tightest gate is about 1.75. Aim for **2.5 marbles** (14.4 units) on a new map, so two can pass. `check` reads this on a path grid with the walls grown by 0.8 of a marble (`MapGrid`): a way that only the grown grid misses is a squeeze; a dead-end slit no route goes through is not a gap a marble must pass, so it is not an issue.
- **No pocket.** No free spot a marble could stand on is cut off from every start.
- **Limits.** At most **24 walls and movers together** (a mover is a wall that moves, so it counts with them), **8 hazards**, **8 springs** and **6 belts**, and neither a hazard nor a mover faster than one pass every **1.5 s**; a still hazard has no pass to make.
- **The snapshot's budget.** One frame of the map with four marbles, its coins and its pieces stays inside 2048 bytes, so a busy map never crowds the phone's frames. The frame carries the floor's theme and the pieces fixed to it as well as the walls and the hazards, since a phone draws the field from the frame alone (the map id names it, and M14 b2's phone copy will save the pieces their bytes).
- **The listing.** Every map is in `index.json` and every line there has its file ([above](#the-folder-and-indexjson)).

Each broken rule is one line from `check`, naming the map, the part and what to change:

```
playroom/start 0: a wall is in the way of the start, so a marble begins touching it. Move the start or the wall.
playroom/start 1: the way from the start 1 to the goal passes a gap narrower than 1.6 marbles. Move the walls on the way apart, so a marble never has to squeeze through.
playroom/race: wall 3 overlaps the goal pad. Move the wall, or the goal.
playroom/hazard 2: its sweep crosses the goal, so a marble can be hit as it arrives. Move the hazard, or the goal.
playroom/start 0: in a round that swaps sides no marble can get from the start to the goal. Move a wall, or the start or the goal.
playroom/bumper: the Bumper Round starts 4 marbles, this map gives 3 spots. Give it 4 starts.
playroom/bumper start 2: it is closer than 3 marbles to bumper start 3. Move one of them further away.
playroom/bumper start 0: hazard 1 sweeps across the start, so a marble is hit as it sets off. Move the hazard, or the start.
playroom/coin zone 0: a wall crosses the zone. Move the zone into open floor.
playroom/coin zone 1: it has room for 1 of the 3 coins a zone needs together. Make it bigger, or move it into open floor.
playroom/coin zone 2: no marble can get here from bumper start 0. Open a way, or move the zone.
playroom: a marble can stand at 0.30 across and 0.10 down but no start can reach it. Open a gap into that corner, or fill it with a wall.
playroom: it has 25 walls; a map has at most 24. Remove one, or join two into a longer wall.
playroom: it has 20 walls and 5 movers; a wall and a mover both count, and a map has at most 24. Remove one, or join two into a longer wall.
playroom: it has 9 hazards; a map has at most 8. Remove one, so the screen stays calm.
playroom: it has 9 springs; a map has at most 8. Remove one.
playroom: it has 7 belts; a map has at most 6. Remove one.
playroom/hazard 0: it makes a pass every 1.2 s; the fastest is one every 1.5 s. Make its "periodS" bigger.
playroom/mover 1: it makes a pass every 1.2 s; the fastest is one every 1.5 s. Make its "periodS" bigger.
playroom/spring 0: it sits on start 0, where a marble begins. Move it clear of every start.
playroom/post 0: it sits on bumper start 0, where a marble begins. Move it clear of every start.
playroom/belt 1: it crosses start 2, where a marble begins. Move it clear of every start.
playroom/mover 0: its sweep crosses start 3, where a marble begins. Move it clear of every start.
playroom/spring 0: it sits in coin zone 0, where coins appear. Move it clear of the coin zones.
playroom/belt 1: it crosses coin zone 1, where coins appear. Move it clear of the coin zones.
playroom/mover 0: its sweep crosses coin zone 1, where coins appear. Move it clear of the coin zones.
playroom/spring 0: it reaches 1.23 across and 0.55 down, outside the field. Keep every part of the map between 0 and 1, across and down.
playroom/mover 0: its sweep runs to 1.30 across and 0.50 down, outside the field. Keep every part of the map between 0 and 1, across and down.
playroom: with four marbles and its coins its snapshot is 2163 bytes; a frame may take 2048. Use fewer pieces, or fewer or shorter walls.
```

The rules are `MapRule`s on a `LevelIssue`, as the puzzles' are `PuzzleRule`s, so the app, the tests and `check` read one list.

### The path grid

`MapGrid` is the map's field in cells about a fifth of a marble across: a cell is free only where a marble's centre fits, with the walls (and the field's edges) grown by a marble's radius, or by whatever `grow` asks for. It flood-fills and finds the shortest way between two points, so a rule asks it a question and gets an answer in field fractions:

| | |
| --- | --- |
| `isFree(point)` | whether a marble's centre may stand there |
| `path(from, to)` | the shortest way, as the cells' centres, or null |
| `hasPath(from, to)` | whether there is one |
| `reachesZone(from, zone)` | whether a marble can get into a rect from a point |
| `spotsIn(zone, apart:, most:)` | up to `most` free places in a rect, each `apart` from the others: where a coin may go |
| `unreachableFrom(starts)` | a free cell no start reaches, or null |

Robo uses it too (M14 b3), so it steers with the same reading of the field the rules check.

### The workflow

```bash
tools/level.sh new map arena --name "Arena"    # file from _template.json, id in maps/index.json
# edit packages/test_game/maps/arena.json
tools/level.sh check arena                     # the rules; no id checks puzzles and maps
tools/level.sh render arena                    # writes docs/design/maps/arena.png
# look at the picture: the field in Sunny and Night, with the starts, the goal,
# the coin zones and each hazard's sweep marked
# commit the map file, its line in index.json and its render
```

`_template.json` is a field that already passes `check`: a wall down the middle with a gap at each end, one slide, a race and a Bumper Round. Edit it from there. Run `tools/check.sh arena` before committing; the map tests redraw `docs/design/maps/` too.
