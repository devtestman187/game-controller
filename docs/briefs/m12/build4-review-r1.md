job: m12 build 4 full review R1 — the wire: protocol, connection, game_kit, metrics; read-only
stop: after the review. Change no file but the report; fix nothing. Write only inside this job's folder.
read: docs/review-rules.md (parts A to D: the rules for this review) · docs/coding-guidelines.md · the job briefs and reports of build 4 in docs/briefs/m12/: bug-1107b-*, bug-1107c-*, bug-1107d-* (g1-plan, a1, b, a2c), bug-1107e-*, s10-g1-plan.md, s10a, s10b, s10c, s11 · the owner's decisions: docs/design/m12-host-touch.md, m12-opponent-mirror.md, m12-joined-view.md §0.3 · docs/protocol.md
diff: `git diff 526a6fc HEAD -- packages/protocol packages/connection packages/game_kit packages/metrics` (build 3 was tagged on 526a6fc; build 4's code ends at 9df6884). Read the tests as well as lib: a test that would still pass if its rule broke is a finding.

do:
1 Part A: for each job in your area, is its self-check true? (Jobs before Nov 7 evening had no self-check: answer A1–A3 yourself for them.)
2 Part B over the diff, B1–B8, focused on: the away slots and their timers (A1, A2+C); `player_away`/`player_back` and old peers both ways; the first frame sent while paused (s10c); paused inputs not counted as delay and the summary copy (1107e); what a reconnecting phone is re-sent; the host's network addresses (1107b).
3 The combination table (A3) for every state your area touches, each pair "tested by <test name>" or "not tested", and for each untested pair what happens (read the code).
4 Part C, only for your area, only what would cost much more to fix later than now.
5 `tools/review.sh` on the range: copy every FAIL.
format: docs/review-rules.md part D, at most 120 lines.
check:
report: docs/briefs/m12/build4-review-r1-report.md
allow: docs/briefs/m12/build4-review-r1-report.md
