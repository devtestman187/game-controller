# Making a Shape Race puzzle

A puzzle is data, not code: one file in [`packages/puzzle_game/puzzles/`](../packages/puzzle_game/puzzles), listed in `index.json`. The app loads the whole library from those files, so a new picture needs no Dart change. This page has what a file's fields mean, the rules the library keeps, and the four commands that carry a puzzle from nothing to a picture to commit.

## The board and its coordinates

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

## A piece

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
| `rotated` | Optional: the piece starts at a random angle, so it must be turned before it fits. Easy allows at most 2. |
| `big` | Optional: a big piece, which two players carry together. Medium has 1 or 2. |
| `kind` | Optional: pieces of one kind are interchangeable, so they must have the same shape and size (the boat's two waves). |

Pieces are drawn in the order they are written: a later piece lies over an earlier one (a window over a wall).

### Turning and symmetry

A piece needs turning when `rotated` is set; `check` wants at least a couple of turnable pieces in each puzzle and no more than two in an Easy one. A square comes back onto itself every quarter turn, a rectangle every half turn, a regular polygon every `360° / corners`, a circle at any angle (so a circle can't be turned and must not be `rotated`). The app snaps a piece onto its outline by the nearest look-alike angle, so a circle with `rotated` would be unfair, and `check` says so.

## Rules by level

| | Easy | Medium |
| --- | --- | --- |
| Pieces | 4 to 5 | 6 to 8 |
| Turned pieces (`rotated`) | at most 2 | any |
| Big pieces (`big`) | any | 1 or 2 |
| Pieces of one shape and size | none | at most one pair |

Every puzzle, whatever its level, also keeps these: each piece's outline lies on the board; the pieces fit the tray on one board and on the split screen; every piece stands out from the board in Sunny and Night; two pieces of one puzzle are told apart unless they share a shape; the finished picture spans at least 60% of the board's width or height, so it reads as one picture rather than a few pieces in a corner. `tools/puzzle.sh check` prints every rule the file breaks, one line each, with a message saying what to change. The rules themselves live in [`puzzle_rules.dart`](../packages/puzzle_game/lib/src/puzzle_rules.dart).

## Colour tokens

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

## Workflow

```bash
tools/puzzle.sh new cat-face --level easy --name "Cat Face"   # file from the template, id in index.json
# edit packages/puzzle_game/puzzles/cat-face.json
tools/puzzle.sh check cat-face        # the rules; no id checks the whole library
tools/puzzle.sh render cat-face       # writes docs/design/puzzles/cat-face.png
# look at the picture: start in the tray, finished picture, Sunny and Night
```

Then commit the puzzle file, its line in `index.json`, its render and anything else the picture needed. `new` makes an Easy 4-piece picture that already passes `check`; edit it from there. Files whose names start with `_` are never puzzles (`_template.json` is what `new` copies), and `check` checks the whole library when given no id, so a broken neighbour is caught too.
