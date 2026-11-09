# M13 13: one pickup reach for every shape, measured to the outline

Job: `docs/briefs/m13/s13-pickup-reach.md`. Stop after it.

## What changed

### puzzle_game, rules
- `lib/src/game.dart`: `PuzzleGame.pickupReach = dotRadius * 1.3` = **3.38** field units, a named constant with its
  design reference (5a, device test 1). Nothing else in the file changed (396 lines, under the 400 hard limit).
- `lib/src/puzzle.dart`: `PieceShape.distanceTo(point, at, angle, {scale})` — the distance from a point to the turned,
  scaled outline, 0 inside; the circle's is `|point − at| − radius × scale`, a polygon's is the shortest distance to any
  side. `contains` now shares `_outline` and `_inside` with it, so both place a shape the same way. New top-level
  `_toSegment` (point to segment, clamped at the ends). 358 lines.
- `lib/src/puzzle_drop.dart`: `_pickUp` reaches a piece when `distanceTo` its drawn outline is at most
  `pickupReach × pickupRange` (0 inside counts, so any edge or a body against it picks it up). Of the pieces in reach,
  the top one the dot stands in is taken (`contains`, as before), otherwise the one whose outline is nearest; ties go to
  the higher layer (`_bestInReach`, `_outlineDistance`, `_isIn`, `_drawnScale` — the last is the old tray-scale rule in
  one place). The grab is unchanged: `p._grab = p.pos - best.pos`. 172 lines.
- `lib/src/settings.dart`: `pickupRange`'s doc now says it is a multiple of the pickup reach from the outline (its range
  and default are unchanged: 0.25–2.0, 1.0).
- `lib/src/worker_painter.dart`: `_bodyShare` is gone; `_workerRadius` starts from `PuzzleGame.pickupReach`, so the body
  the player sees and the reach the rules use are one value. The 7 mm floor on a phone is unchanged.

### puzzle_game, tests
- `test/pickup_reach_test.dart` (new, 7 tests): the reach matrix, the triangle, nearest outline, the tie, and the three
  `distanceTo` tests.
- `test/worker_paint_test.dart`: +1, "the body's radius is the pickup reach the rules use" (measured off the frame);
  `bodyAcross` is now `2 * PuzzleGame.pickupReach` (the same 6.76 units the old `1.3 × dotAcross` gave).
- `test/pickup_test.dart` (new): the "picking up and leaving" group moved out of `rules_test.dart` unchanged apart from
  its first test (below). `rules_test.dart` was 532 lines, over the 500-line test limit that `tools/review.sh` flags;
  it is 450 now.
- `test/rules_test.dart`: the pickup test moved out (to `pickup_test.dart`) and now measures the reach to the square's
  side (5 + the reach) instead of from its middle; its "nearest piece" case moved to `pickup_reach_test` with two
  purpose-built pieces, because two tray pieces of the sample puzzle are no longer both in reach of one spot.
- `test/tray_pile_test.dart`: the tray-size test now pins the reach to the *drawn* outline (0.75 of the piece) and that
  a full-size piece at the same place is reached from the same spot; the pile test's "inside neither" case is a tie
  (3 from each bottom side) and now expects the higher layer.
- `test/phone_tray_reach_test.dart`: `spotOn` measures the reach to the drawn outline instead of the drawn middle.

### docs
- `docs/design/look-and-sound.md` §5a: the "rules don't change" rule no longer claims the dot's reach stays as it is,
  and a new rule says, **"Decided at device test 1"**, what the reach is: the worker's body radius, measured to the
  piece's outline, the same for every shape (owner, Nov 9), with the top piece under the dot first and ties to the
  higher layer.

## Tests

| | before | after |
| --- | --- | --- |
| `puzzle` (`flutter test`) | 185 | **193** |
| `host` | 240 | 240 |
| `phone` | 433 | 433 |
| `tv` | pass | pass |

The 8 new tests are the 7 in `pickup_reach_test.dart` and the 1 in `worker_paint_test.dart`; two tests moved between
files, so the net count is the new ones only.

**They fail against the old rule**: with the old middle-based reach put back in `_pickUp` (temporarily, then restored),
`pickup_reach_test` fails 3 of 7 — the reach matrix ("a piece is taken a little past the outline"), the triangle and
the nearest-outline test — and the `distanceTo` tests could not compile before this job (no such method). The tie test
already passed under both rules, which is why it is written as the tie case only.

## The reach, old and new, for the four puzzles

"Old" is how far outside the middle of a piece's nearest side the dot could stand and still take it:
`dotRadius + radius − the distance from the middle to that side` (board pieces, `pickupRange` 1). "New" is the same
distance for every shape: `pickupReach` = 3.38 field units from the outline. On the split screen a tray piece was drawn
at 0.75, so its old radius — and so its old overshoot — was 0.75 of the figures below; the new reach is 3.38 from the
drawn outline whatever the scale.

| puzzle | piece | radius (far corner) | old overshoot | new |
| --- | --- | --- | --- | --- |
| house | walls (big rect 30 × 22) | 18.60 | 10.20 | 3.38 |
| house | roof (triangle 38 × 18) | 21.02 | 17.09 | 3.38 |
| house | door (rect 8 × 12) | 7.21 | 5.81 | 3.38 |
| house | sun (circle r 7) | 7.00 | 2.60 | 3.38 |
| rocket | body (big rect 14 × 34) | 18.38 | 13.98 | 3.38 |
| rocket | nose (triangle 14 × 14) | 9.90 | 9.37 | 3.38 |
| rocket | left / right fin | 8.60 | 10.78 | 3.38 |
| rocket | window (circle r 6) | 6.00 | 2.60 | 3.38 |
| tree | trunk (rect 8 × 18) | 9.85 | 8.45 | 3.38 |
| tree | crown (circle r 14) | 14.00 | 2.60 | 3.38 |
| tree | sun (circle r 8) | 8.00 | 2.60 | 3.38 |
| tree | mountain (triangle 28 × 20) | 17.20 | 14.07 | 3.38 |
| boat | hull (big trapezium 44 × 10) | 22.56 | 20.16 | 3.38 |
| boat | mast (rect 3 × 30) | 15.07 | 16.17 | 3.38 |
| boat | sail (triangle) | 18.44 | 21.04 | 3.38 |
| boat | flag (triangle 7 × 6) | 7.00 | 9.60 | 3.38 |
| boat | wave 1 / wave 2 (rect 14 × 4) | 7.28 | 7.88 | 3.38 |

(A polygon's radius is its farthest corner, not its side: that is the whole bug. The sail's and the flag's middles lie
on their own outlines, so the old rule let the dot take them from 21 and 9.6 units away from their middles.)

## What a player feels differently

- **Circles and small rectangles become easier, everything with a far corner much harder.** A sun or window was
  reachable only by touching the rim, 2.6 past it; now 3.38 — the body's edge. The door was reached 5.81 past its
  side, the waves 7.88, the roof 17.09: those now need the body against the piece, the same as everything else.
- **"Next to the piece" means the same thing on every side.** The distance is to the nearest point of the outline, so
  a corner, a flat side and a curve all answer the same, at every turn.
- **The tray on a phone is reached like the board.** The reach no longer shrinks with `trayScale`; it is measured to the
  smaller drawn piece, so the body has to overlap the drawn shape by the same amount as anywhere else.
- **Picking a piece out of a pile is steadier.** Pieces whose middles are far but whose edges are close no longer lose
  to a piece whose middle happens to be nearer; the outline decides, and an exact tie goes to the piece on top.

## Computed test values

- `pickupReach` = 2.6 × 1.3 = **3.38**; the tests press at `× 0.95` = **3.211** and `× 1.05` = **3.549** from the
  outline. The shapes: house sun (circle r 7), door (rect 8 × 12), roof (triangle, radius 21.0238) and walls (rect
  30 × 22, big), each in the tray at 0.75 and on the board at 1, turned 0°, 30° and 90°, on all four sides.
- Triangle, old-rule point: 20 left of the roof's middle. Old reach 2.6 + 21.0238 = **23.62** (in reach); distance to
  the left side **7.2213** — the nearest point on the side from (−19, 9) to (0, −9) is (−15.0336, 5.2423), and
  √(4.9664² + 5.2423²) = 7.2213.
- Nearest outline: a plank (40 × 4) ending at x 40 and a tile (4 × 4) starting at x 41, dot at (40.2, 40): **0.2** from
  the plank's outline and 20.2 from its middle, **0.8** from the tile's outline and 2.8 from its middle. The plank is
  taken.
- Tie: two 10 × 10 squares at (40, 40) and (46, 40), both bottom sides at y 45, dot at (43, 48): **3.0** from each;
  the higher layer (index 1) is taken.
- `distanceTo`: circle r 7 at (10, 20) — 0 at the middle and at (17, 20) (the rim), 3 at (20, 20), 4.5 at (18, 20) at
  scale 0.5; door (rect 8 × 12) 10 right of its middle — 6 unturned, 4 turned 90° (it is 12 wide then), 7 at
  scale 0.75; roof 3 above its apex at (0, −9), 7.2213 at (−20, 0), 0 at its middle at 0° and 30°.
- Split-screen tray (scale 0.75): the square's half height is 5, so its drawn top side is 3.75 above its middle; the
  dot 7.63 above the middle is **3.88** past the drawn outline (misses) and the full-size piece's outline is
  **2.63** = 3.38 − 5 × 0.25 + 0.5 away (taken).
- Worker body: measured off a 640 × 360 frame at 2× as `(2 × reach − ink) / (2 × 8)` = **3.38 ± 0.15** field units.

## Self-check (review-rules part A)

1. **Every host setup.** A rules change in the shared `PuzzleGame`, with no snapshot, protocol or view field touched:
   the TV/PC host, a phone hosting ("Play on this phone"), "Show on this device", a joined phone and a phone one build
   older all run this same `_pickUp` on the host and draw the same frames. Shown by `pickup_reach_test` (a phones-size
   field with `trayScale` 0.75), `phone_tray_reach_test` (phones solo and split), and the host, phone and tv suites.
2. **When kept state starts and ends.** Nothing new is held, timed or remembered: `_pickUp` sets the fields it always
   did (`held`, `_holdS`, `_lastTurn`, `_grab`, `_helpS`, `pickups`) and the reach is computed inside the press. A
   pickup still ends through `_drop`, `_letGo` and `_putEverythingDown`. Shown by `pickup_test` ("a held piece can't be
   taken…") and `tray_pile_test` ("a tray piece is reached…").
3. **How a new state combines with the others.** There is no new state: nothing pauses, hides, waits or blocks input,
   and the reach is read only on a press. The pairs are the ones that were already there (pause, away, time-up);
   `rules_test` ("time-up shows the pieces placed…") and the whole rules suite pass unchanged.
4. **Stay in the job's folder.** Only `packages/puzzle_game` (lib and tests), `docs/design/look-and-sound.md` and this
   report are written.
5. **Stop rather than overstep.** The host's settings screen labels `pickupRange` "piece radius" and lives in
   `party_host` (outside `allow:`), so it is not changed — question 1. `rm` was refused by the sandbox, so the scratch
   debug test I made is left as an empty `void main() {}` and listed under Delete.

## Questions and suggestions

1. `packages/party_host/lib/src/text/host_text.dart:231` shows `pickupRange` as "1.00 piece radius"; it is now a
   multiple of the worker's body radius. May I change that label in a job that allows `party_host`?
2. Design §5a's rule 1 said "the dot's reach … stays as it is", which this job makes untrue; I amended it to point at
   the new device-test rule. Is that wording what you want, or should the reach sentence be dropped from rule 1?
3. `tools/review.sh` notes `game.dart` at 396 lines (under the 400 hard limit, over the 300 aim) and a 54-line
   `_trayLayout`. Both were there before this job; a later split would be its own job.
4. `pickupRange`'s range (0.25–2.0) now means 0.85 to 6.76 units past the outline. If the next device test wants the
   reach a little longer or shorter, the setting alone moves it: 1.0 is the body's radius exactly.
5. A piece still in the tray is now reached at the body radius from its drawn (smaller) outline, so on a phone the dot
   has to overlap tray pieces a little more than before. `phone_tray_reach_test` still finds a standable spot for
   every piece in the four puzzles at 0.75 and 1.0; worth a look at the next device test with the tray pile.
6. `docs/design/m12-mirror-*.png` were **not** rewritten by this run (`git status` shows them clean), so no restore was
   needed.

## Commit message

```
One pickup reach for every shape, measured to the piece's outline

A piece is reachable when the dot is within pickupReach × pickupRange of
its drawn outline (0 inside), with pickupReach the worker's body radius
(dotRadius × 1.3), which the painter now draws from the same constant.
Of those in reach the top piece under the dot is taken, else the one
whose outline is nearest, ties to the higher layer. PieceShape.distanceTo
is the new pure outline distance the rules use. A circle is now reached
from its rim, a triangle no longer from far off a side, and the same
"next to it" works for every shape, side and turn. Design §5a records the
owner's device-test decision; the snap, drop and help tolerances are
unchanged.
```

## Status row

M13 13 done: one pickup reach (the worker's body radius) measured to every shape's outline, old middle-based reach and its tests replaced, design §5a updated — open: the host settings label still says "piece radius" (party_host, needs a brief), and an owner pass on the split-screen tray.

## Delete

- packages/puzzle_game/test/scratch_debug_test.dart

## Claude's review (Nov 9, 2026)

Accepted, with one addition. All checks are green (puzzle 194, host 240, phone 433, tv), and review.sh has no FAIL.

- **The body counts too.** The worker's body is drawn standing 1.35 body radii above its grab ring (`_standShare`). With the reach measured from the ring alone, a player walking up to a piece from below saw the body overlap it by more than its radius before the piece could be taken: the owner's "directly over it". The reach is now the nearer of the ring and the body's middle, both measured to the outline (`PuzzleGame.workerStandShare`, which the painter now reads). Test-first: "from below, the drawn body against the edge takes the piece" (all four house shapes, three turns). The "a little further" check skips the side below, where the body reaches further.
- **Q1:** the Pickup range label now reads "125% of the worker's reach" (host_text_test).
- **Q2:** the design wording is fine.
- **Q5:** tray pieces on a phone are worth a look at the next device test.
