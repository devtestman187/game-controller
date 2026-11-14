job: M14 bugs3 f3: the fixes from the bugs3 review (docs/briefs/m14/bugs3/REVIEW.md)
pub: no
stop: after it.
read: docs/briefs/m14/bugs3/REVIEW.md ("Findings" only) · then only the files and lines each finding names · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude's rulings. Do exactly these:
1. (must, B-013 is a Blocker) The Arena waiting card (`arena_waiting_card.dart:110`, `game_screen.dart:310`) must be fully operable from a phone controller: the pad's directions move the focus and A presses the mode, map and Start rows (hand the card's buttons back to `ControllerMenus`, or give it the pad's directions: pick the smaller change). Test: a phone picks a mode, a map and presses Start, twice in a row; fails on the old code.
2. (should) `controller_menus.dart:263`: lift the OK again after the invoke (use a finally) so no press path leaves a button held; test that a TV-remote OK after a phone press works.
3. (should) `board_cache.dart:129`: add the canvas's pixel scale to `StaticBoardKey`; test that a size change records again. Also clear the cache when the view's puzzle changes (could item at :129), and move a used layer to the end of the eviction order.
4. (should) Reports: correct a2's file path and its "No other file changed" line, add the check results line to each report that lacks one (a1, pr-arena, pr-shape, s1), say in a1's report that its music tests landed in i1's commit c4e4e00, and in pr-arena's report fix the cat_test claim (keep 2 visits in a 40 s round; pin the new count with a 120 s round test), the Spinning Tops reason, and name the host_text.dart chaosLine that becomes false. In pr-party's report fix the party-night line cite, quote the PRD G2 "Teams may change between rounds" clause, and add the phone-host test case. In pr-shape's report fix the repeat odds note (guard covers rematches only), the metrics-table claim and the "What does not change" wording. Report text only, no code for these.
5. Skip all other findings. Do NOT touch sound_loop.dart (the owner decides that trade-off).
6. Revert the three modified tv_test_app/windows/flutter/generated_plugin* files if the tree shows them changed.

tests: items 1-3 each get a test that fails first. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines): each item done / not done, decisions. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this) · every text a player sees goes through the text files · write only inside this job's folder · leave no scratch file behind in the repository
allow: docs/briefs/m14/bugs4 docs/briefs/m14/bugs3 · packages/party_host/lib/src/ui · packages/party_host/test · packages/puzzle_game
check: format analyze host phone tv puzzle
report: docs/briefs/m14/bugs4/f3-review-fixes-report.md
