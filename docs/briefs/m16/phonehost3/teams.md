job: M16 phonehost3 teams: "Change teams" label fits on the puzzle results
stop: after Change teams. Do not touch the night footer, the pad, or results answers Q2-Q5.
read: docs/briefs/m16/phonehost3/COMMON.md (first) · docs/briefs/m16/phonehost2/s9m-report.md ("Change teams" 144 wanted in 129.4 px at 960-wide frames) · packages/party_host/lib/src/ui/puzzle_results_widgets.dart (_controls, ~line 201: Row of Flexible compact HostButtons: Shuffle, Play again, Change teams) · host_button.dart (compact) · tests that could break: test/puzzle_results_frame_test.dart, puzzle_results_layout_test.dart, puzzle_results_test.dart, phone_fit_matrix_test.dart
decisions: Make the controls fit without ellipsis at the five sizes: weight the Row by each label's measured width (TextPainter) instead of equal Flexible shares, or wrap to a second row only if the body still does not scroll (it must not: DESIGN rule 6). Text stays >= 20 frame px, keys unchanged (changeTeams, the replay key, the shuffle switch), the footer stays 84 px with Back.
do:
1 Tests first, NEW file packages/party_host/test/puzzle_controls_fit_test.dart: at the five sizes with a series round (all three controls), a non-night `any <level>` round with only Change teams, at 4 and 6 players: the "Change teams" label is not ellipsised (TextPainter width <= available), no scroll, controls fully on screen and tappable, no overflow.
2 Code in puzzle_results_widgets.dart (a new helper file is allowed). Fix tests it breaks without weakening them.
3 Report: label widths before and after at each size.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it.
tests: tests-first: new file above.
rules: aim 80-120 turns, never over 120 · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines · no new strings.
allow: packages/party_host/lib/src/ui/puzzle_results_widgets.dart · packages/party_host/lib/src/ui/puzzle_results_controls.dart · packages/party_host/test/puzzle_controls_fit_test.dart · packages/party_host/test/puzzle_results_frame_test.dart · packages/party_host/test/puzzle_results_layout_test.dart · packages/party_host/test/puzzle_results_test.dart · packages/party_host/test/host_focus_ring_test.dart · packages/party_host/test/puzzle_series_fix_test.dart · docs/briefs/m16/phonehost3/teams-report.md
check: format analyze host
report: docs/briefs/m16/phonehost3/teams-report.md
