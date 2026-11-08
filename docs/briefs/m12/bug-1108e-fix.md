job: m12 bug 1108e — the results' "Play again" after an "any puzzle" round plays a different puzzle
stop: after it.
read: packages/party_host/lib/src/ui/{puzzle_screen,puzzle_screen_widgets}.dart · their tests in packages/party_host/test · docs/review-rules.md

Owner's words (build 5, Nov 8): "Play again when selecting 'any puzzle' actually plays the next puzzle in the list. Can this text be updated to say 'next puzzle' instead? If selecting a single puzzle, 'play again' makes sense."

Claude's rules:
- A round started from "any <level> puzzle" (`PuzzleChoice.puzzleId == null`): the first results button reads "Next puzzle", icon `Icons.skip_next`, key `nextPuzzle`, in both a solo round and a race (the press already picks another puzzle of that level, avoiding this one; that stays).
- A round of one chosen puzzle: unchanged ("Play again" solo, "Rematch" in a race, the replay icon, today's keys).
- The `Results: ...` log line says the button's label. Fix `_rematch`'s and `_ResultButtons`'s doc comments to match.
- Focus, order and the other buttons unchanged.

tests (each failing first): any-puzzle solo shows "Next puzzle" and pressing it opens another puzzle of the level; any-puzzle race shows "Next puzzle"; a chosen puzzle still shows "Play again" solo and "Rematch" in a race.
in the report: test counts before and after, the files changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1108e-fix-report.md · packages/party_host
check: format analyze host phone tv
report: docs/briefs/m12/bug-1108e-fix-report.md
