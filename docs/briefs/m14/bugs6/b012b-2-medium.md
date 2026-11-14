job: M14 bugs6 b012b-2-medium: a harder Medium: new limits and the six Medium puzzles redone (B-012b, phase 2 of 3)
pub: no
stop: after it. Hard puzzles are phase 3.
read: docs/briefs/m14/bugs6/b012b-1b-rules-rest-report.md (Summary and Hand-over only) · packages/puzzle_game/lib/src/puzzle_rule_levels.dart · docs/levels.md · tools/level.sh · the six Medium files in packages/puzzle_game/puzzles (find them in index.json) · puzzle.schema.json
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner: "The puzzles themselves are very easy. Medium should be harder ... by having more pieces, more rotations, etc." Answered: redo the Medium puzzles; 6 Medium puzzles; the clock does not change.
Design:
1 New Medium limits (named constants): 8 to 10 pieces (today 6 to 8), at least 4 pieces turned (non-circles), 1 or 2 big pieces, at most 1 repeated pair. Update docs/levels.md.
2 Redo each of the six existing Medium puzzles in place (same id and picture subject; say in the report that old Medium best times no longer compare) so each meets the new limits: more pieces built from the shape kit, still the same recognisable picture, every piece at least the 8.5 mm floor, tray rules passing. Use tools/level.sh check and render; the PNGs under docs/design/puzzles/ update.
3 Update the Medium count in library_test.dart only if the number of Medium puzzles changed (it stays 6).
4 Tests (each fails on the old code): the rule book refuses a 7-piece Medium and one with 3 turned pieces and accepts a 9-piece one with 4 turned; the library test over the files is green on all twelve puzzles.
5 For EVERY redone Medium puzzle render two pictures, solved and start state (pieces as they start in the tray, turned), as PNG into docs/briefs/m14/bugs6/b012b-2-medium/<puzzle>-solved.png and <puzzle>-start.png, and list every path in the report Summary so the owner can look before the next build. If tools/level.sh render draws only one state, produce the other with a temporary test or script you delete afterwards (leave no code behind).
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what was built, the numbers that matter, decisions, questions, anything not done, and what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it. Do not claim a test passes unless you ran it in this job and saw it; write "not run" otherwise. If a cause is unmeasured, say "needs device check".
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this); every behaviour change gets a test that fails on the old code · no hard-coded tuning numbers: named, documented constants in one place · every text a player sees goes through the text files · write only inside allow: · leave no scratch file behind · stage nothing yourself
allow: docs/briefs/m14/bugs6/b012b-2-medium-report.md · docs/briefs/m14/bugs6/b012b-2-medium · packages/puzzle_game/lib/src/puzzle_rule_levels.dart · packages/puzzle_game/puzzles · packages/puzzle_game/test · docs/levels.md · docs/design/puzzles
check: format analyze puzzle
report: docs/briefs/m14/bugs6/b012b-2-medium-report.md
