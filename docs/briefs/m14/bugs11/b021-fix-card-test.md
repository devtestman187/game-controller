job: M14 bugs11 b021-fix-card-test: two could-fixes in the solo card test
pub: no
stop: after it.
read: packages/party_host/test/solo_arena_card_test.dart (lines 17-70) · packages/party_host/test/support/host_harness.dart (`arenaSnapshot`, line 246)
decide: low-usage mode: never stop for a question. Make the safest choice that fits and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
tests-first: exempt test-only hardening of behaviour that already works

1 `solo_arena_card_test.dart:52` "opens on Surprise me": after `roundStarted`, also assert `arenaSnapshot(tester).mapId` is not `'pinball'` (the saved map).
2 `openNightBumperCard` (line 17) is used by test 2 only and repeats test 1's setup (lines 36-45): give it the `setMap` case as a parameter and let test 1 use it.
in the report: `## Summary` (8 lines max).
rules: aim for 30-60 turns · write only inside allow: · stage nothing yourself · never use git add -A
allow: packages/party_host/test/solo_arena_card_test.dart · docs/briefs/m14/bugs11/b021-fix-card-test-report.md
check: format analyze host
report: docs/briefs/m14/bugs11/b021-fix-card-test-report.md
