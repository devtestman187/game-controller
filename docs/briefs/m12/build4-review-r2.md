job: m12 build 4 full review R2 — the host's screens: party_host and tv_test_app; read-only
stop: after the review. Change no file but the report; fix nothing. Write only inside this job's folder.
read: docs/review-rules.md (parts A to D: the rules for this review) · docs/coding-guidelines.md · the job briefs and reports of build 4 in docs/briefs/m12/: bug-1107b-*, bug-1107c-*, bug-1107d-* (g1-plan, a1, b, a2c), bug-1107e-*, s10-g1-plan.md, s10a, s10b, s10c, s11 · the owner's decisions: docs/design/m12-host-touch.md, m12-opponent-mirror.md, m12-joined-view.md §0.3 · docs/protocol.md
diff: `git diff 526a6fc HEAD -- packages/party_host tv_test_app` (build 3 was tagged on 526a6fc; build 4's code ends at 9df6884). Read the tests as well as lib: a test that would still pass if its rule broke is a finding.

do:
1 Part A: for each job in your area, is its self-check true? (Jobs before Nov 7 evening had no self-check: answer A1–A3 yourself for them.)
2 Part B over the diff, B1–B8, focused on: `Pausable` as the one owner of a round's pause and phase: the pause menu, host away, players away, the Get ready beat, the results and leaving, in every combination; the away card's countdown vs the server's grace; the join screen's own player (Play on this phone vs Show on this device vs TV); back on the results; the round log lines.
3 The combination table (A3) for every state your area touches, each pair "tested by <test name>" or "not tested", and for each untested pair what happens (read the code).
4 Part C, only for your area, only what would cost much more to fix later than now.
5 `tools/review.sh` on the range: copy every FAIL.
format: docs/review-rules.md part D, at most 120 lines.
check:
report: docs/briefs/m12/build4-review-r2-report.md
allow: docs/briefs/m12/build4-review-r2-report.md
