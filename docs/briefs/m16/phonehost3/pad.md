job: M16 phonehost3 pad: in-game board pad clearance correct under HostFrameGate scaling
stop: after the pad fix. Do not touch join seats, puzzle results, night_* or footer labels.
read: docs/briefs/m16/phonehost3/COMMON.md (first) · docs/briefs/m16/phonehost2/wph-report.md (section "The board's pad clearance": numbers and cause) · packages/party_host/lib/src/ui/puzzle_screen.dart (lines ~305-340; 372 lines, move code to a NEW file) · packages/party_host/lib/src/ui/host_frame.dart (HostFrameInfo.maybeOf: scale, frame) · packages/party_host/lib/src/providers.dart:160 (hostPadProvider: pxPerMm and rects in DEVICE px) · controller_app/lib/src/host/host_overrides.dart:71 · controller_app/lib/src/host/host_frame_gate.dart · controller_app/test/host_frame_wiring_test.dart · packages/party_host/test/puzzle_screen_test.dart (tests that could break)
decisions: Cause: `hostPadProvider` rects and pxPerMm are device px, applied to a box that is frame px (device = frame x s). Fix: in the host, when a `HostFrameInfo` is above, ask the pad for rects of the DEVICE-sized box (box x s), map each returned rect back to frame px (divide by s), and pass `pxPerMm / s`. With no frame above nothing changes (TV, "Show on this device"). Assert against the pad's device rects divided by s (at 852x393 s = 0.63148148; the pad's up arm is about (129.6,60)-(237.4,218.5) device px).
do:
1 Tests first, NEW file packages/party_host/test/puzzle_pad_clearance_test.dart (and, if needed, controller_app/test/pad_clearance_frame_test.dart): a puzzle round under HostFrame with a fake hostPadProvider returning known device rects; assert the rects the board receives (PuzzlePlayView.padRects) equal device rects / s at 852x393 and 640x360, and pxPerMm = mm / s; with no HostFrame they are unchanged.
2 Code: small helper in a NEW file (e.g. lib/src/ui/puzzle_pad_scale.dart) used by puzzle_screen.dart; puzzle_screen.dart ends no longer than now.
3 Report: before/after rects at 852x393.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it.
tests: tests-first: new file(s) above. Await async effects.
rules: aim 80-120 turns, never over 120 · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines.
allow: packages/party_host/lib/src/ui/puzzle_screen.dart · packages/party_host/lib/src/ui/puzzle_pad_scale.dart · packages/party_host/test/puzzle_pad_clearance_test.dart · packages/party_host/test/puzzle_screen_test.dart · controller_app/test/pad_clearance_frame_test.dart · controller_app/test/host_frame_wiring_test.dart · docs/briefs/m16/phonehost3/pad-report.md
check: format analyze host phone
report: docs/briefs/m16/phonehost3/pad-report.md
