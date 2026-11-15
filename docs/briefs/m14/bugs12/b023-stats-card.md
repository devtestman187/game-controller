job: M14 bugs12 b023-stats-card: the phone Settings "Stats" row shows its sharing status and plainly opens another screen (B-023)
pub: no
stop: after it. No change to the consent flow, the Stats screen or the green switch.
read: controller_app/lib/src/ui/settings_screen.dart (_ControlStats about :270-305, _openStats) · packages/party_host/lib/src/text/host_text.dart (statusLine :293-300, the states) · packages/party_host/lib/src/text/settings_text.dart · controller_app/lib/src/ui/connect_screen.dart (:202, the chevron row look) · docs/coding-guidelines.md · tests the change could break: controller_app/test/host_stats_test.dart, phone_host_stats_lifecycle_test.dart, settings_test.dart (while working run only `flutter test` on your files plus these; the full `tools/check.sh phone` runs once, at the end)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner row B-023: stats from an iPhone host never reached Firebase because the host's consent was never answered. A phone asks only when the "Stats" row (bar-chart icon) is tapped; the card's green switch "Share control stats with the TV" is a different setting, so the owner thought sharing was on. Owner: "That needs to be made clearer. Show the status on the card I screenshotted. Make it clear there is another submenu".
Design:
1 TEST FIRST, new file controller_app/test/settings_stats_row_test.dart (must fail on the old code): with hosting on, the row `settingsHostStats` shows one status line per state: consent null "Sharing hosted sessions: not answered" plus a "Tap to choose" hint; false "...: off"; true with no upload "...: no upload set up"; true "...: on, N uploaded, M waiting"; with lastError "...: last try failed". It has a trailing chevron (Icons.chevron_right), and tapping it opens the Stats screen (answered consent) or the consent screen first (null).
2 Text: add `SettingsText.hostShareLine(StatsState)` in settings_text.dart (host_text.dart is near its 380-line cap), reading the same fields as `HostText.statusLine`; no new state logic in the UI.
3 Row: the status replaces the old subtitle (keep `hostStatsLine` if used elsewhere), trailing chevron, whole row tappable like the other navigation rows (use the connect_screen look); when consent is null the hint is emphasised (bold or accent colour from the app's theme).
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what changed, test counts you saw, decisions. State "Fixed, unverified: needs device check". End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: each new test goes in a NEW test file and must fail on the code as it was (the runner proves it). await every async side effect before teardown.
rules: aim for 80-120 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first · write only inside allow: · stage nothing yourself · never use git add -A · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/bugs12/b023-stats-card-report.md · controller_app/lib/src/ui/settings_screen.dart · packages/party_host/lib/src/text/settings_text.dart · controller_app/test · packages/party_host/test
check: format analyze host phone
report: docs/briefs/m14/bugs12/b023-stats-card-report.md
