job: M14 stats1 b5-2-offset: each round records its start offset in seconds from the session start (phase 2 of 2)
stop: after it. Nothing else.
read: docs/briefs/m14/stats1/b5-1-split-report.md (Summary and Hand-over only) · packages/metrics/lib/src/session.dart (roundStarted, roundEnded, startMs) · packages/party_host/lib/src/session_recorder.dart (the round_start case; host.nowMs is the session clock, LiveStats passes startMs: host.nowMs at live_stats.dart:225) · packages/party_host/lib/src/live_stats.dart (READ ONLY: it is exactly 380 lines, the review.sh cap, and just got B-019 fixes; do not edit it) · packages/metrics/lib/src/report_rounds.dart · the existing party_host test that builds a SessionRecorder (round_stats_test.dart)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: the stats analysis needs when in the session each round began. Design: no change to live_stats.dart is needed.
do:
1 TEST FIRST, new files packages/metrics/test/round_offset_test.dart and packages/party_host/test/round_offset_recorder_test.dart (must fail on old code): roundStarted(hz:, atMs:) then roundEnded writes startS into the round JSON = (atMs - session startMs) / 1000 to 1 decimal, never negative; a round with no roundStarted (old callers) has no startS; the recorder passes host.nowMs on round_start; two rounds give increasing offsets. B-019 behaviour (pause ends the session, a new session starts after) keeps its tests passing: run the live_stats tests.
2 metrics roundStarted gets an optional atMs; the round JSON gets startS only when known. Old summaries still parse.
3 session_recorder passes host.nowMs.
4 Rounds CSV, appended at the END of the header: start_s (blank when unknown).
tests-first: each new test file must fail on the old code.
rules: aim for 80-150 turns · live_stats.dart must not change and no lib file you touch may end over 380 lines · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · do not touch controller_app/lib/src/host/phone_host.dart · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/lib/src · packages/metrics/test · packages/party_host/lib/src/session_recorder.dart · packages/party_host/test/round_offset_recorder_test.dart · packages/party_host/test/round_stats_test.dart · docs/briefs/m14/stats1/b5-2-offset-report.md
check: format analyze metrics host
report: docs/briefs/m14/stats1/b5-2-offset-report.md
in the report: start with "## Summary" (at most 30 lines): what changed, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
