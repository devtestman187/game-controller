# M12 step 7 s7e — G4 report: the clock and score beside the board; the tray row without overlap

Stopped at G4 as the brief says. Contract §0.7c (the owner's option 3) is in: the `phones` world reserves
no column for the clock, its tray row packs piece beside piece with no overlap, and the clock, the score and
the time bar are painted in screen space in the box's spare width beside the world — on one line, on two
lines, or (when neither fits) over the board's top-left corner.

## What was done

### 1. `_computePhones`: no clock area, the row as wide as it is (`split_layout.dart`, 385 → 382 lines)

- **`SplitLayout.hud` is gone**, not always null, and `hudWidth` (40 units) with it: a `phones` world no
  longer contains a clock area. New `final LayoutTarget target` on `SplitLayout` (documented §0.4/§0.7c,
  defaulting to `screen` in the private constructor): `PuzzleCamera.scale` used to tell a phone world by
  `layout.hud == null` and now asks `layout.target == LayoutTarget.phones`. Giving it a default keeps the
  screen path's `_computeScreen` at its 120 lines, so `tools/review.sh`'s pre-existing FAIL doesn't move.
- `_phoneWorld(crop, trayWidth, trayHeight)` is now
  `Size(max(crop.width + 2 * margin, trayWidth + 2 * margin), margin + trayHeight + margin + crop.height + margin)`:
  the width is the wider of the board and the row, both plus margins (§0.7c); the height is unchanged.
- `_phoneTray` packs with `packTray(..., overlap: 0, scale: _trayScale)` at `double.infinity` — the row
  cannot break, so its width is the row's right edge plus `trayGap`. `_packedTray` therefore no longer takes
  an `overlap` (it is always 0) and its row step is `start = max(start, previous.x + previousWidth + trayGap)`.
  The two-row fallback (a world wider than 2.2:1) still runs first and re-packs at a finite width.
- `PuzzleField.trayOverlap` is `0` on phones, so the rules' start-time packing goes through
  `game.dart:157`'s `packTray(puzzle, starts, tray.width, overlap: field.trayOverlap, scale: field.trayScale)`
  — the same call as before, now with no overlap and the row's width; nothing in `game.dart` changed, and
  the s7c test "a phones split match starts every piece where packTray puts it" still passes untouched.

World and row sizes at seed 1 (units); the old values are s7c's:

| puzzle | board | tray row | world before | world now | scale on the world |
| --- | --- | --- | --- | --- | --- |
| house | 60.00 × 62.00 | 80.46 × 20.50 | 90.88 × 88.50 | **84.46 × 88.50** | 4.4407 (852×393), 4.2373 (667×375) |
| rocket | 40.00 × 59.00 | 81.90 × 14.50 | 89.19 × 79.50 | **85.90 × 79.50** | 4.9434, 4.7170 |
| tree | 70.00 × 71.00 | 77.62 × 25.00 | 91.06 × 102.00 | **81.62 × 102.00** | 3.8529, 3.6765 |
| boat | 74.00 × 61.00 | 117.63 × 13.52 | 111.59 × 80.52 | **121.63 × 80.52** | 4.8810, 4.6574 |

The old width was `max(crop, trayOld + 40) + 4` with the old trays at `trayOverlap` 0.5 (46.88, 45.19,
47.06, 67.59 — all four worlds were tray-driven), so dropping the 40-unit column narrows house, rocket and
tree; the boat's no-overlap row
(117.63) is now wider than its board and decides, so its world grows by 10.04 units. No shipped puzzle
takes the two-row path today (the widest is the boat at 1.51:1), and heights are untouched everywhere,
which is why no mm changes (below).

### 2. `PuzzleCamera.hudPlace` (`camera.dart`, 94 → 197 lines)

`static ({Rect rect, HudForm form}) hudPlace(SplitLayout layout, PuzzleCamera camera, Size box)` is pure —
it reads the layout, the camera and the box and returns the clock area's rect in px plus which form it
takes; new public `enum HudForm { oneLine, twoLines, corner }`. Every constant is named, with its unit and
the reason for its value:

| constant | value | unit | why |
| --- | --- | --- | --- |
| `hudTopFraction` | 0.14 | of the box height | 55.02 px at 393, just below the phone app's 52 px top bar (§0.7b) |
| `hudClockFraction` | 0.08 | of the box height | the clock is the one thing read from across the room |
| `hudScoreFraction` | 0.04 | of the box height | half the clock: a readable subtitle |
| `hudLineGapFraction` | 0.02 | of the box height | half the score's height, so lines read apart at any size |
| `hudBarFraction` | 0.012 | of the box height | 4.7 px at 393: as thin as a text stroke |
| `hudOneLineHeight` | 0.112 | of the box height | clock + gap + bar |
| `hudTwoLineHeight` | 0.172 | of the box height | clock + gap + score + gap + bar |
| `hudOneLineWidth` | 0.62 | of the box height | 5 clock chars at 0.08 + gap + 20 score chars at 0.04, each glyph 0.5 em |
| `hudTwoLineWidth` | 0.4 | of the box height | the longest score ("Left 2/4 · Right 3/6", 20 chars) at 0.04 |
| `_glyphEm` | 0.5 | character width ÷ text height | the app's font draws most glyphs narrower, so a form picked by it is never too small; the test font's square glyphs are wider |
| `_clockChars` / `_scoreChars` | 5 / 20 | characters | "10:00" (a 10 minute limit) and the longest score today |
| `hudMarginPx` | 8 | px | from the box's left edge: clear of the screen's rounded corner |
| `hudWorldGapPx` | 8 | px | from the clock area to the world: clear of the board |
| `hudCornerMarginPx` | 8 | px | from the board's top-left corner in the fallback form |

The rule: `spare = world.origin.dx − hudMarginPx − hudWorldGapPx` (the width left of the world), `top =
0.14 × box.height`; one line when `spare ≥ 0.62 × height`, two lines when `spare ≥ 0.4 × height`, otherwise
over the board's top-left corner (`board.left + 8`, `board.top + 8`, `min(0.4 × height, board.width − 16)`
wide). The `whole` camera asks for the left world's placement, so the HUD sits left of everything drawn —
side by side or stacked.

Forms at seed 1 (the `side` camera, except the `whole` row), all four puzzles, the boxes the brief names:

| box | house | rocket | tree | boat |
| --- | --- | --- | --- | --- |
| 852 × 393 | twoLines | twoLines | **oneLine** | corner |
| 667 × 375 | corner | corner | **twoLines** | corner |
| 1024 × 768, `whole` | twoLines | corner | twoLines | corner |

The HUD's px rects the brief asks for (seed 1; the rect is the same solo and race, because the layout
depends on the puzzle and seed, not on the match):

| box | tree, solo | house, race |
| --- | --- | --- |
| 852 × 393 | oneLine (8.0, 55.0) – (251.7, 99.0) | twoLines (8.0, 55.0) – (165.2, 122.6) |
| 667 × 375 | twoLines (8.0, 52.5) – (158.0, 117.0) | corner (214.4, 111.8) – (364.4, 176.3) |

The house's corner rect starts 8 px inside the board's top-left, and the board on the SE is
254.2 × 262.7 px at (206.4, 103.8), so the panel covers the board's top-left corner as §0.7c says.

### 3. The HUD is drawn in screen space (`match_painter.dart`, 254 → 286; `view.dart`, 75 → 84)

- `_phones` draws each world as before, then calls `_hud(canvas, size, layout)` — screen space, after the
  worlds, so the HUD is never scaled or clipped by a world.
- `_hud` asks `hudPlace`, draws the translucent panel (`_hudPanel`, `0x8C000000`, an `RRect` inflated by the
  line gap) in the corner form only, then `_hudTexts`, then the bar:
  `Rect.fromLTWH(rect.left, rect.bottom − bar, rect.width × frac, bar)` in `_right` (`0xFF43D17A`) — or
  `_wrong` (`0xFFE53935`) while `warning && phase == playing`. `frac` is the same `timeLeftMs / limit` the
  strip uses; no bar without a time limit.
- `_hudTexts` draws one line as a single `TextPainter` with two spans (clock bold at 0.08, `' ' + score` at
  0.04, centred on `top + (clock + gap) / 2`), or the clock above the score (two left-aligned `_text`s at
  `top + clock/2` and `top + clock + gap + score/2`). The clock is white in the HUD in both states: §0.7c
  gives the warning to the bar (the screen's strip keeps its red clock, untouched).
- `phoneHud(s, side)` keeps returning texts, in the format the tests can pin:
  `({String clock, String score})`. One board: `'0 of 4 placed'`. A race with a side: `'You 2/4 · Right
  3/6'` (the camera's side first, the other side named). A race drawn `whole`: `'Left 2/4 · Right 3/6'`
  from one HUD — `side == null` is the whole match. Its old shape, `({clock, own, other})` with a `whole:`
  flag, is gone; no caller outside `view_test` used it.
- `_right` moved from `puzzle_painter.dart` to a library-level constant in `view.dart` (both painters use
  it); `puzzle_painter.dart` 258 → 257 for that line.

### 4. The screen layout is unchanged

`_computeScreen` is untouched (still 120 lines, still `hudStrip`/`trayBelow` as s7c), `PuzzleCamera.place`
and `fieldIn` are untouched, and the screen still ignores the camera: `view_test`'s "the screen ignores the
camera" compares `whole` and `side(right)` at 960×540 and finds a difference of 0.0. The only change
`LayoutTarget` brings to the screen path is that a screen layout now says so (`target == screen`) instead
of having a null `hud`.

## Tests

| check | before | after |
| --- | --- | --- |
| `format` | PASS | PASS |
| `analyze` | PASS | PASS |
| `puzzle` | 101 tests | **106 tests** |
| `host` | 76 tests | 76 tests |
| `phone` | 329 tests | 329 tests |

Per file: `camera_test` 8 → 12, `view_test` 10 → 11, `split_layout_test` 11 → 11.

- **`split_layout_test`** — the phones rules test keeps its checks on the world (board and tray inside it,
  tray on top at the left margin, board the crop and centred) and drops the clock-area ones; it now asserts
  `layout.target == LayoutTarget.phones`, `field.trayOverlap == 0`, `field.tray.width >= crop.width`,
  `packTray` at the tray's width overflowing nothing and making one row, and — per the brief's new rule —
  that the pieces' boxes, sorted by x, each start at least `trayGap` after the previous one ends and none
  overlap. The height per puzzle is unchanged from s7c (the print test still prints it and the mm).
- **`camera_test`** — four new tests in "the clock area beside the world":
  - 852×393, tree: `oneLine`, top `55.02` (0.14 × 393), left `8`, width `243.66` (0.62 × 393), height
    `44.02` (0.112 × 393), the world at `268.76` and the HUD's right edge at least `hudWorldGapPx` short of it.
  - 667×375, tree: `twoLines`, top `52.5`, width `150` (0.4 × 375), height `64.5` (0.172 × 375), world
    `183.46`, and the width below the one-line width's need.
  - 380×375, tree: `corner`, 8 px inside the board's top-left, inside the board's other edges.
  - 1024×768, `whole`: `twoLines` left of both worlds, which are stacked (same x, the right one lower).
- **`view_test`** — the HUD texts solo (`'0 of 4 placed'`), race (`'You 0/4 · Right 2/4'` and
  `'You 2/4 · Left 0/4'`) and whole (`'Left 0/4 · Right 2/4'`); the picture test now draws a phones match at
  **both** 852×393 and 667×375, for all three cameras, and checks no exception and a non-blank picture; and
  a new test draws the house's HUD and reads the bar's pixel: `0x43D17A` with time left, `0xE53935` with a
  10 s limit (inside `warningS` 15). The screen-ignores-the-camera check is unchanged and still passes.
- **`controller_app/test/puzzle_size_test.dart`** — untouched and passing. **No mm changed** (old = new):
  667×375 house sun 9.42, rocket window 8.99, tree sun 9.34, boat flag 10.35; 734×372 9.34 / 8.91 / 9.26 /
  10.27. The phone's height still decides the fit on every phone screen in that table: the tightest box
  (667×375, 1.78:1) is still wider than every world (0.80 to 1.51:1), and the heights are unchanged, so
  `PuzzleCamera.scale` gives the same px/unit as s7c. No case changed; the widths changed but never bind.

### Changed expected values, old → new

| file | old | new |
| --- | --- | --- |
| `split_layout_test` | `layout.hud!` and the five clock-area assertions (the tray ends before the HUD, `hud.width == SplitLayout.hudWidth`, `hud.right == size.width − margin`, `tray.width <= size.width − hudWidth − 2m`, no piece in `hud`) | those removed; `layout.target == phones`, `trayOverlap == 0`, `tray.width >= crop.width`, boxes `>= trayGap` apart and not overlapping |
| `split_layout_test` | test name "…with the clock area beside it…" | "…with piece beside piece…" |
| `camera_test` | `expect(layout.hud, isNull, reason: 'a screen layout has no phone clock area')` | `expect(layout.target, LayoutTarget.screen, reason: 'a screen layout is not a phone one')` |
| `camera_test` | `import 'dart:ui' show Size` | `show Rect, Size` |
| `view_test` | `phoneHud(s, left, whole: false)` = (clock `'1:05'`, own `'You 0/4'`, other `'Right 2/4'`) | `phoneHud(s, left)` = (clock `'1:05'`, score `'You 0/4 · Right 2/4'`) |
| `view_test` | `phoneHud(s, right, whole: false)` = (own `'You 2/4'`, other `'Left 0/4'`) | `phoneHud(s, right)` = (score `'You 2/4 · Left 0/4'`) |
| `view_test` | `phoneHud(s, left, whole: true)` = (own `'Left 0/4'`, other null) and `phoneHud(s, right, whole: true)` = (own `'Right 2/4'`) | `phoneHud(s, null)` = (score `'Left 0/4 · Right 2/4'`); the per-side whole case is gone, one HUD per match |
| `view_test` | one board: `phoneHud(s, left, whole: false)` = (own `'You 0/4'`, other null); `whole: true` = (own `'0/4'`) | `phoneHud(s, left)` and `phoneHud(s, null)` both = (score `'0 of 4 placed'`) |
| `view_test` | the phones picture test drew one box, 667×375 | it draws 852×393 and 667×375 |
| `split_layout_test` print | world 90.88 / 89.19 / 91.06 / 111.59 wide | 84.46 / 85.90 / 81.62 / 121.63 (the printed assertions are unchanged; only the line's numbers move) |

Nothing else in the repo expected a value that moved: `controller_app/test/puzzle_size_test.dart`,
`phone_tray_reach_test.dart`, `tray_packing_test.dart`, `tray_pile_test.dart` and the host's tests all pass
untouched.

## Line counts (changed files)

| file | before | after | |
| --- | --- | --- | --- |
| `lib/src/split_layout.dart` | 385 | **382** | over 300 (pre-existing NOTE); did not grow |
| `lib/src/camera.dart` | 94 | **197** | |
| `lib/src/match_painter.dart` | 254 | **286** | |
| `lib/src/view.dart` | 75 | **84** | |
| `lib/src/puzzle_painter.dart` | 258 | **257** | |
| `test/split_layout_test.dart` | 421 | **410** | over 300 (pre-existing), under 500 |
| `test/camera_test.dart` | 130 | **208** | |
| `test/view_test.dart` | 364 | **395** | over 300 (pre-existing), under 500 |

No lib file is over 400 and no test file over 500.

## Checks run

- `tools/check.sh format analyze puzzle host phone`:
  `PASS format (1s)`, `PASS analyze (4s)`, `PASS puzzle (106 tests, 12s)`, `PASS host (76 tests, 11s)`,
  `PASS phone (329 tests, 17s)`, "All checks passed (48s)".
- `tools/review.sh`: `1 fail, 1 note` — the FAIL is the pre-existing `_computeScreen` 120 lines
  (`split_layout.dart:135`, was FAILing at HEAD too, see `bug-1107-fix-report.md`), the NOTE is
  `split_layout.dart` 382 lines. Nothing on the lines I added.
- The HUD's drawing was also checked by pixel: the new `view_test` test reads `0x43D17A` and `0xE53935` out
  of the bar, and a throwaway probe counted 624 green and 5,778 white pixels inside the 852×393 house HUD
  rect before the test was written.
- `git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
  `generated_plugins.cmake` as modified; their content diff is empty (line endings only) and this job did not
  touch them.

## Questions

1. **The corner form happens on real phones, and the contract says it shouldn't.** §0.7c: "If the spare
   width is too narrow even for two lines (no phone today), the HUD draws over the board's top-left corner"
   and "two lines … as on the iPhone SE". Measured at seed 1 (table above): at 667×375 the house, rocket and
   boat take the corner; at 852×393 the boat does. The spare width is the box's width minus the world's, and
   the world's width is set by its height: the boat's SE world is 566 px of 667, leaving 34 px. The house
   (139 px spare) and rocket (115 px) are short of my 150 px two-line width; a real font draws the score at
   ~135 px, so the house is borderline and the rocket genuinely doesn't fit. Options: (a) accept the corner
   on the narrow phones as §0.7c's rule playing out, (b) let the HUD overlap the world's left edge instead
   of the corner (draw it on a panel over the board's left), (c) shrink the score to 0.03 of the height on
   boxes under ~1.8:1. I implemented (a) as written.
2. **`HudForm` is a second public type in `camera.dart`,** next to the camera itself, because `hudPlace`'s
   record needs it. Fine, or should it live in `view.dart`/`match_painter.dart`?
3. **`_glyphEm` 0.5 is an estimate of the app's font.** A score longer than 20 characters ("You 10/12 ·
   Right 10/12") would overflow the rect rather than step down a form, and the painter doesn't clip. Worth a
   follow-up if puzzles with more than 9 pieces reach phones.
4. **The whole match's clock** is the left board's `timeLeftMs` (`phoneHud`'s `board`), which is what the
   board panel uses; in a race both boards count down together, so this is only a label. Confirm?
5. **The clock is white in the HUD while warning** — only the bar turns red, as §0.7c says. The screen's
   strip still turns its clock red. Change it for consistency?

## Suggestions

- Pin the form for all four puzzles at both phone sizes in `camera_test` (a four-row table as above), so a
  change to the fractions or a puzzle's world shows up as a form change rather than a silently wider HUD.

## Commit message

m12 s7e: the phone clock beside the board, no overlap in the tray row

Phones worlds reserve no clock column: width = max(board, tray row) + margins,
the row packs with trayOverlap 0 and heights are unchanged, so no mm moves.
PuzzleCamera.hudPlace picks one line, two lines or the board's corner from
§0.7c's fractions of the box height, all named with their units.
The HUD is painted in screen space after the world: clock, score and the
green time bar, red while the clock warns; solo, race and whole texts.
SplitLayout.hud is gone; LayoutTarget says which world a layout is.

## Status row

| 7 Puzzle on phones | s7e G4 done ([s7e-report.md](s7e-report.md)): §0.7c — the phones world reserves no clock column (width `max(board, tray row) + margins`, the row packs with `trayOverlap` 0, heights unchanged so no mm moves), `PuzzleCamera.hudPlace` picks one line, two lines or the board's corner from named fractional constants, and the HUD is painted in screen space after the world (clock, score, green bar, red while warning; "0 of 4 placed", "You 2/4 · Right 3/6", whole "Left 2/4 · Right 3/6"); `SplitLayout.hud` is gone and `LayoutTarget` says which world a layout is; puzzle 101 → 106. Open: the corner form lands on the SE for house, rocket and boat (Q1) |

## Delete

- packages/puzzle_game/test/s7e_numbers_test.dart
