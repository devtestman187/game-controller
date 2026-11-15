job: M14 stats1 a3-round-frames: frames_drawn, frames_late and fps per round in the rounds CSV
stop: after it. No start offset.
read: packages/metrics/lib/src/session.dart (frames() ~262 adds session totals; roundEnded) · packages/party_host/lib/src/session_recorder.dart (the frames record ~106 arrives AFTER round_end) · packages/test_game/lib/src/arena_session.dart (~178: round_end, then frames record, then reset) · packages/puzzle_game/lib/src/puzzle_report.dart · packages/party_host/lib/src/live_stats.dart ~107 (read only, do not edit) · packages/metrics/lib/src/report_rounds.dart
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: per-round frame counts are needed in the rounds CSV; today only session totals exist.
do:
1 TEST FIRST, new file packages/metrics/test/round_frames_test.dart (must fail on old code).
2 In metrics session.frames(): besides the totals, add the counts to the LAST round as framesDrawn and framesLate when that round has none yet and the call follows its roundEnded (an abandoned round has no round: add nothing). Old data stays valid.
3 Rounds CSV, appended at the END of the header (after the columns jobs a1 and a2 added): frames_drawn, frames_late, fps = framesDrawn / timeS to 1 decimal; blank when frames are unknown or timeS <= 0.
4 The Summary says whether puzzle rounds also get frames (read puzzle_report.dart); if not, list it as a finding.
tests-first: each new test must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself, never git add -A · never export player names or device IDs · do not touch controller_app/lib/src/host/phone_host.dart · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/lib/src · packages/metrics/test · packages/party_host/lib/src/session_recorder.dart · packages/party_host/test · docs/briefs/m14/stats1/a3-round-frames-report.md
check: format analyze metrics host
report: docs/briefs/m14/stats1/a3-round-frames-report.md
in the report: start with "## Summary" (at most 30 lines): what changed, tests seen failing then passing with counts, decisions, anything not done. End with "## Hand-over" (at most 20 lines).
