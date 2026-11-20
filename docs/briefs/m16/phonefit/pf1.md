job: m16 phonefit pf1 — measurement-only test: do the night screens fit a phone host?
pub: no
stop: after the test runs and PNGs + results are saved. No lib changes, no fixes, no layout proposals.
read: packages/party_host/test/night_screens_test.dart (how the start card, scoreboard, reveal and final scores are reached; helpers openNight, appContainer, roundResult, threeAwards) · packages/party_host/test/support/{host_harness,night_harness,pixels,toy_fonts}.dart · packages/party_host/test/screen_fit_test.dart (sizes, fonts via loadLookFonts) · packages/party_host/test/arena_results_test.dart and puzzle_screen_test.dart (how round results are shown) · packages/party_host/lib/src/ui/night_{start,scoreboard,reveal}_screen.dart, arena_results.dart, puzzle_results_widgets.dart
decide: never ask; list any choice under "Decisions" in the report.

do:
1 New file packages/party_host/test/phone_fit_test.dart (guard with `skip` unless env PHONE_FIT=1 is set; no tags, so the normal suite is untouched). For each screen: night start card, scoreboard mid-night (after 2 of 5 rounds), final scores (night over), awards reveal, arena round results, puzzle round results (if one is not reachable cheaply, skip it and say why).
2 Data: 4 players, 5-round night, nicknames of 18+ characters (e.g. "Bartholomew The Great"), real fonts (setUpAll loadLookFonts), Sunny look.
3 Sizes (logical, devicePixelRatio 1, via pumpHost size:): 640x360 and 360x640 (phone), 1280x800 (tablet), 1280x720 (TV).
4 For every screen x size record: (a) any RenderFlex overflow or other exception (tester.takeException, and FlutterError.onError captured per case so one failure doesn't stop the run); (b) vertical scroll: content height minus viewport when the screen is a scrollable (Scrollable maxScrollExtent) and whether the primary action button is on screen without scrolling; (c) text clipping: any Text whose laid-out size is wider than its ancestor's constraints (ellipsis or overflow) ; (d) the smallest effective font size in dp over all Text widgets on the screen (RenderParagraph text style fontSize times any ancestor scale; the test must say how it accounts for Transform.scale/FittedBox), and the size actually rendered for a 24 px label if one exists.
5 Save a PNG per screen x size to docs/briefs/m16/phonefit/<screen>-<WxH>.png (RepaintBoundary or the layer toImage as test/support/pixels.dart does, under tester.runAsync). Write results as JSON to docs/briefs/m16/phonefit/results.json (the test writes it).
6 Run it with PHONE_FIT=1 and `flutter test test/phone_fit_test.dart` from packages/party_host with PHONE_FIT=1.
in the report: `## Summary` (at most 30 lines) first: a table screen x size = fits / overflows / scrolls / text small, smallest text dp on the 640x360 size, whether any global scale wrapper exists in the screens you ran (say what you observed), turns used; end with `## Hand-over` and `## Decisions`.
self-check: test passes with PHONE_FIT unset (skipped) and with it set; no lib file changed.
tests-first: exempt measurement-only test, no behaviour change
rules: no lib file may change · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines · test file under 380 lines
allow: packages/party_host/test/phone_fit_test.dart · docs/briefs/m16/phonefit
check: format analyze host
report: docs/briefs/m16/phonefit/pf1-report.md
