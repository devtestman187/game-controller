job: M14 cleanup1 c4: documentation nits
pub: no
stop: after it.
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
tests-first: exempt docs and a comment re-wrap only
read: packages/test_game/lib/src/arena_piece_painter.dart (the class doc) · docs/code-health.md (its table format and the section for known debt) · packages/party_host/lib/src: GameField's constructor (game_field.dart or similar) · the local-pad filter code in the Arena waiting card and in ControllerMenus (grep for the filter of local pad / phone-vs-local players)

Do exactly these:
1. Re-wrap the over-long line in arena_piece_painter.dart's class doc to the 120-column limit. Nothing else changes.
2. In docs/code-health.md add two rows in the existing known-debt table, in its style: (a) `GameField` takes 9 constructor parameters (list their names) - Low, a parameter object when next touched; (b) the local-pad filter is duplicated between the Arena waiting card and ControllerMenus (name both files and lines) - Low, one shared helper when either is touched. Cite file:line you verified.
No code change except item 1's comment.

in the report: start with `## Summary` (at most 30 lines, in its first 40 lines): each item done / not done, decisions. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 100 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · every text a player sees goes through the text files · write only inside this job's folder and the allow: paths · leave no scratch file behind in the repository · never touch tv_test_app/windows/flutter/generated_plugin* or PNG files
allow: docs/briefs/m14/cleanup1 · docs/code-health.md · packages/test_game/lib/src/arena_piece_painter.dart
check: format analyze arena
report: docs/briefs/m14/cleanup1/c4-nits-report.md
