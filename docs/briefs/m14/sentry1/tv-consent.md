job: sentry1 tv-consent: the TV and Windows app asks its two questions and starts Sentry
pub: no
stop: after it. No CI, no phone app.
read: docs/design/sentry-consent.md (all) · tv_test_app/lib/main.dart · tv_test_app/lib/src/tv_host_setup.dart · tv_test_app/lib/src/app_info.dart · tv_test_app/lib/src/ui/home/first_launch_consent.dart and home_screen.dart · packages/party_host/lib/src/consent/ and crash/ (consentProvider, askConsents, crashAvailableProvider, startCrashReporting) · tests the change could break: tv_test_app/test home_screen_test.dart, coverage_all_test.dart, tv_host_setup_test.dart, support/pump_app.dart
decide: low-usage mode: never stop for a question. Make the safest choice that fits docs/design/sentry-consent.md and list each under "Decisions" with one line of why. Stop only if the job cannot be done; then say why under "Blocked".
Owner's decision, quoted: "EVERY app instance (phone host, controller-only phone, TV/Windows app) asks its own two questions ... Sentry initialises ONLY after crash consent = yes (and can be turned off live)."
do:
1 tv_host_setup.dart: const sentryDsn = String.fromEnvironment('SENTRY_DSN'). main.dart: await startCrashReporting(prefs, dsn, release from app_info, environment) before runApp and override crashAvailableProvider with sentryDsn.isNotEmpty; the rest of main stays.
2 FirstLaunchConsent calls askConsents(context, ref) (crash then stats, each only if unanswered; crash only when available) instead of the stats prompt alone; it still takes no space and shows once per launch while something is unanswered. The TV's crash toggle itself lives on the Stats screen (another job): do not touch party_host files.
3 Fix the existing tests' pins; tests that need the old single prompt keep crash unavailable (the default).
4 Tests (new files): crash unavailable asks only stats (as before); crash available asks crash first then stats, remote OK/back work both dialogs; an answered question is not asked again on the next launch; with crash answered no and stats yes only nothing prompts; startCrashReporting is called with the fake reporter when the app's setup function is exercised (put the setup in a small testable function if main cannot be called).
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what changed, test counts you saw, decisions; state "Fixed, unverified: needs device check" for anything only a device shows. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: new tests go in NEW files (so the runner can prove they fail on the old code); await every async side effect before teardown.
rules: aim for 80-120 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was · write only inside allow: · stage nothing yourself · never use git add -A · no DSN or secret value in any file · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/sentry1/tv-consent-report.md · tv_test_app/lib · tv_test_app/test
check: format analyze tv
report: docs/briefs/m14/sentry1/tv-consent-report.md
