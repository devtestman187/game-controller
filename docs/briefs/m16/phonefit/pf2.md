job: m16 phonefit pf2 — capture the joined phone's round strip as a PNG (M16 item 1)
pub: no
stop: after the PNG exists. No lib changes.
read: controller_app/test/round_state_test.dart (the strip test; roundStart/roundFrame helpers) · controller_app/test/support/{pump_app,joined}.dart · controller_app/test/site_shots_test.dart and packages/party_host/test/support/pixels.dart (how a test saves a PNG) · docs/briefs/m16/ux-review/mockups/proposal-mockups.html frame 0 (the intended look, 816x384)
decide: never ask; list choices under "Decisions".

do:
1 New file controller_app/test/round_strip_png_test.dart: guard with `skip` unless env ROUND_STRIP_PNG=1 is set. Pump the joined phone at 852x393 (dpr 1, then again at 2 if easy), as round_state_test does with a view start "Round 2 of 5" and a frame with 42 s left. Load the real fonts if the existing site_shots_test does.
2 Save the whole screen as PNG to docs/briefs/m16/phonefit/round-strip-852x393.png (layer toImage under tester.runAsync, as pixels.dart does; create the folder if needed). If the test harness paints only placeholder boxes with no text (no fonts), say so in the Summary.
3 Run with ROUND_STRIP_PNG=1 from controller_app: `flutter test test/round_strip_png_test.dart`.
in the report: `## Summary` (at most 15 lines) first: PNG path and size, whether text rendered with real fonts, turns used; end `## Hand-over`.
tests-first: exempt screenshot helper, no behaviour change
rules: no lib file may change · write only inside allow: · stage nothing · no git add -A · test file under 380 lines
allow: controller_app/test/round_strip_png_test.dart · docs/briefs/m16/phonefit
check: format analyze phone
report: docs/briefs/m16/phonefit/pf2-report.md
