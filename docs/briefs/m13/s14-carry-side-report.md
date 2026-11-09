# M13 14: a held piece stays where it was taken, the worker keeps its side, and the grab ring goes

The owner's iPhone test of `m13.2` saw the worker swinging round a piece as it walked and turned ("The player's
character moves around too much when moving and rotating the blocks. Can we have the character stick to the side be
picked up the block from as much as possible?") and the empty-handed ring as a flickering bug ("If that's not needed
can it be removed? I don't see it all the time. So it appears to be a visual bug.").

Two causes. A small piece's middle jumped to the dot at the pickup (`_carrySmall` set `piece.pos = p.pos`), so the
side the worker took it from was gone by the next frame, and since device test 1 a piece is taken from up to a body
radius off its edge, so the jump is bigger than before. With no side from the dot, `_noteHeld` put the worker on the
edge behind the way it walked (`-travel`), eased at 360°/s, so it swung round the piece whenever the walk changed
direction — in the video: below, left, top-left, top-right, right, left within three seconds. The ring was the
empty-handed worker's grab-point marker (`pose.onDot`), so it came and went with the pickup and drop.

Now every carrier keeps its grab, as a team's big piece already did, and the worker's side is decided once and kept.

## What a player feels differently

- Picking up: the piece stays where it lies. The worker stands where it stood, beside the piece, and pushes it from
  there; nothing jumps under the worker.
- Walking: whichever way the player goes — right, left, up, down, or a curve of all four — the worker stays on the
  piece's same side. It no longer swings round it.
- Turning: the piece turns under the worker. The dot, and the worker with it, stays where it was (apart from the push
  back in at the field's edge), so a turn no longer drags it round the middle.
- The field's edge: a piece can be pushed all the way there even when its dot is pressed against the edge first, so
  the dot's own clamp never holds the piece back. The worker's body still slides in or goes round the piece when it
  would be drawn off the field (`_fitted`, unchanged).
- Empty-handed there is no ring: the dot is just the worker. The pickup reach is unchanged (from the dot or the
  body).
- Dropping, the snap, the drop-ready highlight and the hint are unchanged: they work from the piece's middle, which
  is where it's drawn.

## The rules

- `_pickUp` already set `p._grab = p.pos - best.pos`; it now matters for every piece, not just a team's big one.
- `_carrySmall(p, piece, push)` (in `puzzle_carry.dart`): `piece.pos = _insideField(piece, piece.pos + push)` then
  `p.pos = _inField(piece.pos + p._grab, PuzzleGame.dotRadius)`. The piece moves by the push from where it was taken;
  the dot follows at its grab. Because the piece is fitted to the field first and the dot only to its own clamp, a
  piece reaches the edge even when the dot cannot.
- `_keepHeldInField` (after the turns): unchanged in shape — a piece pushed back inside takes every carrier with it,
  each at its own grab. Since a turn doesn't move the piece's middle, a turn alone leaves the dot alone; only a
  piece that turned into an edge pushes the dots back.
- `_moveAll` in `game.dart` computes the push first, then hands it to `_carrySmall` for a held ordinary piece, or
  moves the dot itself when empty-handed. `_carryBig` is untouched (it already kept grabs).
- Nothing is added to the snapshot, the protocol or the events: the drawing works out the side from the piece's
  middle and the dot, which the snapshot already carries.

## The worker's side

`_noteHeld` in `worker_moments.dart` takes the side when the piece is first seen held (`index != held`) and never
again for that carry:

```
Offset _takenSide(Offset middle, Offset dot) {
  final ray = dot - middle;
  if (ray.distance > sideUnits) return ray / ray.distance;
  if (walking) return -travel;
  return const Offset(0, -1);
}
```

`sideUnits` is 0.5 field units. So: the way from the piece's middle to the dot, when the grab holds the dot off the
middle; else behind the walk when the piece was taken up on the move; else above. The easing and
`sideTurnDegPerS`/`_noteSide`/`_turnToward` are gone; `turned` (the tongue and the arms twisting) stays, worked out
from the piece's angle. `_raySide` stays for `_SeenPlayer`'s constructor, so a joined phone that first sees a player
already holding takes the side from the dot too.

`worker_frames.dart`: `_Stand` is now `({Offset at, Offset away})` (no `onDot`), `_stand` puts the body on the edge
along that fixed side, `_edge` and `_fitted` are unchanged — the edge exception still slides the body in, or takes it
round to the piece's other side when sliding would pull it off the piece. `work` (push or pull) still compares the
travel with `side`, so the effort faces still show shoving and dragging, now against a side that stays put.

## The ring

`worker_painter.dart`: `_ringShare` and the `if (pose.onDot) canvas.drawCircle(…)` block are gone. `_ringInkShare` is
renamed `_thinInkShare`, which is what it is: the sweat drop and the call mouth use the same thin stroke.
`WorkerPose` loses `onDot` (field, parameter, copies, `toString`). Nothing else used it: the painter tests show the
grab point is the board's colour with no ink right of it (`worker_paint_test.dart`).

## Tests

New, each failing first on the old code except where noted:

- `test/carry_test.dart` (4): a piece taken from `pickupReach × 0.9` left of its left side hasn't moved after the
  pickup or a frame with no push, and the dot is at `middle + grab`; pushed right, left, up and down, the piece and
  the dot move by the same step (8 units in 10 frames) and the grab is kept to 1e-9; 30 frames of X leave the dot
  where it was with the piece at 90°; 200 frames left bring the piece's outline to 0 with the dot clamped at
  `dotRadius`, and 20 frames right re-seat the grab.
- `test/worker_side_test.dart` (3): a real `PuzzleGame` walked and turned, fed to `WorkerMoments` through snapshots.
  A door taken from its left stays at 180° (this test's degrees clockwise from the piece's right, so 180° is on its
  left) walking right, left, up and down and through four quarter turns (a whole turn back to 0°); a piece taken from
  0.2 of its middle while walking right puts the body on its left and keeps it there when the walk turns down; a
  joined view that first sees a player already holding takes the side from the dot. The last of these passes on the
  old code — it is a pin for `_raySide`, not a new behaviour, and is reported as such.
- `test/support/worker_carry.dart` and `test/worker_carry_png_test.dart`: the picture below.

Changed existing tests, all for the new rules only (a piece no longer goes to the dot at the pickup, the side no
longer follows the walk, no ring):

- `worker_paint_test.dart`: the ring test is now "an empty-handed worker stands on its grab point, with no ring round
  it" — the grab point is the board's colour, and a 3-pixel-high strip from 0.25 to 2 body radii right of it has no
  ink. The carrying test says "no mark on a carried piece".
- `worker_moments_test.dart`: `onDot` assertions and the old side group (walk-following side, eased) removed, and a
  small-piece ring test removed; the rest still pass. The side group's new home is `worker_side_test.dart`.
- `worker_stride_test.dart`: its held ball is placed 6 right of the dot, so the dot ray gives the side, and the push
  and pull still show.
- `rules_test.dart`, `field_test.dart`, `pickup_test.dart`, `tray_pile_test.dart`, `match_test.dart`,
  `view_test.dart`, `mirror_png_test.dart`: they put a held piece on the dot (or read it there) assuming the pickup
  jump; they now set the piece's `pos` beside the dot as the rules do. `match_test.dart`'s "one carrier leaves"
  asserts the crate 3 right of the player, the grab it took it by.

Counts: puzzle **211 → 217** (+4 carry, +3 side, −1 removed moments test); host 240, phone 433, tv all pass.

## The picture

`docs/design/m13-carry-side.png` (3936 × 292, 480 × 272 cells at 8 px a field unit), made like `m13-worker-run.png`:
one worker holding the house's door (8 × 12) from its left, at a fixed place in every cell, with the caption "the
door", in Sunny with the look's own fonts. Cells: walking right, left, up and down (twelve steps each, the door
landing exactly on the cell's place, so the walk never drags the pair), then the door turned 0°, 90°, 180° and 270°
(one pickup, a quarter turn each, a settle frame). The drawn snapshot always has the door at the same place and the
dot at `door + carryGrab`, so the cells differ only in the walk's stride and the door's angle. Deterministic: fixed
positions and frame counts, the view's clock stepped 17 ms a frame.

## Computed test values

- `pickupReach` = 2.6 × 1.3 = **3.38**; `tookBy` = 3.38 × 0.9 = **3.042**. A 10 × 10 square (half 5) taken from its
  left: grab = (−(5 + 3.042), 0) = **(−8.042, 0)**; home (60, 40) puts the dot at (51.958, 40).
- Ten frames at 48 units a second and 1/60 s each: **8.0** units, for every direction; the dot's step equals the
  piece's to 1e-9 and `dot - piece - grab` stays 0 to 1e-9.
- Thirty frames of X at 180°/s: **90°**, dot unmoved.
- Pushed left to the edge: a 10 × 10 square's turned bounds are ±5, so the middle rests at x 5 with `box.left` **0**;
  the dot's grab is −8.042, so it would be at −3.042 and is clamped at `dotRadius` **2.6**; `p.pos.dy` stays 40.
- The door: 20 × 20, half 10; a dot 3 left of its left side is 13 from the middle → grab **(−13, 0)** → side
  **(−1, 0)** = 180° in the test's clockwise-from-right degrees. A grab of (0.2, 0) is inside `sideUnits` 0.5, so the
  side comes from the walk: walking right, behind it is (−1, 0), 180°. The joined view: middle (60, 40), dot (47, 40)
  → away **(−1, 0)**, body at **middle + (−10, 0)** = (50, 40).
- Four quarter turns of 30 frames: 30 × 3° = 90° each; 120 frames take the angle back within **0.01°** of where it
  started.
- The picture: 96 px caption + 8 × 480 = **3936** wide; 272 + 20 = **292** high; 41 011 bytes.

## Anything that read the dot as the piece's middle

- `_carrySmall`: `piece.pos = p.pos` — for an ordinary piece the dot *was* the piece's middle. Now the piece keeps
  its own middle and the dot sits at `middle + grab`.
- `_noteHeld`: a dot on or near the middle gave no side, so the worker took the walk's `-travel` and eased it. Now
  `_takenSide` decides once from the dot's ray, else the walk, else above, and keeps it.
- `_SeenPlayer`'s constructor comment said "an ordinary piece's dot is its middle"; updated (every grab, big or
  ordinary, holds the dot off the middle).
- `worker_frames._stand`: with no fixed side the body went behind `_travel` every frame. It now stands along `side`.
- `worker_painter`: the ring marked the empty-handed dot as the grab point. Removed.
- Left as they were, because they should read the middle: `_matchingTarget`, `_nearestFreeTarget`, `_dropAt` (the
  snap and the piece's place), and `_raySide` for a joined view's first snapshot.

## Self-check (review-rules part A)

1. **Every host setup.** A rules and drawing change in the shared packages, with no snapshot, protocol or event
   field touched: the TV/PC host, a phone hosting, "Show on this device", a joined phone and a phone one build older
   all run the same `_carrySmall` and the same `WorkerMoments` from the snapshot. Shown by `view_test`'s host and
   joined snapshots, `worker_side_test`'s joined view, and the host, phone and tv suites (240, 433, tv all pass).
2. **When kept state starts and ends.** `_grab` starts in `_pickUp` and lasts until the piece is let go — by `_drop`,
   `_letGo`, `_putEverythingDown` (stop and time up) — after which the dot moves freely again; `side` starts on the
   first snapshot that has the piece held and is cleared when it isn't (`_noteHeld`: `side = null`). With nothing
   held, neither is read. Shown by `carry_test` (a)–(d) for the grab lasting the whole carry, and
   `worker_side_test`'s first test for the side lasting through walking and turning; `rules_test` still drops and
   re-picks pieces as it did.
3. **How a new state combines with the others.** Nothing new pauses, hides, waits or blocks input; only where a held
   piece and its dot go. A turn into an edge goes through `_keepHeldInField` (`carry_test` (d)); pause, away,
   "Get ready", the results and leaving are untouched and their tests (host 240, phone 433) pass. Exactly one owner
   decides a round's pause and phase, as before: `Pausable`.
4. **Stay in the job's folder.** Written: `packages/puzzle_game` (6 lib files, 4 new tests, 1 new support file, 10
   changed tests), `docs/design/look-and-sound.md` and this report. Not written by hand: `docs/design/m13-carry-side.png`
   is this job's allowed picture. The puzzle tests also rewrite `docs/design/m12-mirror-*.png` (3 files) and
   `docs/design/m13-worker-run.png` (question 1).
5. **Stop rather than overstep.** The brief says to restore `docs/design/m12-mirror-*.png` with `git checkout`; my
   standing instructions forbid git commands that change anything, so I did not — question 1. Nothing else needed a
   file outside `allow:`.

## Questions and suggestions

1. The puzzle tests rewrite `docs/design/m12-mirror-169.png`, `-iphone.png`, `-iphone-stick.png` and
   `docs/design/m13-worker-run.png` whenever they run (all are deterministic). The brief asked me to `git checkout`
   the mirror ones back; git changes are forbidden to me, so they are left as the tests wrote them. The worker's
   drawing did change (the ring is gone), and `STATUS.md` says the mirror pictures are deterministic and to commit
   them when the worker changes, so keeping the new ones may be right — your call.
2. `review.sh` notes `game.dart` at 399 lines (limit 400, aim 300), `worker_frames.dart` 342, `worker_moments.dart`
   332 and `worker_painter.dart` 336 (aim 300), and `_trayLayout` at 54 lines. All were there before this job.
3. `sideUnits` (0.5) now decides both whether a pickup gives a side and how the first snapshot of a joined view reads
   one. A grab shorter than half a field unit under a door's middle gives no side (the walk or above does), which is
   what the owner asked for; worth a look at the next device test for big pieces taken from their middle.

## Commit message

```
A held piece stays where it was taken; the worker keeps its side

A small piece no longer jumps to the dot at pickup: every carrier keeps
its grab, a push moves the piece and puts the dot at its grab, and a
turn doesn't move the dot; the dot's clamp never holds the piece back
from the field's edge. The worker's side is decided once, at the pickup
or first seen held (the dot's ray, else behind the walk, else above);
the easing, sideTurnDegPerS and the empty-handed grab ring
(pose.onDot) go. Design §5a records the owner's decision.
```

## Status row

M13 14 done: a held piece stays where it was taken and the worker keeps the side it took it from, moving and
turning; the grab ring is gone, design §5a records the decision, picture `docs/design/m13-carry-side.png` — open: the
regenerated mirror and run pictures need committing, and an owner pass on the next device test.

## Delete

- none

## Claude's review

- Accepted: the rules change (every carrier keeps its grab; the piece moves by the push, the dot follows), the side decided once, the ring gone, the design note. `m13-carry-side.png` shows the worker on the door's left in all eight cells; `m13-worker-run.png` and the three mirror pictures were redrawn without the ring.
- Fixed, test first: the side was decided only on a snapshot whose game time moved. A phone can show the pickup first in a snapshot that repeats the time, and the worker then stood above the piece for the whole carry. `note` now decides it there too. Test: "a pickup first seen in a snapshot that repeats the game time still takes the side from the dot" (failed before: the side was (0, -1)).
