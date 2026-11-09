job: M13 device fixes 1: Shape Race's worker moves smoothly, and the held piece and the worker are never cut off at the field's edge (owner's iPhone test of m13.1, Nov 9, 2026)
pub: no
stop: after it.
read: docs/design/look-and-sound.md sections 5a, 6 ("Decided at step 9") and 7 · packages/puzzle_game/lib/src/worker_moments.dart, worker_frames.dart, worker_pose.dart, worker_painter.dart, puzzle_painter.dart (the field clip, line 112), match_painter.dart (line 101), view.dart (when the view observes a snapshot), game.dart (moving, line 257-263; turning), puzzle_carry.dart (_inField, _carryBig), snapshot.dart · their tests (worker_moments_test, worker_paint_test, rules_test and the carry tests) · docs/review-rules.md · docs/coding-guidelines.md

What the owner saw (iPhone, phone host, landscape, solo Shape Race, stick mode):
1. **"The player animation is off and not smooth."**
   Claude tracked the worker in the owner's 60 fps recording. Its position moves evenly (about 11 px a frame), so the drawing isn't dropping frames. What jumps is the pose:
   - **Walking against standing is decided per snapshot:** `moved = distance > movingUnits` (0.25 field units between two snapshots, worker_moments.dart:189). That is a distance, not a speed. With the analog stick part-way, the dot travels near 0.25 a snapshot, and the pose flips between walking and standing from one snapshot to the next. A snapshot seen twice (distance 0) flips it too, and the same speed reads differently at 30 and 60 Hz.
   - **The worker swings round the piece it carries.** In the recording, the carried door's middle, relative to the worker's body, went from (-100, +90) px to (0, -80) to (+25, -180) over about two seconds of straight walking. The worker slides from below-left of the piece to well above it, so the carry doesn't read as pushing or pulling. Find what moves it: `side`, `travel`, the frame's grip, the piece's turn. Report the cause.
   - At rest the worker's drawn position alternates between two values every frame (about 0.7 px). Report its cause; fix it if it's a flip-flop rather than a planned bob.
2. **"The player and shapes clip when reaching the left or right side where the controls are. We should not do this."**
   The rules keep only the dot inside the field (`_inField(..., dotRadius)`). A held piece's middle is the dot, so near the field's left or right edge half the piece hangs outside, and `PuzzlePainter`'s `clipRect` (field) cuts it and the worker beside it. The owner's screenshots show a green circle and the worker cut at the field's left edge, and the circle at its right edge.

Claude's rules:
1. **Walking is a speed, with hysteresis, on the game's clock:**
   - Work out each player's speed from consecutive snapshots using the game's time in the snapshot (the clock the snapshot carries, e.g. `timeLeftMs`), not the view's arrival time and not "per snapshot".
   - A snapshot with no game time passed (a repeat) changes nothing.
   - The worker starts walking above `walkStartSpeed` and stops only once it has been below `walkStopSpeed` for `walkStopMs` (~120 ms). Choose the speeds from `PuzzleGame.speed`, e.g. 15 % and 8 % of it, and name and document each.
   - `travel`, the walking direction, is the direction of a short moving average, so a stick wobble doesn't swing it.
2. **The side the worker holds a piece from turns smoothly:** the worker's place round the piece eases toward its target side at no more than `sideTurnDegPerS` (e.g. 360°/s), worked out from the game's time between snapshots. It never jumps more than that allows. If the cause found in item 1 is a bug (e.g. the side recomputed from a lagging ray), fix the cause; the easing is the guard.
3. **Nothing held leaves the field:**
   - In the rules, after moving and after turning, an ordinary held piece is kept so that its whole turned outline's bounds lie inside the field. The dot moves with it, since the dot is the piece's middle. Do the same for a team-carried big piece and its carriers.
   - A piece on its target is inside the board, which is inside the field, so every target is still reachable. Test that a piece can be locked on a target that touches the board's edge.
   - Free pieces in the tray are unchanged.
4. **The worker stays inside the field when drawn:** where its pose would put any of its body, ears or hands outside the field, the painter slides it inward along the side, or flips it to the piece's other side if sliding isn't enough. This is drawing only (the rules' dot stays as rule 3 leaves it). An empty-handed worker at the field's edge is kept inside the same way.
5. **The field clip stays** (on the TV two boards sit side by side). With rules 3 and 4, nothing of a player's needs to cross it.
6. All of it is rules-side or painter-side, as design 7 says: no Flutter in the moments, no change to the snapshot or the protocol, the same pose on the host and on a joined phone from the same snapshots.

tests (each failing first):
- **Walking:**
  - a dot moving at 50 % speed, fed at 60 Hz and at 30 Hz, walks every frame after it starts, with no frame of standing;
  - the same with every snapshot repeated once;
  - a stick wobbling round the threshold (speeds alternating 12 % / 9 %) walks continuously once started;
  - stopping stands within `walkStopMs` + one snapshot.
- **The side:** a worker carrying a small piece in a straight line keeps its body on one side of the piece, moving under `sideTurnDegPerS`. Over 2 s of straight walking the body's angle round the piece changes by no more than a few degrees after the first turn.
- **At rest:** the drawn pose is the same on two consecutive frames with no new snapshot, and with a repeated one.
- **The field:**
  - an ordinary piece carried hard left, right, up and down stops with its bounds inside the field, at every turn the piece can take (0°, 45°, 90°);
  - turning a piece at the edge pushes it inward;
  - a big team piece is the same;
  - a piece whose target touches the board's edge still locks.
- **The painter:** a worker carrying a piece at the field's left and right edges paints no ink outside the field (paint the field into a bigger canvas without the clip, and check the outside strip is the background), in Sunny and Night.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any you change, and why, especially worker-pose tests that pinned the per-snapshot rule.

in the report:
- test counts before and after;
- the files changed;
- the cause of the side swing, and the cause of the rest flip-flop;
- the constants chosen, and why;
- what a player sees differently.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · the puzzle tests rewrite docs/design/m12-mirror-*.png: restore them with `git checkout -- docs/design/m12-mirror-*.png` before you finish.
allow: docs/briefs/m13/s10-device-worker-report.md · packages/puzzle_game
check: format analyze puzzle host phone tv
report: docs/briefs/m13/s10-device-worker-report.md
