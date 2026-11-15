job: M14 stats1 b4-puzzle-level-tag: why no puzzle round carries a level_ tag
stop: after it. Diagnose first.
read: packages/puzzle_game/lib/src/puzzle_session.dart (_endTags ~185, the write ~145) · packages/puzzle_game/lib/src/puzzle_report.dart (round_end, tags) · packages/party_host/lib/src/session_recorder.dart (round_end tags to roundEnded) · packages/metrics/lib/src/session.dart (_roundTags, _roundTagPattern, maxRoundTags) · git log -S for when the level_ and chaos_ tags were added
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Facts: of 36 exported puzzle rounds none has a level_ tag; 14 Nov TV rounds have chaos_ and no level; Windows rounds have no tags. git says the level tag commit is 5e43313 (2026-11-14); find the m14 build dates (docs/briefs/m14/STATUS.md, git tags) to see whether the tag simply shipped after those builds.
do:
1 Trace one tag from _endTags to the summary round JSON by reading code; check every filter (the regex ^[a-z0-9_.-]{1,32}$, take(8), the actual values of match.puzzle.level.name: a capital letter in an enum name would fail the regex).
2 If a real bug drops it, fix it with a test in a NEW file packages/puzzle_game/test/level_tag_survives_test.dart that fails on the old code (ideally through the real filter). Otherwise add no code and write the finding.
3 The Summary states: root cause with file:line, or "builds predate the tag" with dates. Unmeasured => "Fixed, unverified: needs device check".
tests-first: a new test must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · do not touch controller_app/lib/src/host/phone_host.dart · tools/review.sh: no FAIL on your lines.
allow: packages/puzzle_game/lib/src · packages/puzzle_game/test · docs/briefs/m14/stats1/b4-puzzle-level-tag-report.md
check: format analyze puzzle metrics
report: docs/briefs/m14/stats1/b4-puzzle-level-tag-report.md
in the report: start with "## Summary" (at most 30 lines): what changed or found, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
