# M14 a1 — points in Shape Race (G1)

Stop: the brief's `stop:` is "after it", so the job runs through the rules, the tests, the drawing, the
snapshot, the round result and the checks, then stops there; nothing of a2 or later is started. (The "(G1)" in the
job's title is PRD v2's goal G1, which the `read:` line cites, not a plan-only gate.)

Points are counted by the rules per side, credited in full to every player on the side, popped up on screen in a
party night, carried in snapshot version 2, and handed to the night as a `RoundResult` from `MatchResult.round`.

## The scoring table as built

All values live in `PuzzlePoints` (`lib/src/points.dart`) and every award is `base * settings.pointsScale`, so a
night's last round (scale 2) doubles each one. Points only ever go up: nothing subtracts, and a lost round keeps
what it earned.

| Award | Base | Scale 1 | Scale 2 | Happens where | Test |
| --- | --- | --- | --- | --- | --- |
| piece snapped on the first try | `snap` 2 | +2 | +4 | `puzzle_drop.dart`, at the piece's target | points_test "a snap on the first try earns +2…" (scale 1 and 2) |
| piece snapped after a wrong drop of *that* piece | `wrongSnap` 1 | +1 | +2 | same place; `PieceRuntime.wronged` set by a wrong drop | points_test "a piece snapped after a wrong drop earns +1…" |
| big piece snapped while two players carry it | `together` 1 | +1 | +2 | same place, only for `big` and `carriers.length >= 2` | points_test "a big piece carried home by two…" (and "carried alone earns no carry point") |
| picture finished first | `finish` 5 | +5 | +10 | `game.dart`, at `field.board.center`, flag icon | points_test race / one-board / time-up tests |
| the cat shooed (a2) | `catShooed` 1 | +1 | +2 | `awardCatShooed(id, at)` — the hook a2 calls | points_test "the cat's +1 goes through the place job a2 calls" |

Notes on the two that could be read more than one way:

- The wrong-then-snap award is **+1, not +2**: `_awardSnap` asks the piece whether it was `wronged` and pays
  `wrongSnap` instead of `snap` (one award, not a bonus on top). The player's `tryAgains` is incremented there.
- The finish is paid only when a picture is finished (`PuzzlePhase.finished`), never at time-up, and in a race
  to the side that finished. Both sides finishing in the same frame is a draw and both keep their +5 (the match
  already decided a two-finish frame as a draw before this job).
- `carries` counts **every** carrier of the big piece (`carriers`), while `snaps` counts the player who dropped
  it; the "Best Helper"-style awards want that.

Credited per player: points are held per game, and each game is one side, so `RoundResult.points` gives every
player of a side its full total. The 2-vs-1 test asserts both sides earn the same for the same play and that both
players of the side of two are credited in full.

`PuzzleSettings` gained `pointsScale` (int, default 1, JSON `pointsScale`, clamped to ≥ 1 on read — a scale of 0
would silently switch the points off) and `night` (bool, default false, JSON `night`). Neither is in `ranges`, so
the settings validator is untouched.

## Where the points are kept

- `PuzzleGame.points` (int) and `PuzzleGame.popups` (a fresh list of `PuzzlePopup` each read).
- `_popups` in the rules, each `_Popup` holding its side, place, scaled amount, icon and `ageS`; `ageMs` is
  `(ageS * 1000).round()`, so the snapshot carries whole ms.
- Ageing runs in `PuzzleGame.update` **before** the `phase != playing` early return (`_agePopups(dt)`), so the
  final +5 keeps fading while frames are still published after the round is decided.
- The list is capped at `PuzzlePoints.maxPopups = 5`: the most one side can make in one frame (two players each
  snap a big piece carried by two = two awards each, plus the finish). Newest kept, oldest dropped, so a frame
  never carries more than five and the byte budget is bounded.

## Snapshot version 2

`PuzzleSnapshot.version = 2`, `MatchSnapshot.version = 2` (the frame's top-level `v`), and `shapeRaceModule`
`snapshotVersion` 2, so an older phone compares 2 with the 1 it knows and draws `updateAppText` ("Update the app
to see this game") instead of the frame — tested in `snapshot_v2_test.dart` with a `_VersionOneShapeRace` module
that declares version 1.

New keys, inside each board's JSON, all left out when at their default so a round outside a night encodes exactly
as before:

| Key | Type | When | Meaning |
| --- | --- | --- | --- |
| `pts` | int | when > 0 | the points that board's side has earned (scale applied) |
| `pop` | list | when not empty | the live pop-ups, oldest first, each `[side, x, y, amount, age ms, icon]` |
| `nt` | `1` | in a night round | `PuzzleSettings.night`; `MatchSnapshot.night` is true if any board says so |

`side` is `PuzzleSide.index` (0 left, 1 right), `x`/`y` are field units to a tenth (like piece positions), `icon`
is `PuzzleIcon.index` (0 star, 1 flag). `lerpTo` keeps the newer frame's `pts`, `nt`, `pop` unchanged (they are
not interpolated), like the clock and the phase.

`MatchSnapshot` gained `points` (`Map<PuzzleSide, int>` from the boards' `pts` by index) and `night` (any board),
both getters: no extra bytes on the wire.

Sample frame (from the size test; second board's `pop` entries are the same, `pl` says 3 and 4):

```json
{"v":2,"b":[{"v":2,"pz":"boat","t":119968,"ph":0,"o":[2,0,3,4,5,1],
"pc":[[342,729,1810,0],[595,701,900,0],[154,746,1120,0],[391,712,1880,0],[424,705,0,0],[482,705,0,0]],
"pl":[[1,80,325],[2,80,205]],"nt":1,"pts":199,
"pop":[[0,1234,567,4,1199,1],[0,1234,567,4,1199,1],[0,1234,567,4,1199,1],[0,1234,567,4,1199,1],[0,1234,567,4,1199,1]]},
{"v":2,"pz":"boat","t":119968, … "pl":[[3,700,325],[4,700,205]],"nt":1,"pts":199,"pop":[ … five again ]}],"sd":7}
```

(wrapped and abridged for the report only; the test builds one unbroken string).

**Size: 666 bytes** for four players with five pop-ups on each of two boards — 1382 bytes inside
`PuzzleSnapshot.maxBytes` (2048). The test asserts `< maxBytes` and prints the number the report quotes.

`docs/protocol.md` gained one paragraph after the `view_start` paragraph: the three keys, the entry layout, the
1.2 s / 5-pop-up bound, that a race carries a `pts`/`pop` per board and `setup` carries nothing new, and the
version-1 update text.

## Drawing: only when `nt` is true

- **Pop-ups** (`points_paint.dart`, called from `PuzzlePainter.paint` only when `s.night`): `+amount` in
  `look.type.clock` (Fredoka) at `_popupSize = 22` screen px, with the award's icon in a circle to its left —
  star for a points award, flag for the finish (both drawn as paths, because the fonts have no glyphs; the same
  decision as the look job's marks). The whole mark rises `PuzzlePoints.risenPx(age)` = 24 px × age/1200 and
  fades with `PuzzlePoints.left(age)` = 1 − age/1200. With `look.effects` off both helpers return 0 and 1, so it
  appears and goes without moving (G5, tested).
- **Each side's points beside its badges in the HUD**: the side's count line is now `_countWithPoints` instead of
  `_text` — the same `n/m placed` text, then the side's number with the star mark beside it (the short-string form
  the HUD uses, not a second line). It is drawn three ways to fit the three HUD shapes `SplitLayout` picks:
  - one board (`board_hud.dart`): after the count, right aligned, at `_hudY` along the top of the field;
  - split, strip HUD (`match_hud.dart`): each side's chip beside its own count, star after the left count and
    before the right count so both sit inside their halves;
  - split, gap HUD (tall puzzles such as 'tree'): the gap has no room beside the counts, so each side gets its
    own line just under its count at `_gapPointSize = 1.6`, and the gap's bar moves from y 17 to `_gapBarTopNight`
    = 20 to make room; chips stay in x 250..390 of a 640-wide box, tested.
- Never colour alone: every mark is a number plus a star/flag path, tested by counting pixels of two different
  two-digit numbers and requiring the same pixel count in a different place (the test font draws every glyph as
  the same box, so a one-digit change is invisible — the test uses 12 vs 34 and 0 vs 12 and says why).
- Outside a night `pts`/`pop` are not in the frame and nothing new is drawn: a paint test compares a board with
  points and pop-ups but `night: false` to the plain board and requires identical pixels (width 640, same
  `Uint8List`), and another does the same for the HUD.

## The night's result

`MatchResult` gained `round`, a `RoundResult` (`game: 'puzzle'`) built by the match in `_roundResult`:

- `winners`: the winning side's players (empty on one board, and on a draw);
- `draw`: `format.split && winner == null` — as the match decides today, so a one-board time-up is not a draw;
- `points`: each player's side's points;
- `stats`: `snaps`, `wrongDrops`, `carries`, `catsShooed` (0 until a2; the field and the counter exist),
  `tryAgains`, all `int`;
- `lines`: a race's `win`/`loss`/`draw` with `count` = pieces placed and `countOf: RoundCount.pieces`; one
  board's `done` with `timeS` (the finish time, or the time played at time-up) and no count — the results card
  shows a time, not a score.

A player who left mid-round keeps their line and their points, and gets zero counters (the game has forgotten
them), so the night never sees a missing id. `party_host` needed no change: it already reads `MatchResult`.

`PuzzleSide` moved to `puzzle_values.dart` (re-exported from `match.dart`), so the rules, the snapshot and the
painters can name a side without importing the match.

## Where the cat's +1 goes in a2

`PuzzleGame.awardCatShooed(String id, Offset at)` in the public `PuzzlePointsRules` extension
(`lib/src/puzzle_points.dart`): it increments that player's `catsShooed`, then awards `PuzzlePoints.catShooed` at
`at` on the shooer's side with a star icon. a2 calls it from its cat code with the bat-away position; no other
change is needed for the points, the pop-up, the snapshot or the night's `stats`.

## Files changed

- `docs/protocol.md` — one paragraph: Shape Race snapshots are version 2 (`nt`, `pts`, `pop`, entry layout, the
  1.2 s / five-pop-up bound, per-board keys, the version-1 update text).
- `packages/puzzle_game/lib/puzzle_game.dart` — exports `src/points.dart` (`PuzzlePoints`, `PuzzlePopup`,
  `PuzzleIcon`).
- `packages/puzzle_game/lib/src/points.dart` — new: the award values, `popupMs`, `risePx`, `maxPopups`, the
  rise/fade helpers, `PuzzleIcon` and the immutable `PuzzlePopup`.
- `packages/puzzle_game/lib/src/puzzle_points.dart` — new part of `game.dart`: `_Popup`, the credits
  (`_award`, `_awardSnap`), the ageing, and `awardCatShooed` for a2.
- `packages/puzzle_game/lib/src/points_paint.dart` — new part of `view.dart`: the star and flag paths, the award
  icon, `_pointsMark`/`_countWithPoints`, and `_popups` for `PuzzlePainter`.
- `packages/puzzle_game/lib/src/settings.dart` — `pointsScale` and `night`, with docs, JSON and the ≥ 1 clamp.
- `packages/puzzle_game/lib/src/game.dart` — `side`, `points`, `popups`, the finishing award, the ageing before
  the phase early return, and the three new snapshot fields.
- `packages/puzzle_game/lib/src/puzzle_drop.dart` — passes the drop's carriers to `_awardSnap` and marks a wrong
  drop with `piece.wronged`.
- `packages/puzzle_game/lib/src/puzzle_player.dart` — `carries`, `tryAgains`, `catsShooed` counters.
- `packages/puzzle_game/lib/src/puzzle_values.dart` — `PuzzleSide` moved here; `PieceRuntime.wronged`.
- `packages/puzzle_game/lib/src/snapshot.dart` — `points`, `night`, `popups` on the board, `version` 2, the JSON
  keys, the decode, `lerpTo`, and `MatchSnapshot.points`/`night` + version 2.
- `packages/puzzle_game/lib/src/match.dart` — `export 'puzzle_values.dart' show PuzzleSide;`, a side per game,
  and `MatchResult.round` with `_roundResult`.
- `packages/puzzle_game/lib/src/view.dart` — `part 'points_paint.dart';`, the `points.dart` import, and no
  longer needs `match.dart`.
- `packages/puzzle_game/lib/src/puzzle_painter.dart` — draws the pop-ups after the workers and only in a night.
- `packages/puzzle_game/lib/src/board_hud.dart` — the one-board count line gains the side's points.
- `packages/puzzle_game/lib/src/match_hud.dart` — the strip counts gain the side's points; the gap HUD gets a
  points line per side and moves its bar down in a night.
- `packages/puzzle_game/test/points_test.dart` — new, 13 tests.
- `packages/puzzle_game/test/match_round_test.dart` — new, 6 tests.
- `packages/puzzle_game/test/snapshot_v2_test.dart` — new, 6 tests (incl. the version-1 reader).
- `packages/puzzle_game/test/points_paint_test.dart` — new, 7 tests (pixels, no goldens).
- `docs/briefs/m14/a1-points-report.md` — this report.

Nothing else in the repo was written by hand. `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}`
and `generated_plugins.cmake` show as modified in `git status`: the Flutter tool rewrote them during `pub get` /
`analyze`; they are generated, unedited by me, and outside `allow:`.

## Computed values the tests assert

- A pop-up starts at **16 ms** (one 16 ms step ages the drop's own frame; asserted `< 50 ` so a slow first frame
  is allowed), is at **1166 ms** after 1.2 s worth of 50 ms steps minus one (23 × 50 = 1150 after the start),
  and is **gone on the next step** (1216 ms ≥ 1200).
- The rise is **12 px at half life** (600 ms): measured from the pixel bands before and after, ±3 px, and the
  same drawing at 0 and 600 ms is pixel-identical with the effects off.
- The strip HUD's chips stay inside their halves (left chip's right edge < 320, right chip's left edge > 320 of
  640); the gap HUD's chips stay inside x 250..390; the one-board chip's bottom is < 60 (along the top).
- The gap HUD's bar moves from y 17 to y 20 only in a night.
- The 4-player / two-board / five-pop-ups-a-side night frame is **666 bytes**.

## Test counts, before and after

Counts from `tools/check.sh` (before: the run at the start of the job; after: the run at the end).

| Suite | Before | After |
| --- | --- | --- |
| puzzle | 290 | 322 (+32: 13 points, 6 round, 6 snapshot, 7 paint) |
| host | 276 | 276 (unchanged) |
| phone | 439 | 439 (unchanged) |
| tv | 53 passed, 1 skipped | 53 passed, 1 skipped (unchanged) |

Every existing rules test passes unchanged: the scoring code is additive (`0` points and `[]` pop-ups leave the
snapshot bytes and the pixels as they were), so no existing expectation moved.

## Checks run

```
tools/check.sh format analyze puzzle phone tv host
PASS format (2s) · PASS analyze (15s) · PASS puzzle (322 tests, 50s) · PASS host (276 tests, 28s)
PASS phone (439 tests, 37s) · PASS tv (12s) · All checks passed
```

`tools/review.sh`: **0 fail, 13 note**. The notes are: `game.dart` 305 lines, three functions over 40 lines
(54, 41, 42 — none over 60), `puzzle_painter.dart` 349 lines with two functions over 40, `snapshot.dart` 303
lines, three numeric literals (the pop-up entry's `3`, `4`, `5` in `fromJson`), `view.dart` 315 lines. No file is
over 400 (`match_painter.dart` is exactly 400 and untouched; `camera.dart` 399 and untouched).

## Mirror pictures unchanged

- `git status --short` shows no `docs/design/m12-mirror-*.png` change: the goldens were re-produced by the phone
  suite and came out byte-identical.
- By construction: nothing new is drawn unless `s.night`, and `night` defaults to false, so the mirror (which
  never sets it) draws the same canvas it did. The paint test "outside a night the points and pop-ups draw
  nothing new" asserts the same bytes for a board that carries points and pop-ups but is not a night.

## Self-check — docs/review-rules.md part A, items 1–5

1. **Every host setup.** TV/PC host and a phone on "Show on this device" draw the night's board and both sides'
   points (`points_paint_test` strip and gap HUD tests, which draw through `PuzzlePainter`/`MatchPainter`);
   "Play on this phone" and a joined phone draw what the frame holds, including pop-ups with their age and both
   sides' points (`snapshot_v2_test` round-trip; `points_test` pop-up age). **Gap:** the phone host's own HUD
   panel (`match_painter.dart` `phoneHud`) has no line for points — see Question 1. A phone or host one build
   older shows the update text instead of a version-2 frame (`snapshot_v2_test` "a version-1 reader shows the
   update text for a version-2 frame", `find.text(updateAppText)`).
2. **When kept state starts and ends.** A pop-up starts at its award (the drop's frame or the finish; its first
   age is one step, 16 ms) and ends when its age reaches `popupMs` (1200 ms; gone on the 1216 ms step) — tested
   by `points_test` "each award pops up once at its place, and is gone 1.2 s later". Its age advances only inside
   `PuzzleGame.update`, which pauses by not running, so a pause, the results screen or a hidden app freezes it and
   nothing catches up — tested by "a pop-up does not age while the round stands still". Points start at 0 with
   the game and end with the snapshot/`RoundResult` that outlive it; nothing is held after the round, and a new
   round starts from 0.
3. **How a new state combines with the others.** The pop-ups are state inside `PuzzleGame`, whose one owner is
   `Pausable`/the phase: pause stops the steps so they freeze (tested above); the results screen keeps drawing
   the last frame, where the final +5 fades for 1.2 s and then goes (`_agePopups` runs before the phase early
   return, same test asserts the finish pop-up exists after the round is decided); a player away stops the match's
   steps the same way, so pop-ups freeze with everyone else's (`points_test` fairness test drives an away player);
   "Get ready" and a dropped link produce no frames, so nothing ages; leaving removes the player from the counters
   but not from `RoundResult.points`/`lines` (`match_round_test` keeps a departed player's line by zero-filling
   the stats). The night flag itself is a plain setting, so changing it mid-round changes drawing only.
4. **Stay in the job's folder.** Only `docs/briefs/m14/a1-points-report.md`, `docs/protocol.md`,
   `packages/puzzle_game/lib/**` and `packages/puzzle_game/test/**` were written (`git status --short`), plus the
   tool-generated `tv_test_app/windows/flutter/generated_*` files the Flutter tool rewrote on its own.
5. **Stop rather than overstep.** Stopped at the gate the brief names and changed no file outside `allow:`. Two
   things were not built because they need a decision or a file outside the allow list: the phone host HUD's
   points (Question 1) and nothing else. The rule book (`puzzle_rules*.dart`, `puzzle.dart`, `piece_shape.dart`),
   `puzzles/`, `packages/game_kit`, `packages/party_host` and `tools` are untouched.

## Questions

1. **The phone host's HUD panel has no points line.** `match_painter.dart`'s `phoneHud`/`_hudTexts` draws a fixed
   set of strings in a rect sized by `camera.dart`, and both files are at the 400/399-line wall, so adding a chip
   needs an owner outside this job's allow list (the camera would reserve a line, or `phoneHud` would return an
   extra string). A phone host in a night therefore sees the pop-ups and the board's own HUD only on the board
   that fits, but not a running points figure in its panel. Say how you want it: extra line in the panel (camera
   change, next job), or points only on the board's own HUD (which is what a phone host shows today)?
2. **`MatchSnapshot.points` assumes board order is side order** (board 0 = left). That is true for a race and
   for a phones match whose side is left; a one-board match whose side is the layout's right world would report
   its points as left's. Nothing builds that today (a one-board match is always the left world) — worth a `side`
   field on the board, or a fix in the brief that adds it, before one does?
3. **`pointsScale` and `night` are not in `ranges`**, so an out-of-range scale from an untrusted settings map is
   clamped (≥ 1) rather than rejected. Fine, or should they validate like `timeLimitS`?
4. **Pop-ups after the round only fade while frames keep coming.** The final +5 keeps ageing because the host
   keeps publishing frames while the results are up; if a host stopped publishing at `view_end`, the pop-up
   simply disappears with the frame. Confirm that is the behaviour you want (it is the cheap one).

## Suggestions

- A follow-up brief for the phone HUD points (Question 1) together with the camera's line reservation; that job
  can also move one of the `match_painter.dart`/`camera.dart` functions out to make room.
- The three numeric-literal notes in `snapshot.dart`'s pop-up decode could go away with a list pattern
  (`if (p case [final int side, …])`) once the file has room; it is over the 300-line aim already.
- The night could use a `pointsScale` of 2 *and* a per-round label ("last round, double points") — that is a
  N4/UI job, not this one; the scale is already a setting, so no rules change would be needed.
- `PuzzlePoints.maxPopups = 5` is an argument, not a measurement: if a2's cat can be shooed by several players in
  one frame, revisit it (the cap keeps the frame bounded, so the cost of a bigger cap is bytes only).

## Commit message

Shape Race counts points and shows them in a party night

- Rules: +2 a first-try snap, +1 a try again, +1 a big piece two carried home, +5 the picture
  finished (first in a race, before time-up alone), +1 the cat (a2's hook), each × the round's
  new `pointsScale`; points only go up and are credited to every player on the side.
- Each award makes a pop-up (side, place, amount, icon) that lives 1.2 s, kept with its age so a
  joined phone draws the same rise and fade.
- Snapshot version 2 adds `pts`, `pop` and `nt` inside each board (666 bytes for four players
  with five pop-ups a side); an older phone shows the update text. `docs/protocol.md` updated.
- Drawing only in a night: "+2" in Fredoka with a star or flag rising 24 px and fading, and each
  side's points beside its count in every HUD shape; effects off draws them still.
- `MatchResult.round` gives the night a `RoundResult`: winners, draw, points, the counters, and
  each player's line; `party_host` unchanged.

## Status row

M14 a1 done: Shape Race scores points per side (a2's cat hook in place), night-only pop-ups and HUD points, snapshot version 2 (666 bytes worst case, older phones see the update text), `MatchResult.round`; open: the phone host HUD has no points line (needs a camera change, question 1) and a2's cat itself.

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted. Checked on the tree with k1a merged: `tools/check.sh format analyze puzzle kit phone tv host` passes
(puzzle 323), `review.sh` 0 fail; the mirror pictures are unchanged and nothing new is drawn outside a night; the
snapshot is version 2 with `pts`, `pop` and `nt`, and docs/protocol.md says so; `MatchResult.round` carries the
night's numbers and `party_host` is untouched.
- Q1 (the phone host's panel has no points line), Q2 (a board's side, not its order) and Q3 (`pointsScale` and
  `night` validated in `ranges` like the other settings) go to a2, which works in the same painter, snapshot and
  settings files; version 2 is unreleased, so a2 may add a side key to it.
- Q4: accepted. The host keeps publishing frames while the results are up, so a last pop-up fades out.
