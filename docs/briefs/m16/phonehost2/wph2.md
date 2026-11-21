job: M16 phonehost2 wph2 — fix the phone app's tests that pinned the old host layout
tests-first: exempt a test-only job: the failing tests are the proof; no lib change
stop: after wph2. No controller_app/lib or packages/ change. If a test fails for a reason that is a real bug in the new layout (not a pinned old layout), do not hide it: leave it failing, say so in the report with the numbers.
read: docs/briefs/m16/phonehost2/COMMON.md · docs/briefs/m16/phonehost2/wph1-report.md (the list of failing phone tests and why) · docs/briefs/m16/phonehost2/s3-report.md, s4-report.md, s5-report.md, s8p-report.md, s8j-report.md, s6a-report.md, s6b2-report.md (what moved) · controller_app/test/host_title_bar_test.dart · host_menu_fit_test.dart · host_bar_test.dart · host_mode_test.dart · support/host_app.dart
decisions: the host's screens now live in HostFrame below the phone's top bar (wph1) and use HostFrameScreen (header 64, footer 84 in frame px, back arrow only when the route can pop, no hostBarHeightProvider inset). A test that pinned the old title bar, the old scroll ranges or device-px sizes is rewritten to the same intent in the new layout (for example: the header starts below the top bar; the picker, join and night screens do not scroll at 852x393; sizes in frame px times the frame scale). A test about the pad, the top bar or a joined phone is NOT to change.

do:
1 Run `flutter test` in controller_app (cd controller_app && flutter test), list every failure, and for each decide: pinned old layout (rewrite, same intent) or real bug (leave, report).
2 Rewrite the pinned ones. Keep every assertion's intent; no test deleted without a replacement saying the same thing in the new layout.
3 Report: a table of tests changed (file, test name, old pin, new assertion) and any left failing.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each.
tests: await async effects.
rules: aim 80-120 turns · write only inside allow: · stage nothing · no git add -A · leave docs/design/, site/shots/ and tv_test_app/windows/flutter/ alone.
allow: controller_app/test · docs/briefs/m16/phonehost2/wph2-report.md
check: format analyze phone
report: docs/briefs/m16/phonehost2/wph2-report.md
