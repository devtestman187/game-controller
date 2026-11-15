job: M14 bugs10 b019-2-phone-wiring: the phone host ends its stats session when the app goes to the background and retries uploads on resume (B-019, phase 2 of 2)
pub: no
stop: after it.
read: docs/briefs/m14/bugs10/b019-1-stats-core-report.md (read only its Summary and Hand-over: pause() and resume() on StatsService) · controller_app/lib/src/host/phone_host.dart (start, the AppLifecycleListener, dispose) · controller_app/test/host_lifecycle_test.dart (how it moves the lifecycle) · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner row B-019: on iOS the background suspends the host's timers, so its running stats session is never ended or uploaded until the next app start. Phase 1 added `pause()` and `resume()` to the stats service.
do:
1 TEST FIRST, new file controller_app/test/phone_host_stats_lifecycle_test.dart (must fail on the old code), using the fake stats from party_host/testing and `WidgetsBinding.instance.handleAppLifecycleStateChanged`: (a) AppLifecycleState.paused calls stats.pause() once; (b) resumed calls stats.resume() once; (c) hidden/inactive alone call neither (a phone call or the app switcher must not end the session); (d) after dispose, a lifecycle change calls nothing; (e) the existing presence behaviour (onHide / onShow, the round pausing) is unchanged.
2 In phone_host.dart extend the existing AppLifecycleListener with onPause and onResume that call `service.stats.pause()` and `service.stats.resume()` (unawaited, errors logged, never thrown). It is the same listener, disposed in dispose(). Keep the file under 380 lines.
3 Run the phone suite once and fix pins your change breaks, keeping their intent.
tests-first: the new test file must fail on the old code.
rules: aim for 60-120 turns · no lib file you touch may end over 380 lines · write only inside allow: · stage nothing yourself · never use git add -A · tools/review.sh: no FAIL on your lines.
allow: controller_app/lib/src/host · controller_app/test · docs/briefs/m14/bugs10/b019-2-phone-wiring-report.md
check: format analyze phone
report: docs/briefs/m14/bugs10/b019-2-phone-wiring-report.md
in the report: start with `## Summary` (at most 30 lines): what changed, tests seen failing and passing with counts, decisions, "Fixed, unverified: needs device check" (background the app on an iPhone host, reopen, see the session uploaded). End with `## Hand-over`.
