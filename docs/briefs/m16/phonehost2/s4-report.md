# M16 phonehost2 S4 — scoreboard and final scores in HostFrameScreen with ScoreRow

## Summary

- `night_scoreboard_screen.dart` is now a `HostFrameScreen`: title `NightText.partyNight`, a trailing chip
  (key `nightScoreChip`, 48 px) holding the last-round banner (key `nightLastRoundBanner`, scaled down inside
  the chip line) and a `ToyPill` (key `nightScoreRound`, "Round n of m" / "Final scores"); body = confetti on
  the final scores plus the score card (key `nightScoreboard`); footer = `NightFooterButtons` between rounds and
  one "Back to games" button (key `nightBackToGames`, autofocus) on the final scores. `nightScoreCardWidthPx`,
  `nightCrownSlotPx`, `nightPlaceSlotPx` and `nightRoundPointsSlotPx` are deleted; the old `_ScoreRow` is gone.
- `score_row.dart` grew the brief's optional fields with today's look as the default: `rank` with a "3=" tie,
  a podium disc for 1-3, a taller winner row (68 px, 58 px badge, 32 px name, gold wash), the crown on the
  badge (`badgeMark`, passed by the night as `NightCrown`), `isAway` dimming, `isRobo`'s head, `+delta`, and a
  `ScoreRowKeys` value object so the night's finders keep their names (`nightRow-<id>`, `nightName-<id>`,
  `nightPlace-<id>`, `nightTotal-<id>`, `nightRoundPoints-<id>`). No night word appears in the file, so Arena's
  results can reuse it.
- One real bug fell out of the "before any round" test: a fill of **0** width inside the card's `IntrinsicWidth`
  asks a `FractionallySizedBox` for `infinity × 0` (a NaN) during the card's measuring pass, which stopped the
  whole card laying out on an unscored night. The bar now draws its track alone when it has nothing to fill
  (`score_row.dart`), and `score_row_test.dart`'s empty-bar test says so.
- Tests first: new `test/night_scoreboard_frame_test.dart` (34 tests: five devices × 4 and 6 players, the
  header, the ties, away and Robo, the final scores with the celebration once, both footers, the deltas, the
  20 px floor, and the nickname fit measured with the real fonts). `score_row_test.dart` has one test rewritten
  (the empty bar). `night_screens_test`, `night_robo_test`, `night_round_test`, `arena_night_test`,
  `end_night_arena_test` and `end_night_puzzle_test` needed no change and pass.
- Checks: `tools/check.sh format analyze host` → PASS format, PASS analyze, PASS host (`flutter test` in
  `packages/party_host`: 737 passed, 104 skipped — the `PHONE_FIT` ones). `tools/review.sh` → 0 fail, 2 notes
  (the place `3` in `_medalOf`'s switch, and `score_row.dart` at 380 lines against the 400 limit).
- Files: the three lib files above, the new frame test, `score_row_test.dart`, this report. `run.log` and
  `tv_test_app/windows/flutter/generated_plugin*` show as changed but are the job runner's log and `check.sh`'s
  `flutter pub get`, not my edits.

## The frame px this draws (960x540 frame at every device)

- Header 64, footer 84, body 392: unchanged by this job, and the frame keeps 960x540 at all five sizes, so the
  scoreboard's numbers below are the same everywhere (`getSize` in the frame test reports frame px).
- Rows 52 px each; the winner's row 68. Card = rows + the card's 16 px padding top and bottom.
  - Between rounds, 6 players: 6 × 52 = 312 + 32 = **344 of 392** (48 spare).
  - Between rounds, 4 players: 4 × 52 = 208 + 32 = **240 of 392** (152 spare).
  - Final scores, 6 players: 68 + 5 × 52 = 328 + 32 = **360 of 392** (32 spare).
  - Final scores, 4 players: 68 + 3 × 52 = 224 + 32 = **256 of 392** (136 spare).
  - Nothing scrolls and no layout exception fires in any of the ten device/players cases.
- Header chip: exactly `roundChipHeightPx` = 48 inside the 64 header (asserted), its pill and the banner in
  one row, the banner `FittedBox(scaleDown)` so a long banner never makes the line taller.
- Footer: `NightFooterButtons` is the 480 × 64 pair the footer band already took (S3); on the final scores one
  64 px `HostButton` centred, inside the band and hit-testable at 640x360 (s = 2/3).
- Row internals: rank column 32, badge 38 (58 for the winner), name column 190, the bar takes the slack at
  16 px high, star 24, total in the body size, "+n" in the frame's 20 px small size.

## Nickname fit, measured with the real fonts

Widths in frame px, `TextPainter` with `ToyType.frame.body.copyWith(fontSize:)` after `loadLookFonts`
(`test/support/toy_fonts.dart`), against the 190 px column:

| name | 22 px (body) | 32 px (winner) |
| --- | --- | --- |
| Alexandria | 111.5 | 162.1 |
| Nightshade | 117.4 | 170.8 |
| WWWWWWWWWW | 244.9 | 356.2 |
| MMMMMMMMMM | **191.0** | 277.8 |
| iiiiiiiiii | 56.1 | 81.6 |

- Alexandria and Nightshade fit at both sizes, with 72.6 and 19.2 px to spare at 32 px (asserted, and the
  rendered `RenderParagraph.didExceedMaxLines` is false for both on the final scores).
- `WWWWWWWWWW` does not fit at either size, as the brief expects (asserted > 190), so such a name ellipsises.
- `MMMMMMMMMM` is 1.0 px over the column at 22 px (191.0 vs 190.0): the narrowest realistic worst case is one
  pixel too wide and ellipsises by one glyph's edge. The column is left at 190 as the brief says; see Question 2.

## Tests written and rewritten

New `test/night_scoreboard_frame_test.dart` (34 tests), all at the five devices from `host_frame_screen_test.dart`
through `hostFrameBuilder` unless a test says otherwise:

1. "`<device>`, 4 players / 6 players: no scroll, 52 px rows and the footer on screen" (10 tests) — no
   `Scrollable` under `hostFrameBody`, no exception, every row exactly `scoreRowHeightPx` (frame px), and the
   footer's buttons inside the header/body/footer keys and `hitTestable`.
2. "… every text on the scoreboard is at least 20 frame px" (10 tests) — every `Text` under the screen with its
   effective style (`DefaultTextStyle` merged with the widget's own) is >= 20.
3. "the header says which round it is, and before the last round it says the round is double" — "Round 1 of 3",
   no banner yet.
4. "before the last round the header carries the banner in its 48 px chip line" — "Round 2 of 3", the banner
   present, the chip exactly `roundChipHeightPx` and inside the header's rect.
5. "the final scores say so in the header and drop the banner" — "Final scores", no banner.
6. "two players on the same total share their place, so the row reads \"3=\" and \"1\"" — p3 and p4 both "3=",
   p1 "1", p2 "2".
7. "a player who left is greyed and Robo is drawn full, as it is never away" — that row's `Opacity` is
   `nightAwayOpacity` (0.45), Robo's and the present players' are 1, and the leader's bar is 1.0.
8. "the final scores: the winner is taller with the crown, and ranks 1 to 3 wear the podium" — winner row 68, the
   others 52, `nightCrown-p1` only, gold = the look's focus (a disc `DecoratedBox` of that colour), silver on
   p2, bronze on p3 and p4 (tied third), none on p5, confetti present, and the celebration played exactly once
   even after another frame.
9. "between the rounds the footer is the night's two buttons and no row wears a crown" — two `HostButton`s, no
   `nightBackToGames`, no crown, no disc, no confetti, all rows 52.
10. "the final scores' footer is one button, Back to games, and it ends the night" — one `HostButton`, the key,
    no Shape Race or Bumper Round, and a tap leaves `partyNightProvider` null (the screen is the first route,
    so nothing is left to pop).
11. "a row shows what the round added, and a round with nothing to add shows no \"+0\"" — "+9" and "+2".
12. "before any round the bars are empty and no row has a \"+0\"" — no `nightRoundPoints-<id>` key and every
    bar at a share of 0.
13. "the frame's small text is used and the winner's name is the design's 32 px" — 32 on p1, the body's 22 on
    p2, and "+n" in `ToyType.frameSmall`.
14. `group('nickname fit')` — the measurements above (Alexandria and Nightshade fit at 22 and 32; the widest ten
    letters need more than 190; the final scores draw both real names whole).

Rewritten: `test/score_row_test.dart` "a card with no points yet draws an empty bar and never divides by zero"
now expects no fill widget inside `scoreRowBar` (the track alone) instead of a `FractionallySizedBox` with
`widthFactor: 0.0` and a 0 px size — the row draws the same pixels, and the assertion that fails if the bar
tries to divide by zero (or asks for a share of an unbounded width) stays. Everything else in that file is
untouched.

## Self-check (review-rules part A)

1. **Every host setup** — the scoreboard reads only the look, the night, the players, the settings and the fake
   sound player, so a TV/PC host, a phone hosting, "Show on this device" and a joined phone draw the same
   widget; the five-device run includes 640x360 (s = 2/3) and 1920x1080 (s = 2) with taps that go through the
   frame ("the final scores' footer … ends the night"); no protocol or saved state changed, so an older build
   is unaffected.
2. **When kept state starts and ends** — the only kept state is `_celebrated`: false when the screen is built,
   set the first time the night is over (the sound plays then, and not again on rebuild: test 8), and it dies
   with the screen; `LobbyHold` keeps the lobby music while the scoreboard is up, and the night's own rows are
   read fresh each build, so nothing runs when no night is on (`night == null` draws neither card nor footer,
   as before).
3. **How a new state combines** — nothing new blocks input: the final scores differ only by the confetti stack,
   the crown and the medals, and the footer's one button; away players and Robo combine as test 7 says; Escape
   still asks "End the party night?" (with No staying and Yes clearing, `night_screens_test` "Back asks first"),
   and the celebration is a sound, not a wait.
4. **Stay in the job's folder** — `git status` shows only the three lib files, the new frame test, the
   rewritten `score_row_test.dart` and this report; `run.log` and the `tv_test_app/windows/flutter` generated
   plugin files are the runner and `check.sh`'s `flutter pub get`.
5. **Stop rather than overstep** — the silver and bronze could not stay raw `Color(0x…)` constants (review's
   colour rule: none outside `toy_look`), and `toy_look` is outside `allow:`, so the two named values now take
   the look's palette (Question 1); the 190 px name column is 1 px short for `MMMMMMMMMM` and is left as the
   brief says (Question 2); dead code in `night_widgets.dart` is reported, not deleted (Question 3).

## Questions

1. **Silver and bronze come from the look's palette, not from raw colour constants.** The brief asks for
   "silver and bronze named constants", but `tools/review.sh` fails any `Color(0x…)` outside `toy_look`, and
   `toy_look` is outside `allow:`. I made `scoreSilver(colors) => colors.wall` (a cool grey-blue in both
   palettes) and `scoreBronze(colors) => colors.caution` (the look's amber, the same in both). Should
   `ToyColors` gain silver/bronze/focus-metal names of its own, so a podium's three metals are the look's?
2. **`MMMMMMMMMM` is 1.0 px over the 190 px name column** (191.0 measured at 22 px). The brief says not to
   change the column and to report it: it is reported. Nothing realistic (Alexandria 111.5, Nightshade 117.4)
   needs more room, so the owner's call is whether a 192 px column is worth it for the ten-M case.
3. **Dead code left in `night_widgets.dart`** (outside `allow:`): `NightGameButtons` is no longer used by any
   lib file or test, and `nightAwayOpacity` (0.45) is now only used by two tests, since `ScoreRow`'s
   `scoreRowAwayOpacity` carries the same value; one of the two names can go when that file is next touched.
4. **`test/coverage_all_test.dart` is generated** and does not list `score_row.dart` (nor `award_tile.dart` or
   `night_footer_buttons.dart` from S3); it needs `dart run tools/coverage_imports.dart` in a job allowed to
   touch it.
5. **The night's celebration is now on `HostFrameScreen`'s body**, as before, but it is only asserted in the new
   frame test; `night_reveal_test.dart` tests the reveal's own sound, so the two together are the coverage.
   Should the night's sounds have one test of their order (reveal → scoreboard)?

## Hand-over

- Arena's results (the later job) can build `ScoreRow`s the same way: a `ScoreRowData` per coin holder with
  `medal`, `isWinner`, `isRobo` and a `ScoreRowKeys` of its own (`arenaRow-<id>` etc.), the same three metals
  (`scoreSilver`/`scoreBronze` take the look), and its own card in the body. Nothing in `score_row.dart` says
  "night".
- The header pattern is reusable: title + a 48 px `SizedBox` chip carrying a `FittedBox` banner and a `ToyPill`,
  and the footer is the S3 `NightFooterButtons` between rounds, one `HostButton` (autofocus) when there is only
  one way on.
- A card with an `IntrinsicWidth` (every `ToyCard`) must not hold a `FractionallySizedBox` whose factor can be
  0 next to a flex child: the measuring pass multiplies an unbounded width by it. Drawing nothing at 0 is the
  cheap answer.

## Commit message

Draw the night's scoreboard and final scores in the host frame

- NightScoreboardScreen on HostFrameScreen: the night's title, a 48 px chip
  (last-round banner, "Round n of m" / "Final scores"), the footer pair
  between rounds and Back to games on the final scores.
- ScoreRow: "3=" ties, podium discs for 1-3, a taller winner row (58 px badge,
  32 px name, gold wash), dimmed leavers, Robo's head, +delta and keys kept.
- The bar draws its track alone when empty, so an unscored card lays out.
- Tests: a five-device scoreboard frame test, the nickname widths measured
  with the real fonts, and the empty-bar row test rewritten.

## Status row

S4 done: night scoreboard and final scores on HostFrameScreen with ScoreRow (ties, podium, winner row, away, Robo, keys), the 48 px status chip, both footers, and the empty-bar layout fix at the five devices (34 new tests); score_row_test's empty-bar test rewritten. Open: the palette's silver/bronze (question 1), the 190 px column and `MMMMMMMMMM` (2), dead night_widgets code (3), coverage_all_test (4), the night's sounds' order (5); S5 (reveal), S6 (Arena/puzzle results).

## Delete

- none
