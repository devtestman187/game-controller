job: sentry1 ci-wiring: pass the Sentry DSN to release builds
pub: no
tests-first: exempt build configuration and docs only
stop: after it.
read: .github/workflows/release.yml · codemagic.yaml (the ios-testflight "Build the signed .ipa" step and its FIRESTORE handling) · docs/release.md · docs/design/sentry-consent.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits docs/design/sentry-consent.md and list each under "Decisions" with one line of why. Stop only if the job cannot be done; then say why under "Blocked".
Owner's decision, quoted: DSNs are GitHub vars SENTRY_DSN_PHONE / SENTRY_DSN_TV; Codemagic group `firestore` has SENTRY_DSN_PHONE. "Pass DSN via --dart-define (SENTRY_DSN) in the CI/Codemagic build steps; empty DSN = Sentry disabled. Do not put a DSN value in the repo."
do:
1 release.yml: the phone appbundle step gets --dart-define=SENTRY_DSN=${{ vars.SENTRY_DSN_PHONE }}; the TV appbundle step and the Windows step get --dart-define=SENTRY_DSN=${{ vars.SENTRY_DSN_TV }}. Update the vars list in the header comment.
2 codemagic.yaml: in the signed .ipa step, trim SENTRY_DSN_PHONE like the Firestore values (tr -d whitespace), add --dart-define=SENTRY_DSN only when non-empty, and echo only "Sentry: set" or "Sentry: not set" (never the value). Update the header comment.
3 docs/release.md: a short section: the two Sentry projects, the var and group variable names, that an empty DSN disables reporting, and the reminders to turn on "Prevent Storing of IP Addresses" in both Sentry projects (Settings, Security and Privacy) and to check the data scrubbing options.
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what changed, test counts you saw, decisions; state "Fixed, unverified: needs device check" for anything only a device shows. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: new tests go in NEW files (so the runner can prove they fail on the old code); await every async side effect before teardown.
rules: aim for 80-120 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was · write only inside allow: · stage nothing yourself · never use git add -A · no DSN or secret value in any file · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/sentry1/ci-wiring-report.md · .github/workflows/release.yml · codemagic.yaml · docs/release.md
check: format
report: docs/briefs/m14/sentry1/ci-wiring-report.md
