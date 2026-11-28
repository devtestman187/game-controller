# f1c report

## Summary
STATUS: done. The side panel draws `seats` seats a side, and the pop-up cap scales with the setting.
- `seats` goes JoinScreen.build (`cap`) → `_JoinBody` → `_Sides` → `_SidePanel`. Rows keep 52 px, and shrink (floor: the 38 px badge) only when the room left in the panel is smaller.
- `maxPerSide` const removed. `defaultMaxPerSide = 2` replaces it, with reworded docs.
- `PuzzlePoints.maxPopupsFor(perSide) = 2 * perSide + 1`. `_award` caps by it using `settings.maxPerSide`.
- Checks: tools/mine.sh OK (party_host 28 test files, puzzle_game 16).

## Files changed
- join_side_panel.dart: `seats` on `_Sides` and `_SidePanel`; a LayoutBuilder computes the row height; `_PlayerRow` and `_EmptySeat` take `heightPx`.
- join_screen_widgets.dart: `seats` on `_JoinBody`, passed to `_Sides`.
- join_screen.dart: `seats: cap`; `maxPerSide` → `defaultMaxPerSide`; docs reworded.
- points.dart, puzzle_points.dart: `maxPopupsFor`; `_award` uses it.
- join_screen_frame_test.dart, phone_fit_matrix_support.dart: `maxPerSide` → `defaultMaxPerSide`.
- join_seats_test.dart (new): 3 and 4 seats, both looks, 960x540 and 360x640; 2 a side keeps 52 px.
- points_test.dart: pop-up cap of 5 at 2 a side and 9 at 4 a side.

## Computed values
- Pop-ups: 2 a side → 5, 4 a side → 9. 8 and 12 awards were made, so the oldest went.
- Empty seats with one player joined: 2*perSide - 1 (3 at 2, 5 at 3, 7 at 4).
- Seat height at 2 a side: 52.
- Unchanged: `cat_snapshot_test`, `snapshot_eight_players_test` and the other `maxPopups` loops use the default 2 a side, so they stay on `maxPopups`.

## Questions / suggestions
- The row-height floor is the badge size (38 px). I did not measure how often it shrinks at 4 a side; the tests only show nothing overflows.
- join_seats_test.dart joins one phone only: the harness had one joinable phone.
- The tests did not check the new test fails on the old code. It cannot compile without `seats`, so it fails there by missing parameter.

## Commit message
race1a f1c: side panel draws N seats, pop-up cap scales

The join screen's side panel takes `seats` (the cap the state computes)
and shrinks its rows only as far as 4 seats need. The const maxPerSide
becomes defaultMaxPerSide. PuzzlePoints.maxPopupsFor(perSide) = 2n+1
caps a side's pop-ups by the maxPerSide setting (5 at 2, 9 at 4).

## Status row
f1c done: side panel draws N seats (rows shrink to fit), pop-up cap scales with maxPerSide; open: nothing known.

## Delete
- none
