job: M14 bugs3 i1-ok-presses: an iPad controller's OK/A press works only once on a TV (owner's device test, Nov 14, 2026, build m14.3)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · controller_app/lib (how a joined phone sends button and menu presses to the TV) · packages/connection · the TV/host menu input code in packages/party_host/lib/src/ui (search for how menus take the press)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Two owner reports, both Blockers, probably one root cause. B-008: "When connected to a TV, OK not registering to Play from iPad. First press works. Second one doesn't. This happens across the entire UX." B-013: "Arena mode: iPad cannot control TV menu at all here. I had to use the TV remote." Setup: an iPad/iPhone controller (iOS app 0.14.0 build 456, sticks mode) joined to the Android TV host over the LAN websocket; the TV menus are driven by the phone's menu keys (OK/A, directions).
Find the root cause by reading the code (suspects: a press edge/latch never reset after the first press, focus or input-mode state on the TV lost after the first screen change, menu input ignored while the Arena is the active game, a debounce or sequence number that stops accepting after the first event, the phone sending menu presses only in one controller mode). Fix it so every press works in every menu on the TV, including the Arena menus, and add a test that reproduces two successive presses (and the Arena menu case) and fails on the old code.

tests: each new test fails first where testable. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines): root cause, what changed by file, decisions, anything not done, what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); if a bug cannot be tested, say so in the report · every text a player sees goes through the text files · write only inside this job's folder · leave no scratch file behind in the repository · do not change gameplay rules, maps or balance
allow: docs/briefs/m14/bugs3/i1-ok-presses-report.md · controller_app/lib · controller_app/test · packages/connection · packages/protocol · packages/party_host/lib/src/ui · packages/party_host/test
check: format analyze host phone tv protocol
report: docs/briefs/m14/bugs3/i1-ok-presses-report.md
