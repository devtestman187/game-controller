# pf1 — do the night screens fit a phone host? (measurement only)

## Summary

Setup: Sunny look (midday clock, `toyTvProvider` false, so the look's phone type 32/18/15), real Fredoka and
Nunito, four phones joined with nicknames of 18 to 21 characters, `devicePixelRatio` 1, 5-round night.
"fits" = no exception reported; "scrolls N" = the screen's Scrollable `maxScrollExtent` in dp; "off/under" =
the screen's way-on button is not on the screen without scrolling.

| screen | 640x360 | 360x640 | 1280x800 | 1280x720 |
| --- | --- | --- | --- | --- |
| night start card | fits, scrolls 551, button off | fits, scrolls 293, button off | fits | fits, scrolls 70 |
| scoreboard, 2 of 5 | fits, scrolls 175, buttons 27 px under | 4 overflows 16/15/8.6/7.7 px, nicknames 0 wide | fits | fits |
| final scores | fits, scrolls 115, button under | 4 overflows 18/18/14/7.3 px, nicknames 0 wide | fits | fits |
| awards reveal | fits, scrolls 15 | overflow 121 px (winner row) | fits | fits |
| Arena results | fits, scrolls 71, Play again on | 4 overflows 63/56/39/3.1 px | fits | fits |
| puzzle results | fits, scrolls 86, Next puzzle on | 2 overflows 188 + 17 px | fits | fits |

- Smallest text dp on the 640x360 size: start card 15.0, scoreboard 18.0, final scores 18.0, reveal 13.5,
  Arena results 18.0, puzzle results 13.5. The 13.5 is a badge's number (`ToyType.title` cut to the disc),
  not body type; nothing renders below 13.5 dp anywhere in the run.
- A 24 px label exists on the three night screens (start, scoreboard, final) and renders at 24.0 dp; the
  reveal, Arena and puzzle results have none in the run (`label24Dp` empty).
- Global scale wrapper: none observed. Every text's painted scale is exactly 1 in all 24 cases
  (`scalesAwayFromOne` empty everywhere), so no Transform.scale, FittedBox or MediaQuery text scale sits
  above any measured text.
- Turns used: about 20 of my messages (the two extra were the way-on key fix and the paragraph de-duplication,
  each followed by a rerun).

## What it measured, screen by screen (the numbers behind the table)

640x360 (a phone host lying down) — every screen fits, and the ones that scroll:

- start card: viewport 304, `maxScrollExtent` 551; the Shape Race button is at y 755–803, so 443 px below the
  fold; 23 Texts.
- scoreboard: 304 / 175; Shape Race at 387–435 (below a 360 screen, reached by one short scroll); 27 Texts.
- final scores: 304 / 115; Back to games at 387–435; 25 Texts.
- reveal: 304 / 15 (its card is 15 px taller than the viewport); it has no button; 8 Texts.
- Arena results: the card's own scroll view 360 / 71; Play again at 303–351, on screen; 19 Texts.
- puzzle results: 360 / 86; Next puzzle at 305–348, on screen; 19 Texts.

360x640 (a phone host standing up) — the size that spills:

- start card: fits, 584 / 293; Shape Race at 777–825 (off screen, 233 px under).
- scoreboard: 4 RenderFlex overflows on the right (16, 15, 8.6, 7.7 px). The four nicknames are laid out
  0 dp wide with an ellipsis: they want 201, 199, 190 and 185 dp, and the row's fixed slots (crown, place,
  badge, points) already take its width, so the Expanded name gets nothing.
- final scores: the same four rows, overflows 18, 18, 14, 7.3 px; the same four nicknames 0 dp wide.
  Both screens report no scroll (0 of 584): the card is cut off instead.
- reveal: one overflow of 121 px on the right, in the winner's row ("One winner" + badge + name + crown +
  +3 points); no scroll.
- Arena results: 4 overflows (63, 56, 39 and 3.1 px) in the player rows; no scroll.
- puzzle results: 2 overflows (188 px in the side row, 17 px below it); no scroll.

1280x800 and 1280x720 (a tablet and a TV): every screen fits with no scrolling apart from the start card's
70 dp at 1280x720. No text is shortened anywhere on either.

## What changed

- `packages/party_host/test/phone_fit_test.dart` (new, 359 lines) — the measurement. Six screens × four
  sizes, each a `testWidgets` that opens the screen, saves `docs/briefs/m16/phonefit/<screen>-<WxH>.png`,
  measures it and appends to a list; `tearDownAll` writes `results.json`. The whole file is skipped unless
  `PHONE_FIT` is set.
- `docs/briefs/m16/phonefit/*.png` (24 pictures) and `results.json` — written by the test, not by hand.
- No `lib/` file changed. `git status` shows three `tv_test_app/windows/flutter/generated_plugin*` files as
  modified; `git diff` on them is empty (line endings only), and I did not write to them.

How each measurement is taken:

- **Exceptions.** `FlutterError.onError` is replaced for each case, so a RenderFlex overflow is collected
  into `errors` instead of failing the test (and one screen cannot stop the others); the binding's handler is
  restored in a `finally`. `tester.takeException()` is also read after the open and its message added if
  it has one (it is null in all 24 cases, since the capture comes first).
- **Scrolling.** One walk under the screen's root widget collects every `ScrollableState`; the result is
  each one's `maxScrollExtent` (content height minus viewport) and `viewportDimension`.
- **Text clipping.** For each `RenderParagraph`: it is clipped if it hit its lines' limit
  (`didExceedMaxLines`, i.e. an ellipsis or a cut) or if it cannot wrap (`!softWrap`) and its intrinsic
  width is wider than the constraints its ancestors gave it (`constraints.maxWidth` + 0.5 dp slop). Each hit
  records the text (40 characters), the width it wants, the width it was given and its laid-out width.
- **Smallest text dp.** For each paragraph: `style.fontSize` × the paragraph's own `TextScaler`
  (`MediaQuery`'s text scale) × the scale everything above it paints with. That last factor is the distance
  between `localToGlobal(Offset.zero)` and `localToGlobal(Offset(1, 0))`, which reads every
  `Transform.scale`, `FittedBox` and anything else an ancestor pushes (`RenderTransform` exposes no public
  transform in this Flutter, and the painted scale is what a player sees anyway).
- **The 24 px label.** Any paragraph whose declared `fontSize` is 24 is reported with the dp it renders at.
- **Way on.** The first of a per-screen list of button keys that exists, with its rect compared to the
  screen's rect (0.5 dp slop). Keys: start and scoreboard `nightShapeRace`, final scores
  `nightBackToGames`, Arena `arenaAgain`, puzzle results `nextPuzzle`/`rematch`/`playAgain`/`next` (the card's
  first button in this run was Next puzzle, a series round), the reveal none.
- **Pictures.** The root layer's `toImage` under `tester.runAsync`, as `test/support/pixels.dart` does, then
  `toByteData(png)` and a sync write.

How the screens are reached (helpers from `test/support/`):

- The roster is the fake host's four phones: the sample's own p1 and pairing p2 are removed and p1–p4 added
  with the long names, so `gamePlayersProvider` carries them like a real join.
- start card: `openNight`.
- scoreboard: the night started by hand (five rounds, `threeAwards`), two rounds recorded, Escape, then the
  picker's night card again; the final scores the same with all five rounds.
- reveal: `NightRevealScreen` mounted, the night started and played, one `pump` — never `pumpAndSettle`,
  which would run the award's 4 s timer and move on to the next award.
- Arena results: `ArenaResults` mounted as the home (it owns the card alone, the same mount
  `arena_results_test` uses), with P1 winning the coins.
- puzzle results: Shape Race's 1v1 round (P1 left, P2 right) to its end via `openJoin`, `startRace`,
  `lockEveryPiece`, `endRound`.

## Computed values (for checking against the rules)

- Wanted widths of the four nicknames at the look's button type: 201, 199, 190, 185 dp; given 0 dp and
  laid out 0 dp on both scoreboard screens at 360x640.
- The scoreboard card at 360x640: `maxScrollExtent` 0 of a 584 dp viewport; its rows overflow by 16, 15, 8.6
  and 7.7 px (final scores: 18, 18, 14, 7.3 px).
- Start card `maxScrollExtent`: 551 of 304 at 640x360, 293 of 584 at 360x640, 0 of 744 at 1280x800, 70 of 664
  at 1280x720. Shape Race button: 755–803 at 640x360 (443 px under the fold), 777–825 at 360x640 (233 under),
  634–682 at both 1280 sizes (on screen).
- Reveal: 15 of 304 at 640x360; card 371 dp tall in a 640-high screen; winner row overflows 121 px at 360x640.
- Arena results: Play again at 303–351 (640x360) and 379–427 (360x640), on screen both times.
- No text was clipped on any size other than 360x640, and no exception was reported on any size other than
  360x640.

## Not covered, or worth knowing

- The PNGs show a box where an icon goes: the test bundle has no icon font (`toy_fonts.dart` says icons keep
  their box size, so the fit is unaffected). Everything else in the pictures is the look's own face.
- The look is the phone one (`toyTvProvider` false is the harness's default). A phone host running the TV
  type, and a host set to a larger system text scale, are not measured.
- The Arena results card is measured on its own, without the title bar and background the Arena puts it over.
- The reveal is measured on its first award (Best Helper, won by P1), with its timer running; the other two
  awards' layouts are not in the pictures.
- Two players sit the puzzle round out (P3 and P4), so their names are not on that card at all.

## Questions

1. Keep `--dart-define=PHONE_FIT=true` as a second switch? This session's shell refuses a `PHONE_FIT=1 …`
   prefix and a helper script, so the run used `flutter test --dart-define=PHONE_FIT=true`. Say the word and
   the environment variable stays the only switch.
2. The fake host passes a controller's name through as the nickname uncapped (`FakeGameHost.players`), while
   a real host cuts it to 10 characters (`nicknameOf`). These numbers are therefore the worst case with an
   18–21 character name. Should pf2 also measure the real 10-character cap, so a fix is judged against what
   a couch sees?
3. The puzzle results' way-on button in this run is "Next puzzle" (a series round started from the puzzle
   pick). If the intended case is a plain round's "Rematch", say so and the helper can start one instead.

## Suggestions (not acted on)

- A 360x640 measurement with the 10-character cap would separate "the row cannot hold a real nickname" from
  "the row cannot hold any nickname".
- The scoreboard and the results rows are the only places where a long name spills; the start card, reveal
  and puzzle cards spill their whole card instead (no horizontal scroll, nothing shortened), which is the
  same finding at a different place.

## Self-check (review-rules part A)

1. **Every host setup.** Test-only; no shipped code touched, so no host setup changes behaviour. The run
   used the harness's phone look at four sizes (`phone_fit_test.dart`, all 24 cases).
2. **When kept state starts and ends.** The test keeps one global list and writes it once in `tearDownAll`;
   the reveal's award timer is the screen's own and is cancelled when its widget is disposed at the end of
   the case (no pending-timer failure in the run).
3. **New state combined with others.** Not affected: no round, pause or away state is invented here; the
   screens are the ones the existing helpers open.
4. **Stay in the job's folder.** Yes — only `packages/party_host/test/phone_fit_test.dart` and
   `docs/briefs/m16/phonefit/` were written (the test writes there itself).
5. **Stop rather than overstep.** Not needed; the only deviation is the `--dart-define` fallback, reported
   above as a question.

## Hand-over

Run it from `packages/party_host` with `PHONE_FIT=1 flutter test test/phone_fit_test.dart` (or the
`--dart-define` above); without either it skips in under a second and the normal suite is untouched. It takes
about 7 s and rewrites the 24 PNGs and `results.json` in place. pf2 can read `results.json` directly: one
entry per screen and size, with `errors`, `scrolls`, `clipped`, `smallestFontDp`, `label24Dp`, `wayOn` and
`scalesAwayFromOne`.

## Decisions

- "Sunny look" = the harness's default look (midday clock, `toyTvProvider` false → phone type and menu sizes);
  the clock stays `harnessNow`.
- Nicknames are 18–21 characters: "Bartholomew The Great", "Maximilian Thunderbolt", "Alexandria Nightshade",
  "Christopher Von Trapp".
- The scoreboard is "mid-night" after 2 of 5 rounds; the final scores have all 5 rounds recorded and a crown.
- The reveal is mounted under a night already played rather than reached by a round's Next, which is how
  `night_reveal_test` opens it; only one `pump` so the first award stays.
- The Arena results card is mounted alone, as `arena_results_test` does; a whole Arena round would add the
  field and the title bar the brief did not ask about.
- The puzzle results come from a 1v1 Shape Race race between P1 and P2, the cheapest way through the existing
  helpers; P3 and P4 do not join it.
- "Way on" is a per-screen key list, the first key found being the one checked; the reveal has none.
- "On screen" means the button's rect is inside the screen's rect (0.5 dp slop), not inside the scrollable's
  viewport — the title bar overlays the top, and no way-on button sits there.
- Clipping, the smallest dp and the 24 px label follow the rules written above; the painted-scale trick
  stands in for reading `Transform.scale`/`FittedBox` directly.
- `--dart-define=PHONE_FIT=true` was added because this shell cannot set an environment variable for one
  command; it is the same switch, and it is a question for Claude.

## Commit message

Add a phone-fit measurement test for the night screens

phone_fit_test measures the night's start card, scoreboard, final scores,
awards reveal, Arena results and puzzle results at 640x360, 360x640,
1280x800 and 1280x720, with four long-nicknamed phones and the real fonts.
It records exceptions, scroll extents, whether each screen's way-on button
is on screen, shortened text and the smallest text dp, and writes a PNG per
screen and size plus results.json. Skipped unless PHONE_FIT is set; no lib
file changes.

## Status row

pf1 done: measurement test, 24 PNGs and results.json in docs/briefs/m16/phonefit (skipped unless PHONE_FIT=1).
Open: 360x640 is the size where the scoreboard, final scores, reveal, Arena and puzzle results spill or lose
their nicknames; what pf2 does about it, and the three questions above.

## Delete

- docs/briefs/m16/phonefit/run.sh
