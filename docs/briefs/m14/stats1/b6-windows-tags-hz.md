job: M14 stats1 b6-windows-tags-hz: why Windows-hosted rounds carry no tags and no hz
stop: after it. Diagnose first.
read: packages/party_host/lib/src/session_recorder.dart (round_start hz, round_end tags) · packages/party_host/lib/src/live_stats.dart (read only; another session edits it: do not change it) · packages/metrics/lib/src/session.dart (roundStarted, roundEnded, _roundHz) · packages/test_game/lib/src/arena_session.dart (round_start hz, _tags) · packages/puzzle_game/lib/src/puzzle_session.dart (_roundStartData) · how a Windows host differs from the TV/phone host in building sessions (search hostType and platform)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Facts: exported Windows-hosted rounds have no tags and no hz, while Android TV rounds of 14 Nov have chaos_ tags. Find the Windows build dates (docs/briefs/m14/STATUS.md, git tags) and whether the tag/hz code (git log -S) shipped after them.
do:
1 Trace from the game record to the summary on the Windows path by reading code. Is any step skipped on Windows (another recorder, host.viewRateHz null, records not reaching the recorder, session() null)?
2 If current code really leaves them off on Windows, fix it with a test in a NEW file packages/party_host/test/windows_round_tags_test.dart that fails on the old code. Otherwise add no code and show that current code sets them (file:line for tags and for hz) and the exports came from older builds (dates).
3 The Summary states: root cause with file:line, or "older builds only" with dates. Unmeasured => "Fixed, unverified: needs device check".
tests-first: a new test must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · do not touch controller_app/lib/src/host/phone_host.dart · tools/review.sh: no FAIL on your lines.
allow: packages/party_host/lib/src/session_recorder.dart · packages/party_host/lib/src/ui · packages/party_host/test · docs/briefs/m14/stats1/b6-windows-tags-hz-report.md
check: format analyze host
report: docs/briefs/m14/stats1/b6-windows-tags-hz-report.md
in the report: start with "## Summary" (at most 30 lines): what changed or found, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
