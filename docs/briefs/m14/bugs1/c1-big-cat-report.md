## Summary

- Shape Race's cat is now big: its head slides down from the top edge of that side's board area — a quarter of the
  board's width (20 units), ears, eyes and nose, eyes following the chosen piece — and then slides back up.
- A paw on a bowed foreleg reaches from beside the head to the piece, draws back a little, and swats: the piece moves
  at contact, a small caution-coloured burst marks it, the paw withdraws, the head leaves.
- The old small cat drawing (the paw at the edge and the small face) is gone; the shadow on the target piece stays.
- Timing comes from a view-side `CatMoments` on the view's clock, like `PieceMoments`: the snapshot, `CatView` and the
  rules are untouched, so the cat's tests and the snapshot bytes are as they were.
- Split screen: each side's cat stays inside its own half under the strip; the mirror draws the opponent's cat with
  the same pose.
- Sunny and night both paint in the pieces' outline weight; a mid-game look change is followed on the next frame.
- Reduced motion: the head appears at rest, the piece moves, no reach and no burst; leaving draws nothing, as before.
- Pictures: `docs/design/m14-cat-peek-sunny.png`, `m14-cat-peek-night.png`, `m14-cat-swat-sunny.png` and
  `m14-cat-swat-night.png`, written by the existing `capturePng` helper at 640 × 360 (4 px per unit), no new package.
- Files: 7 in `packages/puzzle_game/lib` (4 new: `cat_pose`, `cat_moments`, `cat_head`, `cat_paw`; `cat_paint`
  rewritten; `view`, the three painters and the export changed) and 3 new tests; no `toy_look` change was needed.
- Decisions below; nothing was skipped.
- Try on a device: Shape Race with the cat chaos on — the head peeks in, the paw reaches, swats and leaves; both
  looks, a mid-game look change, split screen with two pads, and the TV.

## Self-check (docs/review-rules.md part A)

1. **Every host setup** — the head and paw are computed from `field.board` alone and drawn by `PuzzlePainter` and
   `MirrorPainter` behind `MatchPainter`, so the same code runs on a TV host, a phone on "Play on this phone", a host
   phone on "Show on this device" and a mirror (the mirror test and `puzzle_frames` suites paint it); the cat tests
   cover the one-board field (160 × 90, the TV-shaped field) and a split field at `LayoutTarget.phones`; a joined
   phone draws frames from the host, and the snapshot and protocol are unchanged, so an older build simply draws the
   old cat (`cat_peek_test`, `cat_swat_test`, existing cat tests untouched).
2. **When kept state starts and ends** — `CatMoments` sets its start on the frame's clock when the cat's state
   changes and reports progress from 0 to 1 within `CatRules.spanMs(state)`; with no cat the state is null and
   nothing is drawn; a pause stops the frames, so the motion freezes and resumes with the clock and nothing catches
   up; `cat_peek_test` (share 0, 0.5) and `cat_swat_test` (walk to bat) show the ends.
3. **How a new state combines** — the cat only draws: it blocks no input, pauses nothing and owns no clock, so the
   pause menu, host away, a player away, "Get ready", the results and leaving all leave it frozen, absent or last
   drawn; during "Get ready" and the results the snapshot has no cat, so nothing is drawn (the existing cat tests and
   the full puzzle suite pass).
4. **Stay in the job's folder** — only `docs/briefs/m14/bugs1/c1-big-cat-report.md`, `packages/puzzle_game` and
   `docs/design` changed. The check run itself rewrote picture files and `tv_test_app`'s generated plugin files (other
   suites and `pub get` do that); they were put back as committed with `git show HEAD:<path>` and `git status` now
   lists only the job's files.
5. **Stop rather than overstep** — no file outside `allow:` was needed. One wording point was decided rather than
   guessed past (the head sits fully inside the board area, below the HUD texts); it is Decision 1 and Question 1.

## Decisions

1. **The head's top edge is the board area's top edge, not the screen's** — the HUD texts sit above the board and the
   brief asks for the head clear of them, so "fully on screen" is read as fully inside the board area; the visible
   slide-in comes from the head starting one head-height above that edge.
2. **Head width is exactly a quarter of the board area's width** (20 of the board's 80 units), height 0.92 of it
   (18.4); clamped so the head stays inside the area, which gives centre x 26 at the left edge and 86 at the right.
3. **The old small cat is removed, not kept beside the new one; the shadow on the target piece stays** — the shadow
   is the design's (party-night §5) warning marker and the only cue left when motion is reduced.
4. **The motion is timed by a new `CatMoments` in the view, from the frame's clock** — the snapshot may not change
   (brief: bytes unchanged), and `PieceMoments`/`WorkerMoments` already do view-side timing this way.
5. **The existing states carry the new motion without new rules** — warning: the head slides in over its first 40 %;
   walk: the paw reaches over 75 % and draws back 18 % of the head width over the last 25 %; bat: the tip is on the
   piece and the burst fades over the bat; leave: the head slides up over the last 60 % and the paw returns.
6. **`CatPose` is public and lives in `puzzle_game`, next to `PuzzleField`** — head, shoulder, aim, tip and swat share
   need the field and the board, which are the package's, and the tests assert the geometry without a canvas.
7. **Only the head is clipped to the board area; the paw and burst are not** — a piece still in the tray (x 102–156)
   is outside the board (16–96) and must be reachable.
8. **The burst uses the look's `caution` token** — it reads in both looks and is the colour already used for a warn.
9. **Reduced motion (`look.effects` false) draws the head at rest only** — no reach, no burst, and nothing at all
   during leave, which the existing "nothing is drawn as it leaves" test requires.

## Tests and computed values

- `cat_peek_test` (6 tests): head width 20 = a quarter of 80; head top 13 = `boardRect.top`; centres 26 and 86; head
  clear of the strip (13 ≥ `field.top` 10 and ≥ 8); split screen outside-its-box count 0 with the strip 6; slide-in
  at share 0 has the head's bottom at 13 (`closeTo` 0.01); gaze 1.2 units from the head's centre, on the piece's side.
- `cat_swat_test`: the reach draws back 3.6 units (asserted above 0 and under 5, a quarter of the head); at the bat the
  tip is the piece's contact point and the burst exists; the piece moves on the tick the state turns to bat, with the
  aim where the piece was before (`catRace` on a flat world, `Chaos.little`); the head and the burst change pixels in
  Sunny and in Night.
- `cat_pictures_test` writes the four PNGs at 640 × 360 (4 px per unit), peek at 900 ms of the warning, swat at 100 ms
  of the bat, and each file is over 5 000 bytes.

## Not done

- Nothing from the brief was skipped; the pictures are stills, not a video, as the brief asked.

## Questions

1. The head sits inside the board area (Decision 1); if "poking out from the top of the screen" meant the screen's own
   top edge over the HUD, the head would need a second clamp above `field.top` and a way to clear the clock text.
2. The paw is a cartoon reach with a fixed draw-back (18 % of the head width); the owner may want it longer or a real
   arc once he sees it on the TV.

## Commit message

Make the Shape Race cat big: a head peeks in, a paw swats

The cat's head slides down from the board area's top edge at a quarter of
its width, eyes on the piece, and a paw on a bowed foreleg reaches, draws
back and swats, with a small burst at contact and the head leaving after.
The motion is timed view-side by CatMoments from the frame's clock, so the
snapshot, CatView and the rules are unchanged; the old small cat drawing is
gone and the shadow on the target stays. Reduced motion draws the head at
rest only. Four pictures are saved under docs/design.

## Status row

M14 bug c1 (big cat): head-and-paw cat in Shape Race for sunny and night, split screen, the mirror and reduced
motion, with the old small cat removed; rules and snapshot bytes unchanged; four pictures saved; open: the owner's
device look, and whether the head should break the board's top edge (Questions 1–2).

## Delete

- none
