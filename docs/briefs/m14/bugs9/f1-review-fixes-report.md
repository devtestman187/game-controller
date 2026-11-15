# M14 bugs9 review fixes: the badge keeps off the eyes, the numbers are right

## Summary

The bugs9 review's four `should` findings are fixed, and the `could` items the
brief named (a TV field and a width check that can fail, the `_countStyle` doc,
the dialog's title, buttons and slider lines) are done too. The luminance helper
stays where it was (recorded elsewhere).

The badge no longer slides down over the marble. `ArenaCoinBadgePainter.layout`
still puts the pill above the head; when its **pop peak** would cross the field's
top edge there, it puts the pill **below the head** at the same gap instead, and
only a marble with room for neither keeps the old clamp. New file
`packages/test_game/test/coin_badge_eyes_test.dart` (2 tests, phone and TV)
failed **2 of 2** on the old code and passes **2 of 2** now.

Positions, Sunny, at rest / at the pop peak (`pop` 0 and 1), a marble at the wall:

| field | radius | count | above the head (a marble mid-field) | below the head (a marble at the top wall) |
| --- | --- | --- | --- | --- |
| phone 390 x 844 | 12.48 px | `7` | rest top y = cy - 39.7 | rest y 14.4..39.7, peak y 10.6..43.5 |
| phone 390 x 844 | 12.48 px | `100` | rest top y = cy - 42.4 | rest y 14.4..42.4, peak y 10.1..46.6 |
| TV 1920 x 1080 | 51.84 px | `7` | rest top y = cy - 135.3 | rest y 59.6..135.3, peak y 48.3..146.6 |
| TV 1920 x 1080 | 51.84 px | `100` | rest top y = cy - 135.3 | rest y 59.6..135.3, peak y 48.3..146.6 |

At the top wall the old code wore the `7` pill at y 0..25.3 while the eyes span
-8.4..5.4 px: the overlap the review found. The new below-pill starts 9.0 px
under the eyes' box (14.4 > 5.4) on the phone and 39.7 px under it on the TV
(59.6 > 19.9). At the left wall the pill is moved in **25.7 px** for `7` and
**49.5 px** for `100` (peak left edge at 0); the eyes' box is beside the pill,
not under it.

Checks, run in this job (`tools/check.sh format analyze arena phone`): format
PASS, analyze PASS, **arena 232 tests PASS** (was 230; +2 in the new file),
**phone 468 tests PASS**. The legibility file's 5 tests still pass with the TV
field added and its width check now drawing at x = 0.

Decisions (each with one line of why) are under "Decisions"; nothing in the
brief was left undone except restoring the tracked pictures, which this
environment's rules forbid (see "Not done").

## What changed

- `packages/test_game/test/coin_badge_eyes_test.dart` (new, 67 lines, 2 tests):
  for a marble at the top wall, both top corners and the left wall, on a phone
  field and a TV field, with 7 and 100 coins, the pill's box at rest and at its
  pop peak must not overlap the eyes' box and must stay on the canvas. The eyes'
  box is built from the marble painter's own constants (`eyeOffsetShare`,
  `eyeRiseShare`, `eyeWideShare`, `eyeTallShare`, `eyeLookShare`, `eyeInkShare`)
  and the field's style, so it moves with the code.
- `packages/test_game/lib/src/arena_coin_badge_painter.dart` (170 -> 190 lines):
  the centre's height now comes from `_badgeY(above, below, half, extent)` — the
  peak-top check for above, the peak-bottom check for below, and `_kept(above)`
  when neither fits. `_countStyle`'s comment now says "bold, ink, at the count's
  own line height"; the layout, paint and class comments say the pill can go
  below the head and why.
- `packages/test_game/test/coin_badge_legibility_test.dart` (172 -> 192 lines):
  `fieldLooks` covers the phone upright, the phone turned and a TV (1920 x 1080,
  `tvSunny`); the font, edge and digits tests run on all three with each look's
  own radius (`marbleRadiusOn(field, look)` now multiplies by
  `arenaPlayerScale`). The width-check widget test draws its marble at (0, 0)
  and searches the paper only inside the badge's peak box (`boxOf(..., within:)`),
  asserting the paper reaches within a pixel of the pill's ink on each side.
- `controller_app/test/stick_text_contrast_test.dart` (120 -> 146 lines): the
  group's comment says which two tests are B-017's evidence (the dialog's, which
  failed at 1.07:1) and which two guard `ToyCard`'s Settings behaviour (they
  passed before). The dialog test now also reads its title
  (`PhoneText.sticks`, found under `find.byType(AlertDialog)`), its Defaults and
  Done buttons, and all three slider lines, found by the same `SettingsText`
  calls `stick_dialog.dart` makes from `const StickSettings()` (the test app
  saves nothing). The luminance helper is untouched.
- `docs/briefs/m14/bugs9/b018-coin-count-report.md`: the summary's and table's
  "3.7 px" is now 0.75 px, the `100` pill is 76.1 px wide, the three old-pill
  movement figures are replaced by the new pill's own positions (below the head
  at the top wall; 49.5 / 25.7 px in at the left wall), and the "Not done" line
  no longer says the test has no TV field.
- `docs/briefs/m14/bugs9/b017-stick-text-report.md`: says which tests failed on
  the old code (the two dialog tests at 1.07:1; the two Settings tests passed
  then too) and what the contrast test now also asserts.

## Computed test values

All in the Sunny look, the arena's style (outline 3 px on a phone, 4 px on a TV).

Phone, radius 12.48 px, gap 0.15 r = 1.872 px:

- `7`: font 14 px, pill 39.6 x 25.3 px; above peak top = -(12.48 + 1.872 +
  25.305 x 1.3 / 2) = **-43.5** at the wall; below rest y 14.352..39.657, peak
  half 16.448 -> y 10.556..43.453.
- `100`: font 16 px, pill 76.1 x 28.1 px; below rest y 14.352..42.415, peak
  y 10.141..46.626.
- Eyes' box at the top wall: y -8.39..5.39 (whites -5.24..2.25, grown by
  `eyeLookShare` r = 2.246 and the ring's half, 0.6 x 3 / 2 = 0.9).
- Left wall, peak: half widths 25.711 (`7`) and 49.454 (`100`) -> moved in
  25.7 and 49.5 px.

TV, field 1920 x 1080, radius 0.032 x 1080 x 1.5 = 51.84 px, gap 7.776 px:

- `7`: font 49.248 px, pill 127.2 x 75.7 px; above peak top **-146.7**; below
  rest y 59.6..135.3, peak y 48.3..146.6.
- `100`: pill 225.7 x 75.7 px (the count's 3 x 49.248 = 147.7 px in the test
  font); moved in 146.7 px at the left wall, `7` 82.7 px.
- Eyes' box at the top wall: y -32.3..19.9.

Contrast (probed in this job with a temporary print in `expectReads`, removed
after): the dialog's title 17.41:1 at night / 15.53:1 at midday; the subtitle the
same; the stick line 6.87 / 6.09; the three slider lines 17.41 / 15.53; Defaults
and Done `#FF120D2E` / `#FF1E1646` on the dialog's action surface `#FF2E9BF0`,
**6.29:1** at night and **5.61:1** at midday.

## Decisions

- **Below, not slid**: the below position uses the same gap (0.15 r) so the pill
  keeps its distance from the head on either side; it is chosen only when the
  peak above would cross y = 0, which is exactly the case the review described.
- **Neither fits: the old clamp**, of the above position, because the brief says
  so and no app field is short enough to reach it (a 390 px shortest side needs
  44 px above and below; a TV needs 109 px of its 1080).
- **The eyes' box includes the look shift and the ring's half width**: a marble
  may look any way when it is drawn, and the ring is drawn around the whites, so
  the box covers every marble the painter can draw rather than the one still.
- **One TV field (1920 x 1080)**: a TV is watched in landscape; the phone keeps
  both orientations.
- **The eye box and the radius are computed from the painter's constants and
  `arenaPlayerScale`**, not restated, so a change to either reaches the test.
- **The width-check test searches inside the peak box**: the eyes are paper too,
  so a whole-canvas paper search would have measured the face; the band plus the
  "within one pixel of the ink on each side" assertion still fails a pill drawn
  off the left edge (a clamped-wrong pill shows 6 px less paper).
- **The slider lines come from `const StickSettings()`**: the dialog reads the
  prefs and the test app saves none, so the defaults are what it shows; the three
  lines are built by the dialog's own `SettingsText` calls.
- **`76.0` -> `76.1`** in the B-018 report: the same rounding inconsistency the
  review listed beside the numbers this job corrects.

## Not done

- `git checkout --` on the tracked pictures: this environment's rules forbid git
  commands that change the tree. `docs/design/maps/*.png` were rewritten by the
  arena suite and are byte-identical (`git status` lists none of them);
  `docs/design/m13-puzzles*.png`, `docs/design/m13-tablet-board.png` and
  `site/shots/*.png` show as modified in this working copy (they were already
  modified before this job, per the review).
- No device look: the below-pill has not been seen on a phone or TV.
- `b018-coin-count-report.md`'s `42` peak width still reads 78.2 px where the
  exact value is 78.1 px (78.08): outside this brief's list.

## Self-check (review-rules part A)

1. **Every host setup.** The badge is a view: it is drawn from the snapshot's
   place, the look's radius and the round's clock, and this job adds no state and
   no host branch. The eyes test covers a phone field and a TV field (the TV's
   1.5x radius through `arenaPlayerScale`); the legibility test covers both
   phone orientations and a TV, and the arena suite (232 tests) still passes.
2. **When kept state starts and ends.** None kept: `CoinBadgeLayout` is made and
   dropped inside one paint; the pop is read from `ArenaMoments` as before.
3. **How a new state combines with the others.** None added; the placement is a
   pure function of the snapshot, the field and the pop.
4. **Your folder only.** Only `packages/test_game/lib/src`,
   `packages/test_game/test`, `controller_app/test` and the three bugs9 reports
   changed, all inside `allow:`.
5. **Stop rather than overstep.** Done. The findings outside this brief
   (`toy_theme.dart:41`, `paper_tiles.dart`, the luminance helper move, the
   picture writing in `map_render_test`) are left for their own jobs.

## Hand-over

Claude: the risky parts are (a) the below-the-head placement, which only the
owner's eye can judge — the numbers say it clears the eyes by 9.0 px on a phone
and 28.4 px on a TV, at the wall and at the peak; (b) the legibility test's new
band search, which measures the pill's paper rather than the face's; and (c) the
contrast test's dependence on the app's saved stick settings being the defaults
(it asserts `const StickSettings()`; a test that saves prefs first would need
them passed in). The eyes test's radius comes from `arenaPlayerScale`, so a
change to the TV's scale moves the TV's expectations with it.

## Commit message — a draft

Close the bugs9 review: the coin pill no longer covers the eyes

The top-wall clamp moved the pill down over the marble, hiding the eyes of
every marble at the top wall. The badge now goes below the head at the same
gap when its pop peak does not fit above, and is clamped only when neither
fits; a new phone and TV test checks the eyes' box at the wall and at the pop
peak. The B-018 report's numbers are corrected (0.75 px, 76.1 px, the new
pill's own positions) and the B-017 report says which tests failed.
The legibility test gains a TV field and a width check that can fail, and the
contrast test the dialog's title, its buttons and all three slider lines.

## Status row

- **M14 bugs9 B-017 + B-018 review fixes:** both `should` findings fixed (the
  pill goes below the head at the top wall; the B-018 report's distances and
  overflow corrected to 0.75 px) and the four briefed `could`s done (TV field,
  a width check that can fail, the `_countStyle` doc, the dialog's title, buttons
  and all three slider lines); arena 232 and phone 468 tests pass, format and
  analyze clean; open — the owner's device look at the below-pill, the
  `toy_theme.dart:41` root fix, the tracked pictures still modified.

## Delete

- none
