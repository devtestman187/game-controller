# M14 bugs4 f3 — the fixes from the bugs3 review (report)

Job: M14 bugs4 f3. Read for it: `docs/briefs/m14/bugs3/REVIEW.md` ("Findings" only), the files and
lines each finding names, `docs/coding-guidelines.md`. Code changed in `packages/party_host` (the
waiting card, its rows, the menus, the game screen) and `packages/puzzle_game` (the board cache and
its two views); item 4 is report text only.

## Summary

- **1 (must, B-013) done.** A phone works the Arena's waiting card: the screen hands the card and the
  results the menus' controls (`game_screen.dart`), each player row is a `HostCardButton` and so the
  card's Start (`arena_waiting_widgets.dart`), and the card reads only a local player's pad
  (`arena_waiting_card.dart`). Tests: `arena_phone_card_test.dart` (a phone picks a mode, a map and
  starts the round, press after press; and readies another player's row), plus `arena_waiting_test.dart`
  and `arena_touch_ready_test.dart`, which move the focus to a row first (`focusRow` in the harness).
- **2 (should) done.** `controller_menus.dart` lifts the OK again in a `finally` around the invoke;
  `menu_remote_after_phone_test.dart` takes turns, phone and remote, and all four presses land.
- **3 (should) done.** `StaticBoardKey` holds the canvas's pixel scale (`board_cache.dart`,
  `puzzle_painter.dart`), a used layer moves to the end of the eviction order, and both views clear the
  cache when their puzzle changes (`view.dart`); three new tests in `board_cache_test.dart`.
- **4 (should) done, report text only.** a2: the file is `arena_player_scale_painter.dart` and the
  "no other file changed" line is gone. a1: its music tests landed in i1's commit `c4e4e00`; checks
  line added. pr-arena: `cat_test.dart` keeps 2 visits in a 40 s round (a new 120 s test pins 3), the
  Spinning Tops reason is the post in the carousel's sweep, `chaosLine` is named. pr-party:
  `party-night.md:61` cited, G2's "Teams may change between rounds" (`PRD-v2.md:168`) quoted, the
  host's-own-player rule tested both ways. pr-shape: repeat odds are the rematch path's (1/6 on the
  join path), the metrics claim split into what the summary gets free and the table work, the "What
  does not change" heading is Medium's pieces, turn rules and files; checks lines added to it and s1.
- **5 Skipped, as ruled.** No other finding was acted on; `sound_loop.dart` is untouched.
- **6 Done.** The three `tv_test_app/windows/flutter/generated_plugin*` files are back at `HEAD`'s
  bytes (read with `git cat-file -p`); `git status` still flags them, a line-ending difference only —
  `git diff` lists no change for them, as the bugs3 review found them.
- Checks (the brief's `check: format analyze host phone tv puzzle`): all pass — `format` pass ·
  `analyze` pass · `host` 399 tests · `phone` 464 tests · `tv` pass · `puzzle` 403 tests; `arena` also
  passes (219 tests), which a1's corrected line cites.

## Decisions (low-usage mode)

- Item 1: reuse `ControllerMenus` instead of copying its focus walk and OK lift into the card, which is
  the smaller change of the two the ruling offers, and make the row the Start (a `HostCardButton`
  around it) rather than add a new button under the roster.
- Item 1: the card keeps reading its own pads but skips every player that isn't local. The menus skip
  `local` players by design, so a phone's rows are pressed once by the menus; without the skip a
  local player's A would press its row twice (the card and the menus).
- Item 3: the record observer is injected through the constructor (`BoardCache({this.onRecord})`),
  which `docs/coding-guidelines.md` §2 allows, rather than a test hook in the frame path.
- Item 3: `clear()` empties the layers and the paths together: a path is built for a board, so it is
  no more valid for another puzzle than a layer is.
- Item 1 changed `game_screen.dart` to 401 lines, past the 380-line rule, so the field moved to its own
  file (`game_field.dart`, a `ConsumerWidget` taking the round's game, stage, settings, tags and
  callbacks). The screen is now 369 lines and the field 90.
- Item 4, pr-party: the review asks for a test named "a phone host on 'Show on this device' with one
  roster player still gets the join screen", but that host pairs no player at all
  (`controller_app/lib/src/host/hosting.dart:23-27`, "a phone that shows the game never pairs a
  player"), so one joined phone is the whole roster and the pick starts its solo round. The test
  bullet pins the rule from both sides instead: "Show on this device" + one phone starts solo, "Play
  on this phone" + one phone keeps the join screen (its own player makes two).
- The suites rewrite ten pictures as they run (`docs/design/m13-placed-look.png`,
  `docs/design/puzzles/*.png`, `site/shots/*.png`); each rewritten copy was put back from `HEAD` byte
  for byte after the last run, as the bugs3 review did with its own run.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** A TV or PC host and a phone host on either setting work the card as before
   (their own pad and the menus agree; `if (!p.local) continue` only narrows what the card reads); a
   joined phone now works it, which is the new test; no wire field changed, so a phone or host one
   build older is not affected.
2. **When kept state starts and ends.** The OK latch is lifted before and after every menu press, so it
   never outlives one (`menu_remote_after_phone_test.dart`); a cache layer starts on a board's first
   still frame, moves to the end when drawn, and goes when the view gets another puzzle
   (`board_cache_test.dart`'s three new tests); the path cache ends with the layers.
3. **How a new state combines with the others.** The menus own the card's and the results' input and
   `Controls.game()` owns the field's, switched by the stage, so no press reaches both
   (`game_screen.dart`); the pause, the 3-2-1, the away host and a dropped link are untouched, and a
   phone presses the card right up to the round's start (`arena_phone_card_test.dart`).
4. **Stay in the job's folder.** Every write is inside `docs/briefs/m14/bugs4`, `docs/briefs/m14/bugs3`,
   `packages/party_host/lib/src/ui`, `packages/party_host/test` or `packages/puzzle_game`.
5. **Stop rather than overstep.** Item 6 needed files outside `allow:` — the ruling named them, and
   they are back at `HEAD`'s bytes; the picture side effect of the suites was undone rather than left
   for someone else.

## Questions and suggestions

- The pr-party test the review names cannot pass as written (the case it describes is the solo one);
  the report pins the rule with both cases instead. Say if a different case was meant.
- Splitting the field out of `game_screen.dart` was needed for the 380-line rule only; if the field
  belongs somewhere else in `lib/src/ui`, it is a one-file move.

## Commit message

M14 bugs4 f3: the fixes from the bugs3 review

B-013: a phone works the Arena's waiting card. The screen gives the card
and the results the menus, each player row is a HostCardButton and so
the card's Start, and the card reads only a local player's pad. The
menus lift the OK after the invoke too, so no press path leaves a button
held. The board cache's key holds the canvas scale, a view given another
puzzle clears it, and a used layer moves to the end of the eviction
order. Six bugs3 reports corrected; the field moved to game_field.dart
so the screen stays under 380 lines.

## Status row

B-013 fixed (the Arena waiting card is fully worked from a phone; tested twice in a row), the menus' OK lifts again after the press (tested with a remote after a phone), and the board cache is keyed by the canvas's pixel scale with a used layer kept last and a puzzle swap cleared (all tested); six bugs3 reports corrected; the three generated_plugin files back at `HEAD` (line endings only).

## Delete

- none
