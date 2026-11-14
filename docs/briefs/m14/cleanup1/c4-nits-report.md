# M14 cleanup1 c4: documentation nits — report

## Summary

1. **Re-wrap the over-long doc line — done.** `packages/test_game/lib/src/arena_piece_painter.dart:13`'s
   paragraph (the pieces doc above the belt constants, the file's top doc) is wrapped again at the doc's own
   ~80-column width; no word changed, no code line touched (294 lines, was 293; longest line is still the
   formatted code line 121 at 115 columns).
2. **Two known-debt rows — done.** `docs/code-health.md` `### party_host` table, two rows in its style:
   `GameField`'s 9 constructor parameters (`game_field.dart:18-29`) and the local-pad filter written in
   `arena_waiting_card.dart:142` and `controller_menus.dart:155`. Both cited lines were read, not guessed.

### Decisions
- The brief calls the doc line "over-long" against 120 columns, but measured it is **103** columns
  (`sed -n '13p' | wc -c` = 104 with the newline; `wc -L` gives 115 for the whole file, the formatted code
  line 121). The line broke the doc's own ~80-column wrap, so I wrapped the paragraph at that width, which
  is the smallest change that leaves the doc uniform; nothing else in the file changed.
- `GameField` counts 9 named parameters besides `super.key` (`game`, `playing`, `debug`, `hosting`,
  `keyboard`, `roundTags`, `onEvent`, `onClock`, `onFinished`, `game_field.dart:18-29`); the row lists those
  nine and cites the constructor's range.
- The two filters are not identical, they are complementary: the card reads only local pads
  (`arena_waiting_card.dart:142`, `if (!p.local) continue;`), the menus address only phone players
  (`controller_menus.dart:155`, `if (!p.simulated && !p.local && !p.away) p`). The row says so ("in opposite
  senses") rather than calling them copies; the same split also sits in `pause_menu.dart:313` and
  `pause_menu_widgets.dart:18`, which the row names in parentheses.
- Rows went in `### party_host` (both files live there), not in `### M14 bugs1`, which is scoped to bugs1's
  review.

### Self-check (review-rules.md, part A)
1. Every host setup: docs and one comment only, no behaviour change; `arena` (219 tests) passes on the
   existing TV/PC, phone-host and joined-phone paths.
2. When kept state starts and ends: no state held, timed or remembered is added or changed.
3. New state combined with others: none added; the card's and menus' pads are unchanged.
4. Stay in the job's folder: only `docs/briefs/m14/cleanup1/c4-nits-report.md`, `docs/code-health.md` and
   `packages/test_game/lib/src/arena_piece_painter.dart` changed (`git status` confirms; the untracked
   `bugs3/*.patch` and `bugs6/` files predate this job).
5. Stop rather than overstep: no rule broken; the two premise differences above are recorded, not worked
   around.

### Checks
- `tools/check.sh format analyze arena`: PASS format (3 s), PASS analyze (18 s), PASS arena (219 tests,
  28 s); all checks passed (49 s).
- No file touched grew over 380 lines (painter 294, code-health 104).

## Commit message

M14 c4: wrap the pieces doc, log two party_host nits

The pieces doc's paragraph in arena_piece_painter.dart is wrapped again at the
doc's own width; its words and the code are unchanged. code-health.md's
party_host table gains two when-touched rows: GameField's 9 constructor
parameters want a parameter object (game_field.dart:18-29), and the
local-vs-phone pad filter is written in two places in opposite senses
(arena_waiting_card.dart:142, controller_menus.dart:155, also
pause_menu.dart:313, pause_menu_widgets.dart:18), so one helper when either is
touched. No behaviour change.

## Status row
M14 cleanup1 c4: docs nits done (pieces doc wrapped; GameField params and local-pad filter logged in code-health); open: the two rows are when-touched, nothing else.

## Delete
- none
