job: M16 phonehost2 wtv — the TV app wears HostFrame (one line in main.dart)
stop: after wtv. Do not edit packages/party_host/ or controller_app/. Do not move any screen.
read: docs/briefs/m16/phonehost2/COMMON.md (shared decisions, read first) · docs/briefs/m16/phonehost1/s1-report.md ("Wiring the main session must add", "The focus ring") · packages/party_host/lib/src/ui/host_frame.dart (hostFrameBuilder, HostFrameInfo) · tv_test_app/lib/main.dart (:70-100) · tv_test_app/test/tv_fit_test.dart · tv_test_app/test/home_screen_test.dart · tv_test_app/test/host_away_tv_test.dart · tv_test_app/test/app_with_build_test.dart (read the tests that pump the whole app before editing)
decisions (owner, Nov 20: "TV uses the same scaler, s = 2 at 1920x1080: one layout everywhere"): the TV app gets the one line from s1-report, `builder: (context, child) => hostFrameBuilder(context, ControllerMenus(child: child!)),` (check the import prefix and the real signature of hostFrameBuilder first). The frame scaling the focus ring is intended; a later job measures it.

do:
1 Tests first, NEW file tv_test_app/test/host_frame_wiring_test.dart: the TV app at 1920x1080, 1280x720 and 1024x768 has a HostFrameInfo above its home screen with scale 2.0, 1.3333 and 1.0667 (frame 960x540, 960x540, 960x720); MediaQuery.size inside is the frame; tapping a home button still works; the d-pad (arrow key) still moves the focus between two home buttons at 1920x1080; a dialog opened from the home screen is inside the frame too (HostFrameInfo.maybeOf finds it).
2 Code: the one builder line (and its import). Fix tv_test_app tests the frame breaks (tv_fit_test and others) without weakening them: where a test measured device px it now measures frame px, say so.
3 Report: which TV tests changed and why; the home screen's size in frame px at 1920x1080.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it.
tests: tests-first: new file above. Await async effects.
rules: aim 40-80 turns · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines · leave docs/design/, site/shots/ and tv_test_app/windows/flutter/ alone.
allow: tv_test_app/lib/main.dart · tv_test_app/test · docs/briefs/m16/phonehost2/wtv-report.md
check: format analyze tv
report: docs/briefs/m16/phonehost2/wtv-report.md
