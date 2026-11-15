job: M14 stats1 fix2-tests-clock: three findings of the run review (REVIEW.md findings 1, 3, 4)
stop: after it. Do not edit live_stats.dart (it is at the 380 cap).
read: docs/briefs/m14/stats1/REVIEW.md (findings 1, 3 and 4 only) · packages/metrics/test/round_frames_test.dart (~62) · packages/party_host/lib/src/session_recorder.dart (constructor ~22, the round_start case ~76, host.nowMs uses) · packages/party_host/test/round_offset_recorder_test.dart · packages/party_host/test/round_stats_test.dart (~22) · packages/metrics/lib/src/session.dart (_sinceStartS ~207) · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 TEST FIRST, new file packages/party_host/test/round_offset_clock_test.dart (must fail on old code): SessionRecorder takes an optional `int Function()? nowMs` (default host.nowMs, so LiveStats stays unchanged); with a fake clock the round_start record gives exact startS values (for example 0.0, 61.5, 125.0), no real time involved. Then drop the real-clock assertions (within 50 ms) in round_offset_recorder_test.dart and make round_stats_test.dart assert exact offsets with the fake clock instead of deleting startS.
2 Finding 1: round_frames_test.dart header check back to `endsWith(',players,frames_drawn,frames_late,fps,start_s')`.
3 Finding 4: in session.dart replace the bare 1000 in _sinceStartS by Duration.millisecondsPerSecond (or a named constant). Keep session.dart at most 380 lines.
tests-first: the new test file must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · tools/review.sh: no FAIL on your lines.
allow: packages/party_host/lib/src/session_recorder.dart · packages/party_host/test/round_offset_clock_test.dart · packages/party_host/test/round_offset_recorder_test.dart · packages/party_host/test/round_stats_test.dart · packages/metrics/lib/src/session.dart · packages/metrics/test/round_frames_test.dart · docs/briefs/m14/stats1/fix2-tests-clock-report.md
check: format analyze metrics host
report: docs/briefs/m14/stats1/fix2-tests-clock-report.md
in the report: start with "## Summary" (at most 30 lines): what changed, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
