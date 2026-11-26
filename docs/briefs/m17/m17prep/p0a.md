job: m17prep p0a — measure the night cards at 360x640 and 667x375 and record where Thumby's corner head and a 2-line caption strip fit
stop: change no lib file; no layout fix, no Thumby widget (that is later work); no phone-fit option C.
read: docs/briefs/templates/COMMON.md · packages/party_host/test/phone_fit_option_c_test.dart:1-130 (the pattern to copy: measuring test, results written only when PHONE_FIT=1, strip case) · packages/party_host/test/support/phone_fit_support.dart · packages/party_host/test/support/host_harness.dart:54-120 · packages/party_host/lib/src/ui/night_start_screen.dart:1-60 · night_scoreboard_screen.dart:1-60 · night_reveal_screen.dart:40-60 · controller_app/lib/src/ui/result_night.dart:1-60 · controller_app/test/night_end_provider_test.dart (how a phone result card is mounted) · M17 plan, quoted: "Measure the night cards (start, scoreboard, reveal, results) at 360x640 dp and 667x375 and record where Thumby's corner head and caption strip fit"
changes: nightCardsFit · NIGHT_FIT · night_cards_fit_test · night_result_fit_test
model: sonnet
turns: 80
expected-min: 40
tests-first: exempt measuring test; its proof is a case with a deliberate overflow stub that the measurer must report
touch-target: exempt measurement only, no layout change
do:
1 New packages/party_host/test/night_cards_fit_test.dart: for NightStartScreen, NightScoreboardScreen and NightRevealScreen at 360x640 and 667x375 (the host frame, framed as the phone host draws them; copy option C's setup) with 4 and 6 players, measure and assert: no overflow or exception; every Text at or above the frame's 20 px text floor (matrixTextFloorPx); the free band below the lowest content (dp) and the free width at the top-right corner (the corner head needs 56x56 dp, the 2-line strip needs 2 body lines of the screen's own type x full width); the verdict per case "head fits / strip fits" and, where one does not, which element is in the way. Results go to docs/briefs/m17/m17prep/p0a-fit.json only when NIGHT_FIT=1 (as option C does), never in a normal run. One extra test pumps a deliberately overflowing widget through the same measurer and expects it to report the overflow.
2 New controller_app/test/night_result_fit_test.dart: the same for the phone's night result card (result_night.dart) at the same two sizes, with the same free-band and corner measures. Same NIGHT_FIT=1 gate and p0a-fit.json section name.
3 Run each file once with NIGHT_FIT=1 (`flutter test --dart-define=NIGHT_FIT=1 <file>`; the option C test shows which form works) to produce p0a-fit.json, then once plain. Report (docs/briefs/m17/m17prep/p0a-report.md): a table of the measured numbers per card x size, the head and strip verdicts, and a 5-line conclusion: can the setup screen and Thumby fit at 360x640 without phone-fit option C (the owner's Q3)?
4 Before finishing run `flutter analyze` on the files you changed and fix every info, warning and error on them.
allow: packages/party_host/test/night_cards_fit_test.dart · controller_app/test/night_result_fit_test.dart · docs/briefs/m17/m17prep/p0a-fit.json
check: format analyze
report: docs/briefs/m17/m17prep/p0a-report.md
