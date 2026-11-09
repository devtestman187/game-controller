job: M13 device fixes 4: picking up a piece works the same for every shape, from its edge (owner's iPhone test, Nov 9, 2026: "For the triangle I only need to be next to the piece but the circles and smaller rectangle I have to be directly over it. Piece pickup should be consistent. Picking up from the edge should be accepted.")
pub: no
stop: after it.
read: docs/design/look-and-sound.md section 5a (the worker stands above its grab point, which a small ring marks) · packages/puzzle_game/lib/src/puzzle_drop.dart (`_pickUp`), puzzle.dart (`PieceShape`: `radius`, `contains`, `bounds`), game.dart (`dotRadius`), settings.dart (`pickupRange`), worker_painter.dart (`_bodyShare`, `_standShare`, the ring) · the pickup tests in puzzle_game/test · docs/review-rules.md · docs/coding-guidelines.md

The cause (Claude, from the code): `_pickUp` reaches a piece when the dot is within `dotRadius + shape.radius × scale × pickupRange` of the piece's **middle**. `shape.radius` is the distance to the farthest corner. So:
- a triangle, whose corners reach far past its sides, is reached from well off a side;
- a circle is reached only by touching its edge;
- a small rectangle is reached only near its corners' distance.

And since M13 the worker's body is drawn standing above the dot (`_standShare`). The body a player steers sits higher than the grab point, so "next to the piece" looks different on each side.

Claude's rules:
1. **One reach for every shape, measured to the outline:**
   - A piece is reachable when the distance from the dot to the piece's outline is at most `pickupReach × pickupRange`. The outline is the turned and scaled shape; a tray piece is at `field.trayScale`, as now.
   - The distance is 0 when the dot is inside the piece.
   - `pickupReach` is the worker's body radius in field units: `dotRadius × 1.3`. Name it in the rules, and have the painter's `_bodyShare` take its value from the same constant, so the drawn body and the reach agree.
   - So touching any edge, or standing with the body against it, picks the piece up, the same for a circle, a door, a triangle or a big piece.
2. **Which piece, when several are in reach:** the top piece under the dot, as now. Otherwise the piece whose outline is nearest the dot, not whose middle is nearest. Ties go to the higher layer.
3. **`PieceShape.distanceTo(point, at, angle, {scale})`:** the distance from a point to the shape's outline, 0 inside. For a circle it's the distance to the middle minus the radius; for a polygon, the shortest distance to any edge. It's a pure function, rules-side.
4. **The grab is unchanged:** `_grab = p.pos - best.pos`, so a piece picked up from its edge is held by that edge, as today with a big piece. Carrying, turning and dropping are unchanged.
5. **No other tolerance changes:** the snap, drop and help distances stay as they are.
6. Say in design section 5a, "Decided at device test 1": pickup reach is the worker's body radius, measured to the piece's outline, the same for every shape (owner, Nov 9).

tests (each failing first):
- For a circle, a small rectangle (the door), a triangle and a big piece, each in the tray and on the board:
  - the dot at `pickupReach × 0.95` outside the middle of an edge picks it up;
  - at `× 1.05` it doesn't;
  - checked at three turns (0°, 30°, 90°);
  - and on each side (left, right, above, below).
- The triangle is no longer reached from a point well off a side (a point the old rule reached: within `dotRadius + radius` of its middle but over `pickupReach` from its outline).
- Two pieces in reach: the one whose outline is nearer wins, though its middle is farther.
- `distanceTo` is 0 inside, matches the circle's formula, and matches a hand-worked point for a turned rectangle and a triangle.
- The painter's body radius equals `pickupReach` in field units.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any you change, and why. Pickup tests that pinned the old middle-based reach may change, to the new rule only.

in the report:
- test counts before and after;
- the files changed;
- the old and new reach for each shape in the four puzzles (a small table: the old reach from the edge's middle, and the new);
- what a player feels differently.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · the puzzle tests rewrite docs/design/m12-mirror-*.png: restore them with `git checkout -- docs/design/m12-mirror-*.png` before you finish.
allow: docs/briefs/m13/s13-pickup-reach-report.md · docs/design/look-and-sound.md · packages/puzzle_game
check: format analyze puzzle host phone tv
report: docs/briefs/m13/s13-pickup-reach-report.md
