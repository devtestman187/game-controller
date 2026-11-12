# M14 bugs1: the run's review (read-only)

## Summary

**Verdict: `one fix batch`.** 1 must, 10 should, 19 could.
- The must is the cat's paw: the leave's tip lerps back to a shoulder that never moves with the head, so every visit
  ends with ~0.5 s of a paw drawn on the board with no head (`cat_pose.dart:51`).
- The one target the run misses: the brief's 15 % rule for look-alikes is applied at 3 % on the mirror path
  (`piece_twins.dart:124`), so a mirrored pair 4–15 % apart of size is neither twin nor look-alike.
- No job updated the design when it changed what a player sees: `docs/design/party-night.md:69` (a paw at the edge),
  `:190` (a ✓ and "Press A") and `docs/design/look-and-sound.md:33` (the palette never changes mid-round) are wrong.
- The cat's swat is unchecked in pixels (`cat_swat_test.dart:130` counts only inside the head's box), reduced motion
  has no test (`cat_paint.dart:41`), and no test draws `LayoutTarget.phones`, the layout the owner's phone uses.
- Across jobs: `PuzzleView` never hands its painter the frame's cat (`view.dart:94`), so the public one-board widget
  draws no cat although `MatchView`, the split screen and the mirror do; six touched lib files sit over the
  guideline's ~300 lines (the run's stop was 380); and b2 had no per-job review (this pass is its first read).
- Only the owner can answer: whether the head may sit inside the board area rather than over the screen's edge
  (c1 Q1, also why it can cover its own target piece), and whether a joined phone's row should say which player is
  "you" (b2 Q2).

## Findings

- **must** packages/puzzle_game/lib/src/cat_pose.dart:51 in `leave` the tip lerps to `shoulder` (line 46), which is fixed under the head's *rest* place, while the head slides out of the board by 60 % of the state, so the last ~0.48 s of every visit draws a paw on the board with no head → move the shoulder with the head's peek, or draw no paw once the head's bottom is above `field.board.top`, so the paw goes back up with the head it came out of (from: c1).
- **should** packages/puzzle_game/lib/src/piece_twins.dart:124 the mirror branch calls `_turnOnto(mirrored, b)`, which uses the 3 % twin tolerance, so mirrored outlines 4–15 % apart of size are neither a twin nor a look-alike, though the brief counts mirror images as look-alikes at 15 % → scale one outline onto the other's size first and test the mirror at `lookAlikeSizeShare` (from: p1).
- **should** docs/design/party-night.md:69 §5 still says the warning is "a paw at the edge of that side" (only the head is drawn in the warning, `cat_pose.dart:47`), line 190 still promises "a ✓ for each ready player" and "Press A when you're ready", and line 211 repeats "the cat's warning (paw, shadow)" → rewrite all three in one docs job (from: c1, b1; across jobs).
- **should** docs/design/look-and-sound.md:33 D1 still says the palette "only changes when a new screen opens, never in the middle of a round", and `docs/design/look-mockups.html:189` repeats it, both made wrong by t1 → change D1 and the mock-up's line to "a Look change shows at once, a round in progress included" (from: t1).
- **should** packages/puzzle_game/test/cat_swat_test.dart:130 the paint test counts changed pixels only inside `head` (x 46–66, y 13–31.4 on the one board, the same box in the warning and the bat frame), so `paintCatPaw` and `paintCatSwat` could draw nothing and it would pass → also count changed pixels in a box round `pose.aim` (from: c1).
- **should** packages/puzzle_game/test/cat_peek_test.dart:82 the split-screen case builds `SplitLayout.of(puzzle, 1)`, whose default target is `LayoutTarget.screen` (`split_layout.dart:128`), so no test covers the `phones` world (tray above the board, cropped board) the phone host draws, though c1's self-check 1 says it does → add a `LayoutTarget.phones` case for the head's size, place and clamp (from: c1).
- **should** packages/puzzle_game/lib/src/cat_paint.dart:41 the reduced-motion branch (head at rest, no paw, no burst, nothing during the leave) has no test; `cat_paint_test.dart:84` only checks the leave draws nothing → add a walk or bat frame with `effects: false` and show it differs from the plain frame only inside the head's box (from: c1).
- **should** packages/puzzle_game/lib/src/cat_pose.dart:38 the head hangs wholly from the board's top edge (bottom at y 31.4) and is drawn after the pieces (`puzzle_painter.dart:123`), so a target piece in that band is hidden, shadow and all, for the whole visit → keep the head's bottom above `aim.dy`, or record in party-night.md that covering a high piece is intended (from: c1).
- **should** packages/puzzle_game/lib/src/view.dart:164 the self-check's "a pause stops the clock, nothing catches up" is false: `_clock` is a `Stopwatch` started at the widget and never stopped, so after a pause `CatMoments.progress` (`cat_moments.dart:35`) jumps by the pause's length and the slide-in and the reach are skipped → reword the self-check, or reset `CatMoments` when the pause ends (from: c1).
- **should** packages/puzzle_game/test/puzzle_twins_test.dart:198 only the mirror pair checks that a non-twin does not fit, so nothing pins the 3 % corner tolerance or the brief's item 4 (with `twinToleranceShare` at 0.15 all eight tests and the library scan still pass) → add a same-shape pair 5 % apart that stays `wrong` and whose two slots are both hinted (from: p1).
- **should** packages/puzzle_game/lib/src/puzzle_painter.dart:230 `_targetOf` finds a locked piece's slot from the twin outlines and no test draws a board with a twin in its twin's slot, so the mapping the view relies on is unchecked → add a painter test that locks a twin in the other's slot and checks its own slot's outline is not drawn (from: p1; its review cited line 209, moved by c1).
- **could** packages/puzzle_game/lib/src/cat_head.dart:49 the pupil is drawn at the full `pose.gaze` (1.2 units) plus its radius (1.0) against an eye of radius 2.0, so it pokes 0.2 units out of the white → clamp the gaze to `(_eyeRadiusShare - _catPupilShare * _eyeRadiusShare) * w` and tighten `cat_peek_test.dart:112` to the eye's radius (from: c1).
- **could** packages/puzzle_game/test/cat_paint_test.dart:76 the test still says "draws its paw and its shadow in the warning", but the warning pose has no tip and at the share a fresh `MatchView` gives the head is hidden too, so it now only sees the shadow → rename it to what it checks (from: c1).
- **could** docs/briefs/m14/bugs1/c1-big-cat-report.md:16 the Summary says "7 in `packages/puzzle_game/lib`" while 11 files changed there, and its own list leaves out `cat_view.dart`, where `CatRules.spanMs` was added → correct the count and add the file (from: c1).
- **could** packages/puzzle_game/test/puzzle_twins_test.dart:245 the mirror test changes only the right wing's colour, so it passes whether the mirror colours look-alike targets only or every target → give a third piece a second colour between the two frames and assert its slot is unchanged (from: p1).
- **could** packages/puzzle_game/test/twins_library_test.dart:67 the scan asserts that every pair inside a twin group is a direct twin, but `PuzzleTwins.groups` is built from links (`piece_twins.dart:42`) and decision 3 allows a chain A–B–C, which would fail this test → assert what decision 3 promises ("linked by turns") or restate the decision as "groups are cliques" (from: p1).
- **could** packages/puzzle_game/test/twins_library_test.dart:34 the "second reading" uses the rule's own `twinToleranceShare` and `lookAlikeSizeShare` (line 41) instead of its own numbers, so a wrong threshold in the rule cannot be caught by the scan → hard-code 0.15 and 0.03 in the test, or say in the report that the reading shares the constants (from: p1).
- **could** packages/puzzle_game/test/twins_library_test.dart:76 `expect(twins.rotation(a, b), isNull)` and the `containsAll` on line 77 can never fail (`lookAlikePairs` only takes pairs whose rotation is null, `piece_twins.dart:38`) → delete them or replace them with a fact that could fail (from: p1).
- **could** packages/puzzle_game/lib/src/mirror_painter.dart:134 the mirror draws a look-alike's target at `_targetLine` (0.5) alpha and `_targetFill` (0.18), fainter than the board's dashed edge, and the mirror test only proves pixels changed → check on a device that the two wings can be told apart in Night before calling decision 5 done (from: p1).
- **could** packages/party_host/lib/src/ui/arena_waiting_card.dart:22 the class doc still promises "a ✓ once they are ready" and "Press A when you're ready", and `arena_waiting_widgets.dart:139` says "Robo is always ready, so it wears a ✓", both contradicted by the rows' `_ReadyLabel` → reword to the words the card now shows (from: b1).
- **could** packages/party_host/test/arena_touch_ready_test.dart:82 test 1 taps Ready with one player joined, so one 16 ms `_tick` would start the round and take the card (and `ready-p1`) away; it passes only because `tester.pump()` advances no time between the taps → add a second phone or change the flag without a tap-then-check window (from: b1).
- **could** packages/party_host/lib/src/ui/arena_waiting_widgets.dart:59 the name's `maxLines: 1` and `TextOverflow.ellipsis` are a display change the brief did not ask for and the decisions do not list → drop it, or list it as a decision (from: b1).
- **could** packages/party_host/lib/src/text/arena_text.dart:27 `readyButton` and `readyLabel` are both `'Ready'`, so the button's word and the row's word can drift apart → one constant, or a doc line saying why they are two (from: b1).
- **could** docs/briefs/m14/bugs1/t1-look-midgame-report.md:54 the report says `round_palette_hold.dart` was "emptied" and lists it under Delete (also lines 19 and 149), but the file is deleted from the tree, so the Delete step names a path that does not exist → say the commit deletes it and drop the Delete entry (from: t1).
- **could** packages/party_host/test/look_midgame_test.dart:84 the Bumper Round test checks only `round`, `mode` and `players.length` after the look change, so the brief's "no lost time, coins or points" is unproven for the Arena → assert the round's clock and a coin figure are the same before and after (from: t1).
- **could** packages/party_host/test/look_midgame_test.dart:35 the Shape Race test asserts the painter's `look.palette`, not a colour drawn, while the brief asks for "the new look's colours on the next frame" → assert a pixel or a drawn colour through the palette the painter is handed (from: t1).
- **could** controller_app/test/round_palette_test.dart:17 the rewritten joined-phone test ends while the view still runs, so nothing now checks the palette after a joined game ends and a page opens → keep that final step in the same test (from: t1).
- **could** packages/puzzle_game/lib/src/view.dart:94 `PuzzleView` builds its `PuzzlePainter` without `cat` or `catMoments`, so the exported one-board widget draws no cat although the frame carries one; c1 gave `MatchView`, the split screen and the mirror the cat and left this path behind → pass `widget.snapshot.cat` and a `CatMoments`, or drop the widget (no shipped code uses it) (from: across jobs).
- **could** packages/test_game/test/arena_hud_coins_test.dart:124 the four-player case runs only in the one-line bar at 667 × 375, so the tall bar's second line — the case the brief names — is never drawn with four names and counts → add the same four players at 960 × 540 (from: b2).
- **could** packages/puzzle_game/lib/src/match_painter.dart:377 is 377 lines (`wc -l`), and `lobby_music.dart` 348, `arena_waiting_widgets.dart` 343, `view.dart` 330, `puzzle_painter.dart` 326 and `arena_waiting_card.dart` 324 were all touched this run: the runner stops at 380, the guideline asks for about 300 → split `match_painter.dart` along the HUD seam before the next job that grows it, and take the others when next touched (from: across jobs).

## Open questions

1. b1 Q1: mark the host phone's own player "(you)" on the night's start card and scoreboard too? — **leave it**: the waiting card already says it and the scoreboard lists every phone alike.
2. b1 Q2: keep the Ready button's focus-yellow fill while ready? — **keep it**: it matches the chosen mode button's meaning.
3. b2 Q1: move the bar's words out of `test_game`? — **leave them**: the game may not import `party_host`; if they must move, give the game its own text file, not `HostText`.
4. b2 Q2: a "you" mark on a joined phone's own row? — **yes, later**: `ViewContext.playerId` is already passed.
5. b2 Q3: "Best –" still shows in a Bumper Round? — **remove it**: it is always null there, as Wins/Hits/Dashes went.
6. b2 Q4: hide the marble's pill at 0 coins? — **keep it**: a drop to nothing must stay visible.
7. p1 Q1: a shipped Shape Race CPU player? — **no**: b3 owns Robo; the brief's Robo was a test player.
8. p1 Q2: the butterfly's colours against the screenshot? — **keep the artwork**: the file's purple/orange and green/blue pairs are the ones the hint colours were chosen for.
9. c1 Q1: head inside the board area, or over the screen's top edge? — **inside**: it keeps clear of the clock text and of the tray; write it into party-night.md §5.
10. c1 Q2: a longer paw draw-back or a real arc? — **leave it** until the owner's TV look.
11. t1 Q1: the `look-and-sound.md` D1 line (and `docs/decisions.md`)? — **fix in the same docs job** as finding 4.
12. t1 Q2: let Auto's hour reach a round on a page push or pop? — **accept it**: a timer inside a round is a separate decision.
13. t1 Q3: drop the `RoundHold` widget and call the music from the round screens? — **leave it**: it still owns the round's music.

## Numbers against targets

- p1's 15 % look-alike rule (brief item 2) is applied at 3 % on the mirror path, so mirrored pairs 4–15 % apart are
  uncovered (finding 2). Today's library has no such pair, so the scan passes.
- c1's "about a quarter of the board area's width" (brief item 1): 20 of 80 units = 25 %, head top 13 = `field.board.top`,
  ≥ the HUD's 8 — met on the one-board and `screen` split layouts; never measured on `LayoutTarget.phones`.
- c1's file split (brief item 4): `cat_head` 59, `cat_paw` 96, `cat_pose` 150 lines — met.
- b2's snapshot budget (brief item 4): the test asserts `lessThan(arenaSnapshotBudgetBytes)` (2048) but the report gives
  no byte figure, so the margin is unverified here.
- b2's pill height: the report's 15.32 px does not follow its own inputs — `max(2×5.04, 11.4) + 2×2.16 = 15.72`; the
  measured pill is inside the paint test's 151.5–175.5 px band either way, so only the figure is off.
- File sizes: the run's stop is 380 lines, the guideline "about 300"; `match_painter` 377, `lobby_music` 348,
  `arena_waiting_widgets` 343, `view` 330, `puzzle_painter` 326, `arena_waiting_card` 324 — over the guideline, under the stop.
- Suite counts agree across the reports: host 380 (p1) → 387 (b1 +7) → 389 (t1 +2); phone 463 (b1, p1) → 464 (b2 +1);
  puzzle 371 at p1 (c1's 9 new tests not totalled). c1's Summary's "7 in `packages/puzzle_game/lib`" is wrong: 11 changed.

## Could not check

- `git` was refused in this sandbox, so I read the listed files whole in the working tree, not the diff; changes to files
  outside the brief's list (the three design docs) were judged from the tree alone.
- No suite was run (the brief names none, and this job is read-only): test counts, pixel counts and the 2048-byte margin
  are the reports' own figures.
- Any device behaviour (TV, phone host, joined phone, the mirror at device size) and the four PNGs' content (they exist,
  34–43 KB each; I did not open them).
- Whether each new test fails on the old code (no second checkout).
- b2 had no per-job review (`waves.txt` runs it alone; no `b2-bumper-coins-review-report.md`), so its code is read here
  once and only by this pass.

## Commit message

Review of M14 bugs1: one must, the cat's floating paw

Read the five jobs as one change against the guidelines, the review
rules and the briefs. The must is the cat's leave: its paw returns to a
shoulder that stays under the head's rest place while the head slides
out, so a paw is left on the board. The one missed target is the
mirror's look-alike tolerance (3 % where the brief says 15 %); the cat's
swat, reduced motion and the phones layout have no test; three design
docs still describe the old cat, the old card and the frozen palette;
and `PuzzleView` never draws the frame's cat.

## Status row

M14 bugs1 run reviewed (one fix batch): 1 must, 10 should, 19 could — the cat's floating paw, the mirror's 3 % vs 15 % look-alike rule, the cat's swat/reduced-motion/phones test gaps, three stale design docs, PuzzleView drawing no cat; open: the owner's answers on the head's place and the joined phone's "you" mark, and b2 had no per-job review.

## Delete

- none
