# M13 16: the clock area on a portrait tablet

The owner's iPad in portrait, joined to a phone, showed the clock area ("7:44", "0/6", the time bar) on a panel over
the board's top-left corner, about a third of the board wide, with half a screen of empty sky under the board above the
pad. The cause was the one the brief names: every HUD size was a fraction of the box's **height**, chosen for a
393-tall phone, so on a 1366-tall tablet the clock area drew 3.5 times as big; and in portrait the world fills the
box's width, so no form fitted beside it and `hudPlace` fell back to the corner, over the board. The clock area now
sizes by the box's **shorter side**, and a portrait box puts it **under the world** before the corner.

Owner's picture: [m13-portrait-hud.png](../../design/m13-portrait-hud.png) (1024 × 1366, house solo, the app's D-pad
rects passed as it passes them, Sunny). The clock area is under the board, 691–806 px down; the corner panel over the
board is gone.

## The rules, rule by rule

1. **The shorter side.** `PuzzleCamera.hudUnit(box) = min(box.width, box.height)`; every `hud*Fraction` and
   `hudTopFraction` is a fraction of it, in the camera and in the painter. A landscape phone's shorter side is its
   height, so nothing landscape moves: `hudUnit == box.height` there.
2. **Under the world.** `hudPlace` takes `padRects` and `split` the way `mirrorPlace` does. When no form fits beside
   the world it tries `_hudUnder`: at the world's left edge, `hudWorldGapPx` under the world's bottom, in the first of
   one line, two lines, short that fits the world's width and the box, and clear of every pad rect inflated by
   `mirrorGapPx`. The world is the one drawn last — a side camera's only world, or the lower (right) one of a whole
   match's stack.
3. **The corner stays last.** Under returns null where the box has no room under the world or the pad is there; the
   corner then uses `hudUnit` too, so a portrait corner panel is no longer 1366-tall-sized.
4. **The mirror keeps its rules.** `mirrorPlace` passes the pad rects and `split` to its `hudPlace` calls, so on a
   portrait phone with a mirror the clock area goes under the world and the mirror goes under the clock (the gap
   place); its corner place still asks `hudPlace` with the mirror and gets the short form beside it. A portrait race
   never puts the mirror over the board, the tray or the pad (tests below).
5. **No `HudForm.under`.** The painter draws the under place exactly as it draws the beside forms: no panel, text at
   the rect's left, the bar at the rect's bottom, `onBackground` ink. The only branch on the form is `corner`, so a
   new value would be a name the painter never reads. `form` stays the text form (one line / two lines / short).
6. **Design doc.** [m12-phone-layout.md §0.7c](../../design/m12-phone-layout.md) has the dated decision ("Decided at
   device test 3 (owner, Nov 9)"), the shorter side, the under place and the corner last, and points at the picture.

**One change outside the brief's letter (Q1).** `PuzzleCamera.place` now aligns a `side` camera's world to the **top**
in a portrait box (it was bottom-aligned, spare height on top). Without it the world touches the box's bottom in
portrait, no under place can ever fit, and the brief's own test 4 (a portrait race with a mirror) can't pass. In a
landscape box `box.height > box.width` is false, so `spare` still goes on top: every landscape placement, test and
picture is unchanged.

## Files changed

- `packages/puzzle_game/lib/src/camera.dart` (394 lines) — `hudUnit`; the fraction docs; `place`'s portrait side
  alignment; `hudPlace`'s `padRects`/`split` and the under place; `_hudUnder`; all HUD sizes by `hudUnit`;
  `mirrorPlace` passing the pads and `split` and sizing by `hudUnit`; `_floorSlack`'s doc widened to a fit's slack.
- `packages/puzzle_game/lib/src/match_painter.dart` — text sizes, line gap and bar by `PuzzleCamera.hudUnit(size)`;
  `hudPlace` called with `padRects: padRects, split: s.split`; doc.
- `packages/puzzle_game/test/portrait_hud_test.dart` (new) — 6 tests: the shorter side; both portrait iPads under the
  world and clear of the pad; the landscape phone and iPad pinned; a box with no room under the world → corner; a
  portrait race with a mirror.
- `packages/puzzle_game/test/support/portrait_pads.dart` (new) — `leftPadRects`'s D-pad rects at 1024 × 1366,
  820 × 1180 and a 393 × 852 phone, to a tenth of a px, with the densities the app uses.
- `packages/puzzle_game/test/portrait_hud_png_test.dart` (new) — writes `docs/design/m13-portrait-hud.png`.
- `controller_app/test/portrait_hud_test.dart` (new) — 2 tests with the **real** `leftPadRects`, every `PadMode`, at
  both portrait tablets (solo) and the portrait phone (race): no literals of the pad's geometry.
- `docs/design/m12-phone-layout.md` — §0.7c's "Decided at device test 3" bullet.
- `docs/design/m13-portrait-hud.png` (new) — the picture.
- `controller_app/test/scratch_numbers_test.dart` — a temporary numbers test, to delete.

No existing test was changed or loosened.

## Test counts

| suite | before | after |
| --- | --- | --- |
| toy_look (look) | 111 | 111 |
| puzzle_game (puzzle) | 218 | 225 (+7: 6 + the picture) |
| controller_app (phone) | 433 | 436 (+3, 435 once the scratch test is deleted) |
| tv_test_app (tv) | 53 (+1 skipped) | 53 (+1 skipped) |
| game_kit (kit) | 48 | 48 |
| test_game (arena) | 66 | 66 |
| party_host (host) | 241 | 241 |

Counts are `flutter test`'s; the before column is the after count less the tests this job adds (no test was removed),
and every suite ran green, the last time after the final code change.

## Computed values

The clock area, before (fractions of the height, no under place) → after. Sizes in px; the board, tray and world in
box px from `SplitLayout.of(puzzle, 1, phones)`.

| box, camera, match | before | after |
| --- | --- | --- |
| 1024 × 1366, whole, house solo, app D-pad | corner, board.topLeft + 8 = (288.5, 197.1), 300.5 × 235.0 (right 589.0, bottom 432.1), clock 109.3 tall | oneLine, (186.1, 691.0), 538.6 × 114.7 (right 724.7, bottom 805.7), clock 81.9 tall |
| 820 × 1180, whole, house solo, app D-pad | corner, (218.0, 171.3), 259.6 × 203.0 (right 477.6, bottom 374.3), clock 94.4 | oneLine, (128.5, 598.0), 431.3 × 91.8 (right 559.8, bottom 689.8), clock 65.6 |
| 852 × 393, side, house solo | oneLine, (8, 55.02), 206.72 × 44.02 | same (pinned) |
| 852 × 393, side, house race | twoLines, (8, 55.02), 164.27 × 67.6 | same (pinned) |
| 1366 × 1024, side, tree solo | short, (8, 143.36), 225.28 × 176.13 | same (pinned) |
| 1366 × 1024, side, house solo | corner, (343.88, 291.48), 225.28 × 176.13 | same (pinned) |
| 820 × 1180, whole, house solo, pad right under the world | corner, (218.0, 171.3), 259.6 × 203.0 | corner, (218.0, 171.3), 180.4 × 141.04 |
| 393 × 852, side, house race, app D-pad | corner, (64.9, 122.0), 187.44 × 146.54, clock 68.2 | oneLine, (0, 419.83), 258.62 × 44.02, clock 31.44; mirror (8, 471.8), 72.3 × 74.7 |
| 393 × 852, race, gyro / stick | corner as above | oneLine as above; mirror (121.5, …) / (112.4, …) |

Where the numbers come from: `hudUnit` = 1024 / 820 / 393; one line is 0.22 + 0.02 + 13 × 0.04 × 0.55 = **0.526** of
the shorter side wide (the score is "0 of 4 placed") and 0.08 + 0.02 + 0.012 = **0.112** high; two lines are
0.418 × 0.172 (the race's 19-character score, 164.27 = 0.418 × 393); the short form is 0.22 wide and 0.172 (solo) or
0.232 (two short lines) high; the corner is 0.22 wide and 0.172 high; the clock is 0.08 (81.92 at 1024, 65.6 at 820,
31.44 at 393, unchanged 31.44 at a 393-tall landscape phone). The under place starts at the world's left (186.09 at
1024, 128.48 at 820, 0 at 393) and 8 px under its bottom (683.0 + 8 at 1024, 590.0 + 8 at 820, 411.8 + 8 at 393). The
pins in the test use `closeTo(…, 0.01)` on each edge; the corner's left/top are `board.left + 8` = 343.8814 / 291.4802
at 1366 × 1024 (the earlier 343.9 / 291.5 in the job's numbers were rounded).

The app test checks: left = world.left and top = world.bottom + 8 to 1e-9, no overlap with the world or any pad rect
(inflated by `mirrorGapPx` for the tablets), the clock area inside the box, at 1024 × 1366 and 820 × 1180 in every
`PadMode`; and at 393 × 852 in the race: the clock area under the world, the mirror's top = the clock's bottom + 8,
the mirror clear of the world, board, tray, clock area and pad, its bottom inside the box.

The picture: house solo, `timeLimitS` 600 (clock "10:00"), `Random(1)`, whole camera, `iPadPortraitPad`,
`iPadPxPerMm`, Sunny with the look's fonts; the clock area at (186.1, 691.0)–(724.7, 805.7). The pad's rects are
passed as the app passes them but not drawn, as the m12 mirror pictures pass theirs (Q2).

## The mirror pictures

`mirror_png_test.dart` rewrites `docs/design/m12-mirror-{iphone,iphone-stick,169}.png` on every puzzle run. Its three
boxes are landscape (852 × 393 twice, 667 × 375), where `hudUnit == box.height`, `place`'s landscape branch is
untouched, no beside form changes, and the under place can never fit (a side world's bottom is the box's bottom), so
the drawing is the one it was. I could not byte-compare against the committed files: any `git` command asks for
approval this session. The review's `git status` shows whether they are dirty; if one is, the cause is outside this
diff.

## Checks

`tools/check.sh` and `tools/review.sh` both run scripts and git and ask for approval this session, so I ran their
commands directly: `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets` →
"0 changed"; `dart analyze --fatal-infos` → "No issues found!"; `flutter test` in `toy_look`, `puzzle_game`,
`controller_app`, `tv_test_app`, `game_kit`, `test_game`, `party_host` → all green (counts above). `tools/review.sh`'s
mechanical checks were applied by hand to the new lines: no file over 400 (camera.dart 394, match_painter.dart 394),
no function over 60 (hudPlace 44, `_hudUnder` 17), no bare numbers outside tests, no `print`, no catches, no
`dynamic`/`!`, no colours.

## Self-check (review-rules.md part A)

1. **Every host setup.** Not affected on a TV/PC host or "Show on this device" (a `screen` layout never calls
   `hudPlace`); a phone on "Play on this phone" and a joined phone get the new rule, landscape unchanged, portrait now
   under the board — `portrait_hud_test.dart` (app, both tablet sizes, every mode), `party_host` 241 green,
   `tv_test_app` 53 green. An older build draws the old sizes; nothing in the protocol changed.
2. **When kept state starts and ends.** Nothing is kept: `hudUnit`, `_hudUnder` and the placement are pure functions of
   the box, the layout and the text — `portrait_hud_test.dart` (the shorter side; the corner test).
3. **How a new state combines with others.** No new state, pause, wait or input path; the clock area is drawn each
   frame from the snapshot as before — `view_test.dart` and the app's `mirror_pad_test.dart` still pass.
4. **Stay in the job's folder.** Every file is under `docs/design`, `packages/puzzle_game`, `controller_app/test` or
   this report; `packages/party_host` is untouched.
5. **Stop rather than overstep.** No stop; the one design decision (top-aligning a portrait side world) is Q1, made
   because the brief's own test 4 cannot pass otherwise, and it is landscape-neutral.

## What I wasn't sure about

- `hudPlace`'s under place is tried **only when there is no mirror** (`mirror == null`). With a mirror the clock area
  is the mirror's companion (rule 5's short form beside it), so the under place is the mirror's business, and
  `mirrorPlace` already gets it through its own `hudPlace` call and its gap place. Confirm this reading of rule 4.
- `packages/puzzle_game` has no font-loaded HUD picture yet; the picture loads the look's fonts (as s12's does), so the
  clock reads "10:00" rather than a block.
- The tablet test in `controller_app` covers the D-pad's arm rects per mode; a *floating* stick's zone is the same
  `leftZone` the app passes, not exercised separately here (`mirror_pad_test.dart` covers it for the mirror).

## Questions and suggestions

1. **The portrait side world's alignment (Q1).** I top-aligned it so the spare height is under it. It changes what a
   portrait **phone** playing its own side draws (the world at the top, clock under it) — there was no portrait layout
   before, only landscape ones. If you want a portrait phone's world to stay bottom-aligned, the under place can't fit
   and the brief's test 4 needs a different rule; say which.
2. **Drawing the pad in the picture.** The picture passes the app's pad rects but doesn't draw the controls (the m12
   mirror pictures don't either). The owner might read the empty bottom half as a bug; a follow-up could paint the
   D-pad and the compact top bar into the picture from the app's own painters, if that's worth a job.
3. **The corner on a portrait tablet.** It now draws 0.172 of the *width* high (176 px at 1024) rather than 235 px: a
   corner panel over the board is smaller in portrait. No test picture shows it; say if it should.

## Commit message

```
Put the clock area under the board on a portrait tablet

HUD sizes are fractions of the box's shorter side now, not its height,
so a portrait iPad's clock is 0.08 x 1024 (82 px), not 0.08 x 1366.
When no form fits beside the world, hudPlace tries a new place under the
world (at its left edge, hudWorldGapPx below it, in the first form that
fits its width, clear of the app's pad rects with mirrorGapPx of air)
before the corner panel. The mirror gets the same place through
mirrorPlace; a landscape phone and its pictures are unchanged.
```

## Status row

M13 16 (device fixes 6, the portrait clock): the clock area sizes by the box's shorter side and, in portrait, goes under the world before the corner (the mirror keeps its rules and moves with it), the m12 landscape layout and pictures unchanged, with a picture; open: the review's git check of the m12 mirror PNGs, and the Q1 alignment and Q2 picture questions.

## Delete

- controller_app/test/scratch_numbers_test.dart

## Claude's review

- Accepted. `m13-portrait-hud.png` shows the clock area under the board at a phone's size, clear of the board; the landscape layouts and the m12 mirror pictures came out byte-identical (git shows no change).
- Questions: 1) top-aligning a portrait side camera's world is right (the spare height goes to the clock area). 2) The picture needn't paint the controls. 3) The smaller portrait corner panel is fine; it's the last resort.
- Not in this job: the board itself is still small on an iPad (owner, Nov 9: "the puzzle area should take up more of the screen"). That's the next job.
