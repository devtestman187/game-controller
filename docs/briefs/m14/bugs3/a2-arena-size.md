job: M14 bugs3 a2-arena-size: Arena: players look too small on a TV (B-014)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · packages/test_game/lib (the Arena's drawing: character size, scale) · how the host scales the Arena on a TV (packages/party_host/lib/src/ui)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner report: "Arena mode: players look too small on a TV." On a phone host the characters read fine; on a TV the map is scaled to the screen so characters become small relative to it. Make the characters (body, face, coin count, name or number marker) draw larger on a TV-sized screen: scale the character picture by a factor from the existing layout classification (e.g. LayoutTarget, no new switch), about 1.5x on a TV, without changing collision radius, speeds or any rule. Keep the phone-host look unchanged. Add a test for the scale function (phone 1.0, TV larger).

tests: each new test fails first where testable. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines): root cause, what changed by file, decisions, anything not done, what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); if a bug cannot be tested, say so in the report · every text a player sees goes through the text files · write only inside this job's folder · leave no scratch file behind in the repository · do not change gameplay rules, maps or balance
allow: docs/briefs/m14/bugs3/a2-arena-size-report.md · packages/test_game · packages/party_host/lib/src/ui · packages/party_host/test
check: format analyze arena host tv
report: docs/briefs/m14/bugs3/a2-arena-size-report.md
