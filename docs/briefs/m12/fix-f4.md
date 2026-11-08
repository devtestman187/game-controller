job: m12 build 4 fix-f4 G4 — the Get ready frame, its protocol row, and the ratings copy
stop: after G4.
read: docs/code-health.md N6, N7 · docs/briefs/m12/build4-review-r1-report.md findings 1–5 · packages/game_kit/lib/src/game_session.dart · packages/protocol/lib/src/view.dart (`FrameMessage.n`) · docs/protocol.md (`frame`, §10a) · packages/metrics/lib/src/{session,session_player}.dart · their tests · docs/coding-guidelines.md
do:
1 The beat frame (`n: -1`) carries what a step's frame carries: the roster (`pl`) and the acks, built by the same code as a step's frame, not a second copy.
2 It is published whether or not a viewer is attached yet, so the host keeps it as the latest frame and a viewer that pairs during the beat gets `view_start` and that frame.
3 docs/protocol.md and `FrameMessage.n`'s doc: `n` is -1 for the frame a host sends before the first step while the round is held (the "Get ready" beat), then from 0; frames stop while a round is paused. Say an older viewer draws it as before (it reads -1 → 0 as no gap).
4 N7: `ratings` is copied into a summary like `rounds` and `games`.
tests (each failing first): the beat frame has the roster and acks; a viewer that pairs during the beat gets `view_start` then the beat frame; a summary taken before a rating doesn't change after it. Existing tests: list any old → new.
in the report: test counts before and after, the files changed, computed values.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/fix-f4-report.md · packages/game_kit/lib/src/game_session.dart · packages/game_kit/test/session_test.dart · packages/protocol · packages/metrics · docs/protocol.md
check: format analyze protocol kit metrics connection host
report: docs/briefs/m12/fix-f4-report.md
