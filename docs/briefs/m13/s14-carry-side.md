job: M13 device fixes 5: the worker keeps to the side it took a piece from, and the grab ring goes (owner's iPhone test of m13.2, Nov 9, 2026: "The player's character moves around too much when moving and rotating the blocks. Can we have the character stick to the side be picked up the block from as much as possible?" and, of the ring under the worker, "If that's not needed can it be removed? I don't see it all the time. So it appears to be a visual bug.")
pub: no
stop: after it.
read: docs/design/look-and-sound.md section 5a · packages/puzzle_game/lib/src/puzzle_carry.dart (`_carrySmall`, `_keepHeldInField`, `_carryBig`), game.dart (`_moveAll`), puzzle_drop.dart (`_pickUp`, the grab), worker_moments.dart (`_SeenPlayer._noteHeld`, `side`, `_noteSide`, `sideTurnDegPerS`, `sideUnits`), worker_frames.dart (`_stand`, `_edge`, `_fitted`, `work`), worker_painter.dart (the ring: `_ringShare`, `pose.onDot`) · the worker and carry tests in puzzle_game/test · docs/review-rules.md · docs/coding-guidelines.md

The cause (Claude, from the code and the owner's video):
- At pickup, a small piece's middle jumps to the dot (`_carrySmall` sets `piece.pos = p.pos`), so the side the worker took it from is lost at once. Since device test 1 a piece is taken from up to a body radius off its edge, so the jump is bigger than before.
- With no side from the dot, `_noteHeld` puts the worker on the edge behind the way it walks (`-travel`), eased at 360°/s. So it swings round the piece whenever the player changes direction: in the video it goes below, left, top-left, top-right, right, left within three seconds.
- The ring is the empty-handed worker's grab-point marker (`pose.onDot`). It shows only with empty hands, so to the owner it comes and goes like a bug.

Claude's rules:
1. **A held piece stays where it was taken (rules).** Every carrier keeps its grab, `p._grab = p.pos - piece.pos`, as a team's big piece already does. A small piece no longer jumps to the dot.
   - Moving: the piece moves by the push, `piece.pos = _insideField(piece, piece.pos + push)`, and the dot follows, `p.pos = _inField(piece.pos + p._grab, dotRadius)`. The dot's clamp never holds the piece back: a piece reaches the field's edge even when its dot is pressed against it.
   - Turning: the grab is in field units, not turned with the piece, so a turn doesn't move the dot (apart from `_keepHeldInField`'s push back inside, which moves dot and piece together, every carrier at its own grab).
   - Dropping, the snap, the drop-ready and the hint are unchanged: they use the piece's middle, which is where it's drawn.
2. **The worker keeps its side for the whole carry (drawing).** The side is decided once, when the piece is taken up (or first seen held, on a joined phone):
   - the way from the piece's middle to the dot, when longer than `sideUnits`;
   - else behind the way it was walking (`-travel`), when walking;
   - else above, `(0, -1)`.
   After that it doesn't follow the walk or ease anywhere. Remove the easing and `sideTurnDegPerS` if nothing else uses them. Push and pull (`work`) still compare the travel with that side, so the faces still show shoving and dragging.
3. **The only exception is the field's edge**: `_fitted` still slides the body in, or takes it round to the piece's other side when sliding would pull it off the piece (the clipping fix from device test 1). Leave that as it is.
4. **The ring goes.** An empty-handed worker draws no ring at its grab point. Remove `_ringShare`, and `onDot` too if nothing else uses it. The pickup reach is unchanged: from the dot or from the body (device test 1).
5. Say in design section 5a, "Decided at device test 2" (owner, Nov 9): a piece stays where it was taken and the worker keeps to the side it took it from for the whole carry, moving and turning; it goes round only at the field's edge. Remove the ring from the "rules don't change" rule (no ring is drawn).

tests (each failing first):
- Rules: a small piece taken from its edge (the dot at `pickupReach × 0.9` left of its left side) hasn't moved after the pickup and an update with no push; the dot keeps that offset.
- Rules: pushed right, left, up and down, the piece and the dot move by the same step.
- Rules: a turn of 90° leaves the dot where it was (the piece well inside the field).
- Rules: a piece held from its left, pushed left into the field's left edge, reaches it (its turned bounds' left at 0), with its dot clamped at `dotRadius`; and the grab is kept, so when pushed right again the dot is back at `piece.pos + grab`.
- Moments: a worker that took a piece from its left stays on its left (`side` within 1° of `(-1, 0)`) while it walks right, left, up and down, and while the piece turns a whole turn.
- Moments: a piece taken from inside, near its middle, while walking right: the worker is on its left, and stays there when the walk turns down.
- Moments: a joined view that first sees a player already holding a piece takes the side from the dot.
- Painter: an empty-handed worker draws no ring (the ring's ink, at the dot below the feet, is gone).
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any you change, and why. Tests that pinned the old jump to the dot, the walk-following side or the ring may change, to the new rules only.
- A picture, `docs/design/m13-carry-side.png`, made the way `m13-worker-run.png` was: one worker holding the house's door from its left, in eight cells: walking right, left, up, down, then the door turned 0°, 90°, 180°, 270°. Sunny. It must be deterministic.

in the report:
- test counts before and after;
- the files changed;
- what a player feels differently;
- anything in the rules that read the dot as the piece's middle (and what you did about it).
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · the puzzle tests rewrite docs/design/m12-mirror-*.png: restore them with `git checkout -- docs/design/m12-mirror-*.png` before you finish.
allow: docs/briefs/m13/s14-carry-side-report.md · docs/design/look-and-sound.md · docs/design/m13-carry-side.png · packages/puzzle_game
check: format analyze puzzle host phone tv
report: docs/briefs/m13/s14-carry-side-report.md
