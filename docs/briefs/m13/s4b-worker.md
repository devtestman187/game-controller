job: M13 step 4b: the worker, Shape Race's player dot drawn as a character with eyes, arms and faces that show effort (design section 5a)
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D8), 3, 4 and 5a (all of it) · docs/design/look-mockups.html (the frame for the worker: its SVG code is the drawing to follow) · docs/briefs/m13/s4a-shape-race-look-report.md (and Claude's review at its end) · packages/puzzle_game/lib/src (all of it, especially piece_moments.dart, view.dart, puzzle_painter.dart, mirror_painter.dart, snapshot.dart, puzzle.dart, puzzle_carry.dart) · packages/puzzle_game/test (look_paint_test, piece_moments_test and support) · packages/toy_look/lib · docs/review-rules.md · docs/coding-guidelines.md

Owner, Nov 8, 2026: "Can the worker in the shape race game have eyes and arms? Can it also make faces that show it's making effort to push/pull pieces?" 4a drew each player's dot as a numbered badge (`_dot` in puzzle_painter.dart). This job turns it into the worker, on the host and on a joined phone alike.

Claude's rules:
1. **Nothing in the rules changes.** The grab point, the dot's reach, its speed and every tolerance stay. The worker is only how the dot is drawn, and nothing is added to the protocol or the snapshot.
2. **The pose is worked out from the snapshots** (design 5a), in a new rules-side `WorkerMoments` beside `PieceMoments` (its own file; no Flutter or toy_look import; tested on its own).
   - It is fed each new snapshot with its time, as `PieceMoments` is, and for each player keeps what it needs:
     - the last position and the direction of travel;
     - the held piece, and its angle at the last frame, to see a turn;
     - when that player last snapped or dropped wrong: the piece they held in the frame before it turned `locked` or `wrong`.
   - It answers `WorkerPose poseOf(board, number, nowMs)`: a small value with the face, the body's lean and squash, where the arms reach, where the body sits, and a hop or shake offset.
   - **Moments** (design 5a's table), checked in this order:

     | Moment | When | Face and body |
     | --- | --- | --- |
     | Right drop | within 500 ms of a snap | happy closed eyes (^ ^), arms up, a hop |
     | Wrong drop | within 600 ms of a wrong drop | "oops": wide eyes, a wavy mouth, a hand on its head, a sweat drop |
     | Round won or lost | the board's phase is `finished` or `timeUp` | a cheering jump on the side that finished, a shrug otherwise |
     | Calling | it holds a big piece whose `calling` is on | one arm waves, mouth open |
     | Rotating | it holds a piece whose angle changed since the last frame | arms twist with the piece, tongue out |
     | Big piece alone, moving | it is the only holder | the strongest effort: squashed body, a sweat drop, a small shake |
     | Big piece with a teammate | both holders | each on its own side, a focused "o" mouth |
     | Pushing or pulling | it holds a piece and moves | effort face (> <), gritted teeth. Pushing (moving away from its own side of the piece): behind it, leaning in, arms straight. Pulling (moving towards its side): in front, leaning back, arms stretched back to the piece |
     | Carrying, still | it holds a piece and doesn't move | hands on the piece's edge, a determined little smile |
     | Moving, empty-handed | it moved since the last frame | eyes look where it's going, a slight lean |
     | Still, empty-handed | otherwise | smile, arms down, a blink every few seconds |

   - **Push or pull:** compare the direction of travel with the side of the piece it holds. "Its side" is the vector from the piece's centre to the dot. Travel against that vector is pushing; travel along it is pulling. A turn below a small dead zone counts as still.
   - **Blinks** come from the time and the player's number (e.g. every 3.5 s, offset by number), never from `Random`, so the host and every phone blink alike.
   - A player away is not in the snapshot. Its "zzz" face is left out; say so in the report.
   - A view built mid-round starts from what the first snapshot shows: no moment fires for it.
3. **Where the body sits.**
   - Empty-handed: on the dot.
   - Carrying: on the edge of the piece it holds, on the ray from the piece's centre through the dot, just outside the piece's outline, so it never covers a target the player is aiming at (design 5a).
   - Empty-handed, a small ring in `ink` marks the exact grab point under it.
4. **The drawing** (a `paintWorker` in a painter part file, the `layers` check allows it).
   - The body is a round `toyShape` in `player(n)`, with the player's number on its tummy in ink: players still tell each other apart without colour.
   - Two eyes, a mouth, two noodle arms (an ink stroke with a `player(n)` inner stroke) and mitten hands. All simple shapes (arcs, ovals, lines), so it reads at a phone's size and costs little with 4 players.
   - Its body is 1.3 times today's dot (`PuzzleGame.dotRadius`), and never less than 7 mm across on a phone: the view knows its `pxPerMm`.
   - Motion (hop, shake, blink, lean) follows the effects setting (D8). With effects off the faces still change, but nothing hops, shakes or blinks.
   - The mirror keeps its small dots (m12-opponent-mirror); no worker there.
5. **Cost:** no allocation per worker beyond its paths; no `TextPainter` per frame beyond the number, as `paintToyBadge` does today.
6. Files under 400 lines, functions under 60.

tests (each failing first):
- **`WorkerMoments`**, one test per row of the table above, built from two or three hand-made snapshots: the right pose for each moment. Also:
  - the order when two apply (a right drop beats carrying);
  - push and pull by travel direction;
  - the dead zone;
  - blinks deterministic by time and number;
  - no moment on a view's first snapshot;
  - effects off, still.
- **Where it sits:** the carrying body is outside the held piece's outline on the ray through the dot; empty-handed it is on the dot, with the ring.
- **Size:** 1.3 × the dot, and at least 7 mm at the phone's `pxPerMm` on the smallest phone (667 × 375) in a phones match.
- **Pixels** (as look_paint_test does), Sunny and Night: the body's middle is `player(n)`; the number's ink is there; a worker carrying a piece doesn't cover the piece's centre.
- All existing tests pass (puzzle, look, host, phone, tv).

in the report: test counts before and after; the files changed; the pose table as built, with any moment left out and why; the worker's size on the TV and on the smallest phone, in px and mm.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s4b-worker-report.md · docs/design/m12-mirror-169.png · docs/design/m12-mirror-iphone-stick.png · docs/design/m12-mirror-iphone.png · docs/design/m12-mirror-stick.png · packages/puzzle_game · packages/party_host/test · controller_app/test · tv_test_app/test
check: format analyze look puzzle host phone tv
report: docs/briefs/m13/s4b-worker-report.md
