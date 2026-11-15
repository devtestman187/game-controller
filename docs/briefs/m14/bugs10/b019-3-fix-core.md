job: M14 bugs10 b019-3-fix-core: three review fixes in LiveStats (B-019)
pub: no
stop: after it.
read: docs/briefs/m14/bugs10/REVIEW.md (only findings 3, 5 and 8 below) · packages/party_host/lib/src/live_stats.dart (_checkPlayers, endSession, resume, uploadNow, dispose) · packages/party_host/test/live_stats_lifecycle_test.dart · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Context: B-019 made pause() end and save the session and resume() retry uploads. The run review found three faults in packages/party_host/lib/src/live_stats.dart.
do:
1 TEST FIRST, new file packages/party_host/test/live_stats_fixes_test.dart (each case must fail on the old code): (a) pause() while the host's own player stays paired, then resume(): a new session starts without a join or leave; (b) a failing upload started by the end of dispose() leaves no retry timer and no upload running afterwards; (c) a session that starts and ends while the previous one is still being written keeps its own `current` summary and `_ending`.
2 Fix 3: resume() also runs the presence check (_checkPlayers) after uploadNow, so a still-paired player gets a session.
3 Fix 5: after dispose() has cancelled `_retry`, a failing uploadNow must not arm a new one (a disposed flag that uploadNow and the retry arming check).
4 Fix 8: endSession clears `_ending` and `current` only when `_ending` is still the session it saved.
tests-first: the new test file must fail on the old code.
rules: aim for 60-120 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · write only inside allow: · stage nothing yourself · never use git add -A.
allow: packages/party_host/lib/src/live_stats.dart · packages/party_host/test/live_stats_fixes_test.dart · docs/briefs/m14/bugs10/b019-3-fix-core-report.md
check: format analyze host
report: docs/briefs/m14/bugs10/b019-3-fix-core-report.md
in the report: start with `## Summary` (at most 30 lines): what changed, tests seen failing then passing with counts, decisions. End with `## Hand-over`.
