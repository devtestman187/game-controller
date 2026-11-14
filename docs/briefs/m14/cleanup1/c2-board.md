job: M14 cleanup1 c2: a real test of the board cache's hint, ready and glow keys, and three nits
pub: no
stop: after it.
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
read: packages/puzzle_game/lib/src/board_cache.dart · packages/puzzle_game/test/board_cache_test.dart (the last testWidgets, "a board drawn from its cache is the board drawn without one, byte for byte") · `git show 95da0ac` (the commit that added the cache; the old code is its parent) · packages/puzzle_game/lib/src/phone_hud.dart around line 139 · packages/puzzle_game/lib/src/board_hud.dart around line 23 · docs/coding-guidelines.md

Claude's rulings. Do exactly these:
1. The last test in board_cache_test.dart draws identical bytes on old and new code, so it proves nothing about the cache's keys. Delete it (keep any helper another test uses) and write its replacement in a NEW file `packages/puzzle_game/test/board_cache_state_test.dart`: paint two snapshots through ONE cached painter (same BoardCache) and assert the cache records a second picture (use BoardCache's `onRecord`) when a hint target, a ready target or a glow changes between the snapshots, and does not record again when none of them changes. It must FAIL on the code before 95da0ac's key fields covered those (i.e. if the key ignored hints/ready/glow, the test fails): check by temporarily removing those fields from StaticBoardKey's equality, run the test, see it fail, restore. Say in the report what you saw.
2. Mark `BoardCache.onRecord` `@visibleForTesting` (package:meta, or flutter/foundation.dart as the file already imports).
3. phone_hud.dart ~139 `track.height / 4`: name the 4 as a private constant with a doc line saying what it is (the inset of the fill from the bar's rounded ends).
4. board_hud.dart ~23 `/ 1000` (ms to s): name it as a private constant (`_msPerSecond`).
No behaviour change. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines, in its first 40 lines): each item done / not done, decisions. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 100 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · every text a player sees goes through the text files · write only inside this job's folder and the allow: paths · leave no scratch file behind in the repository · never touch tv_test_app/windows/flutter/generated_plugin* or PNG files
allow: docs/briefs/m14/cleanup1 packages/puzzle_game
check: format analyze puzzle
report: docs/briefs/m14/cleanup1/c2-board-report.md
