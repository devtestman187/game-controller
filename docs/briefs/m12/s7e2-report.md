# M12 step 7 s7e2 — G4 report: the HUD beside the board by the real text; a tray that keeps room

Stopped at G4 as the brief says. The clock area is now sized by the score it will actually draw (and by
the clock for "10:00"), so a solo match no longer pays for the longest race text, and the short form steps
in before the corner. The tray row overlaps by the smallest of 0, 0.25 and 0.5 that keeps the world within
1.3 × its height, so the boat — the one puzzle that needed it — leaves the clock room beside it. The
outcome: no shipped puzzle takes the board's corner at 852×393, 734×370 or 667×375 at seed 1 any more
(s7e's Q1 is answered by the numbers, not by a new constant).

## What was done

### 1. The forms follow the real text (`camera.dart` 197 → 209 lines)

- **`PuzzleCamera.hudPlace(layout, camera, box, text)`** now takes `({String score, List<String> short})`
  — what `phoneHud` gives — and picks the first form that the spare width fits, in `HudForm`'s order:
  `oneLine` (clock + score) → `twoLines` (clock, then the whole score) → `short` (clock, then each short
  line) → `corner` (over the board's top-left).
- **The clock is measured for "10:00"**, whatever it says now: `_clockChars` 5 at the clock's height.
  `_glyphEm` 0.5 is still the width estimate. Widths and heights are now fractions of the box height:
  - one line: width `0.2 + 0.02 + 0.02 × len(score)` (clock, gap, score), height `hudOneLineHeight` 0.112;
  - two lines: width `max(0.2, 0.02 × len(score))`, height `hudTwoLineHeight` 0.172;
  - short: width `max(0.2, 0.02 × longest short line)`, height 0.172 + 0.06 × (lines − 1) (0.232 for a
    race's two short lines);
  - corner: the short form's size, its width capped at the board's width minus two corner margins.
  `hudOneLineWidth` and `hudTwoLineWidth` are gone: they fixed a 20-character score. `_glyphEm`,
  `_clockChars`, `hudOneLineHeight`, `hudTwoLineHeight` stay; the per-form size is the private
  `_hudSize(form, text)`.
- **`HudForm` gains `short`**: `{oneLine, twoLines, short, corner}`.
- **`phoneHud` returns the short texts too**: `({clock, score, short})`. The score is `short.join(' · ')`,
  so the two can't drift: solo `['0/4']` (score "0 of 4 placed"); a race `['You 2/4', 'Right 3/6']` (score
  "You 2/4 · Right 3/6"); the whole match `['Left 2/4', 'Right 3/6']`.
- **The painter draws the short form** (`match_painter.dart`): the clock, then each short line at
  `top + clock + (i + 1) gap + (i + 0.5) score`, which ends exactly on the bar's top edge. `_hud` asks
  `phoneHud` once and passes the texts to both `hudPlace` and `_hudTexts`.

### 2. A tray that keeps room (`split_layout.dart` 382 → 389 lines)

- New named, documented constants: **`phoneWorldMaxAspect = 1.3`** (a 16:9 to 19.5:9 phone as tall as the
  world leaves 0.48 to 0.87 of the height beside it) and **`_phoneRowOverlaps = [0, 0.25, 0.5]`**.
- `_computePhones` packs the row at 0 and takes the next overlap only while the world is wider than
  `phoneWorldMaxAspect × height`; only after that does the 2.2 two-row rule run (at the overlap chosen).
  The chosen overlap goes into `PuzzleField.trayOverlap`, so `game.dart`'s `packTray` call packs the rules'
  tray the same way (its own test "a phones split match starts every piece where packTray puts it" still
  passes untouched).
- `_packedTray` takes the overlap and now reads the row's right edge straight from `packTray`'s own
  positions (`at[i].dx + box width`, widths scaled exactly as the rules scale them) instead of mirroring
  the row step. That is what makes an overlap safe: `packTray` reduces a piece's overlap when it would
  hide an earlier piece below 55%, so the mirrored step could have been narrower than the real row.
- **Heights don't change** (a one-row tray's height is the tallest box plus gaps, overlap or not), so the
  mm don't.

Worlds and rows at seed 1 (the s7e values on the left of each arrow):

| puzzle | pieces | overlap (seeds 0–19) | tray row | world before → now | aspect now |
| --- | --- | --- | --- | --- | --- |
| house | 4 | 0 | 80.46 × 20.50 | 84.46 × 88.50 → **84.46 × 88.50** | 0.954 |
| rocket | 5 | 0 | 81.90 × 14.50 | 85.90 × 79.50 → **85.90 × 79.50** | 1.080 |
| tree | 4 | 0 | 77.62 × 25.00 | 81.62 × 102.00 → **81.62 × 102.00** | 0.800 |
| boat | 6 | **0.25** | 117.63 × 13.52 at 0 → **87.35 × 13.52** | 121.63 × 80.52 → **91.35 × 80.52** | 1.135 |

Only the boat moves: its no-overlap row made a 1.511:1 world, past 1.3, and 0.25 packs it to 87.35 with
the same 13.52 height, a 1.135:1 world. 0.25 is the smallest overlap that fits, so 0.5 is never asked for.
No seed 0–19 of house, rocket or tree needs an overlap, and every seed of the boat takes 0.25.

### 3. Nothing else moved

`_computeScreen`, `PuzzleCamera.place/scale`, `fieldIn`, the rules (`game.dart`), the host and the phone
app are untouched. `controller_app/test/puzzle_size_test.dart` is untouched and passes.

## The forms table (seed 1)

`side` camera, left side; "solo" = `phoneHud` of a one-board match ("0 of 4 placed" / short "0/4"), "race"
= of a two-board match ("You 0/4 · Right 0/4" / short "You 0/4", "Right 0/4"). The spare width beside the
world (px) is below each box; every form here is beside the board, none is `corner`.

| box | spare px (house / rocket / tree / boat) | house | rocket | tree | boat |
| --- | --- | --- | --- | --- | --- |
| 852 × 393 | 222.5 / 197.7 / 252.8 / 187.1 | one/two | one/two | one/one | two/two |
| 734 × 370 | 174.4 / 151.1 / 203.0 / 141.1 | two/two | two/two | one/two | two/two |
| 667 × 375 | 138.6 / 114.9 / 167.5 / 104.8 | two/short | two/short | two/two | two/short |
| 1024 × 768, `whole` | 312.8 / 288.5 / 342.4 / 278.2 | two | short | two | short |

(solo/race; the 1024 row is the whole camera's one HUD for "Left 0/4 · Right 0/4", only the race text is
meaningful there.)

Widths and heights in px, so the arithmetic can be checked (0.48 / 0.60 of the height for one line solo /
race; 0.26 / 0.38 for two lines; 0.20 for the short form, which the clock decides):

| case | rect |
| --- | --- |
| tree solo, 852 × 393, one line | (8, 55.02) 188.64 × 44.02 = 0.48 / 0.112 of 393 |
| house race, 852 × 393, two lines | (8, 55.02) 149.34 × 67.60 = 0.38 / 0.172 of 393 |
| tree solo, 667 × 375, two lines | (8, 52.50) 97.50 × 64.50 = 0.26 / 0.172 of 375 |
| rocket race, 667 × 375, short | (8, 52.50) 75.00 × 87.00 = 0.20 / 0.232 of 375 |

Old forms at the same boxes (s7e): 852×393 house twoLines, rocket twoLines, tree oneLine, **boat corner**;
667×375 **house corner**, **rocket corner**, tree twoLines, **boat corner**; whole 1024×768 house twoLines,
**rocket corner**, tree twoLines, **boat corner**. All eight corners are gone.

## Tests

| check | before | after |
| --- | --- | --- |
| `format` (whole repo) | PASS | PASS |
| `analyze --fatal-infos` | PASS | PASS |
| `puzzle` | 106 tests | **106 tests** |
| `host` | 76 tests | 76 tests |
| `phone` | 329 tests | 329 tests |

Per file: `camera_test` 12 → 12 (four HUD tests became four; one is the forms table), `view_test` 11 → 11,
`split_layout_test` 11 → 11. No test was skipped or loosened.

- **`camera_test`** — "the form follows the score's real text" is the brief's table: all four puzzles,
  seed 1, solo and race, at 852×393, 734×370 and 667×375, plus the whole camera at 1024×768, with the
  texts taken from real `PuzzleCamera.hudPlace`/`phoneHud` calls (a `PuzzleMatch` with no piece placed, so
  a longer count would move the form too). Every case also asserts `isNot(HudForm.corner)`. The three
  other tests keep the geometry: the tree's one-line rect at 852×393 (width 188.64, not the 243.66 a
  20-character score would take), the corner at 380×375 (still the last resort), and the whole match at
  1024×768 (one HUD left of both stacked worlds).
- **`split_layout_test`** — the phones rules test now pins the overlap per puzzle (`{house: [0], rocket:
  [0], tree: [0], boat: [0.25, 0.5]}`, checked on every seed 0–19), keeps "a tray gap apart, no overlap"
  only where the overlap is 0, adds the bound "no box is over its neighbour by more than the row's
  overlap" where it isn't, and replaces the 2.2 world check with `≤ phoneWorldMaxAspect × height`. The
  two-row test and the print test are untouched (the boat's printed world is now 91.35 wide).
- **`view_test`** — the three `phoneHud` cases compare `(clock, score)` and `short` field by field (a
  record holding a `List` is never `==` to an equal literal, so the whole-record form the s7e test used no
  longer works); solo is short `['0/4']`, a race `['You 2/4', 'Left 0/4']`, the whole match
  `['Left 0/4', 'Right 2/4']`. The bar-colour test passes the drawn snapshot's texts to `hudPlace`.
- **`controller_app/test/puzzle_size_test.dart`** — untouched, passes. **No mm changed** (old = new):
  iPhone SE 667×375 house 9.42, rocket 8.99, tree 9.34, boat 10.35; iPhone 15 734×370 9.29 / 8.87 / 9.21
  / 10.21; 814×407 10.22 / 9.75 / 10.14 / 11.23; 869×404 10.15 / 9.68 / 10.06 / 11.15; 780×382 9.59 /
  9.15 / 9.51 / 10.54; 640×356 8.94 / 8.53 / 8.87 / 9.83; lowest house 8.94, rocket 8.53 (the 8.5 floor),
  tree 8.87, boat 9.76 (all at seed 1 except the boat, seed 8). Every one is height-bound: the screens are
  1.78:1 to 2.15:1 and the widest world is the boat's 1.51:1 before this job (1.14:1 now), so the widths
  never bind, and the heights are untouched.

### Changed expected values, old → new

| file | old | new |
| --- | --- | --- |
| `camera.dart` API | `hudPlace(layout, camera, box)` | `hudPlace(layout, camera, box, text)` with `text = (score:, short:)` |
| `camera.dart` API | `hudOneLineWidth` 0.62, `hudTwoLineWidth` 0.4 (consts) | gone: the width is `_hudSize`'s for the real score |
| `camera.dart` API | `HudForm {oneLine, twoLines, corner}` | `{oneLine, twoLines, short, corner}` |
| `view_test` | `phoneHud` = `(clock, score)` | `(clock, score, short)`; compared field by field |
| `camera_test` | "the tree at 852 x 393 is twoLines" | it is oneLine (0.48 h = 188.64 ≤ 222.5 spare) |
| `camera_test` | "the tree at 667 x 375 has a 150 px rect, short of `hudOneLineWidth`" | 97.5 px (0.26 h, the solo score on its own) |
| `camera_test` | "the corner rect is `min(0.4 h, board − 16)` wide" | it is the short form's width (0.2 h = 75 px at 375) |
| `camera_test` | whole 1024×768: rocket corner, boat corner | rocket short, boat short (288.5 and 278.2 px spare) |
| `split_layout_test` | `field.trayOverlap == 0` for every puzzle | 0 for house/rocket/tree, 0.25 or 0.5 for the boat |
| `split_layout_test` | every tray box ≥ a tray gap after the one before | only when the overlap is 0 (else ≤ the overlap over it) |
| `split_layout_test` | world ≤ `phoneMaxAspect` (2.2) × height | world ≤ `phoneWorldMaxAspect` (1.3) × height |
| `split_layout_test` print | boat world 121.63 × 80.52, row 117.63 × 13.52 | 91.35 × 80.52, row 87.35 × 13.52 (printed, not asserted) |

## Line counts (changed files)

| file | before | after | |
| --- | --- | --- | --- |
| `lib/src/split_layout.dart` | 382 | **389** | over 300 (pre-existing NOTE), at the brief's 390 cap |
| `lib/src/camera.dart` | 197 | **209** | |
| `lib/src/match_painter.dart` | 286 | **300** | at the aim of 300, under the 400 limit |
| `lib/src/view.dart` | 84 | 84 | unchanged |
| `test/camera_test.dart` | 208 | **275** | |
| `test/view_test.dart` | 395 | **398** | over 300 (pre-existing), under 500 |
| `test/split_layout_test.dart` | 410 | **437** | over 300 (pre-existing), under 500 |

No lib file is over 400 and no test file over 500. `split_layout.dart` is 389 of the brief's 390: the
overlap choice (six lines) and the two-row fallback (five) both live in `_computePhones`, which is why it
is 43 lines long — a `review.sh` NOTE, not a FAIL. Moving either out needs a helper with its docs, which
would put the file past 390; the s7e line of `_computeScreen` (a pre-existing 120-line FAIL) is the only
way to make that room and it is outside this job.

## Checks run

- `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets`: 352 files,
  0 changed.
- `dart analyze --fatal-infos`: no issues.
- `flutter test` in `packages/puzzle_game`: 106 tests, all pass; in `packages/party_host`: 76; in
  `controller_app`: 329.
- `tools/check.sh format analyze puzzle host phone` itself could not be run in this sandbox (the shell
  refused the script: "This command requires approval"); each of the five checks it runs was run directly,
  as above.
- `tools/review.sh`: `1 fail, 2 note` — the FAIL is the pre-existing `_computeScreen` 120 lines
  (`split_layout.dart:144`, was `:135` at HEAD; it only moved because lines were added above it), the
  NOTEs are `split_layout.dart` 389 lines and `_computePhones` 43 lines. Nothing else on my lines.
- No pixel probe was needed this time: `view_test` already draws the short and two-line forms at both
  phone boxes (the house race at 667×375 is `short`) and reads the bar's colour out of the rect
  `hudPlace` returned.

## Questions

1. **The short race form is three lines tall** (clock, "You 2/4", "Right 3/6") — 0.232 of the height, 87 px
   at 375. I read the brief's chain as one line per side; the alternative is the clock with both counts on
   one line ("You 2/4 · Right 3/6"), which is exactly the two-line form and would make `short` unnecessary
   for a race. Confirm which you want if the shape matters visually.
2. **The corner form is now the short form's width** (0.2 h = 75 px at 375) instead of s7e's 0.4 h, because
   `hudPlace` uses the narrowest form it would have drawn. With the worlds at 0.80:1 to 1.14:1, only a box
   below about 1.45:1 (house) to 1.62:1 (boat) at 375 px tall reaches it; every phone screen is 1.78:1 or
   wider.
3. **`hudOneLineWidth` / `hudTwoLineWidth` are gone** (their values depended on a 20-character score). If
   a caller outside the package wants "how wide will the HUD be", `_hudSize` would have to be public.
4. **`phoneHud`'s records can no longer be compared whole** when they hold `short` (record `==` compares
   the list by identity). The tests compare fields; a caller doing `expect(hud, (...))` will trip on this.
5. **The boat's row overlaps a quarter, so its tray is denser than the others'.** It still keeps every
   piece 55% visible (`packTray`'s rule) and the rules pack the same way, but it is the only puzzle whose
   tray looks different from s7e. Say if you'd rather have 0.5 or a different world limit.

## Suggestions

- If the short form's three lines are not wanted, the only one-form alternative is a two-line form with
  both counts on one line ("You 2/4 · Right 3/6", 0.38 h): at the SE that is 142.5 px against spares of
  138.6 (house) and 114.9 (rocket), so those two would go back over the board's corner.
- A follow-up could pin the form for one more seed per puzzle (the table is seed 1), so a seed that packs
  a wider row shows up as another form rather than only a wider world.

## Commit message

m12 s7e2: the phone HUD sized by its score; a tray row that keeps room

`PuzzleCamera.hudPlace` takes the score and its short lines and picks the
first form that fits: one line, two lines, a short form (clock over "You
2/4" / "Right 3/6"), then the corner; the clock is sized for "10:00" so
the form never flips. `HudForm` gains `short`; `phoneHud` returns the
short lines and the score is their join.
`_computePhones` overlaps the tray row by the smallest of 0, 0.25 and 0.5
that keeps the world within `phoneWorldMaxAspect` 1.3 × its height, so the
boat's world drops from 121.63 to 91.35 wide and the mm stay put.

## Status row

| 7 Puzzle on phones | s7e2 G4 done ([s7e2-report.md](s7e2-report.md)): the phone HUD is sized by the real score (`hudPlace` takes the score and its short lines; one line → two lines → `HudForm.short` (clock over "You 2/4" / "Right 3/6", solo "0/4") → the board's corner; the clock is measured for "10:00"), and the phones tray row overlaps by the smallest of 0, 0.25 and 0.5 that keeps the world within `phoneWorldMaxAspect` 1.3 × its height, so the boat's world is 91.35 × 80.52 instead of 121.63 × 80.52; no corner form is left at 852×393, 734×370 or 667×375, heights are unchanged and no mm moved; puzzle stays 106. Open: the short race form's three-line shape (Q1) |

## Delete

- packages/puzzle_game/test/s7e2_numbers_test.dart
