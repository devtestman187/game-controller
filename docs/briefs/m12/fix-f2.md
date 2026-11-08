job: m12 build 4 fix-f2 G4 — the phone: a missed host_back; tilt outside a round
stop: after G4.
read: docs/code-health.md N2, N8 · docs/briefs/m12/build4-review-r3-report.md findings 1 and 4 (the should) · controller_app/lib/src/providers/view.dart · controller_app/lib/src/ui/{waiting_card,controller_screen,controller_parts}.dart · controller_app/lib/src/gyro.dart · controller_app/test/{joined_view_test,waiting_card_test,host_mode_test,host_lifecycle_test}.dart · docs/coding-guidelines.md
do:
1 N2: when the link to the host comes back, the host's wait (`_away`) ends too, not only the drop's: a host that accepts a connection is not away, and if it still runs a round it re-sends `view_start`. A `host_away` that arrives after the reconnect starts it again.
2 N8: on the host phone, tilt (gyro) sends only while the round's phase is not `none`: launch, `restoreMode()` and the app's resume respect the phase as the pad does. Joined phones and a TV's phones unchanged.
tests (each failing first): host away, the link drops, the round ends, the link comes back with no `view_start`: no card, no game drawn; the same with a `view_start`: the round, no card; a `host_away` after the reconnect shows the card. Gyro mode on the host phone: no input sent on the picker, the join screen, the pause menu, the results, nor after a resume there; sent in a round. Existing tests: list any old → new.
in the report: test counts before and after, the files changed, computed values.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/fix-f2-report.md · controller_app/lib/src/providers · controller_app/lib/src/ui/waiting_card.dart · controller_app/lib/src/ui/controller_screen.dart · controller_app/lib/src/ui/controller_parts.dart · controller_app/lib/src/gyro.dart · controller_app/test
check: format analyze phone
report: docs/briefs/m12/fix-f2-report.md
