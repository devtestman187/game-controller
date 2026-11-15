job: M14 bugs11 b020-solo-phone-test: a lone night player on a phone host that plays here (run review finding 1)
pub: no
stop: after it. Test only; no lib change.
read: packages/party_host/test/arena_touch_ready_test.dart (the `ownPhoneOverrides` helper about line 23, `openTouchNightCard` about line 49, the p2 add about line 56, the Ready tap test about line 110) · packages/party_host/test/solo_arena_both_test.dart and solo_arena_card_test.dart (setup only) · docs/briefs/m14/bugs11/b020-solo-both-report.md (Summary and Hand-over)
decide: low-usage mode: never stop for a question. Make the safest choice that fits and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
tests-first: exempt test-only hardening of behaviour that already works (f11c4b1 and b020-solo-both)

Finding: the phone host's night card is tested only with a second phone added; the setup whose behaviour changed, a lone night player on a phone that plays here (the host's own player), where the round now waits for that player's Ready tap, has no test.
1 Add ONE test in a NEW file packages/party_host/test/arena_touch_solo_night_test.dart: a phone host (same overrides as `ownPhoneOverrides`; copy the helper, do not edit arena_touch_ready_test.dart) with a night of one player opens the Arena card (`arenaWaitingCard`), the player is not ready, one tap on Ready starts the round (`arena` key shows), and no round starts before the tap. Make it mode-agnostic: do not assert which mode button is chosen.
2 Await every async side effect before teardown (settleUploads / deleteTempFolder as the other party_host tests do).
in the report: `## Summary` (at most 15 lines), then `## Hand-over`. Do not claim a test passes unless you ran it in this job.
rules: aim for 30-60 turns · write only inside allow: · stage nothing yourself · never use git add -A
allow: packages/party_host/test/arena_touch_solo_night_test.dart · docs/briefs/m14/bugs11/b020-solo-phone-test-report.md
check: format analyze host
report: docs/briefs/m14/bugs11/b020-solo-phone-test-report.md
