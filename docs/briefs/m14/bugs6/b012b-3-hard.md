job: M14 bugs6 b012b-3-hard: six Hard puzzles (B-012b, phase 3 of 3)
pub: no
stop: after it.
read: docs/briefs/m14/bugs6/b012b-2-medium-report.md (Summary and Hand-over only) · docs/levels.md (the Hard rules) · tools/level.sh · packages/puzzle_game/puzzles/index.json · two redone Medium puzzles as examples
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: 6 puzzles for the Hard level; harder by pieces and rotation, not by time.
Design:
1 Create six new Hard puzzles with tools/level.sh new (pick six clear, child-recognisable pictures not already in the library, e.g. dragon, windmill, lighthouse, dinosaur, tractor, tower): each 10 to 12 pieces (the 8.5 mm floor may cap a picture at 10), 3 or 4 big, every non-circle piece turned, at most 2 repeated pairs; run tools/level.sh check and render on each; PNGs under docs/design/puzzles/. Register them in index.json.
2 Update library_test.dart's per-level count (Hard 6) and any test that lists puzzle ids.
3 Tests: the library test over the files (check green for every Hard puzzle); a picker test with the library loaded shows the Hard card.
5 For EVERY new Hard puzzle render two pictures, solved and start state (pieces as they start in the tray, turned), as PNG into docs/briefs/m14/bugs6/b012b-3-hard/<puzzle>-solved.png and <puzzle>-start.png, and list every path in the report Summary so the owner can look before the next build. If tools/level.sh render draws only one state, produce the other with a temporary test or script you delete afterwards (leave no code behind).
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what was built, the numbers that matter, decisions, questions, anything not done, and what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it. Do not claim a test passes unless you ran it in this job and saw it; write "not run" otherwise. If a cause is unmeasured, say "needs device check".
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); every behaviour change gets a test that fails on the old code · no hard-coded tuning numbers: named, documented constants in one place · every text a player sees goes through the text files · write only inside allow: · leave no scratch file behind · stage nothing yourself
allow: docs/briefs/m14/bugs6/b012b-3-hard-report.md · docs/briefs/m14/bugs6/b012b-3-hard · packages/puzzle_game/puzzles · packages/puzzle_game/test · docs/design/puzzles · packages/party_host/test
check: format analyze puzzle host
report: docs/briefs/m14/bugs6/b012b-3-hard-report.md
