job: M16 phonehost2 S9t — the TV check at 1920x1080: the focus ring's device px, the home screen in the frame
tests-first: exempt a measurement test over code already built
stop: after S9t. No lib change. Do not touch packages/ or controller_app/.
read: docs/briefs/m16/phonehost2/COMMON.md · docs/briefs/m16/phonehost1/s1-report.md ("The focus ring") · docs/briefs/m16/phonehost1/REVIEW.md (open question 12) · docs/briefs/m16/phonehost2/wtv-report.md (the TV app now wears HostFrame) · packages/party_host/lib/src/ui/host_focus_ring.dart · tv_test_app/test/host_frame_wiring_test.dart · tv_test_app/test/tv_fit_test.dart · packages/party_host/test/support/pixels.dart (how a test reads a picture's pixels; copy the idea, do not edit it) · tv_test_app/lib/main.dart
decisions (owner and main session, Nov 20): "The TV focus ring scaling with the frame is intended; check it in the S9 TV check at 1920x1080 and report its device px." The ring is ToySizes.focusRing = 4 frame px, so 8 device px at s = 2 (DESIGN line 71 says "unaffected": the report says what is true).

do:
1 NEW file tv_test_app/test/tv_focus_ring_frame_test.dart: the TV app at 1920x1080 (devicePixelRatio 1), a focused host button: read the picture of the screen (RepaintBoundary toImage inside tester.runAsync, or the pixels helper's way) and measure the ring's thickness in device px by scanning across its edge; assert it is 8 +- 1 and the ring's colour is the look's focus colour. Do the same at 1280x720 (expect 5.33 +- 1) and 1024x768. Also at 1920x1080: the home screen has no overflow and its smallest Text is >= 20 frame px = 40 device px, and a screenshot-free check that the screen is 960x540 frame px scaled by 2.
2 Report: the ring's device px at each size; the smallest text in device px; anything on the TV home screen that looks wrong in numbers (cut off, off screen). If the measurement cannot be made reliably in a test, say exactly what you tried; do not guess a number.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it.
tests: await async effects.
rules: aim 40-80 turns · no lib change · write only inside allow: · stage nothing · no git add -A · leave docs/design/, site/shots/ and tv_test_app/windows/flutter/ alone.
allow: tv_test_app/test/tv_focus_ring_frame_test.dart · docs/briefs/m16/phonehost2/s9t-report.md
check: format analyze tv
report: docs/briefs/m16/phonehost2/s9t-report.md
