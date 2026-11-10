# Making a level

A level is data, not code: one file in its game's folder, listed in that folder's `index.json`. Both games use one level kit: `tools/level.sh` makes, checks and renders a level of any kind. This page has the parts every kind of level shares, then the guide to Shape Race puzzles.

## The level file

A level file is JSON. Every kind of level starts with the same header:

| Field | What it is |
| --- | --- |
| `$schema` | Points the editor at the kind's schema file next to the levels (`puzzle.schema.json`), so VS Code completes the fields and underlines a mistake as you type. The app ignores it. |
| `format` | The file format's version, `1` today. A missing `format` means 1; a file with a higher number than the app knows is refused with a message saying to update the app, rather than loaded wrong: "This puzzle is format 2; this build reads format 1. Update the app, or save the puzzle in format 1." |
| `id` | The file's name without `.json`, and its line in `index.json`. |

The rest of the fields belong to the kind: [below](#shape-race-puzzles) for a puzzle.

## The folder and index.json

Each kind has a folder of level files (`packages/puzzle_game/puzzles` for puzzles). A file is a level when its name doesn't start with `_`: `_template.json` is what `new` copies, and the kind's schema file is not a level either. Every level is listed in `index.json`, in the order the players see them, and every line there has its file:

```json
{"puzzles": ["house", "rocket", "tree", "sun"]}
```

An id is unique across kinds, so the two games can't both have a level called `sun`. `check` reports a listed id with no file, a file no line lists, and an id used by two kinds.

## The template

`new` copies `_template.json`, so a new level starts as a valid file with every field in place, its notes telling you the workflow. Edit the pieces of the copy; the template itself never changes as you work.

## Colours

Where a kind gives pieces a `color`, it is a named token or `"#RRGGBB"`. A puzzle's tokens are [in its section](#colour-tokens).

## The workflow

```bash
tools/level.sh new puzzle cat-face --level easy --name "Cat Face"   # file from the template, id in index.json
# edit packages/puzzle_game/puzzles/cat-face.json
tools/level.sh check cat-face        # the rules; no id checks every kind's library
tools/level.sh render cat-face       # writes docs/design/puzzles/cat-face.png
# look at the picture: start in the tray, finished picture, Sunny and Night
# commit the level file, its line in index.json and its render
```

`tools/level.sh check` with an id finds the kind by where the file is: the level's own folder says which game's rule book to run.

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

## Arena maps: coming in M14

The Arena's maps join the kit with its own map kit in M14 k1b; until then `tools/level.sh new map` says "Maps come with the Arena's map kit (M14 k1b)."
