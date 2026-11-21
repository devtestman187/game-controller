## Summary

Verdict: **one fix batch**. Counts: must 1, should 4, could 12.
The run moved four host screens onto `HostFrameScreen` (S3 start, S4 scoreboard, S5 reveal, S6b badge floor)
and refreshed the tablet-board picture (S9p); S6b stopped, correctly, before the puzzle results layout.
The five that matter: (1) the score card is never given the stage width, so the scoreboard draws ~380–430 of
912 px and no test measures it; (2) no app installs `HostFrame`, so the night start draws unscaled on the phone
host and keeps a `SingleChildScrollView` the brief forbade; (3) the reveal caps nothing on a tie and a four-way
tie needs 330 px of a 328 px card at 640x360; (4) S4 orphaned `NightGameButtons`, `NightAwardCard`, two widths
and `nightAwayOpacity` in `night_widgets.dart`; (5) s6b's report and commit 8cd1455d claim a `badgeNumberShare`
constant that `player_badge.dart` does not have.
Hand-fixes: none — `run.log` has no `HAND-FIX` line. Tests-first proof exists for all four new test files
(`run.log` 23:25 and 00:08). Of the run's fixes, none was made by reasoning alone (S4's empty-bar bug came from
a failing test, S6b's floor from toy_look's 0.55 read); the two layout findings (card width, four-way tie) are
computed, not measured, so their fixes need a pixel/device check.
Owner-only questions: `RoundSegment.autofocus`, silver/bronze palette names, the 190 px name column, tie cap
vs a tested three-way tie, and S6b's results layout (rule 5 exception vs split vs `host_focus_ring_test` in
`allow:`). Fix-job grouping with files and phone-pinning is at the end of Findings.

## Findings

- **must** packages/party_host/lib/src/ui/night_scoreboard_widgets.dart:66 `_Scoreboard` puts `_ScoreCard` under an `Align`, which gives it a loose width, so `ToyCard`'s `IntrinsicWidth` (toy_card.dart:128) sizes the card to a row's content (≈380–430 of the 912 px stage), against the doc claim at :75 and DESIGN §1 rule 4 "cards fill the stage width"; nothing in night_scoreboard_frame_test.dart measures the card → give it the body's width as the reveal does (`LayoutBuilder` + `SizedBox(width: constraints.maxWidth)` at :97) and assert width = frame − 2 × `hostFrameGutterPx` (from: wave 2 / S4; code + night_scoreboard_frame_test.dart, not phone-pinned)
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:157 the body is a `SingleChildScrollView` because no app installs `HostFrame` yet (controller_app and tv_test_app mount no frame), so the phone host draws the night start unscaled at 852x393 (245 px of body for ~292 px of content) and loses the `hostBarHeightProvider` inset `HostScreen` gave its own bar; night_start_frame_test.dart:132 asserts the scrollable is *present* → land wph1/wtv before the next build, then drop the scroll and judge the bar inset (from: wave 1 / S3; controller_app + night_start_screen.dart + its test — **phone-pinned**)
- **should** packages/party_host/lib/src/ui/night_reveal_widgets.dart:147 one 40 px line per tied winner, no cap, in a card with 328 px of room at 640x360: four winners need 330 px, and night_reveal_frame_test.dart draws two at most → cap the names (two lines plus "+n more") or size for and test a three-way tie (from: wave 2 / S5; widgets + night_reveal_frame_test.dart, not phone-pinned)
- **should** packages/party_host/lib/src/ui/night_widgets.dart:195 S4's rewrite left `NightGameButtons` (:195), `NightAwardCard` (:120), `nightAwardCardWidthPx` (:13), `nightGameButtonWidthPx` (:17) with no lib or test reader and `nightAwayOpacity` (:21) read only by two tests, so one file holds two widgets for the same footer pair, one of them dead → delete the dead widgets and widths and keep one away-opacity name (from: across jobs — wave 1's claim was about a file S4 then rewrote; the condition now holds)
- **should** docs/briefs/m16/phonehost2/s6b-report.md:33 the report (and commit 8cd1455d) lists `badgeNumberShare = 0.55` as added to player_badge.dart, which has only `badgeNumberFloorPx` (:16) and `badgeNumberMinDiameterPx` (:24); the test carries its own copy → correct the report/commit text, or add the constant and use it in puzzle_results_frame_test.dart:40 (from: wave 2 / S6b; docs only)
- **could** packages/party_host/test/night_scoreboard_frame_test.dart:377 the delta test asserts only the `+9`/`+2` text, never the `ToyType.frameSmall` style s4-report.md:101 claims → assert `nightRoundPoints-p1`'s fontSize or correct the report (from: wave 2 / S4; test + doc)
- **could** packages/party_host/test/night_scoreboard_frame_test.dart:186 the five-device loop pumps `rounds: 1` (default at :107), so the final scores (taller winner row, one-button footer) are drawn at 640x360 only, against the brief's "the five sizes … winner row taller on the final" → add one final-scores pass per device (from: wave 2 / S4; test only)
- **could** packages/party_host/lib/src/ui/night_scoreboard_widgets.dart:146 `_medalOf` switches on bare 1/2/3 (and `row.place == 1` at :111 and :138), where guidelines §2 allow only 0, 1, -1 and 2 bare → name the places once and map place to medal (from: wave 2 / S4; widgets)
- **could** packages/party_host/lib/src/ui/score_row.dart:56 two names and two 0.45s for the away dim (`scoreRowAwayOpacity` here, `nightAwayOpacity` at night_widgets.dart:21, which only night_robo_test.dart:63 and the frame test read) → pass the one constant through or delete the other (from: wave 2 / S4+S5; shares night_scoreboard_frame_test.dart)
- **could** packages/party_host/lib/src/ui/player_badge.dart:16 `badgeNumberFloorPx` is public but read by no code, while puzzle_results_frame_test.dart:40 copies 20.0 as `_floorPx` → use the constant in the guard or make it private (from: wave 2 / S6b; badge + its test)
- **could** packages/party_host/lib/src/text/night_text.dart:56 `NightText.winners` lost its last reader when S5 dropped the count line, a dead public string (from: wave 2 / S5; one line)
- **could** packages/party_host/test/night_screens_test.dart:96 the right-press is conditional (`if (!hasFocus)`), so the test proves the direction reaches "5 rounds" only when the chip is not already focused → assert which chip has the focus, then press right unconditionally (from: wave 1 / S3; test only)
- **could** packages/party_host/test/coverage_all_test.dart:100 the generated import list still lacks `award_tile.dart`, `night_footer_buttons.dart`, `score_row.dart`, `host_frame_screen.dart` and `round_segment.dart`, so the coverage gate skips the run's new files → regenerate with `dart run tools/coverage_imports.dart` in a job allowed to touch it (from: S3 Q5 / S4 Q4; test only)
- **could** packages/puzzle_game/test/tablet_board_png_test.dart:99 the guard writes only under `UPDATE_PNG` and otherwise asserts `bytes.length > 5000`, so it never proves the committed picture matches the render and S9p's refresh can go stale the same way → compare the rendered bytes with the file and fail on a mismatch (from: wave 1 / S9p hand-over; outside this run's diff)
- **could** packages/party_host/lib/src/ui/score_row.dart:380 the row file grew to 380 lines (guidelines §3 ~300) carrying six public names and both metals, and Arena's results will reuse it → split the bar/name row out before that reuse rather than after (from: across jobs, S2+S4)
- **could** packages/party_host/test/night_start_frame_test.dart:42 the five-device table and mount are copied in four new test files (:42 here, night_reveal_frame_test.dart:43, night_scoreboard_frame_test.dart:43, puzzle_results_frame_test.dart:30), so a device change is four edits → one support harness once support files are allowed (from: across jobs, the briefs told each job to copy)
- **could** docs/briefs/m16/phonehost2/s3-report.md:36 the report says the band gives a 64 px button "16 px of air above it"; the band pads only `edge.width` (4) and centres the button, so it is 12 above and 8 below → pad evenly or correct the number (from: wave 1 / S3; host_frame_screen.dart:183)

Fix jobs (≤3 findings, no shared files, one wave): **A** card width + bare places (night_scoreboard_widgets.dart,
night_scoreboard_frame_test.dart) and the final-scores loop + `+n` style in the same test file — run as one job,
or A first and the test-only pair after it, never in parallel; **B** reveal tie cap + band padding
(night_reveal_widgets.dart, night_reveal_frame_test.dart, host_frame_screen.dart, s3-report.md); **C** dead
widgets, `NightText.winners`, away-opacity name (night_widgets.dart, night_text.dart, score_row.dart,
night_scoreboard_frame_test.dart — after A); **D** guards (coverage_all_test.dart, tablet_board_png_test.dart);
**E** reports (s3/s4/s6b report lines, no code); **phone** for finding 2 (controller_app wiring + its test).

## Open questions

- `RoundSegment` autofocus (S3 Q1): the safest answer is to add the flag in the job that owns round_segment.dart and keep the footer's focus until then, noted in COMMON.md.
- The scroll net vs a self-scaling frame (S3 Q2, S5 S6b hand-over): safest is wph1/wtv first, then delete the net.
- "Soon" gone from the disabled Bumper Round (S3 Q3): safest is to leave it off and let M17's hint work say why.
- Silver/bronze from the palette (`wall`, `caution`) instead of metals (S4 Q1): safest is to approve for now and add metal names in the look's next job.
- `MMMMMMMMMM` at 191.0 vs the 190 px column (S4 Q2): safest is to leave 190 (nothing realistic overflows) and record it.
- Night sounds' order reveal → scoreboard untested as a pair (S4 Q5): safest is to add one ordering test to the scoreboard frame test.
- The "+3 points" line kept at 26 px off DESIGN §4's list (S5): safest is to keep it; `night_reveal_test` reads it.
- A tie shows the first winner's badge (S5): safest is to keep the first winner's and say so in DESIGN §4.
- The crown at 640x360 (S5): worth a look before a build, no answer needed now.
- S6b's results layout (Q1/Q2): safest is `host_focus_ring_test.dart` in `allow:` with the walk right → Back, up → the body column, left → Change teams; a two-row footer does not fit 84 px.
- Derive the tests a move breaks by running the suite (S6b Q3): safest is yes for the next move brief.

## Numbers against targets

- Score card ≈380–430 px wide in a 912 px stage (must finding; read from the widget chain, not measured) against DESIGN §1 rule 4 and COMMON's "cards fill the stage width"; S4's report gives no card width.
- Final scores drawn at 640x360 only, against S4's brief "the five sizes … winner row taller on the final".
- Four-way reveal tie needs 330 px of the 328 px card room at 640x360 (computed), against S5 decision (d) "a tie fits"; only two winners are tested.
- Night start on the unframed phone at 852x393: 245 px of body for ~292 px of content (41 px overflow), reported by S3; inside the frame the five sizes report `maxScrollExtent == 0`.
- Footer band: 12 px above / 8 below, against s3-report.md:36's "16 px".
- Met: tiles 293.333 (960) and 363.562 (1170.687); rows 52, winner 68; card 344/392 and 360/392 at 6 players; reveal card 912 = 960 − 48; header 64, footer 84, body 392/452/572; every Text ≥ 20; badge floor 37 → 20.35 px ≥ 20 (20 / 0.55 = 36.36); `MMMMMMMMMM` 191.0 reported as asked; picture 167,512 bytes, 2486 × 1414 (= 2×24 + 1366 + 48 + 1024), sha256 `4cd46f7e…`, plain run leaves it alone.

## Could not check

- `tools/review.sh` and the full host suite (S3 701, S4 737 passed): not re-run.
- The card width, the four-way tie's overflow and any screen's look: read from the widget chain and font sizes, no app or device run.
- Whether the phone host can reach these screens after the frame lands: no route walk of controller_app.
- The PHONE_FIT run: `phone_fit_option_c_test` still measures the old start card (S3 Q6), skipped by default.
- `docs/briefs/m16/phonehost2/STATUS.md` and `run-findings.md` do not exist; the read order above used the two wave reviews and the five job reports.