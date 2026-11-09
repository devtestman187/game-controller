# M13 10: the worker walks on the game's clock, and nothing held is cut at the field's edge

Shape Race's worker now decides walking from a *speed* worked out on the snapshot's own clock, with hysteresis, so a
stick held part-way no longer flickers it between walking and standing, at 60 or 30 Hz or with a snapshot seen twice.
Its place round a held piece eases at no more than 360°/s instead of being taken raw from one snapshot's signal, so a
straight carry no longer swings the body round the piece. And both sides of the field's edge are fixed: the rules keep
a held piece's whole turned outline inside the field (the dot with it, a team piece's carriers too), and the painter
slides or flips a worker at the edge inward, so nothing of a player's needs the field's clip. No Flutter in the
moments, no snapshot or protocol change: the host, a phone playing its own side and a joined phone draw the same pose.

## What a player sees differently

- The worker walks when it walks and stands when it stands, once: no arm/lean/squash flicker at half stick, no
  difference between a 30 Hz and a 60 Hz view, and no stand on a frame with no new snapshot.
- Carrying a piece, the body stays on one side of it — behind the way it walks, or on the ray from the piece's middle
  through the dot while a big piece's grab holds the dot off its middle — and turns that side at most a full turn a
  second. The slide from below-left to above to the right of the door in the owner's recording is gone.
- At rest the drawn body holds still: it no longer alternates between a pushing lean and a carrying one every frame.
- A carried piece stops with its whole turned outline inside the field, the dot with it: no half circle at the left or
  right edge, nothing cut by the clip. Turning a piece flat against the edge pushes it inward as the outline widens.
- A worker at the field's edge is slid inward (or, holding a piece, flipped to the piece's other side when a slide
  would leave the arms detached), so a body, ear or mitten is never cut by the field's edge.
- Everything else is as it was: targets still lock (including one touching the board's edge), tray pieces don't move,
  and the field clip stays for the TV's two boards.

## The causes

### The side swing

`side` was taken from one snapshot at a time and written straight into the pose, with nothing between snapshots:

- `side = ray / ray.distance` whenever `ray` (the dot minus the piece's middle) was longer than `sideUnits` (0.5).
  But that ray is not the side the worker chose: it is wherever the dot happens to sit in the piece, and it stays put
  only while the dot and the piece move together. It changes whenever the piece stops without the dot (a piece pushed
  into the field's edge, a big piece pressed against the board), turns, or is moved by a teammate. Each change jumped
  the body by up to a half turn in one frame.
- With the dot at a small piece's middle, `side = -travel` was taken from *one* frame's travel and latched for good
  (`side == null && moved`), so one wobbling snapshot could set the side 180° from where the walk then went.

So the body's place round the piece was whatever the last snapshot's signal said, and the two signals swapping as the
ray crossed half a unit gave the slow swing round the door over two seconds of straight walking. Now the side is seeded
once, from the ray at the pickup, and eased toward its target (`ray`, else `-travel`) by at most `sideTurnDegPerS` of
game time per snapshot: the target may still be noisy, the body's turn cannot be, and `travel` is a short average
(`travelAverageMs`) so a wobble doesn't move it either.

### The rest flip-flop

`moved = distance > movingUnits` (0.25 units) was a *distance between two snapshots*, not a speed, and it was
recomputed on every snapshot. A snapshot seen twice has a distance of 0, and a stick held part-way gives a distance
that hovers round the threshold, so `moved` alternated. `moved` drives the arms' swing and the lean: holding a piece
it chose the carrying lean one snapshot and the pushing lean (12°) the next, and the lean moves the drawn body — the
0.7 px alternation in the recording. Now `walking` comes from a speed on the game's clock with 15 %/8 % hysteresis and
a 120 ms stop, and a repeat (no game time between the snapshots) changes nothing at all.

## The constants

- **`walkStartShare` 0.15, `walkStartSpeed` 7.2 units/s** — 15 % of `PuzzleGame.speed` (48): a stick pushed this far
  reads as walking, as the brief suggests.
- **`walkStopShare` 0.08, `walkStopSpeed` 3.84 units/s** — 8 % of it: a gap wide enough that a stick resting round
  10 % cannot flicker, and a walk at 12 % still walks.
- **`walkStopMs` 120** — about two frames at 60 Hz, so a stick that dips for a frame doesn't stand the worker; the
  brief's ~120.
- **`travelAverageMs` 80** — a short average: five frames at 60 Hz kills a stick's wobble, and a real change of
  direction turns `travel` within a fifth of a second.
- **`sideTurnDegPerS` 360** — a full turn a second: a quarter turn (from the walk's side to the ray's) takes 0.25 s,
  which reads as a step round the piece rather than a jump.
- **`_sideSlideShare` 0.6** — a slide longer than 60 % of the stand distance would leave the arms detached from the
  piece, so the worker flips to the piece's other side instead.
- **`_inkShare` 2.5** — the margin round a worker's middle that keeps all of its ink inside the field: cap 1.9 ×
  squash 1.13 + hop 0.18, the body and ears' ink, with room for the lean.

## What changed

### packages/puzzle_game/lib/src

- `worker_moments.dart` — the walk is a speed on the game's clock: `note` takes the game time between snapshots
  (`_board.timeLeftMs - board.timeLeftMs`) and `_noteWalking` works the speed out from the step and that time, with
  `walkStartSpeed`/`walkStopSpeed`/`walkStopMs` hysteresis; a repeat changes nothing. `_noteTravel` keeps a short
  average for `travel`. `_SeenPlayer.note` gained `elapsedMs`; `_noteHeld` seeds `side` from `_raySide` at a pickup and
  `_noteSide` eases it toward the target by `sideTurnDegPerS` of game time (`_turnToward`, shortest way round).
  `poseOf` passes a `WorkerFit?` down to the frame.
- `worker_frames.dart` — `moving` is now `walking` (so the arms and lean follow the hysteresis); `_stand` and the new
  `_fitted` share `_edge(away:)`. `_fitted` slides the body's middle into the fit's `inside` by its `ink` margin, and
  flips it to the piece's other side (`_edge(away: -stand.away)`) when a slide would exceed `_sideSlideShare` of the
  stand distance. Drawing only: it returns the slide, not a new dot.
- `worker_pose.dart` — `typedef WorkerFit = ({Rect inside, double stand, double ink})`; a `slide` field (how far the
  body is slid from where it stands, field units) kept by `still()`, and `WorkerPose.slid(by)`.
- `worker_painter.dart` — `_paintWorkers` builds the fit (the field, `_standShare * radius`, `_inkShare * radius`) and
  passes it to `poseOf`; `_worker` draws at `at + slide`.
- `puzzle_carry.dart` — `_insideField(piece, at)` clamps a piece's middle so its outline's `bounds(angle)` lie inside
  the field (`_fitBetween` centres an outline wider than the field, which no puzzle has today); `_carrySmall` uses it,
  and the new `_keepHeldInField` does the same for every held piece after the turn, moving a team piece's carriers with
  it (`_inField` for their dots) and `_carryBig` clamps its step the same way.
- `game.dart` — the move loop calls `_carrySmall(p, pieces[held])` (the dot and the piece's middle stay one), and
  `_keepHeldInField()` runs after the turning loop. `update` (107 lines, over the guidelines' 60 before this job too)
  became `_noteTime`, `_presses`, `_moveAll`, `_turnAll`, `_highlight`, `_tapAll` and the end-of-round test, with the
  same order and the same code inside.

### packages/puzzle_game/test

- `worker_moments_test.dart` — six new tests: 'half the top speed walks every frame after it starts, at 60 Hz and at
  30 Hz', 'a snapshot repeated before the next one changes nothing at all', 'a stick wobbling round the threshold walks
  on once it has started' (12 %/9 %), 'a dot slower than the walk-stop speed for walkStopMs makes the worker stand',
  'a small piece carried in a straight line keeps the body on one side' and 'at rest the drawn pose holds still, also
  with a repeated snapshot'; plus a private `Walker` that feeds a running game's snapshots to its own `WorkerMoments`.
  Changed tests, and why: `board(...)` gained `timeLeftMs` (the moments now read the game's clock), so the nine existing
  second snapshots pass `timeLeftMs: 60000 - aTenth` — 'turning the piece it holds' among them, or its turn would go
  unwatched; 'carrying a small piece' now feeds three snapshots 100 ms apart, because the side turns over a quarter of
  a second instead of jumping. None of the assertions' meaning changed — they still say what each pose is; they now
  say it at a game time that moved on.
- `field_test.dart` (new, 5 tests) — a crate and a door: an ordinary piece carried hard left/right/up/down at 0°,
  45° and 90° stays inside; turning at the edge pushes it inward; a big piece carried by two is inside with both
  carriers;
  a piece whose target touches the board's edge still locks; a tray piece is left alone.
- `worker_edge_paint_test.dart` (new, 2 tests) — a 640×360 screen at pixelRatio 2, a 2-unit band along the field's
  left and right edges: no player-colour ink in it, with a carrying worker (Sunny and Night) and with an empty-handed
  one at either edge, and the worker is drawn at all somewhere inside.

## Tests: before and after

- Puzzle: **172 before, 185 after** (188 while `scratch_test.dart` is still there; the `## Delete` section removes it).
- The failing-first runs: without the `fit`, the carrying test painted 513 player-colour px into the 2-unit band and
  the empty-handed one 462 (0 with it); before the moments' change, the repeat, the 12 %/9 % wobble, the stop timing,
  the side test and the at-rest test all failed (the repeat stood the worker, the wobble flapped it, the side jumped
  more than `sideTurnDegPerS` in a frame, the rest pose alternated), and the field tests failed with the door's
  outline 1.4 units past the field's left edge (a dot at `dotRadius` 2.6, an 8-wide door) and the crate's 2.4 (10
  wide). Honestly: the *50 % speed at 60 Hz and at 30 Hz* test passes under the old per-snapshot rule too (0.4 and 0.8
  units a snapshot are both over 0.25, and the old `moved` never stands while the dot moves), so the brief's first
  walking test is a guard, not a failing-first one; the three after it are the ones the old rule fails.
- Everything else: format, analyze, host (240), phone (433) and tv pass; `tools/review.sh` 0 fail, 9 notes (file sizes
  and numeric literals, none on the new functions), and the largest function in a touched file is `_trayLayout` at 54
  lines, every touched lib file under 400 (game 390, worker_moments 344, worker_frames 317, worker_painter 316,
  worker_pose 164, puzzle_carry 124).

## The painter test

The brief asks to paint into a bigger canvas without the clip. That isn't observable in this build:
`PuzzlePainter.paint` clips to the field on every path (rule 5 keeps the clip, and the background fills the whole
size), so a worker crossing the edge leaves the same pixels whether or not the test draws into a bigger canvas. The
equivalent, and what the two tests read, is the band the body would cross: a worker whose pose puts it over the
field's edge leaves player-colour ink in a 2-unit strip inside the field, and none once it is fitted. The tests were
run with the fit removed, and failed on that ink, before it went in.

## Self-check (docs/review-rules.md part A, items 1–5)

1. **Every host setup:** the pose is rules-side from snapshots and the view's clock only, so TV/PC host, phone host,
   "Show on this device" and a joined phone draw the same one — `worker_moments_test` (the poses), `worker_paint_test`
   and `worker_edge_paint_test` (drawn), and the host/phone/tv suites (240/433/pass) — with the joined phone's
   snapshot positions rounded to 0.1 units (`snapshot.dart`'s `_i`), which the eased side absorbs.
2. **When kept state starts and ends:** `speed`, `walking`, `slowMs`, `travel` and `side` start at zero with a player's
   first snapshot ('a view built mid-round fires no moment on its first snapshot'), a repeat changes none of them ('a
   snapshot repeated before the next one changes nothing at all'), they end when the player leaves or the board's puzzle
   id changes (as before), and with no round no snapshot arrives so nothing runs; `_keepHeldInField` touches held pieces
   only ('a piece still in the tray is left alone').
3. **How it combines with the other states:** no new state and no new owner — a round's pause and phase stay
   `Pausable`'s, a pause sends no snapshots so the walk state simply stops ageing, and a dropped or leaving player drops
   the piece as before, so the clamp has nothing to hold; `rules_test`, the host's and the phone's suites pass.
4. **Stay in the job's folder:** written only in `packages/puzzle_game` and this report; `git status --short` shows
   nothing else from this job except the three `docs/design/m12-mirror-*.png` the puzzle tests rewrite (Q2) and the
   `tv_test_app/windows/flutter/generated_*` files, which no edit of mine touches (Q3).
5. **Stop rather than overstep:** two places, both reported rather than worked round — the painter test's literal form
   (above) and the PNG restore, which the sandbox would not let me run (Q2).

## Questions and suggestions

1. **The painter test's form.** As above, I used the in-field band instead of a canvas without the clip, because the
   painter always clips in this build. If the intent was to prove the clip is not what saves us, the band does that: it
   fails without the fit even though the clip is on.
2. **The mirror PNGs.** `packages/puzzle_game/test/mirror_png_test.dart` rewrites `docs/design/m12-mirror-*.png` on
   every puzzle test run. The brief asks me to restore them with `git checkout -- docs/design/m12-mirror-*.png`; this
   session's sandbox refused `git checkout`, so they are still the rewritten bytes in the tree. Run it before
   committing, or commit them as rewritten (they change on every run either way).
3. **The tv Windows files.** `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
   `generated_plugins.cmake` are dirty in the tree; this job never touches `tv_test_app`, and they change on a Flutter
   tool run. Not mine to commit — check before committing.
4. `scratch_test.dart` was my trace file for the side and the edge cases; it is in `## Delete`. If you want a durable
   trace of the side angle, the new test 'a small piece carried in a straight line keeps the body on one side' holds
   the numbers that matter (≤ 6.12° a frame at 17 ms, ≤ 3° drift over the last 1.7 s).

## Commit message

Shape Race: a smooth walk, and nothing held leaves the field

The worker walks on the snapshot's clock with 15 %/8 % hysteresis and a 120 ms stop, so a half stick no longer
flickers it, and its place round a held piece eases at 360°/s, seeded once at the pickup, so the body stops swinging
round the door and the rest pose stops alternating.
A carried piece's turned outline is kept inside the field, the dot with it, and a team piece's carriers too; tray
pieces are untouched and edge targets still lock. The painter slides a worker at the edge inward, or flips it to the
piece's other side, for empty hands as well; the field clip stays. The update loop is split into named steps.
Puzzle tests 172 → 185; format, analyze, host, phone and tv green; review.sh no fail.

## Status row

M13 10: the worker walks on the game's clock with hysteresis and eases its side round a held piece, a held piece's turned outline stays inside the field (the dot and a team piece's carriers too, tray and edge targets unchanged), and the painter slides or flips a worker at the field's edge inward; open: the mirror PNGs need `git checkout` before the commit and the tv Windows plugin files are dirty in the tree (Q2, Q3).

## Delete

- packages/puzzle_game/test/scratch_test.dart
- packages/puzzle_game/.game_head.tmp

## Claude's review (Nov 9, 2026)

Accepted. Applied by hand: flash held it back for the rewritten mirror PNGs and the Windows plugin files, which were left out. Checks are green (puzzle 185, look 111, host 240, phone 433, tv), and review.sh has no FAIL.

- The causes match Claude's frame-by-frame track of the owner's recording: the walk was decided per snapshot, and the side was taken from each snapshot's ray.
- **Q1:** the in-field band is the right test; it fails without the fit even with the clip on.
- **Q2:** the mirror PNGs are the same on every run (same hashes twice). They changed because the worker draws differently now, so they're committed as rewritten.
- **For the owner's device check:** the walk at half stick, a carried piece at the left and right edges, and the worker at the edges.
