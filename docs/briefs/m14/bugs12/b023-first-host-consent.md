job: M14 bugs12 b023-first-host-consent: a phone asks for host stats consent the first time it hosts (B-023)
pub: no
stop: after it. No change to the Stats screen, the consent text, or the Settings row (job b023-stats-card does that row).
read: tv_test_app/lib/src/ui/home/first_launch_consent.dart (:19, the TV's prompt) · packages/party_host/lib/src/ui/stats_screen.dart (askConsent :201) · controller_app/lib/src/host/hosting.dart (start) · controller_app/lib/src/host/host_screen.dart · controller_app/lib/src/ui/connect_panels.dart (where "Host a game" is tapped) · docs/coding-guidelines.md · tests the change could break: controller_app/test/host_lifecycle_test.dart, host_start_log_test.dart, host_stats_test.dart, phone_host_stats_lifecycle_test.dart (while working run only `flutter test` on your files plus these; the full `tools/check.sh phone` runs once, at the end)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner row B-023: stats from an iPhone host never reached Firebase because host consent was never answered. Owner approved: "Yes. Include that as well": a phone asks for host stats consent the first time it hosts, like the TV's first-launch prompt.
Design:
1 TEST FIRST, new file controller_app/test/first_host_consent_test.dart (must fail on the old code): "Host a game" with consent null shows the existing consent screen (reuse `askConsent`, no new dialog) once, before the host route opens, never during a round; with consent answered (true or false) nothing is shown and hosting starts as before; the answer is saved (statsStateProvider consent); a second host after the answer asks nothing; dismissing without an answer still lets the phone host (and asks again next time).
2 Fix: at the "Host a game" tap, before `hostingProvider.start`, await the ask when consent is null. Keep it in a small helper, not in hosting.dart's start (no UI there).
3 Update the pins your change breaks, keeping their intent.
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what changed, test counts you saw, decisions. State "Fixed, unverified: needs device check". End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: each new test goes in a NEW test file and must fail on the code as it was (the runner proves it). await every async side effect before teardown.
rules: aim for 80-120 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first · write only inside allow: · stage nothing yourself · never use git add -A · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/bugs12/b023-first-host-consent-report.md · controller_app/lib/src/ui/connect_panels.dart · controller_app/lib/src/host · controller_app/test
check: format analyze phone
report: docs/briefs/m14/bugs12/b023-first-host-consent-report.md
