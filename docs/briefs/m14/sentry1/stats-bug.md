job: sentry1 stats-bug: the Stats screen shows an error, not an endless loading state, when the sessions list fails; and gets the crash button
pub: no
stop: after it.
read: packages/party_host/lib/src/ui/stats_screen.dart (:39 unawaited(_load()), build) · stats_screen_widgets.dart (_SharingButton) · packages/party_host/lib/src/text/host_text.dart · packages/party_host/lib/src/consent/ (from consent-model: consentProvider, crashAvailableProvider, askCrashConsent) · packages/party_host/lib/src/crash/ (CrashReports.guard/capture) · docs/code-health.md (the stats_screen.dart:39 entry) · tests: packages/party_host/test stats_screen_test.dart, stats_test_support.dart, screen_fit_test.dart; controller_app/test host_stats_test.dart
decide: low-usage mode: never stop for a question. Make the safest choice that fits docs/design/sentry-consent.md and list each under "Decisions" with one line of why. Stop only if the job cannot be done; then say why under "Blocked".
Owner's decision, quoted: "stats_screen.dart:39 failed sessions() leaves the screen stuck on loading (show an error state)".
do:
1 stats_screen.dart: when sessions() throws, show an error state in place of the loading indicator (text HostText.sessionsFailed "Could not read the saved sessions." and a Retry button that loads again, touch and remote focusable like the other HostButtons) and report the error through CrashReports.capture (where 'stats_load'); the load runs through CrashReports.guard so nothing is thrown unhandled. Export and Sharing keep working.
2 Add the "Crash reports: on/off" button (new CrashSharingButton in stats_screen_widgets.dart, same look as _SharingButton) next to the Sharing button, shown only when crashAvailableProvider is true; it opens askCrashConsent and its label follows consentProvider.crash == true. Texts in HostText or consent_text.dart.
3 Remove the stats_screen.dart:39 bullet from docs/code-health.md.
4 Tests (new files): sessions() throwing shows the error text and Retry, never the loading indicator forever; Retry with a working list shows the table; the crash button is absent when crash is unavailable, present and toggling when available; screen fits (see screen_fit_test.dart for the sizes it checks) with the extra button.
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what changed, test counts you saw, decisions; state "Fixed, unverified: needs device check" for anything only a device shows. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: new tests go in NEW files (so the runner can prove they fail on the old code); await every async side effect before teardown.
rules: aim for 80-120 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was · write only inside allow: · stage nothing yourself · never use git add -A · no DSN or secret value in any file · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/sentry1/stats-bug-report.md · packages/party_host/lib/src/ui/stats_screen.dart · packages/party_host/lib/src/ui/stats_screen_widgets.dart · packages/party_host/lib/src/text/host_text.dart · packages/party_host/lib/src/text/consent_text.dart · packages/party_host/test · controller_app/test · docs/code-health.md
check: format analyze host phone
report: docs/briefs/m14/sentry1/stats-bug-report.md
