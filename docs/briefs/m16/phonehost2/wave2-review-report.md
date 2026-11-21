# Wave 2 review — S4 (scoreboard), S5 (reveal), S6b (badge floor)

## Summary

Verdict: **needs Claude**. Counts: must 1, should 2, could 6.
The score card is never given a width: `Align` hands it a loose one and `ToyCard` sizes to its content, so the
scoreboard is ~380–430 px wide in a 912 px stage and the rows' bars have no slack; no test measures the card.
S6b's report and commit message claim a `badgeNumberShare` constant that player_badge.dart does not have.
The reveal adds one 40 px line per tied winner with no cap: four winners need 330 px of text inside the card's
328 px at 640x360, and the tests draw two.
The rest is small: S4's report overstates one test, the final scores are drawn at one device only, and three
naming/leftover details (bare rank literals, a second away-opacity name, an unused string and constant).
S5 is otherwise clean; S6b is a correct, disclosed stop (host_focus_ring_test's series walk is outside its
`allow:`), so its results layout (a)/(b) is still unbuilt and needs a decision.

## Findings

- **must** packages/party_host/lib/src/ui/night_scoreboard_widgets.dart:66 `_Scoreboard` puts the card under an
  `Align`, which lays it out with a loose width, and `ToyCard`'s `IntrinsicWidth` then sizes to the content, so the
  card is only as wide as a row's 32 + 38 + 190 + ~6 bar + 24 + total + delta (≈380–430 of the 912 px stage) and
  the rows' `Expanded` bar gets no slack, against the comment at line 76 and DESIGN section 1 rule 4 →
  give the card the body's width the way the reveal does (`LayoutBuilder` + `SizedBox(width:
  constraints.maxWidth)`) and assert its width is `frame width − 2 × hostFrameGutterPx` in
  night_scoreboard_frame_test.
- **should** docs/briefs/m16/phonehost2/s6b-report.md:33 the report (and 8cd1455d's commit message) list
  `badgeNumberShare = 0.55` as added, but packages/party_host/lib/src/ui/player_badge.dart has no such constant —
  only `badgeNumberFloorPx` (:16) and `badgeNumberMinDiameterPx` (:24); the 0.55 is a doc comment and the test's
  own `_numberShare` → drop the claim from the report and commit message, or add the constant and use it in the
  test.
- **should** packages/party_host/lib/src/ui/night_reveal_widgets.dart:147 the winners' column adds one 40 px line
  per winner with no cap inside a card whose room at 640x360 is 328 px after its 32 px padding: four winners need
  52 + 8 + 4×40 + 16 + 2×26 + 16 + 26 = 330 px before any line spacing, and the tests draw two at most → cap the
  names (two lines plus "+n more") or test a three-way tie and size the card for it.
- **could** docs/briefs/m16/phonehost2/s4-report.md:101 (and its test at night_scoreboard_frame_test.dart:388)
  says test 13 checks "+n in ToyType.frameSmall", but the test asserts only the two name sizes and never the
  delta's style → assert `nightRoundPoints-p1`'s style is `ToyType.frameSmall` or correct the report.
- **could** packages/party_host/test/night_scoreboard_frame_test.dart:181 the five-size loop pumps a night with one
  round only, so the final scores (taller winner row, one-button footer) are drawn at 640x360 alone, where the
  brief asks for "the five sizes … rows 52 px (winner row taller on the final)" → add a `rounds: _nightLength.rounds`
  pass to the loop.
- **could** packages/party_host/lib/src/ui/night_scoreboard_widgets.dart:143 the podium places are bare 1/2/3 (and
  `row.place == 1` at :110 and :136), where guidelines §2 allow only 0, 1, -1 and 2 bare → map the place to the
  medal once with named places and reuse it.
- **could** packages/party_host/lib/src/ui/score_row.dart:56 the away dim now has two names and two 0.45s
  (`scoreRowAwayOpacity` here, `nightAwayOpacity` at night_widgets.dart:21, which only the tests still read) →
  have the night pass its own constant as `awayOpacity` and keep one name.
- **could** packages/party_host/lib/src/ui/player_badge.dart:16 `badgeNumberFloorPx` is public but read by nothing
  but a doc comment, while puzzle_results_frame_test.dart:40 copies 20.0 as its own `_floorPx` → use the constant
  in the guard or keep it private.
- **could** packages/party_host/lib/src/text/night_text.dart:56 `NightText.winners` lost its last use when S5
  dropped the count line, leaving a dead public string in a lib file outside that job's `allow:` → delete it in a
  job that owns night_text (S5's Hand-over names it).

## Decisions to confirm

- S6b's open half: the results layout (a)/(b) and the brief's item 1 tests need `test/host_focus_ring_test.dart`
  in `allow:`, a DESIGN section 1 rule 5 exception for way-on buttons in the body, or a split of the series round;
  the brief's (b) contradicts rule 5 as written.
- S4's silver and bronze are the look's `wall` and `caution`, not metals (s4 Question 1): the palette needs silver,
  bronze and focus-metal names in a job that owns toy_look.
- The 190 px name column is 1.0 px short of `MMMMMMMMMM` (191.0, s4 Question 2): left as the brief says; the owner's
  call.
- S5 keeps the "+3 points" line at 26 px and drops the "One winner" / "N winners" count (which makes
  `NightText.winners` dead); DESIGN section 4's list does not name the +3 line.
- S4's winner row is 68 px: the brief asked for a named height but DESIGN does not give one, so 68 is the job's
  choice.
- The frame is still not installed in either app (wph1/wtv pending), so none of these screens is user-visible yet;
  wave 1's finding stands.

## Could not check

- `tools/review.sh` (the sandbox refused to run it), so the reports' "0 fail, 2 notes" was not re-run.
- A visual check of any screen, including the score card's actual width; finding 1 is read from the widget chain
  (Align loosens, ToyCard sizes to content), not from a measurement.
- A three-way or four-way tie's real overflow: computed from the named font sizes (line boxes are taller, so the
  four-way case is certain and the three-way one is at the limit); the test draws two.
- `run-findings.md` does not exist; `run.log` records all three new test files as failing on the old code.
- The full host suite; I ran the 178 tests of the affected and neighbouring files.

Checks run: `dart format --set-exit-if-changed` on the 11 changed Dart files (0 changed); `dart analyze` in
`packages/party_host` (no issues); `flutter test` on night_reveal_frame_test, night_scoreboard_frame_test,
player_badge_test, puzzle_results_frame_test, score_row_test and night_reveal_test (56 pass), on night_screens_test,
night_robo_test, night_round_test, arena_night_test, end_night_arena_test, end_night_puzzle_test, screen_fit_test and
puzzle_results_test (77 pass), host_focus_ring_test (14 pass) and night_start_frame_test (31 pass).

## Commit message

Review the phonehost2 wave 2 jobs: S4 scoreboard, S5 reveal, S6b

- Wave 2 read against the briefs, the coding guidelines and review rules parts A and B.
- One must: the score card is never given the stage width (Align + ToyCard's IntrinsicWidth), so it
  draws narrow and the bars have no slack; no test measures it.
- Two should: S6b's report and commit message claim a badgeNumberShare constant that was never added,
  and the reveal has no cap on tied winners (four overflow the card at 640x360).
- Six could: the "+n" size claim, the final scores at one device, bare rank literals, a second
  away-opacity name, an unused floor constant and the dead NightText.winners.
- Checks: format, analyze and 178 tests over the affected files; S6b's stop is correct and disclosed.

## Status row

Wave 2 reviewed: S4 draws the scoreboard and final scores in the frame (ties, podium, winner row, both footers; 34 tests), S5 the reveal as one full-width card (6 tests), S6b the 20 px badge-number floor inside the frame (6 tests); open — S4's card width (must) and final-scores coverage, S6b's report's missing constant, the reveal's tie cap, S6b's results layout blocked on host_focus_ring_test and the rule 5 exception, the podium palette, the 190 px column, and wph1/wtv before any build.

## Delete

- none
