job: M14 bugs10 b019-4-fix-phone-tests: two test gaps in the phone host's stats wiring (B-019)
pub: no
stop: after it.
read: docs/briefs/m14/bugs10/REVIEW.md (only findings 4 and 7 below) · controller_app/lib/src/host/phone_host.dart (_statsStep) · controller_app/test/phone_host_stats_lifecycle_test.dart · packages/party_host/lib/src/testing/fake_stats.dart (FakeUploader shows a failWith) · controller_app/lib/src/host/host_app.dart (HostChoice) · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Context: B-019 phone wiring calls stats.pause() and stats.resume() from the app lifecycle, logging failures. Two gaps from the run review.
do:
1 Finding 4: give FakeStats a `failWith` (an Object? that pause() and resume() throw when set, as FakeUploader does) and add a case that a throwing pause/resume gives one log line and no throw out of the lifecycle handler.
2 Finding 7: add a case entering HostChoice.onDevice ("Show on this device") that shows the same pause and resume calls as onPhone.
3 Run the phone suite once; both cases are test-only hardening of existing code.
tests-first: exempt test-only hardening of existing behaviour (cases pass on current lib code).
rules: aim for 40-100 turns · write only inside allow: · stage nothing yourself · never use git add -A.
allow: packages/party_host/lib/src/testing/fake_stats.dart · controller_app/test/phone_host_stats_lifecycle_test.dart · docs/briefs/m14/bugs10/b019-4-fix-phone-tests-report.md
check: format analyze phone
report: docs/briefs/m14/bugs10/b019-4-fix-phone-tests-report.md
in the report: start with `## Summary` (at most 30 lines): what changed, test counts, decisions. End with `## Hand-over`.
