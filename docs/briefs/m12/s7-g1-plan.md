# M12 step 7 G1 — plan: the puzzle on phones

Read-only plan; the only file changed is this report. `file:a–b` is a pre-split line range in today's file.

## 1. Splits first (pure moves, no text change)

### `game.dart` 732 → ≈331
- `lib/src/puzzle_values.dart` (new, plain file): 11–123 — `PieceState`, `PuzzleEventKind`, `PuzzleEvent`, `PieceRuntime`, `PuzzlePlayer`, `PuzzleResult`, `PuzzlePhase` (113 lines). Imports `dart:ui`.
- `lib/src/start_angles.dart` (new, plain file): `startAngles` 665–681 and `compactStartAngles` 683–730 (66). Imports `dart:math`, `puzzle.dart`.
- `part 'puzzle_carry.dart'` (new part): 410–488 — `_teamCarried`, `_move`, `_inField`, `_carryBig`, `_turn` (80).
- `part 'puzzle_drop.dart'` (new part): 490–631 — `_pickUp`, `_drop`, `_letGo`, `_putEverythingDown`, `_putDown`, `_matchingTarget`, `_nearestFreeTarget`, plus `_round` (732) (144).
- Stays: imports 1–9 and `PuzzleGame` 125–408 (doc and ctor, fields, `placed`/`player`/`players`/`team`/`result`, `_layOutTray` 194–217, `_trayLayout` 219–279, `_startFor` 281–285, join/leave/stop 287–301, `update` 303–408) with `snapshot` 633–663 (≈331). Parts use game.dart's imports (`dart:math`, `dart:ui`, connection, puzzle, settings, snapshot, tray).
- Imports: `match.dart`, `snapshot.dart`, `view.dart` and `puzzle_events.dart` add `import 'puzzle_values.dart';`; `split_layout.dart` swaps `game.dart` for `start_angles.dart`; `puzzle_game.dart` exports both new files.
- Parts for the two member groups because they write `pieces`, `_players`, `_filled`, `_nextLayer`: a plain file needs a public API change, a part is a pure move (`protocol/lib/src/messages.dart` does the same; Q6).

### `view.dart` 439 → ≈65
- `part 'puzzle_painter.dart'`: `PuzzlePainter` 184–415 plus the top-level `_text` 417–439 (255).
- `part 'match_painter.dart'`: `MatchPainter` 63–182 (120).
- Stays: imports 1–9, `PuzzleView` 11–30, `MatchView` 32–50, `fieldIn` 52–58, `_background`/`_wrong` 60–61, the two part directives (≈65). s7c adds `lib/src/camera.dart` (plain): `PuzzleCamera` + `scale`.

### `match_test.dart` 1074 — split it
s7b's `phones` cases belong in its `split layout` group, so the file step 7 adds to would pass 500.
- `test/match_helpers.dart` (new, no `_test`, not run): 1–133 — `load`, the `GamepadState` consts, `begin`, `drive`, `tap`, `tapAGame`, `place`, `onePiece`, `crateAndBall`, `twoSquares`, `scaledBounds`, `pieceBox`, `rows`, `visibleFraction`.
- `test/tray_packing_test.dart`: `compact start angles` 215–262 + `tray packing` 263–324 (≈110).
- `test/tray_pile_test.dart`: `tray pile` 542–683 + `tray size in play` 684–728 (≈187).
- `test/split_layout_test.dart`: `split layout` 325–541 (≈217); s7b/s7c add here.
- `match_test.dart` keeps `formats` 134–214, `sides` 729–840, `big pieces` 841–1013, `snapshots` 1014–1074 (≈442). The 31 tests stay 31; s7a's proof is `tools/review.sh --strings` 0/0 and unchanged counts.

## 2. The `phones` world

- `enum LayoutTarget { screen, phones }` in `split_layout.dart`; `SplitLayout.of(puzzle, seed, {LayoutTarget target = LayoutTarget.screen})`, memoised as `Expando<Map<(int, LayoutTarget), SplitLayout>>` (`_keep` 8 unchanged). `_compute` 92–211 becomes `_computeScreen` verbatim; `_computePhones` is new.
- `_computePhones`: angles = `compactStartAngles(puzzle, Random(seed), flat: true)` (a top tray packs in rows like a tray below); board = `boardRect` (80×72, not `_crop`) with `origin = board.center - crop.center`, so the picture is centred (the screen world uses `board.topLeft - crop.topLeft`).
- Width: for `w` from the widest scaled piece + 4 upward in 1-unit steps, `trayH = packTray(puzzle, angles, w, overlap: 0.5, scale: 0.75).height`, `H = hudStrip(6) + trayH + gap(4) + 72 + margin(2) = 84 + trayH`; the first `w ≥ 2H` wins (`_phoneSideAspect = 2.0`); the world is `(w, w/2)` and the spare height stays in the bottom margin.
- Both sides get the same world and angles. `PuzzleField`: `tray = Rect(0, 6, W, trayH)` (across the width), board centred under it, `top = hudStrip` (dots stay out of the strip), `startX = board.left + 6`, `trayOverlap` 0.5, `trayScale` 0.75. No member changes meaning; the values do (`board` is the standard 80×72 instead of the crop, `tray` is on top instead of beside/below).
- `SplitLayout.scale`, `leftBox`, `rightBox`, `hudStrip` and `trayBelow` have no screen meaning for `phones`: plan `scale = 1`, both boxes = the world at 1:1, `hudStrip = true`, `trayBelow = false`, all documented as screen-only (Q5). `PuzzleCamera.scale` fits the world to the real box: `side` = one world bottom-aligned; `whole` = the two worlds side by side above 3:1, else stacked with the left on top, one strip.
- `PuzzleMatch` takes the target and calls `SplitLayout.of(puzzle, seed, target:)` for **every** format, so a solo/team match gets `layout.left` and a split one `layout.left`/`right` + `angles`. `snapshot()` must then send `seed` whenever a layout exists: a solo `phones` match needs it in the frame (version stays 1 — Q4).
- Solo (§0.5) = one side, tray on top, board below, all shown: the viewer draws `PuzzlePainter(puzzle, board, field: layout.left)`. The strip is the world's top 6 units, drawn by the side/whole camera: clock, this side's count, the other's ("Right 3/6"), the time bar.

## 3. The rules: start-time tray packing

- `packTray` needs no change: it already takes a tray *width*, packs tallest-first in rows from the left with 2-unit edge gaps and 0.5 overlap, and returns each box's top-left (relative to the tray), the order and the height used. Only the inputs change: a wide, short tray rect.
- `_trayLayout` 224–279 already takes the `packTray` branch (`trayOverlap > 0`, `trayScale < 1`) and adds `tray.topLeft` after subtracting the scaled box's top-left — right for a tray anywhere, so a top tray works as is. `overflow = packed.height - tray.height` is 0 by construction (the layout sized the tray with the same angles, width and packing).
- `_layOutTray`'s 60-attempt retry runs only without `angles`; a `phones` layout always supplies them, so a match lays out once. With a 214-unit tray each puzzle's row is ≤ 96 units, so one row: pieces at the tray's left, about half the tray empty (Q2). `_startFor` and `_inField` need no change.

## 4. The arithmetic

Formula, once: `trayH = 2 + 0.75 × (tallest start-angle box height) + 2`; `H = 84 + trayH`; `W = 2H`; `scale = min(boxW / W, boxH / (W / 2))` — a 2:1 world is wider than both boxes, so the 667×375 box (1.78:1) is width-limited (`667 / W`, 41.5 px spare on top) and the 852×393 box (2.17:1) height-limited (`393 / (W / 2) = 786 / W`, 66 px spare split at the sides); `px = diameter × scale`; `mm = px / 6.29921` (`phonePxPerMm = 160 / 25.4`). Both boxes are whole screens (§0.7).

| puzzle | trayH | side world (units) | smallest piece (diameter) | SE px/unit | SE px, mm | 852 px/unit | 852 px, mm |
| --- | --- | --- | --- | --- | --- | --- | --- |
| house (easy) | 22.82 | 214 × 107 | sun, 14.0 | 3.1168 | 43.6, **6.93 mm** | 3.6729 | 51.4, **8.16 mm** |
| rocket (easy) | 14.50 | 197 × 98.5 | window, 8.0 | 3.3858 | 27.1, **4.30 mm** | 3.9898 | 31.9, **5.07 mm** |
| tree (easy) | 25.00 | 218 × 109 | sun, 16.0 | 3.0596 | 49.0, **7.77 mm** | 3.6055 | 57.7, **9.16 mm** |
| boat (medium) | 24.37 | 217 × 108.5 | flag, 14.0 | 3.0737 | 43.0, **6.83 mm** | 3.6221 | 50.7, **8.05 mm** |

**Under 9 mm (Easy/Medium): all four on the SE; on 852×393 only house, rocket and boat.** Seed spread: the roof's start angle ranges over 30–46° and the hull's over 30–36°, so their worlds are 214–217 and 217–221 units and every mm value moves by ≤ 0.15. Rocket and tree are fixed (their tallest tray pieces are not turned; the tree's crown, a circle, always beats its mountain).
**9 mm cannot be met on the SE with §1's world:** it needs 56.69 px, so the world must be ≤ 164.7 units wide for a 14-unit piece (≤ 188.2 for tree's 16, ≤ 94.1 for rocket's 8), and a 2:1 side world is at least `2 × (6 + 4 + 72 + 2) = 168` wide even with no tray at all. Sensitivity: with the crop board instead of 80×72 the worlds are 171–216 wide and the values rise to house 7.64 / 9.01 mm, rocket 4.95 / 5.84, tree 7.84 / 9.24, boat 7.60 / 8.96 — still every SE failure.

## 5. Order of work

**s7a — the splits, as pure moves.** No test changes; proof `tools/review.sh --strings` 0/0 and the same 31/7/3/24 counts; `dart format`, `flutter analyze`.
**s7b — §1, the setup key, the host's choice.** In `split_layout_test.dart`, every puzzle and 20 seeds: world aspect 2.0 (±1e-9), strip 6 at the top, tray above the board across the width, board 80×72, `packTray` at `field.tray.width` fits (`overflow ≤ 0`), pieces start in the tray, outlines on the board, both sides identical, memoised per (puzzle, seed, target), `of(p, s)` ≠ `of(p, s, target: phones)`. In `match_test.dart`'s new home: a `phones` match places every piece as `packTray` at the field's width on both sides; a solo `phones` match uses `layout.left` and its snapshot carries `sd`. In `puzzle_module_test.dart`: `shapeRaceSetup` adds `layout: 'phones'` only when the host shares its view; `createViewer` accepts it, a missing key means `screen`, a bad value throws a `FormatException` naming the key. No snapshot version change.
**s7c — §2–§5.** New `camera_test.dart`: `side` fitted and bottom-aligned (667×375 → 3.1168 for house, 852×393 → 3.6729), `whole` side by side above 3:1 else stacked, `screen` = today's `fieldIn` (4.167 on 667×375). `view_test.dart`/`puzzle_module_test.dart` at 667×375 and 852×393: the viewer picks `side`/`whole` from `playerId`, `wholeMatch` and the target. `party_host`: `ownPlayerIdProvider` and the host phone's own view. `arena_view_test.dart`: 667×375 and 852×393, no overflow. `controller_app/test/puzzle_size_test.dart`: §4's table printed, Easy/Medium under `minPieceMm` fail, no Hard puzzle prints "no Hard puzzle".
**Existing expectations that change: none for `screen`** — `match_test`'s split-layout numbers (scale ≥ 0.85, boxes 79/81 and 74/86, gaps 2/12), `view_test`'s picture comparisons at 1280×720 and 960×540, `puzzle_module_test`'s `MatchView`, `snapshot_lerp_test`, `frame_size_test`. Every addition is an optional parameter (`SplitLayout.of` target, `PuzzleMatch` target, `MatchView`/`MatchPainter` target and camera) defaulting to today's behaviour; the memo key goes from `seed` to `(seed, target)` with the same identity behaviour.

## 6. Conflicts and questions

1. **9 mm is unreachable on the SE** (§4): no top-tray 2:1 world can pass for any of the four puzzles, and today's whole-field split already gives the house's sun 7.9 mm. May the check fail (and the contract record it), or does the world need another shape? A tray-beside world of about 116 × 82 units would give the house's sun 10.2 mm; a smaller board or a cropping camera also helps.
2. The 214-unit world leaves about half the tray empty (one row of ≤ 96 units). Intended, or should the width be the content width (world then narrower than 2:1, pieces bigger)?
3. Board 80×72 (which §1 says) or the crop? I used 80×72; the sensitivity line in §4 has the crop's numbers.
4. A solo `phones` match needs `seed` in a one-board `MatchSnapshot` (an additive key; version 1). Confirm.
5. `SplitLayout.scale`/`leftBox`/`rightBox`/`hudStrip`/`trayBelow` for `phones`: my placeholder values are in §2; nullable fields would be cleaner but a wider change.
6. Parts in `game.dart` (private state) and `view.dart` (private `_text`, colours): project-notes prefers plain files for host-screen widgets. OK?
7. Tray at 0.75 and 0.5 overlap in the phones world: at full size the house's world widens to 226 and its sun drops to 6.6 mm.
8. Strip height: `SplitLayout.stripHeight` 6, not `puzzle.dart`'s `hudHeight` 10.
9. The `match_test.dart` split into four files and the `test/match_helpers.dart` name.
10. A top tray's angles: `compactStartAngles(flat: true)`.

Checks: none to run — this is a read-only plan with no code; the report is the deliverable.

## Commit message

```
docs(m12): plan the puzzle's phone layout, splits and sizes

Split maps for game.dart (732, to puzzle_values and start_angles plus
the puzzle_carry and puzzle_drop parts), view.dart (439, to the
puzzle_painter and match_painter parts) and match_test.dart (1074,
to helpers and three test files). The phones world as two identical
2:1 side worlds, 214/197/218/217 units wide, and the arithmetic for
the smallest piece: 6.93/4.30/7.77/6.83 mm on the SE, so every
Easy/Medium puzzle misses 9 mm there. packTray needs no change.
Open: ten questions, the 9 mm floor above all.
```

## Status row

| 7 Puzzle on phones | G1 plan done ([s7-g1-plan.md](s7-g1-plan.md)): the splits of `game.dart`, `view.dart` and `match_test.dart` are named, the `phones` world is two identical 2:1 side worlds (tray across the top, board 80×72 below), the tray packing needs no change; smallest piece 6.93/4.30/7.77/6.83 mm on the SE, so every Easy/Medium puzzle misses 9 mm there. Open: Claude's answers to the ten questions, then s7a |

## Delete

- none
