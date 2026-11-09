# M13 4b: the worker

Shape Race's player dot is a round worker now — a body in `player(n)` with the player's number on its tummy, two
eyes, a mouth, two noodle arms with mitten hands — on the TV/PC host, on a phone playing its own side and on a joined
phone alike. Its face and body are worked out by a new rules-side `WorkerMoments`, which reads only the snapshots and
the view's clock; nothing in the rules, the protocol or the snapshot changed.

## What changed

### packages/puzzle_game/lib/src

- `worker_moments.dart` (new, 232 lines): `WorkerMoments(puzzle)`, fed each snapshot with its time (`observe`), answering
  `WorkerPose poseOf(board, number, nowMs, {effects})` and `static bool blinks(number, nowMs)`. `board` is an index,
  as `PieceMoments.ageMs`'s is (question 1). It keeps per board a `_BoardWorkers` (the last snapshot, the pieces' last
  states, and a `_SeenPlayer` per number: last position, travel, the held piece's last angle, when its own drop landed
  right or wrong, and which side of the held piece it is on). The first snapshot for a board only seeds it, and a new
  puzzle id reseeds it. This file also holds the moment lengths and the geometry tolerances
  (`happyMomentMs` 500, `oopsMomentMs` 600, the blink's 150/3500/700, `movingUnits` 0.25, `sideUnits` 0.5,
  `sideDeadZoneDeg` 20, `turnDeg` 0.1). A rules-side file: `dart:ui` for `Offset`, no Flutter, no toy_look (the same
  import `puzzle.dart` and `puzzle_values.dart` already take).
- `worker_pose.dart` (new, 126 lines): the value the view draws — `WorkerFace` (smile, effort, call, oops, happy,
  blink), `WorkerHands`, `WorkerPose` (`at`, `away`, `onDot`, `face`, `look`, `leanDeg`, `squash`, `motion`, `hands`,
  `sweat`) with `WorkerPose.on(dot)` for a view with no moments, `still()` (the pose with the effects' motion taken out,
  D8) and the shape constants it describes (where the hands rest for each moment, the hop, the shake, the leans, the
  squashes). `worker_moments.dart` exports it, so `puzzle_game.dart` and every existing import still see `WorkerPose`.
- `worker_frames.dart` (new, 280 lines): `part of 'worker_moments.dart'` — `_Frame` gathers one worker's pose from the
  last snapshot and builds it: the order of the moments, where it stands, which side of its piece it is on, shove or
  drag, and the shape of each pose. A part because it needs the same library's private `_SeenPlayer`; parts are the
  package's own pattern for the painters, and `tools/review.sh` allows a part with no imports. Three files rather than
  one because the one file was 637 lines, over the 400 limit.
- `worker_painter.dart` (new, 315 lines): `part of 'view.dart'` — `_paintWorkers` (the loop `_dot` used to be), and
  `_worker`: the ink ring at the grab point when empty-handed, the body as a round `toyShape` in `player(n)` with the
  look's outline width and shadow, the two arms (an ink stroke with a `player(n)` inner stroke and a mitten hand each),
  the face (`_Face` holds the eyes' places and the stroke width; one small function per face), and the number in
  `look.type.title` in ink, one `TextPainter`, as `paintToyBadge` did. Per worker: about 15–20 draw calls (the ring,
  the body's fill and edge, 2 arms × 2 strokes, 2 mittens × 2, the eyes and mouth, the number), so under 80 with 4
  players, and no `TextPainter` beyond the number.
- `view.dart`: `PuzzleView` and `MatchView` each keep a `WorkerMoments(widget.puzzle)` and note every snapshot in
  `initState`/`didUpdateWidget` with their clock's time, as they already did for `PieceMoments`; both pass it down.
- `puzzle_painter.dart`: takes `workers` and `pxPerMm`; the dot loop became `_paintWorkers` and `_dot` is gone.
- `match_painter.dart`: passes `workers` to both paths, and `pxPerMm` in the phone-panel path, where a phone's own
  millimetres decide the worker's floor.
- `puzzle_game.dart`: exports `src/worker_moments.dart` (and with it `src/worker_pose.dart`).

The mirror is untouched: `mirror_painter.dart` still draws its small dots and nothing there draws a worker.

### packages/puzzle_game/test

- `worker_moments_test.dart` (new, 305 lines, 20 tests): one per row of the table below, then the order (a right drop
  beats carrying), push and pull by travel, the dead zone (19° carries, 21° pulls), blinks by time and number (and the
  same on a second view), no moment on a view's first snapshot, where the body sits (empty-handed, carrying, a small
  piece), and effects off.
- `worker_paint_test.dart` (new, 238 lines, 5 tests): the body is 1.3 × the dot, measured left and up from its middle
  in Sunny and in Night; the body's middle is `player(1)` and its tummy has the number's ink; an empty-handed worker
  stands on its grab point with a hollow ink ring round it; a carrying worker leaves the crate's middle and the grab
  point clear and stands 1.35 radii outside the piece's edge; on the smallest phone a worker is 7–8 mm across.
- `_worker_measure_test.dart` (new, 103 lines, 2 tests, **scratch**): prints the layouts, scales and the printed sizes
  below. It is in Delete.

### docs/design

- `m12-mirror-169.png`, `m12-mirror-iphone.png`, `m12-mirror-iphone-stick.png` show as modified in `git status`
  because `mirror_png_test` rewrites them every time the puzzle tests run; this job does not touch the mirror's
  drawing. `m12-mirror-stick.png` came out byte-identical. They are in `allow:` and were not edited by hand.

## Test counts

| target | before | after |
| --- | --- | --- |
| look | 88 | 88 |
| puzzle | 144 | 171 (+25: 20 moments, 5 pixels) |
| host | 197 | 197 |
| phone | 403 | 403 |
| tv | pass | pass |

The 171 includes the 2 scratch tests; without them the package is 169.

## The pose table as built

Checked in this order; the first that applies wins.

| Moment | When | Face | Body, arms, motion |
| --- | --- | --- | --- |
| Right drop | the piece it held a snapshot ago turned `locked` within 500 ms | happy (eyes shut, curved up) | arms up, squashed 0.94 × 1.07, a hop 0.18 radii high, one sine over the 500 ms |
| Wrong drop | the piece it held a snapshot ago turned `wrong` within 600 ms | oops (eyes shut, curved down, a flat mouth) | one hand up at its head, a sweat drop, looking down |
| Round won | the board's phase is `finished` | happy | arms up, squashed, hopping once a second |
| Round lost | the board's phase is `timeUp` **or `stopped`** | oops | hands shrugged out either side, looking up |
| Calling | it holds a piece whose `calling` is on and it is **not** moving | call (eyes open, mouth a wide "o") | one hand up waving ±0.15 radii at 2 Hz, looking at the piece |
| Rotating | its held piece's angle moved more than 0.1° since the last snapshot | effort (eyes screwed shut, a flat mouth) | hands on the piece, squashed 1.13 × 0.87, looking at it |
| Big piece alone, moving | `calling` **and** moving | effort | hands on the piece, squashed, a sweat drop, shaking 0.05 radii at 9 Hz |
| Big piece with a teammate | the piece has more than one holder | smile | both hands on the piece, looking at it |
| Pushing | it holds a piece, moved 0.25 units, and travels against its side by more than 20° | effort | leaning 12° toward the piece, hands on it, squashed |
| Pulling | the same, travelling along its side | effort | leaning 14° away from it, arms stretched back to it, squashed |
| Carrying, still | it holds a piece and didn't move | smile | hands on the piece's edge, looking at it |
| Moving, empty-handed | it moved more than 0.25 units since the last snapshot | smile | eyes look along the travel, leaning 8° × the travel's x, arms swinging |
| Still, empty-handed | otherwise | smile; a blink (eyes shut) for 150 ms of every 3.5 s, each number 700 ms along | arms down |

Two rows of the brief's table can't both fire: `piece.calling` **is** "a big piece carried alone"
(`puzzle_carry.dart:41`, `piece.calling = alone`), so "Calling" and "Big piece alone, moving" share one condition. They
are split by movement: standing still with a calling piece waves; moving with one strains (question 2).

A race's loser gets `PuzzlePhase.stopped`, not `timeUp` (the brief names `finished` and `timeUp`). Every phase that is
not `playing` ends the round: `finished` cheers, `timeUp` and `stopped` shrug, both tested (question 3).

## Left out: the away player's zzz face

The design's row "Player away | eyes closed, faded, zzz" is **not drawn**. An away player is not in the snapshot at
all (`PlayerView` has no away marker; the board's `players` simply lacks that number), and this job may not add one
(rule 1). A worker whose number is not on the board is not drawn, and `poseOf` for a number the board doesn't hold
answers a still worker at the field's corner, which no view asks for.

## Where the body sits

- Empty-handed, `at` is the dot, `away` is up, and `onDot` is true, so the painter draws a small ink ring at the grab
  point with the worker's feet just above it (the body's middle is 1.35 radii up, so the ring shows).
- Carrying, `at` is where the ray from the piece's middle through the dot leaves the piece's outline (a circle's
  radius, else a ray–polygon hit on the shape the puzzle gives, turned by the piece's angle), and `away` is that ray.
  For the test's crate at (60, 45) with the dot at (55, 45) that is the left edge at (55, 45); the body's middle is
  1.35 × 3.38 = 4.56 field units further out. A small piece has its dot on its middle, so the ray is undefined: the
  worker uses the side it first took up with the piece (the reverse of its first move), and that is cleared when it
  lets go (question 4).
- Push or pull: travel against that side is a push (leaning in), along it a pull (leaning back), and anything within
  20° of sideways is a plain carry.

## Blinks

`(nowMs + number × 700) % 3500 < 150`, read from the clock, never from `Random`, so every frame and every device agree
at the same time value. The clock is each view's own `Stopwatch`, as `PieceMoments`' is, so two devices blink at the
same phase only to within their start-up difference (question 7). With the effects off a standing worker doesn't
blink, and nothing hops, shakes or leans; the faces still change.

## The worker's size

The body's radius is `1.3 × PuzzleGame.dotRadius` = 3.38 field units, so 6.76 units across against the dot's 5.2 — and,
where the view knows its millimetres, never less than 3.5 mm (7 mm across) in the phone's own px.

| Where | Scale | Dot across | Worker across |
| --- | --- | --- | --- |
| TV/PC host, 1920 × 1080 | 12 px a unit | 62.4 px | **81.1 px** |
| TV/PC host, 1280 × 720 | 8 px a unit | 41.6 px | **54.1 px** |
| Smallest phone, 667 × 375, a race's side | 3.68 (tree) / 4.72 (rocket) / 4.24 (house) / 4.66 (boat) px a unit | 19.1 / 24.5 / 22.0 / 24.2 px | without the floor 24.9 / 31.9 / 28.6 / 31.5 px = 3.95 / 5.06 / 4.55 / 5.00 mm; **with the floor 44.1 px = 7.0 mm** |

At `pxPerMm` 160/25.4 = 6.299 px a mm, 7 mm is 44.09 px, so the floor binds in all four puzzles on that phone and the
body is 7.0 mm across before its outline: measured across including the look's ink edge it is between 7 and 8 mm, as
wide as it is tall (the paint test pins both). The TV gets no `pxPerMm` — at 81 px the floor is nowhere near.

## Pixels and what they pin

The paint tests draw a 640 × 360 box at twice its size (8 image px a field unit) in Sunny and in Night:

- the body's middle is exactly `player(1)` (a colour gap of 0), and its width and height measured from that middle are
  60 image px against the 54.08 + 6 the dot's 1.3 share and the look's outline call for (within 2 px each way);
- the tummy box around the number holds ~490 ink px in Sunny and ~497 in Night (the test asks for more than 20);
- an empty-handed worker's grab point itself is `board` — the ring is hollow — with ink within 12 × 12 px just right of
  it;
- a carrying worker leaves the crate's middle and the grab point in the crate's own `AA7744`, and its body's middle is
  `player(1)` at the computed point 1.35 radii outside the piece's edge, with no ring;
- on the smallest phone the body's middle is `player(1)` where the floor puts it, and the same frame shows that without
  the floor the worker would be under 7 mm.

## Rules and cost

- Nothing in the rules changed: no new field, message or snapshot value, and the grab point, reach, speed and
  tolerances are the files they were. `puzzle_module_test`, `puzzle_session_test` and `rules_test` pass untouched.
- `worker_moments.dart` allocates per `poseOf` call (one `_Frame` and one `WorkerPose`), as `PieceMoments` does per
  query; the painter allocates a few paths and small point lists per worker per frame, the same order of cost as the
  badge it replaced, and grows with the players the snapshot holds, never with history.
- `tools/review.sh`: 0 fail (the notes it prints for the new files are numeric literals and one file at 315 lines
  against the 300-line aim; the 400-line limit holds).
- No file over 400 lines, no function over 60 (the face is six small functions).

## Self-check, review rules part A

1. **Every host setup.** One `paintWorker` reads one `WorkerPose` on every path: the TV/PC host, a phone on "Play on
   this phone" (`play_view` → `MatchView`), a phone on "Show on this device" (the same `MatchView`) and a joined phone.
   The only thing that differs is `pxPerMm`, which the phone-panel path passes and the whole-screen path doesn't, and
   nothing reads a platform or a size. `worker_paint_test` draws both the plain view and a phones match at 667 × 375;
   `mirror_test`, `mirror_place_test`, `match_test` and `view_test` pass unchanged, so the mirror and a joined phone
   draw as before, and nothing in the protocol moved, so an older build plays unchanged.
2. **When kept state starts and ends.** `WorkerMoments` starts empty when the view builds; the first snapshot for a
   board only seeds it, so no moment fires (`worker_moments_test`, "no moment on a view's first snapshot"); a new
   puzzle id replaces the board's notes rather than adding to them; a player that lets go drops its side and its held
   angle in `_SeenPlayer._noteHeld` (by construction, not separately tested); and it holds no timer, so nothing runs
   when there is no round — the round rows change only when the phase in the snapshot changes (both tested).
3. **How a new state combines with the others.** The worker adds no state that pauses, hides or waits: it is a drawing
   of the snapshot plus the effects flag. A pause is a snapshot whose pieces don't move, so no moment fires (a paused
   piece is `held` and unmoving — "carrying, still"); a player away is absent from `players` and not drawn; a dropped
   link shows the last frame's pose, which needs nothing. The effects off pair is tested (no hop, shake, blink or lean,
   faces kept), and the game still owns the phase (`PieceMoments` and this class only observe).
4. **Stay in the job's folder.** Every file written is under `packages/puzzle_game` (7 lib files, 3 test files) or is
   this report, all in `allow:`. The three `docs/design/m12-mirror-*.png` and the three
   `tv_test_app/windows/flutter/generated_*` files `git status` lists were not written by hand: the PNGs are rewritten
   by `mirror_png_test` on every test run, and the generated files changed line endings when the checks ran
   `flutter pub get` in that app.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`. The brief's own table contradicts the code in
   two places (calling *is* alone; a race's loser is `stopped`) and its "its side" is undefined for a small piece's
   dot; those are questions 2, 3 and 4. The 7 mm floor's reach and the effects clock's per-device phase are questions 6
   and 7.

## Questions

1. **`poseOf(board, …)`'s `board`**: I read it as the board's index (0 the left of a race, else the one board), as
   `PieceMoments.ageMs(board, piece, nowMs)` does. If you meant the snapshot itself, it is a small change.
2. **Calling against big-alone**: `piece.calling` is set to `alone` (`puzzle_carry.dart:41`), so the two rows of the
   table are one condition. I split them by movement (waving when still, straining when moving). If "big piece alone"
   should also cover a small piece carried alone — which never calls — the condition wants to be
   `holders == 1 && the piece is big`, and I would need to know whether a small piece's solo carrier should strain.
3. **A race's loser**: the brief says `finished` or `timeUp`, but the side that loses because the other finished is
   `stopped`. I treat every phase but `playing` as the end of the round. Say if `stopped` should cheer, shrug
   differently, or not count.
4. **"Its side" for a small piece**: a small piece's dot is its centre, so the vector from the centre to the dot is
   zero. I use the dot's offset when it is more than 0.5 units off the middle, else the side the worker first took up
   with the piece. The alternative is to keep the previous frame's side (what I do) or to call every small piece's
   carry a carry.
5. **Drawing details I did not draw**: the tongue out while rotating, a "determined" mouth while carrying still and a
   focused "o" mouth for two holders. Six faces are shared between the thirteen rows (rotating and two holders reuse
   `effort` and `smile`), because each new face is a new function in the painter. If those three need their own faces,
   it is a small follow-up.
6. **The 7 mm floor's reach**: it applies where a view knows `pxPerMm` — a phones match's panels and `PuzzleView`/
   `PlayView` (both take it). A whole-screen *match* on a phone ("Show on this device", `target: screen`) passes none,
   so its workers are 1.3 × the dot with no floor. One word to change in `match_painter._screen` if you want it; the
   brief's test asks only for the phones match, so I left it.
7. **Blink phase between devices**: each view blinks from its own `Stopwatch`, so the host and a phone agree at the same
   clock value but not to the frame (two views started minutes apart are at different phases). Sharing it would need a
   field in the snapshot, which rule 1 forbids. It is invisible in practice; say if the design wants the host's clock.
8. **The body's stand-off**: the brief says the body sits "on the dot" empty-handed. I put its middle 1.35 radii above
   the dot so the ink ring shows under its feet; centred exactly on the dot the ring would be hidden behind the body.
   Say if the ring should instead be drawn at the feet.

## Commit message

M13 4b: Shape Race's dot is the worker

The player's dot is a round worker now — a body in player(n) with the player's number in ink on its tummy, two eyes, a
mouth, noodle arms with mitten hands — on the host, on a phone's own side and on a joined phone. A new rules-side
WorkerMoments works its pose out of the snapshots alone (right and wrong drops, the round's end, calling, turning, a
big piece alone or with a teammate, shoving and dragging by travel against its side, carrying, walking, standing with
a blink), so nothing was added to the rules, the protocol or the snapshot. The body is 1.3 times the dot, at least 7 mm
across on the smallest phone, sits on the piece's edge while carrying so it never covers a target, and its hop, shake,
lean and blink follow the effects setting while its faces still change.

## Status row

M13 4b: Shape Race's player dot is the worker on the host, a phone's own side and a joined phone (a rules-side WorkerMoments with thirteen moments, a paintWorker drawing in player(n) with eyes, arms, mitten hands, effort faces and a number, 1.3 × the dot and at least 7 mm on a phone, sat on the held piece's edge, motion following the effects setting); open: the away player's zzz face is not drawn (no away marker in the snapshot), three design details are not drawn (tongue, "determined" mouth, focused "o"), and the whole-screen match on a phone has no 7 mm floor (questions 5 and 6).

## Delete

- packages/puzzle_game/test/_worker_measure_test.dart

## Claude's review (Nov 8, 2026)

Accepted, with one change (test-first), after Claude rendered the worker still, walking, pushing, pulling, after a wrong drop and after a right drop, in the look's real fonts:

- **The tummy's number was a thin scratch** across the body's bottom edge (0.7 of the radius, centred 0.66 radii down), and it is how players tell each other apart without colour. It is now 0.95 of the radius, centred 0.56 radii down, between the mouth and the bottom edge.
  - New worker_number_test.dart, in Fredoka: the digit covers more than 15 % of the tummy band. It was 11 %.
  - worker_paint_test now loads the look's fonts too, because the test font's solid digit boxes reached the body's middle once the number grew.

Answers to the questions:
1. **`board`** is the index, as you read it.
2. **Calling versus big-alone**: split by movement, as built.
3. **`stopped`** shrugs like `timeUp`, as built.
4. **A small piece's side**: keep the side it first took, as built.
5. **The three faces not drawn** (the tongue while rotating, the determined mouth carrying still, the "o" with a teammate) are a small follow-up for step 9's polish. The reused faces read correctly.
6. **The 7 mm floor on "Show on this device"**: leave it. The TV and that mode share the whole-screen path and the view can't tell them apart. A phone's whole match draws the worker about 5.7 mm across, which reads. Step 9 checks it on a device.
7. **Per-device blink phase**: fine.
8. **The body standing above the dot** with the ring at its feet: fine.

Counts after the review: puzzle 170, look 88, host 199, phone 403, tv 50 (+1 skipped).
