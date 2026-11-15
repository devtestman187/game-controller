# Review of the bugs9 run (B-017 floating-sticks text, B-018 coin count)

## Summary

Verdict: **one fix batch**. Counts: 0 must, 4 should, 8 could. Both fixes meet their brief's targets; what is wrong
is in the B-018 report's numbers and in what the two new tests do not cover.

The five that matter most:
1. The coin badge's top-wall clamp keeps the pill on the canvas by moving it down over the marble itself: on a phone a
   marble against the top wall wears its pill at y 0..25.3 while its eyes sit at 7.2..14.7, so the badge hides the eyes
   of every marble that touches the top wall (no test asks what the pill covers).
2. The B-018 report's three clamp distances (33.2 / 34.1 / 18.7 px) are the *old* pill's offsets; the new pill moves
   43.4 / 49.5 / 25.7 px.
3. The B-018 report's "3.7 px past its inside right" is 0.75 px (the outline width counted twice).
4. B-017's two Settings tests pass on the old code, so only the two dialog tests are its evidence, while the report
   reads as if all four failed at 1.07:1.
5. The coin test has no TV field, and its width check cannot fail (the marble sits at x = 0.5).

Only the owner can answer: whether the 14/16 px floors are enough, and whether the clamped pill reads well on a phone.

Checks I ran: `git diff --stat 972fd38..04b7316` (13 files, no picture or generated file in the two commits) and the
reports' arithmetic recomputed by hand (B-017's five ratios hold; B-018's three distances and "3.7 px" do not). I ran
no test suite: `flutter test` rewrites tracked pictures (see the last finding).

## Findings

- **should** packages/test_game/lib/src/arena_coin_badge_painter.dart:108 The clamp keeps the pill on the canvas by
  moving it down, and for a marble within ~27 px of the top wall that puts the pill over the marble: a phone marble at
  the wall (centre y = radius 12.48) wears its `7` pill at y 0..25.3 while its eyes span 7.2..14.7, so the badge hides
  the eyes of every marble touching the top wall → decide the overlap (draw the badge under the marble when it overlaps
  it, or stop the clamp at the marble's top) and test what the pill covers, not only that it is on the canvas. (from:
  across jobs — b018's test asks only "inside the field")
- **should** docs/briefs/m14/bugs9/b018-coin-count-report.md:19 The three "moved" distances — 33.2 px down, 34.1 and
  18.7 px in, repeated in the table on :60-61 — are the old pill's peak offsets: with the new pill (`7` 39.6 x 25.3,
  `100` 76.1 x 28.1, scale 1.3) the peak top starts at -43.45 px and the `100`/`7` peaks at 49.46 / 25.71 px in, so
  "Measured: every number above" is false there → recompute the three figures or drop the movement and keep "top at 0 /
  left at 0". (from: b018 review)
- **should** docs/briefs/m14/bugs9/b018-coin-count-report.md:10 "the count's box ran ... 3.7 px past its inside
  right" (and the table's "3.7 px over the right" on :59) is wrong: the old pill is 28.704 px wide with a 3 px stroke,
  the count starts at pad 2.2464 + 2 x coinRadius 10.4832 + gap 1.872 = 14.6016 and is 11.856 wide, so its right runs
  0.754 px past the ink's inner edge — the same 0.75 px as the top, which the b018 review itself quotes → say 0.75 px
  in both places. (from: across jobs — the two documents disagree)
- **should** controller_app/test/stick_text_contrast_test.dart:50 The two Settings tests assert what `ToyCard` already
  did before this job (`packages/toy_look/lib/src/toy_card.dart:184` puts tiles back to ink), so they pass on the old
  code, yet `b017-stick-text-report.md:19-21` and `:54` read as if all four tests failed at 1.07:1 → say in the group's
  comment and in the report which pair is B-017's evidence and which pair guards `ToyCard`. (from: b017 review)
- **could** packages/test_game/test/coin_badge_legibility_test.dart:19 The test covers phone fields only, yet the new
  `inset` (the look's outline width plus the padding) grows the TV's pill too, and `arenaPlayerScale`
  (packages/test_game/lib/src/arena_player_scale_painter.dart:8, 1.5 on the TV) is not in `marbleRadiusOn` → run the
  same font, edge and digits assertions on a TV field with the TV look's radius. (from: b018 review)
- **could** packages/test_game/test/coin_badge_legibility_test.dart:169 The width check cannot fail: the marble is at
  x = 0.5 and the pill is far narrower than the field, so the paper box is always the pill's full width → draw that
  marble at x = 0, where the clamp moves the pill, so the assertion can catch a clipped pill. (from: b018 review)
- **could** packages/test_game/lib/src/arena_coin_badge_painter.dart:153 The doc comment says "the look's own weight
  and line height" but `_countStyle` hard-codes `FontWeight.w700` and `height: 1` → say what the style is (bold ink at
  the count's own line height) or take the weight from the look. (from: b018 review)
- **could** controller_app/lib/src/ui/stick_dialog.dart:32 Only `content` gets the paper theme: the title
  `PhoneText.sticks` and the Defaults/Done buttons are ink only through `dialogTheme`
  (packages/toy_look/lib/src/toy_theme.dart:78) and no test reads them → add the dialog's title (found under
  `find.byType(AlertDialog)`, since 'Sticks' also names the mode tab) to the contrast test. (from: b017 review)
- **could** controller_app/lib/src/ui/paper_tiles.dart:10 This repeats the `ListTileThemeData(textColor: ink,
  iconColor: ink)` inside `ToyCard._body` (packages/toy_look/lib/src/toy_card.dart:184) while the root cause stays at
  `toy_theme.dart:41` (`onBackground`), so "a tile on paper is ink" now has three definitions → when
  `toy_theme.dart:41` takes `colors.ink`, delete `paperTileTheme` and `ToyCard`'s copy in the same job; until then say
  so in this file's doc comment. (from: across jobs)
- **could** controller_app/test/stick_text_contrast_test.dart:103 A second copy of the WCAG luminance and ratio maths
  already sits at packages/toy_look/test/contrast_test.dart:10-20 (same threshold, same curve) → move one helper into
  `packages/toy_look/lib/testing.dart` (guideline §2) and use it from both tests. (from: across jobs)
- **could** controller_app/test/stick_text_contrast_test.dart:47 `'Button size:'` is a hand-typed slice of
  `SettingsText.stickButtonSizeLine`, and the dead-zone and sensitivity lines are not measured while the report says
  "its slider lines are ink on paper" → find the line by the same `SettingsText` call the dialog makes and assert all
  three lines, or narrow the report's wording. (from: b017 review)
- **could** packages/test_game/test/map_render_test.dart:41 A suite run rewrites tracked pictures
  (`docs/design/maps/*.png`; `controller_app/test/support/site_shots.dart:89` writes `site/shots/*.png`), so every
  review in this run had to restore the tree and this working copy now carries three modified `docs/design/*.png` →
  write them to a temp dir (or behind an explicit flag) so a test never changes a tracked file. (from: across jobs)

## Open questions

- Are the 14/16 px font floors what the owner wants? Suggested: yes for now — they are the brief's numbers and the two
  consts are the only knobs.
- Does a three-digit count need its own size? Suggested: no; the brief asked for one- and two-digit floors, 16 px holds.
- Does the clamped pill read well over the marble's head? Suggested: only the owner's device look can say; fix the eyes
  finding first so the look judges the design and not a bug.
- Is the TV's pill growing (the new inset) acceptable? Suggested: yes, bigger only — and add the TV field to the test.
- Is the pill sliding while it pops at the field's edge acceptable? Suggested: yes; it is what keeps the peak on the
  canvas, and it only shows at the top and left edges.
- Should `ArenaCoinBadgePainter` and `CoinBadgeLayout` be exported from `packages/test_game/lib/test_game.dart` instead
  of the test's `src` import? Suggested: keep the `src` import, as `party_host`'s tests do; no export.
- Should the `toy_look` root fix (`toy_theme.dart:41` → `colors.ink`) be scheduled now? Suggested: yes, as its own
  small job before any other dialog gets a tile; `paperTileTheme` and `ToyCard`'s copy go with it.
- Does `ListTileTheme(data:)` replace or merge with the app's own `listTileTheme` in the pinned Flutter version?
  Suggested: check the SDK once; nothing is lost today because `toy_theme.dart:41` sets colours only.
- Does the b018 fix need marking "Fixed, unverified: needs device check"? Suggested: yes — its cause was never
  measured on a device and the fix is reasoning on two candidates; B-017's cause was reproduced by its failing test,
  so only its look needs the check.
- Should this run's findings be written into `docs/code-health.md` (review-rules.md:11 says every kept finding goes
  there)? Suggested: yes, the four `should` items, when the batch closes.

## Numbers against targets

No fix misses a target in its brief: 4.5:1 (B-017) → 17.41 night / 15.53 sunny (recomputed 17.409 / 15.532); ≥14 px and
≥16 px (B-018) → 14.0 / 16.0; pill on the canvas at eight edges and corners on both phone fields (test passes); `100`
inside its pill (test passes); 468 phone tests, 230 arena tests (both per-job reviews re-ran them).

Report values that are wrong, with the arithmetic:
- `b018-coin-count-report.md:19-21`, `:60-61` — moved down 33.2 px: the new `7` pill's peak top is
  0 - 12.48 - 1.872 - 25.305 - 16.448 = **-43.45**, so it moves **43.4** px; moved in 34.1 / 18.7 px for `100` / `7`:
  the new half peaks are 76.087/2 x 1.3 = **49.46** and 39.555/2 x 1.3 = **25.71** px.
- `b018-coin-count-report.md:10`, `:59` — 3.7 px past the inside right: **0.754** px (3 px = one outline width).
- `b018-coin-count-report.md:58` — the `100` pill is **76.1 px** wide (14.152 + 1.872 + 48 + 12.063 = 76.087), which
  the summary's "76.0" on `:17` rounds away from while the table's other widths round up.
- Verified, no action: 12.48 px radius (0.032 x 390), 11.856 px old font, 28.7 x 16.35 old pill, 39.6 x 25.3 (`7`) and
  28.1 (`100`) heights, 51.4 x 32.9 / 78.1 x 36.5 / 98.9 x 36.5 peak boxes (`78.2` and `99.0` are rounded), the TV's
  17.78 px count; and B-017's 1.0744, 17.409, 15.532, 6.099, 6.868.

## Could not check

- That the two new test files fail on the old code: only the runner's tests-first check and the authors' reports say
  so; I ran nothing (a suite run rewrites tracked pictures).
- Anything on a device: both bugs are the owner's eye reports, and neither fix has been seen on a phone or TV.
- Whether `ListTileTheme(data:)` merges with or replaces the app's `listTileTheme` in this Flutter version (SDK source
  not read); nothing is lost today because that theme sets only text and icon colours.
- That the host app's dialogs have no list tile today (so the `toy_theme.dart:41` cause is latent): checked by grep,
  not by running the TV app.
- Whether the three modified `docs/design/*.png` in the working copy predate this run: `git diff --stat` shows neither
  commit contains a picture, but I cannot tell which run wrote them.

## Commit message — a draft

M14 bugs9 review: the clamp puts the pill over the marble's eyes

Both fixes meet their briefs; what is wrong is the B-018 report's numbers and
what the two new tests leave uncovered.
The top-wall clamp moves the pill over the marble itself: a marble at the wall
wears its pill at y 0..25.3 while its eyes sit at 7.2..14.7.
The report's distances are the old pill's (33.2/34.1/18.7; the new pill moves
43.4/49.5/25.7) and its "3.7 px" overflow is 0.75 px.
B-017's Settings tests pass on the old code, so the report counts four tests as
one proof.
The coin test needs a TV field and a width check that can fail, the contrast
test the dialog's title, and the WCAG maths sits in two files.

## Status row

- **M14 bugs9 B-017 + B-018 (reviewed):** both fixed and tested (dialog tile 1.07:1 → 17.41:1 with a contrast test;
  coin count 11.9 → 14/16 px with the pill clamped on the field), 468 phone and 230 arena tests pass; open — the clamp
  covers the eyes of a marble at the top wall, three wrong distances and one wrong overflow in the B-018 report, a TV
  field and a real width check in the coin test, the dialog's title in the contrast test, both fixes' device check.

## Delete

- none
