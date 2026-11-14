job: M14 bugs3 p2-coop-fps: Shape Race co-op: the TV frame rate looks choppy with two players (B-016)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · packages/puzzle_game/lib (painter, per-frame work, snapshot handling on a TV host) · packages/party_host/lib/src/ui
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner report: "Shape race co-op. Frame-rate on TV appears choppy with two players." Android TV host, two iPhone/iPad controllers, Shape Race co-op. A phone's own stats of a phone-hosted session show 60 Hz, 19512 frames drawn, 4 dropped, received_to_drawn median 6 ms; so the choppiness is on the TV. Read the code for per-frame costs that grow with two players (piece painting rebuilt every frame, paths or pictures created per frame, saveLayer/blur/shadow per piece, repeated sorting, per-frame allocations, setState of the whole tree on each snapshot) and cut the cheap, safe ones: cache paths/pictures, avoid saveLayer, RepaintBoundary around static parts (board, HUD) separate from moving parts, interpolation of remote players so motion looks smooth between snapshots. Do not change gameplay. Report what you found, and add tests for what is testable (a cache is reused between frames, a repaint boundary exists).

tests: each new test fails first where testable. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines): root cause, what changed by file, decisions, anything not done, what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); if a bug cannot be tested, say so in the report · every text a player sees goes through the text files · write only inside this job's folder · leave no scratch file behind in the repository · do not change gameplay rules, maps or balance
allow: docs/briefs/m14/bugs3/p2-coop-fps-report.md · packages/puzzle_game · packages/party_host/lib/src/ui · packages/party_host/test
check: format analyze puzzle host tv
report: docs/briefs/m14/bugs3/p2-coop-fps-report.md
