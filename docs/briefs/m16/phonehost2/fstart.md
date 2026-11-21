job: M16 phonehost2 fstart — the night start loses its scroll net now that the apps install HostFrame (REVIEW.md: 1 should)
stop: after fstart. Do not edit host_frame_screen.dart or any other screen. Needs wtv and wph (committed before this wave): the TV and the phone host's subtree wear HostFrame.
read: docs/briefs/m16/phonehost2/REVIEW.md (finding night_start_screen.dart:157) · docs/briefs/m16/phonehost2/wtv-report.md · docs/briefs/m16/phonehost2/wph-report.md · packages/party_host/lib/src/ui/night_start_screen.dart · packages/party_host/test/night_start_frame_test.dart (:120-140 asserts the scrollable is present) · docs/briefs/m16/phonehost2/s3-report.md
decisions: the frame now lies below the phone's top bar (wph), so no hostBarHeightProvider inset is needed inside it. S3 kept a SingleChildScrollView as a net while no app installed the frame; the design says no scrolling on any host screen, so the net goes.

do:
1 Tests first, NEW file packages/party_host/test/night_start_noscroll_test.dart (fail on old code): at the five sizes, 4 and 6 players, a running night and a fresh one: the night start has no Scrollable at all (find.byType(Scrollable) finds nothing under the screen), its content (awards, cat line, players line, pick-round line) ends inside the body at every size, nothing overflows.
2 Fix: remove the scroll net from night_start_screen.dart (keep the Spacer/Column layout so nothing overflows; if the content is taller than 392 at some size, shorten spacing, not type). Update night_start_frame_test.dart where it asserts the scrollable is present.
3 Report: content height vs body height per size.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it.
tests: tests-first: new file above. Await async effects.
rules: aim 30-60 turns · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines · leave docs/design/, site/shots/ and tv_test_app/windows/flutter/ alone.
allow: packages/party_host/lib/src/ui/night_start_screen.dart · packages/party_host/test/night_start_noscroll_test.dart · packages/party_host/test/night_start_frame_test.dart · packages/party_host/test/night_screens_test.dart · controller_app/test · docs/briefs/m16/phonehost2/fstart-report.md
check: format analyze host phone
report: docs/briefs/m16/phonehost2/fstart-report.md
