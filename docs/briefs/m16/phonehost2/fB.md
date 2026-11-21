job: M16 phonehost2 fB — the reveal's tie fits at 640x360; the footer band's padding is even; the s3 report's number (REVIEW.md: 1 should, 2 coulds)
stop: after fB. Do not edit score_row.dart, night_widgets.dart or other screens.
read: docs/briefs/m16/phonehost2/REVIEW.md (findings night_reveal_widgets.dart:147, host_frame_screen.dart:183 / s3-report.md:36; verified real by Claude) · packages/party_host/lib/src/ui/night_reveal_widgets.dart · packages/party_host/lib/src/ui/host_frame_screen.dart (the footer band, :170-200) · packages/party_host/test/night_reveal_frame_test.dart (harness to copy) · packages/party_host/test/night_reveal_test.dart · docs/briefs/m16/phonehost2/s3-report.md (:36) · docs/briefs/m16/phonehost2/COMMON.md
decisions (main session): no new strings. Winner names shrink by count instead of being capped: 1-2 winners 40 px (as designed), 3 winners 32 px, 4 or more 24 px (still at the 20 px floor); one line per name, ellipsis. The footer band pads its content evenly: the ink line's width is inside the band, the buttons are centred in the room below it.

do:
1 Tests first, NEW file packages/party_host/test/night_reveal_tie_test.dart (fail on old code): at the five sizes a 3-way, a 4-way and a 6-way tie reveal: no scrollable, no overflow, the card's bottom inside the body, nothing under 20 px, name sizes 32 (3) and 24 (4+), 40 stays for 1-2 winners; and, for HostFrameScreen at the five sizes with two footer buttons, the space above the buttons equals the space below them inside the band, within 0.5 frame px.
2 Fix: night_reveal_widgets.dart (the size tiers) and host_frame_screen.dart (even band padding). Fix night_reveal_test.dart / night_reveal_frame_test.dart / host_frame_screen*_test.dart only if they pin the old numbers (say which).
3 Correct s3-report.md :36 to the real numbers after the fix.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it.
tests: tests-first: new file above. Await async effects (timers).
rules: aim 40-80 turns · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines · leave docs/design/, site/shots/ and tv_test_app/windows/flutter/ alone.
allow: packages/party_host/lib/src/ui/night_reveal_widgets.dart · packages/party_host/lib/src/ui/host_frame_screen.dart · packages/party_host/test/night_reveal_tie_test.dart · packages/party_host/test/night_reveal_test.dart · packages/party_host/test/night_reveal_frame_test.dart · packages/party_host/test/host_frame_screen_test.dart · packages/party_host/test/host_frame_screen_safe_area_test.dart · packages/party_host/test/night_start_frame_test.dart · docs/briefs/m16/phonehost2/s3-report.md · docs/briefs/m16/phonehost2/fB-report.md
check: format analyze host
report: docs/briefs/m16/phonehost2/fB-report.md
