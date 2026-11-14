job: M14 bugs3 s1-progress-bar: Shape Race: the top progress bar does not fill all the way when every piece is placed (B-001)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · packages/puzzle_game/lib (search for the progress bar in the HUD/status painter)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner report: "Shape Race: Top progress bar doesn't fill up all the way when all pieces are placed." Find how the bar's fraction is computed (wrong total, rounding, an animation cut off by the round ending, a twin or locked piece not counted, snapped pieces only). Fix so it is exactly full when the last piece is placed (and stays full on the win screen), in one-board, split-screen and co-op layouts. Add a test.

tests: each new test fails first where testable. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines): root cause, what changed by file, decisions, anything not done, what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); if a bug cannot be tested, say so in the report · every text a player sees goes through the text files · write only inside this job's folder · leave no scratch file behind in the repository · do not change gameplay rules, maps or balance
allow: docs/briefs/m14/bugs3/s1-progress-bar-report.md · packages/puzzle_game · packages/party_host/lib/src/ui
check: format analyze puzzle host
report: docs/briefs/m14/bugs3/s1-progress-bar-report.md
