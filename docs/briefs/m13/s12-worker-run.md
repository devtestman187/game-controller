job: M13 device fixes 3: the worker runs. A step cycle with feet, swinging arms, a body bob and floppy ears; a breathing idle; easing into and out of a walk (owner, Nov 9, 2026: "Ensure player animations are smooth and cute. It can be a longer animation such as running or swinging arms. Maybe add more animation frames as well")
pub: no
stop: after it.
read: docs/design/look-and-sound.md sections 5a, 5b, 6 and 7 · docs/briefs/m13/s10-device-worker.md and its report (speed-based walking, the eased side; this job builds on them) · packages/puzzle_game/lib/src/worker_moments.dart, worker_frames.dart, worker_pose.dart, worker_painter.dart and their tests · packages/toy_look/lib/src/toy_accessory.dart (the ears and other accessories) · docs/review-rules.md · docs/coding-guidelines.md

Where it stands: after s10, the worker walks or stands by its speed, with hysteresis. A walking worker still has one fixed pose (`handsWalk`, `walkLeanDeg`) and no legs, so a run looks like a slide. The owner wants it smooth and cute, "a longer animation such as running or swinging arms", with more frames.

Claude's design (drawn, not sprites: every frame is worked out, so there are as many frames as the screen draws):
1. **The step cycle.** The worker gets a stride phase that advances with the distance its dot has travelled, not with time. So the feet keep pace with the stick at any speed, a stop freezes the cycle mid-step, and a 30 Hz and a 60 Hz host give the same picture at the same place.
   - **Stride:** one full cycle (two steps) per `strideUnits` of travel, about the worker's body diameter (name it from the dot radius). The phase is kept per player in `WorkerMoments` and advanced from the snapshots, as s10's speed is.
   - **Feet:** two small ovals in the worker's colour, darkened by the shade mix, with the ink edge, under the body.
     - Each swings forward and back by ±0.3 of the body radius along the travel direction, in opposite phase.
     - The foot in the air lifts by 0.15 of the radius at the middle of its swing.
     - Standing, both feet rest side by side under the body.
   - **Arms, empty-handed:** they swing opposite to the feet, ±35° about the shoulder, from `handsDown` (left arm forward when the right foot is). They replace the fixed `handsWalk`.
   - **Body:** it bobs up by 0.06 of the radius twice a cycle (at each step's middle). It squashes 4 % wide and short at each foot's contact, and leans `walkLeanDeg` into the travel.
   - **Ears or accessory:** they follow the bob a quarter cycle late, up to ±8° (secondary motion), so they flop. Do this through `paintAccessory` with a tilt or offset parameter, in toy_look. Every accessory takes it; a crown just tilts.
2. **Carrying:**
   - The hands stay on the piece's edge, as now.
   - The feet keep stepping. At the push and pull leans the stride is shorter: 0.7 of the cycle's swing.
   - The bob is half as high.
   - The effort face and the sweat stay.
3. **Easing in and out:**
   - The cycle's amplitude (feet, arms, bob, ear flop) rises from 0 to 1 over 150 ms of game time when walking starts. It falls back over 200 ms when it stops, so the feet settle together rather than freezing apart.
   - The phase carries on from where it stopped.
4. **Idle:**
   - A standing worker breathes: 2 % taller and 1 % narrower at 0.4 Hz, on the game's clock. Each player is offset by its number, like the blink, so four workers don't breathe together.
   - The blink stays.
   - Every few seconds of standing the worker looks left then right, a 1.2 s glance (eyes only), also staggered by number.
5. **Moments still win:** a happy grin (hop, hands up), an oops (shake) and a call (wave) override the arms as now. The feet keep their last phase.
6. **Effects off, or the effects setting off:** no cycle, bob, flop, breathing or glance. The still pose, with the feet side by side. Design D8.
7. **Same picture everywhere (design 7):** everything is worked out from the snapshots and the game's time in them. Nothing goes in the snapshot or the protocol. Rules-side code has no Flutter.
8. **Size:** the feet sit inside the space the worker already takes, so s10's field-edge rule still holds. Check it with s10's painter test at the edges.
9. Files under 400 lines, functions under 60. `worker_frames.dart` is 280 lines today: put the cycle in its own file (e.g. `worker_stride.dart`).

tests (each failing first):
- **The phase:** it advances by exactly one cycle per `strideUnits` of travel, at 30 Hz and at 60 Hz; it doesn't advance standing; it carries on after a stop.
- **The feet:**
  - at phase 0 and 0.5 they are mirrored;
  - the lifted foot is the one swinging forward;
  - standing, they are side by side.
- **The arms swing opposite the feet:** the left hand is forward when the right foot is.
- **The bob** peaks twice a cycle, at 0.06 of the radius, and half that carrying.
- **Easing:** 75 ms after walking starts the amplitude is about 0.5; 200 ms after it stops it's 0.
- **Idle:** the breathing's period and size; two players are out of step; the glance comes and goes.
- **Effects off:** every one of these is still.
- **The painter:** a frame at four phases paints the feet in four different places, in Sunny and Night. A worker standing at the field's edge and one walking keep their ink inside the field (s10's test).
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any you change, and why.

in the report:
- test counts before and after;
- the files changed;
- every constant, with its value and what it moves;
- a strip of 8 frames of one cycle, saved as a PNG under docs/design/ (`m13-worker-run.png`), walking right, empty-handed, then carrying, in Sunny, rendered from a test with the look's fonts, for Claude to look at.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · the puzzle tests rewrite docs/design/m12-mirror-*.png: restore them with `git checkout -- docs/design/m12-mirror-*.png` before you finish.
allow: docs/briefs/m13/s12-worker-run-report.md · docs/design/m13-worker-run.png · packages/puzzle_game · packages/toy_look
check: format analyze look puzzle host phone tv
report: docs/briefs/m13/s12-worker-run-report.md
