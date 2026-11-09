# M13 12: the worker runs — a stride, feet, swinging arms, a bob and floppy ears, and a breathing idle

Shape Race's worker has a step cycle now, drawn rather than sprited: a stride phase that moves with the distance the
dot travelled (one cycle per `strideUnits`, the body's diameter), so the feet keep pace with the stick at any speed and
a 30 Hz and a 60 Hz view draw the same frame. It has two small shade ovals for feet that swing ±0.3 radius in opposite
phase and lift 0.15 in the air, arms that swing ±35° about the shoulder from `handsDown` against the feet, a body that
bobs 0.06 twice a cycle, squashes 4 % at each contact and leans into the walk, and an accessory that flops up to 8° a
quarter cycle behind the bob through a new `tiltDeg` on `paintAccessory`. The amplitude eases in over 150 ms of game
time and out over 200 ms with the phase carried on, so a stop settles the feet together rather than freezing them
apart; carrying keeps the hands on the piece and steps at 0.7 of the swing with half the bob. A standing worker
breathes 2 % taller and 1 % narrower at 0.4 Hz on the game's clock, staggered by its number, keeps its blink, and
glances left then right once every four seconds. Nothing goes in the snapshot or the protocol, the rules side has no
Flutter, and the feet stay inside the room the worker already took, so s10's field-edge test still passes.

## What a player sees differently

- An empty-handed worker walking now steps: one foot swings forward and lifts while the other goes back, the arms swing
  opposite the feet (the left arm forward when the right foot is), the body rises at the middle of each step and
  squashes at each contact, it leans into the travel, and its ears (or hat, bow, crown) flop a little after the body.
  The fixed `handsWalk` pose s10 left is gone.
- A stick pushed slowly walks slowly: the stride is worked out from how far the dot went, not from the clock, so a
  half-pushed stick takes longer steps instead of sliding.
- Letting go settles it: the feet come together over 200 ms rather than freezing apart, and the phase keeps its place,
  so walking on again carries on from where the feet were.
- Carrying, the feet step under the piece at 0.7 of the swing and the bob is half as high; the effort face and the
  sweat while shoving or dragging are as they were, and the hands stay on the piece's edge.
- Standing, it breathes (2 % taller, 1 % narrower, 0.4 Hz), still blinks, and every few seconds glances left then
  right with its eyes only. Two players on the same board are out of step in both.
- A moment (a grin, a wince, a call, the round's end) takes the arms as before, and the feet keep the phase they had.
- With the effects off, everything of this holds still and the feet are side by side (design D8).
- Every screen shows the same: the whole cycle is worked out in `WorkerMoments` from the snapshot's `timeLeftMs` and
  the dot's travel, so a TV host, a phone playing on itself and a joined phone draw the same feet.

## The cycle, rule by rule

`worker_stride.dart` (new, a `part` of `worker_moments.dart`) holds the cycle:

- **`_Walk`** — one per player, kept in `_SeenPlayer`. `note(step, elapsedMs)` adds `step.distance / strideUnits` to
  `phase` (mod 1) when the dot moved, and eases `ease` up by `elapsedMs / strideRiseMs`; when it didn't, it eases
  `ease` down by `elapsedMs / strideFallMs` and leaves the phase alone. It is called beside s10's speed hysteresis and
  is independent of it: the phase is distance, the ease is stillness, so the hysteresis (which stops a wobble
  flickering the pose) no longer decides whether there is a stride.
- **`_Step`** — what one frame draws, from `phase` and `ease`: the two feet, the bob, the contact squash and the
  accessory's tilt. `_Step.stand([phase])` is the still one (feet together, no motion), used standing and with the
  effects off.
- **`swingingHands`** — `handsDown` with each hand turned about its shoulder (the left about
  `Offset(-0.62, 0.34)`, the right about `(0.62, 0.34)`) by `±armSwingDeg`, the sign taken so the hand goes along the
  travel; the left arm uses `-cos(wave)`, the right `+cos(wave)`, which puts the left arm forward when the right foot
  is.
- **`breathAt(number, gameMs)`** — `sin(2π(gameMs + number × breathStaggerMs) / breathPeriodMs)`, ±1, from the game's
  clock only.
- **`glanceAt(number, gameMs)`** — the first 600 ms of each glance look left `Offset(-0.8, 0.15)`, the next 600 right
  `Offset(0.8, 0.15)`, else null (ahead).

The maths, in body radii and with `wave = 2π·phase`:

- foot `x` from its rest: `±0.5` plus `swing × ±cos(wave)` along the travel, `swing = 0.3 × ease` (× 0.7 while shoving
  or dragging); the two feet are always mirror images of each other about the middle (the right is the left's negative),
  so at phase 0 they are at −0.2 and +0.2, and at 0.5 — the widest — at −0.8 and +0.8.
- foot lift: `0.15 × ease × max(0, ±sin(wave))` — the foot at the middle of its forward swing.
- bob: `0.06 × ease × sin²(wave)` up (twice a cycle, half carrying).
- contact squash: `0.04 × ease × max(0, cos(2·wave))` — wider and shorter at both contacts.
- accessory tilt: `−8° × ease × sin(2·wave)`, a quarter cycle behind the bob.
- `_worker` in the painter draws arms, body, face, accessory and sweat inside a `scale(squash)` and a `translate(bob)`,
  then the feet after that `restore()` — on the ground, outside the bob and the squash, and out of the body's shadow.

## The constants

New, in `worker_stride.dart`:

- **`strideUnits` 6.76 field units** — `2 × PuzzleGame.pickupReach`, the body's diameter: the travel of one whole
  cycle, two steps (7.1 cycles a second at the top speed of 48 units/s, 3.5 at half stick).
- **`strideRiseMs` 150, `strideFallMs` 200** — how long the amplitude takes to reach 1 after the dot starts moving, and
  to reach 0 after it stops, in game time (the brief's 150 and 200).
- **`footSwingShare` 0.3** — how far each foot swings either side of its rest along the travel.
- **`footLiftShare` 0.15** — how far the foot in the air lifts at the middle of its swing.
- **`workSwingShare` 0.7** — the share of the swing a shoving or dragging worker keeps.
- **`bobShare` 0.06, `carryBobShare` 0.5** — the rise at the middle of a step, and the share of it carrying.
- **`contactSquashShare` 0.04** — how much wider and shorter the body is at each foot's contact.
- **`earFlopDeg` 8.0** — how far the accessory tilts, a quarter cycle behind the bob.
- **`breathHz` 0.4, `breathPeriodMs` 2500** — a standing worker's breath (the period is `1000 / breathHz`).
- **`breathTallShare` 0.02, `breathNarrowShare` 0.01** — how much taller and narrower at the top of a breath.
- **`breathStaggerMs` 625** — a quarter of the period between one number and the next.
- **`glanceLengthMs` 1200, `glancePeriodMs` 4000** — a 1.2 s glance every four seconds of standing (left for half of
  it, right for the other half).
- **`glanceStaggerMs` 1250** — how far each number's glance is shifted along the period.

New or changed, in `worker_pose.dart`:

- **`workerShoulderShare` (0.62, 0.34)** — where each arm's shoulder sits: the point it swings about. The painter's
  `_shoulderShare` already read it for the arm's shape, so the pose and the drawing turn about the same point.
- **`armSwingDeg` 35** — how far either arm swings either side of `handsDown`.
- **`footApartShare` 0.5** — each foot rests 0.5 radius either side of the middle; with the swing and the oval's half
  width (0.16 radius) a foot's outer edge reaches 0.96 radius, inside the body's own radius.
- **`footUnderShare` 1.3 (was 1.2)** — how far below the middle the feet rest: a foot's bottom edge is 1.46 radius
  below it, below the body's round bottom, and inside s10's `_inkShare` 2.5 for the field's edge.
- **`WorkerFoot`, `WorkerFeet`, `feetTogether`** — where one foot is and where both are; the pair a worker stands on.
- **`WorkerPose.feet`, `.stride`, `.stridePhase`, `.tiltDeg`, `.walking`** — the pose carries the cycle; `still()` puts
  the feet together and drops the tilt while keeping the phase, and `slid()` copies them all.

New, in `worker_painter.dart`:

- **`_footWideShare` 0.16, `_footTallShare` 0.16** — a foot is 0.32 radius across and tall (shares of the diameter).
- **`_footInkShare` 0.35** — the foot's ink edge is 35 % of the look's outline width, thin so a twelve-pixel foot
  keeps a solid shade middle.

In `toy_look`:

- **`paintAccessory(..., {double tiltDeg = 0})`** — degrees, turning the whole accessory about the body's middle
  before it is drawn and back after; every accessory takes it, and a crown simply tilts.
- **`toyShadeOf(colour)`** — the shade mix as a function, so a foot is the body's own darkest band; `toyShape`'s
  shader and fallback use the same mix.

Existing, used differently:

- **`walkLeanDeg` 8** — the empty-handed lean is now `walkLeanDeg × travel.dx × stride`, so it arrives and leaves with
  the stride instead of coming on whole the first walking frame.
- **`handsWalk`** is removed: `swingingHands` replaces it.

## What changed

### packages/puzzle_game/lib/src

- `worker_stride.dart` (new, 202 lines) — the cycle: `_Walk`, `_Step`, `swingingHands`, `breathAt`, `glanceAt` and
  their constants; a `part` of `worker_moments.dart`, no Flutter beyond the `Offset` the moments already use.
- `worker_moments.dart` (351) — `part 'worker_stride.dart'`; `_SeenPlayer.walk = _Walk()`, advanced in `note()` beside
  `_noteWalking` inside the `elapsedMs > 0` guard, so a repeated snapshot still changes nothing.
- `worker_frames.dart` (345) — `_step(effects)` builds the frame's `_Step` (or `_Step.stand(phase)` standing and with
  the effects off); a `travel` getter; `_posed` lays the step's feet, bob, squash, tilt, `stride` and `stridePhase`
  under a moment's face, hands, look, lean and motion (so a moment overrides the arms and the feet keep their phase);
  `_empty` picks `_walk` or `_standing` by the ease; `_walk` uses `swingingHands` and the eased lean; `_standing` reads
  `breathAt` and `glanceAt` from the game's clock when the effects are on.
- `worker_pose.dart` (230) — the feet, the shoulders and the arm swing, `stride`/`stridePhase`/`tiltDeg`/`walking`;
  `still()` and `slid()` updated; `handsWalk` removed.
- `worker_painter.dart` (349) — `_workerFeet` draws two `drawOval`s in `toyShadeOf(colour)` with the ink edge, after the
  body and outside its bob and squash; the new `_foot*` shares; `paintAccessory` is given `pose.tiltDeg`.

### packages/toy_look/lib/src

- `toy_accessory.dart` (234) — `paintAccessory`'s `tiltDeg`, a save/rotate about the body's middle around the switch.
- `toy_shape.dart` (125) — `toyShadeOf(colour)`, the shade mix the shader and fallback already had.

### packages/puzzle_game/test

- `worker_stride_test.dart` (new, 298, 14 tests) — the cycle, the feet, the arms, the bob, the carrying stride, the
  idle and the effects off. Its `Walker` feeds a running game's snapshots to its own `WorkerMoments` (17 or 33 ms a
  snapshot, the game's clock losing that time); `walkedTo(phase)` fills the ease with ten half-speed snapshots and then
  jumps a few whole strides, which is allowed because the phase counts distance only.
- `worker_feet_paint_test.dart` (new, 79, 1 test) — a frame at four phases in Sunny and Night, reading the pixels within
  `footGap` 20 of `toyShadeOf(workerColour(look))` in a band from −1.2 to 1.2 radii across and 1.2 to 1.8 down: at
  least 25 such pixels at each phase, and at least 30 pixels different between any two phases.
- `worker_run_png_test.dart` (new, 63, 1 test) — writes the strip (below).
- `support/worker_run.dart` (new, 149) — the cell the two painting tests share: a 60 × 34 field at 8 image px a unit,
  drawn 480 × 272 at pixelRatio 2, one big crate for the carrying row; `RunWalker` feeds the moments the dot running
  right on 17 ms snapshots but hands the painter the dot at a fixed `cellDot`, so every frame of the strip lines up.
- `worker_moments_test.dart` (499) — two changed assertions, no change of meaning: `_walking(pose) => pose.walking`
  (the s10 tests read the hysteresis flag; `stride` is now the eased amplitude, not a yes/no), and 'walking
  empty-handed: a smile and swinging arms' compares the lean with `walkLeanDeg × walking.stride` instead of `walkLeanDeg`,
  because the lean now comes on with the stride (one snapshot in, it is part way).
- `worker_paint_test.dart` — the smallest-phone test's "as wide as it is tall" tolerance 1.5 → 2.5 image px: a standing
  worker now breathes, so a frame can catch it up to 2 % taller than it is wide (2 × 47 px, about a pixel a side).

### docs/design

- `m13-worker-run.png` (new) — the strip.

## Tests: before and after

- Puzzle: **194 before, 210 after** (+16: 14 stride, 1 feet painter, 1 strip). Look 111 (unchanged), host 240, phone
  433, tv 53 (+1 skipped), arena 66, kit 48 — all as before.
- Failing first: with `return;` the first line of `_Walk.note` (phase and ease never move) **11 of the 15** new cycle
  and painting tests fail — the four cycle tests (one cycle per `strideUnits` at 17 and 33 ms, the phase standing
  still, carrying on after a stop, the 150/200 ms easing), the mirrored feet, the lifted foot, the arms, the bob, the
  carrying stride, the effects-off test (it asserts a stride while walking) and the feet painter. The 4 that pass are
  the idle ones, which don't need the cycle: 'standing, the feet rest side by side under the body', 'a standing worker
  breathes…', 'two players are out of step' and 'the glance comes and goes…'. The probe was removed again.
- The computed values the tests hold: `stridePhase` 0.4 after 0.4 × `strideUnits` of travel (at both 17 and 33 ms);
  `stride` 0.5 at 75 ms of walking, 1 at 150, 0 after 210 of standing; feet −0.2/+0.2 at phase 0 and −0.8/+0.8 at 0.5;
  hands left −1.236 at 0 and −0.708 at 0.5, right +1.236 at 0 and +0.708 at 0.5; `motion.dy` −0.06 at 0.25 and
  0.75 and −0.03 carrying; the pushed foot at 0.5 − cos(2π·0.45) × 0.3 × 0.7 = 0.6997; squash (0.99, 1.02) at the top
  of a breath and (1.01, 0.98) half a breath later.
- `tools/review.sh`: **0 fail, 7 note** (three file sizes — `worker_frames` 345, `worker_moments` 351,
  `worker_painter` 349 — and four numeric literals on lines that were already numbers: 0.4 and 0.3 in
  `worker_frames.dart`, −0.8 in `worker_stride.dart`'s glance, 180 in `toy_accessory.dart`'s degrees-to-radians). No
  function over 60 lines and no lib file over 400 (the largest new function is `_Step.of`, 27 lines).
- `tools/check.sh` itself was refused by this session's sandbox ("This command requires approval"), so each check it
  runs was run on its own: `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages
  assets` (537 files, 0 changed), `dart analyze --fatal-infos` (no issues), and `flutter test` in each package (the
  counts above).

## The strip

`docs/design/m13-worker-run.png` (3936 × 584) is written by `worker_run_png_test.dart`, from the painter, in Sunny,
with the look's own fonts, in two rows of eight cells (480 × 272 each, pixelRatio 2): the top row walks empty-handed and
the bottom row shoves the crate it carries, each cell labelled 1/8 to 8/8 with the phase it is drawn at (0, 0.125, …,
0.875). The two rows show the same eight phases twice — the brief asks for both "empty-handed, then carrying" and one
cycle of eight frames; if a single row of eight that switches in the middle is wanted instead, say so. Between cells
only the phase changes: the dot the painter draws is at the same place in every cell, and the moments were fed the dot
walking right at half the top speed, so the feet, the arm swing, the bob, the contact squash and the flop can be read
in order.

## Self-check (docs/review-rules.md part A, items 1–5)

1. **Every host setup:** not affected — the whole cycle is worked out in `WorkerMoments` from the snapshot's game time
   and the dot's travel, nothing is added to the snapshot or the protocol, so the TV/PC host, a phone on "Play on this
   phone", a phone on "Show on this device" and a joined phone draw the same worker, and a build one older simply draws
   s10's worker (it has no feet and ignores the new pose fields). Shown by `worker_stride_test` (poses from snapshots
   only), `worker_feet_paint_test` and `worker_run_png_test` (drawn frames), and host 240/phone 433/tv 53 passing.
2. **When kept state starts and ends:** `_Walk` starts at phase 0, ease 0 with a player's first snapshot; it moves only
   when the game's clock moved (`elapsedMs > 0`) and the dot moved; a stop settles the ease to 0 over 200 ms and keeps
   the phase; it ends with the player (`_SeenPlayer` per board) and with a new round (`_BoardWorkers` on a puzzle id
   change); with no round, or a paused round, no snapshot arrives, so nothing runs and the breath and glance hold.
   Tests: 'the phase stays put while the dot stands', 'after a stop the walk carries on from where the phase stopped',
   'the stride eases in over 150 ms and settles over 200 ms', 'standing, the feet rest side by side under the body'.
3. **How it combines with the other states:** no new state and no new owner — a round's pause and phase stay
   `Pausable`'s, and this only reads `timeLeftMs`; the moments still win the arms and the feet keep their phase (the
   happy/oops/call/round-end tests in `worker_moments_test`, which now thread a `_Step`), and the effects off gives the
   still pose with the feet together (`worker_stride_test`'s effects-off test). Results, pause, away and leaving are
   untouched, and the host and phone suites pass.
4. **Stay in the job's folder:** written only in `packages/puzzle_game`, `packages/toy_look`, this report and the PNG.
   `git status --short` also shows the three `docs/design/m12-mirror-*.png` the puzzle tests rewrite (Q2) and
   `tv_test_app/windows/flutter/generated_*`, which no edit of mine touches (Q3).
5. **Stop rather than overstep:** two things the sandbox would not let me do, both reported rather than worked round —
   `git checkout -- docs/design/m12-mirror-*.png` (Q2) and `tools/check.sh` (Q1).

## Questions and suggestions

1. **`tools/check.sh`.** The sandbox refused it ("This command requires approval"), so I ran exactly what it runs, one
   command at a time (format, `dart analyze --fatal-infos`, and `flutter test` per package). Run
   `tools/check.sh format analyze look puzzle host phone tv` once before committing to confirm the same.
2. **The mirror PNGs.** `packages/puzzle_game/test/mirror_png_test.dart` rewrites `docs/design/m12-mirror-iphone.png`,
   `-iphone-stick.png` and `-169.png` on every puzzle test run, and their bytes change now (the worker has feet). The
   brief asks for `git checkout -- docs/design/m12-mirror-*.png`; this session's sandbox refused `git checkout`, so
   they are still the rewritten bytes. Restore them before committing, or commit them as rewritten (s10's report took
   the second way).
3. **The tv Windows files.** `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
   `generated_plugins.cmake` are dirty in the tree; this job never edits `tv_test_app`, and they change on a Flutter
   tool run. Not mine to commit — check before committing.
4. **A suggestion for later:** `worker_moments_test.dart` is 499 lines, one under the 500 limit for tests. The next test
   that lands there needs the "walking is a speed" group moved out (e.g. `worker_walk_test.dart`), as
   `worker_stride_test.dart` already holds the cycle.
5. **A suggestion, not acted on:** the feet are drawn `_footWideShare` 0.16 of the body's diameter; the doc comment
   said "radius", which was wrong, and I corrected the comment only. If 0.16 reads a little small on a phone, it is
   one constant, but it would push a foot's outer edge past the body's own radius (0.96 today) if it grows much.
6. **The strip's shape:** two rows of eight phases rather than eight frames that switch from empty-handed to carrying
   in the middle. Say if you would rather look at the second form.

## Commit message

Shape Race: the worker runs, with feet, swinging arms and a floppy hat

The worker's walk is a step cycle now. Its phase moves with the dot's travel (one cycle per `strideUnits`, the body's
diameter), so the feet keep pace at any speed and a 30 Hz and a 60 Hz view draw the same frame. Two shade ovals for
feet swing ±0.3 radius in opposite phase and lift 0.15 in the air; empty-handed arms swing ±35° about the shoulder from
`handsDown` against the feet; the body bobs 0.06 twice a cycle, squashes 4 % at the contacts and leans into the walk;
the accessory flops up to 8° a quarter cycle late, through `paintAccessory`'s new tilt in toy_look. The amplitude eases
in over 150 ms and out over 200 ms of game time with the phase kept, so a stop settles the feet together; carrying
steps at 0.7 of the swing with half the bob, its hands on the piece; and a standing worker breathes 2 %/1 % at 0.4 Hz,
blinks and glances left then right every four seconds, staggered by its number. Moments override the arms and the feet
keep their phase; with the effects off nothing moves and the feet are side by side. Puzzle tests 194 → 210; look 111,
host 240, phone 433, tv 53, arena 66, kit 48 green; format, analyze and review.sh (0 fail) clean.

## Status row

M13 12: the worker walks with a distance-driven stride (feet, swinging arms, a bob, contact squash, a lean and a floppy accessory), eases in and out over 150/200 ms, steps at 0.7 carrying, and a standing one breathes, blinks and glances on the game's clock, staggered by number, all from the snapshots with nothing added to them; open: the m12 mirror PNGs need `git checkout` before the commit and the tv Windows plugin files are dirty in the tree (Q2, Q3).

## Delete

- Nothing. (The failing-first probe — a `return;` at the top of `_Walk.note` — was removed again; there is no scratch
  test or trace file.)

## Claude's review (Nov 9, 2026)

Accepted, with Claude's change to the feet. All checks are green (puzzle 211, look 111, arena 66, host 240, phone 433, tv, kit), and review.sh has no FAIL. Applied by hand (flash held it for the rewritten mirror PNGs); a second copy of this job, started by mistake, was stopped before it finished.

- **The feet:** in the strip, a sixth of the body wide and a third of a radius below it, they read as floating dots, not feet. They're now little shoes: `footWideShare` 0.26 × `footTallShare` 0.17 of the body's diameter, apart 0.45, their middles 0.95 radii down, so their tops tuck under the body. They live in worker_pose.dart beside their placement, and the ink edge is 0.5. Test-first in worker_stride_test. The feet paint test's band and the tummy test's box follow the new feet.
- **Q2:** the mirror PNGs are committed as rewritten (the worker has feet now).
- **Q4:** noted for the next worker test.
- **Q6:** two rows is fine.
- **For the owner's device check:** the run at full and half stick, carrying, standing, and the feet's size on a small phone.
