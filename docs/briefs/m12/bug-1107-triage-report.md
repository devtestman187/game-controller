# M12 bug triage — 1107: the dot can't reach the tray in a phone-hosted Shape Race

Read-only triage, no fix. Read: the ten `puzzle_game` sources the brief names plus `tray.dart` (the packing, not on
its list), `split_layout_test.dart`, `docs/design/m12-phone-layout.md` §1, `s7-g1-plan.md` §2,
`s7b-g3-report.md`, `docs/coding-guidelines.md` and the owner's screenshot (`bug1-shot.png`: dot 1's top edge on the
board panel's top edge, the four pieces piled at the tray's left, "1:31 / You 0/4" at its right end). One check was
run, read-only: `flutter test test/split_layout_test.dart --plain-name "prints every puzzle's phone world and its
smallest piece at two phone sizes"` → tree 91.06 × 102.00. The checkout's puzzle code is the m12.3 one (s7b–s7d in).

## Numbers — the tree at seed 1, `LayoutTarget.phones`, world units

| what | value | where |
| --- | --- | --- |
| world | 91.06 × 102.00 = max(70 + 4, 47.06 + 40 + 4) × (2 + 25 + 2 + 71 + 2) | print test, `_phoneWorld` |
| crop = board | 70 × 71 at (10.53, 29) → bottom 100 | `_crop`, `split_layout.dart:287` |
| tray | (2, 2) 47.06 × 25 → bottom **27**, right 49.06 | `:291` |
| tray height | trayGap 2 + 0.75 × 28 (the crown is the tallest box) + trayGap 2 = 25 | `_packedTray` |
| HUD | (49.06, 2) 40 × 25 | `:308` |
| row | all four boxes' tops at y = **4**, right edge 45.06 = 47.06 − trayGap | `tray.dart:49` |
| crown (first in the row) | box 21 × 21 at (4, 4) → centre **(14.5, 14.5)** | — |
| `field.top` | margin + tray.height = **27** | `split_layout.dart:294` |
| dot's lowest centre | top + dotRadius 2.6 = **29.6** → its top edge on 27, the tray's bottom | `puzzle_carry.dart:21` |
| dot's start | (16.53, 64.5) = board.left + 6, board centre | `:295`, `game.dart:209` |

## Bug 1 — the dot stops on the board's top edge and cannot enter the tray

**Cause** `PuzzleField.top = margin + tray.height` (`split_layout.dart:294`) and the clamp
`at.dy.clamp(field.top + margin, …)` in `_inField` (`puzzle_carry.dart:19-22`, `dotRadius` at `game.dart:262`).
Tree, seed 1: top 27 → the dot's centre stops at 29.6, its edge on y = 27 (the tray's bottom, 2 above the board's
top 29) — "only to the edge of the box"; only y is clamped (`startX` 16.53 and the rects are not it), so the dot
slides along the whole row (x 2.6…88.46) and stays 15.1 from the crown's centre.
A split `phones` match: the same (one field for both sides, `:300-301`; a solo/team one plays `layout.left`, so a
`whole` camera only moves the drawing); `screen`'s `top: 0` is why the TV's dot enters its tray.
**Confidence** sure (code path, arithmetic, and the screenshot's dot at this y).
**Fix** `split_layout.dart:294` → `top: margin`, in `_computePhones` only. Nothing else reads `top` on phones
(`_startFor`'s `top + 6` → 8, the start y 64.5 unchanged; the painter's `field.top − 1.2` bar is `hud: false`
there); `puzzle.dart:43`'s doc for `top` needs the phones sentence.
**Test** (fails now) the tree at seed 1 in a phones game (`SplitLayout.of(tree, 1, target: LayoutTarget.phones)`'s
field and angles): hold the stick up 2 s, `expect(player.pos.dy, lessThanOrEqualTo(27.0))` (29.6 today), then A
takes a piece — `held != null`, its drawn shape contains the dot (`scale: field.trayScale`).
**Risk** the dot may stand over the HUD area and the world's top margin (cosmetic); a carried full-size piece is
clipped at the world's top while its dot is deep in the tray (the crown at y 4.6 reaches y −9.4); `_carryBig`'s
`_inField(piece.pos, 0)` lets a team-carried big piece's centre reach y = 2. The screen layout, world sizes and
mm values are untouched, so `puzzle_size_test` is unaffected. ("unsure": the clipping, Q3.)

## Bug 2 — A takes a piece by centre distance, so a piece "appears randomly"

**Cause** `_pickUp` (`puzzle_drop.dart:4-54`): it keeps the pieces whose *centre* is within `dotRadius + radius ×
trayScale × pickupRange` (`:14`) and takes the top-layer one whose drawn shape contains the dot (`:17-23`), then
falls back to the nearest *centre* (`:24-33`). The dot can never be inside a tray piece (Bug 1: its edge stops on
27, the crown's bottom is 25), so `contains` never runs and the centre fallback always decides — the piece comes out
of the pile from 13+ units away, not from under the dot. Tree, seed 1, `pickupRange` 1: crown 15.1 away vs a 13.1
reach (2.6 + 14 × 0.75) → **nothing** is pickable; mountain 17.0 vs 15.5, sun 19.6 vs 8.6, trunk 22.6 vs 10.0. The
crown needs `pickupRange` ≥ 1.19, the mountain ≥ 1.12, the sun 2.83 and the trunk 2.71 (above the 2.0 maximum, so
never from the edge). Above ~1.2 the crown and mountain trade places with the dot's x (their centres 2 units apart
under overlapping boxes): the "random" piece.
**Confidence** sure for the geometry, the reaches and "A does nothing at 1.0" (which fits the screenshot's 0/4 after
29 s); likely that the owner's host holds a saved `pickupRange` above 1.12 (the host's saved playtest settings feed
the round, `providers.dart:299`, 1.25 steps) — "unsure" which value (Q1).
**Fix** Bug 1's, and no change to `_pickUp`: with the dot over the row, `contains` decides and the top layer under it
wins (the rule `tray_pile_test.dart:114` already pins); the centre fallback stays for the gap beside a piece.
**Test** Bug 1's second half, plus a sweep: for each of the four tray pieces, a point inside the tray that the
clamped dot can stand on where A takes *that* piece — fails for all four today.
**Risk** pickups get easier on phones only; in an overlap the pile's top layer decides, which is "the piece under
the dot".

## Bug 3 — the tray's pieces are drawn on top of each other

**Cause** by design, not a bug. Contract §1 asks for one row at `trayScale` 0.75 with 0.5 overlap
(`split_layout.dart:114-115`): the crown (21 wide) puts the mountain at half its width (10.5), and `packTray` only
reduces an overlap when it would leave a piece under 55% visible (`tray.dart:98-107`), so the rest stay at 0.5 and
the row ends at 45.06 — the extra 5 units over a naive 0.5 sum is where an overlap was reduced.
The tray is **not** narrower than its row: 47.06 = 45.06 + trayGap, and the pieces span 4…47.06 inside 2…49.06.
The drawing is at the packing's scale and positions: `_piece` uses `field.trayScale` for `PieceState.tray`
(`puzzle_painter.dart:119`) at the snapshot's positions, and `split_layout_test.dart`'s phones tests assert
`packTray` at the tray's width gives these positions for 4 puzzles × 20 seeds and that every box sits in the tray
and out of the HUD. The screenshot agrees: the crown's 21-unit diameter is ~30% of the board's 70, the pile is
inside the panel, and the trunk (last, top layer) lies over the sun.
**Confidence** sure for "packed and drawn as the design asks"; "likely" for reading the screenshot's pixel sizes
(±15% by eye).
**Fix** none. It shares Bug 2's sting only because the picked piece is not the visible top one.
**Test** none new; the existing phones packing test covers it (`split_layout_test.dart:241-341`).
**Risk** none.

## Files changed

- `docs/briefs/m12/bug-1107-triage-report.md` — new: this triage.

## Checks

- `flutter test test/split_layout_test.dart --plain-name "prints every puzzle's phone world …"` — PASS (1 test):
  house 90.88 × 88.50, rocket 89.19 × 79.50, tree 91.06 × 102.00, boat 111.59 × 80.52 (units).
- No other check: the brief's only `check:` is this report.

## Questions

1. What is the host phone's saved `pickupRange` (Settings → playtest settings)? At the default 1.0 A takes nothing
   from the tray at all; the owner's "a piece appears randomly" needs ≥ 1.12 (mountain) / 1.19 (crown).
2. Was the "piece appears" with the dot on the board's top edge, or elsewhere on the board?
3. After the fix the dot may stand over the HUD area and over the world's top margin, and a carried full-size
   piece is clipped at the world's top. Accept, bound the dot to the tray row, or something else?
4. Should the fix be tagged as a bug fix for build 180 alone (one value + one test), or bundled with the
   `packTray`/`_computeScreen` size debt?

## Suggestions (not acted on)

- A stopgap if the phone game must be playable before the layout change: add the packing's `trayGap` to the reach
  for tray pieces (`puzzle_drop.dart:14`), which makes the crown reachable from the edge — but it still isn't what
  the owner asked for ("move the dot into the tray"), and the sun and trunk stay out of reach.
- A row-wide reach test for all four puzzles, so a future tray height or gap change can't make a piece unpickable
  again.
- The pile makes "the piece under the dot" hard to see; a highlight on the piece A would take would help the look
  milestone, not this fix.

## Commit message

```
docs(m12): triage the phone Shape Race's unreachable tray

The phones world's top (margin + tray height = 27 for the tree at
seed 1) plus _inField's clamp stop the dot's edge on the tray's
bottom; the nearest tray piece's centre is then 15.1 away against a
13.1 reach, so A takes nothing at pickupRange 1 and only the crown or
mountain above 1.19/1.12, by centre, not what is under the dot.
The overlapping tray pieces are the design. Fix: top = margin on
phones, with a failing dot-in-tray test first. Open: the owner's
pickupRange.
```

## Status row

| Bug triage 1107 | G0 survey done ([bug-1107-triage-report.md](bug-1107-triage-report.md)): the phones world's `PuzzleField.top` (`margin + tray.height` = 27 for the tree at seed 1) and `_inField`'s clamp stop the dot's edge on the tray's bottom, and the tray reach (13.1 for the crown) is 2.0 short, so A takes nothing at the default settings; the split matches are the same and the overlapping tray pieces are the design. Fix proposed: `top: margin` in `_computePhones` plus a failing dot-in-tray test; the screen layout, world sizes and mm values are unaffected. Open: the owner's `pickupRange`, then the fix brief |

## Delete

- none
