job: M14 bugs8 b012c-2-bests-clear: clear the old Medium best times once (B-012)
pub: no
stop: after it.
read: packages/party_host/lib/src/best_times.dart · packages/party_host/test/best_times_test.dart · packages/party_host/lib/src/prefs.dart · packages/puzzle_game/puzzles/index.json (Medium ids are boat, car, robot, train, castle, butterfly: the puzzles redone in b012b-2)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner (Nov 14): "Old medium best times can be cleared." The Medium puzzles were redone, so times saved on the old pictures mean nothing. Easy and Hard bests stay. Clear them ONCE: a time recorded after the clear must be kept on every later start.
Design:
1 TEST FIRST, new file packages/party_host/test/best_times_medium_clear_test.dart (fails on the old code): with mock SharedPreferences holding a 'bestTimes' JSON that has solo and team boards for boat, car, robot, train, castle, butterfly (Medium) plus house (Easy) and dragon (Hard) and no migration marker: reading bestTimesProvider drops every Medium board and keeps the Easy and Hard ones; the cleaned data is saved back to prefs; a time recorded afterwards for a Medium puzzle is kept; building the provider again from the same prefs (a restart) keeps that new Medium time (cleared once, not on every start); a fresh install (no 'bestTimes' key) gets the marker too so its first Medium time survives a restart. Also a test that the Medium id list in the code equals the library's Medium puzzles if the library can be loaded in party_host tests (other party_host tests load it; else say so).
2 Implement in best_times.dart (keep it under 380 lines, split if needed): a documented const for the migration version and one for the list of Medium ids that were redone, a prefs marker key (e.g. 'bestTimesVersion', int), run inside BestTimesNotifier.build before decoding: if the marker is below the version, remove those boards (keys 'id|solo' and 'id|team'), save the cleaned map back when there was one, write the marker. Never throw on bad data (the existing FormatException path stays).
3 Run flutter test in packages/party_host once (quiet reporter) and fix what your change breaks.
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): how the clear works, the marker key, test results with counts you saw, decisions, anything not done. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
tests-first: the new test file must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself · never use git add -A
allow: docs/briefs/m14/bugs8/b012c-2-bests-clear-report.md · packages/party_host/lib/src · packages/party_host/test
check: format analyze host
report: docs/briefs/m14/bugs8/b012c-2-bests-clear-report.md
