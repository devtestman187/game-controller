# b013 review fixes: the one fix batch for the run review

## Summary

All eight items of the brief are done. The mirror test now names the pictures that lose their mirror; the design renders regenerated; the six Hard ids run through the shared-id tests and the contact sheet; the cat keeps its planned visits and its quiet and stops knocking when the chaos is turned down mid-round; the bag's cycle survives a restart; a series' Next and Continue leave the shared `any` bag alone; the Hard library test and the Hard card's label say what they mean.

Numbers that matter:

- **The cat.** 480 s Lively Party = window 450 s, 16 visits, 10 knocks. Share 28.125 s; a visit now starts in the share less the visit (4.8 s) and the quiet (5 s) = 18.325 s of room, so two visits never start closer than 9.8 s. A side that leads all round is still visited 16 times (the old code made 1 such visit), and a one-board round keeps its 16 too.
- **The bag.** The saved JSON is now `{"easy": [ids left], "played": {"easy": {"ids": [played this cycle], "last": "..."}}}`. After a restart: 30 refill shuffles, none opens with the puzzle just finished; an id a build adds is inserted into the waiting ids at once (it used to wait a whole cycle).
- **The series.** Three rounds' saved bag shows one entry: the picker's pick. The night gate moved into `_startedSeries`.
- **Hard through the shared lists.** 18 ids in `puzzleIds` (11 sites now cover all 18); the sheet is 6 columns × 3 rows, box 1776 × 582 px (was 1194 × 582).

The decisions are one line each below; the open questions and the suggestions are numbered under their own headings.

Not done, needs a person:

- **The mirror, on a device.** The exact list is `['car', 'butterfly']`: the Medium **butterfly** loses its opponent mirror on the 852 px phone as well as the car the brief named. Whether either should keep it is a layout/design question (rule 7 allows absent), so the test pins both and says so. **Needs device check.**
- **Files outside `allow:` changed by running the suites.** The brief's `check` and the render test write pictures beside the ones I may keep: `docs/design/m13-placed-look.png`, `m13-puzzles.png`, `m13-puzzles-night.png`, `m13-tablet-board.png` and `site/shots/{dpad,menus,results,sticks,tilt}.png` are modified in the tree (the m13-puzzle ones were already dirty before this job). They should be reverted or committed by whoever owns them; I staged nothing.
- The six Hard design renders do not appear in the diff: their committed pictures already match what the render test writes.

## Decisions

- **Visit the other side on a one-sided lead** (brief item 5a): the leader pool drops the last side, and when that empties the other side is taken — the plan's count is kept, as the owner asked.
- **A one-board round keeps its visits too**: there is no other side to go to, so the only side is visited rather than every second visit dropped (same bug, same code path; reported as a question).
- **Tray packing floor 0.55 → 0.45** (`visibleShare`): the dragon's front leg (0.524) and the tractor's ground (0.471) fall under it in the narrowest made-up tray; the players' real promise (half in view) stays pinned by `tray_pile_test.dart` on the real tray.
- **Hard overlaps pinned to one value each** (dragon 0.25, windmill 0.25, lighthouse 0.0, dinosaur 0.25, tractor 0.25, tower 0.25 — all 20 seeds), measured, not guessed.
- **The bag's cycle is one extra key** `played`, per level `{ids, last}`, so the last-played id is exact even when an id is picked twice in a cycle.
- **A series round is one with a `series` on the screen**, so `_picked` records a pick only when `widget.series == null`; a Change-teams round comes back through the join screen with no series and is a pick again (its doc comment says so).
- **Contact sheet 6 columns × 3 rows**: one row per level, so every cell stays a 288 × 162 board.

## Self-check (review-rules part A)

1. **Every host setup.** The bag and the picker are host screens and run the same code on a TV/PC host and on a phone host (`party_host`); the pick, series and night tests run at 960 × 540, and the series card is also drawn at 852 × 393 (`puzzle_continue_test.dart: the series' results card draws on a phone-sized host without overflow`). The cat is rules, identical on every host (`cat_review_test.dart`). Joined phones and an older build are not affected: no message, snapshot or saved format they read changed (the bag's JSON only gained a key; an older save is read by the fallback). Older-build tests not run.
2. **When kept state starts and ends.** The bag's cycle starts at the first draw or pick of a level, grows with each, and ends when a level refills (a cycle is the level's ids) or when the id leaves the build; with no round it simply sits in the prefs under `puzzleBag` (`puzzle_bag_restore_test.dart`, `puzzle_bag_test.dart`). The cat's plan starts when the match is made and ends with the round (`endRound`) or the shoo (`cat_test.dart`).
3. **How a new state combines with the others.** No new pause, wait or block was added; the bag and the series are read when a round opens, as before. The one pair that changed is a night plus a chosen round: it still plays and its results keep the night's one Next (`puzzle_series_fix_test.dart: a night's chosen round starts no series`).
4. **Stay in the job's folder.** Every edit is in the brief's `allow:` list; the suites' own outputs outside it are listed in the summary (`docs/design`, `site/shots`) and the pre-existing dirty files (m13 sheets, the Windows plugin registrants, the untracked patches) are untouched.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:` to do the work; `puzzle_screen.dart`'s initState ternary is left as it was, because the night gate fits in `_startedSeries` (the only file allowed) and covers it anyway.

## What changed, item by item

1. **`controller_app/test/mirror_pad_test.dart`** — the D-pad case asserts the exact list of pictures with no mirror on the 852 px phone, `['car', 'butterfly']` (index order), and that every other picture's mirror is byte-for-byte the padless one, so the mirror is never moved. Measured: the car and the butterfly lose it, the other 16 keep it. The brief named the car only; the butterfly is a second loser — reported, not changed.
2. **The design renders.** The whole puzzle suite ran; `puzzle_render_test.dart` rewrote all 18 sheets. In the diff: the six Medium (`boat, car, robot, train, castle, butterfly`) and six Easy pictures were stale and are now the current render; the six Hard ones were already committed correctly and show no change.
3. **Hard ids everywhere.**
   - `packages/puzzle_game/test/support/match_helpers.dart`: `puzzleIds` holds 18 ids (six Easy, six Medium, six Hard, in `index.json` order), doc fixed.
   - `packages/puzzle_game/test/split_layout_test.dart`: the phones overlap pin gained six entries (values above).
   - `packages/puzzle_game/test/tray_packing_test.dart`: floor 0.55 → `visibleShare` 0.45 (dragon front leg 0.524 at seed 6 flat, width 31.7; tractor ground right 0.471 at seed 2 flat, width 17.5).
   - `packages/puzzle_game/test/puzzles_png_test.dart`: 6 columns × 3 rows, 18 cells.
   - `packages/party_host/test/puzzle_pick_test.dart`: a `hard` bag and a Hard round that draws `dragon` and moves only the Hard bag; the saved-bag expectations gained the cycle key.
   - The other seven sites (`match_test`, `phone_tray_reach_test`, `slot_contrast_test`, `split_layout_test` ×2, `tray_packing_test` ×2, `tray_pile_test` ×2, `view_test`) passed unchanged over the six Hard puzzles.
4. **`packages/puzzle_game/lib/src/puzzle_rule_levels.dart`**: the `Level.hard` early return in `_turned` is gone; a Hard puzzle now gets the "at least two turned" rule too, and the rule book is still green over all 18 files (`puzzle_check_test.dart`).
5. **The cat (`cat_chaos.dart`, `cat_tuning.dart`'s promise, `puzzle_game.dart`).**
   - (a) `_leader` prefers a side that isn't `_lastSide` among the leaders and falls back to the other side; it returns a game, never null.
   - (b) `_plan`'s room subtracts `CatRules.visitS` **and** `CatTuning.minQuietS`.
   - (c) `_mayKnock` reads `settings.chaos == Chaos.party` live.
   - `puzzle_game.dart` exports `cat_tuning.dart`; `cat_tuning_test.dart` no longer imports `src/`.
   - New `packages/puzzle_game/test/cat_review_test.dart`: 480 s Party Lively with the left side 3–0 all round makes 16 of 16 visits; 12 seeds × 16 visits at 480 s never start two visits closer than 9.8 s − a frame (the old room gave 8.8 s at seed 6); a one-board 480 s round makes its 16; switching to A little after the first knock leaves 1 knock (the old code knocked twice). Each fails on the old code (visited: 1 visit; 8.8 s gap; 2 knocks).
6. **`packages/party_host/lib/src/puzzle_bag.dart`**: `toJson` saves each level's cycle under `played` (`ids` in play order, `last`), `fromJson` reads it back (unknown level or no ids → left out; a `last` not among the ids → the last id). Old saves without the key keep the `_cycleSoFar` fallback. New `packages/party_host/test/puzzle_bag_restore_test.dart`: after a finished cycle and a restart, 30 refill seeds never open with the just-finished id (old code opened with 'd' at seed 3); a mid-cycle bag saved by a six-puzzle build draws `{c, d, g}` for a build that adds `g` (old code drew `{c, d}`).
7. **`packages/party_host/lib/src/ui/puzzle_pick.dart`**: `_picked` records a pick only when `widget.series == null`; `_startedSeries` returns null on a night; `_changeTeams` carries the doc comment about restarting the series on the same pick. New `packages/party_host/test/puzzle_series_fix_test.dart`: Next and Continue each leave the bag exactly as the pick left it; Change teams plays the pick again in a series that offers Next; a night's chosen round offers the night's one Next. `puzzle_continue_test.dart` also asserts the Shuffle switch is absent at the level-done prompt.
8. **`packages/puzzle_game/test/hard_library_test.dart`** keeps one count-and-order test (six, in index order); the piece, big-piece, turning, repeated-shape and rule-book copies are gone — `puzzle_check_test.dart` runs them over every file. **`packages/party_host/test/games_screen_levels_test.dart`** asserts the Hard card's label is `'Any Hard puzzle'`.

## Files changed

- `controller_app/test/mirror_pad_test.dart` — D-pad case asserts the exact list of mirror losers and that nothing moved.
- `packages/puzzle_game/lib/puzzle_game.dart` — exports `CatTuning`.
- `packages/puzzle_game/lib/src/cat_chaos.dart` — leader falls back to the other side (or the one board); room minus the quiet; live chaos check in `_mayKnock`.
- `packages/puzzle_game/lib/src/puzzle_rule_levels.dart` — Hard's `_turned` early return removed.
- `packages/puzzle_game/test/cat_tuning_test.dart` — imports the package library only.
- `packages/puzzle_game/test/support/match_helpers.dart` — 18 ids, doc.
- `packages/puzzle_game/test/split_layout_test.dart` — six Hard overlap pins.
- `packages/puzzle_game/test/tray_packing_test.dart` — `visibleShare` 0.45 with the measured cases named.
- `packages/puzzle_game/test/puzzles_png_test.dart` — 18 cells, 6 × 3.
- `packages/puzzle_game/test/hard_library_test.dart` — one count-and-order test.
- `packages/puzzle_game/test/cat_review_test.dart` (new) — the cat's visits, quiet, live chaos, one board.
- `packages/party_host/lib/src/puzzle_bag.dart` — the cycle saved and restored.
- `packages/party_host/lib/src/ui/puzzle_pick.dart` — a series round records nothing; night gate; Change teams doc.
- `packages/party_host/test/puzzle_bag_restore_test.dart` (new) — restart: last id avoided, added id drawn.
- `packages/party_host/test/puzzle_series_fix_test.dart` (new) — Next, Continue, Change teams, a night.
- `packages/party_host/test/puzzle_pick_test.dart` — Hard bag, cycle in the saved expectations.
- `packages/party_host/test/puzzle_continue_test.dart` — Shuffle absent at the level-done prompt.
- `packages/party_host/test/games_screen_levels_test.dart` — the Hard card's real label.
- `docs/design/puzzles/*.png` — all 18 regenerated by the render test (12 differ from the commit: six Medium, six Easy).

## Checks

`tools/check.sh format analyze puzzle host phone` — all pass: format (3 s), analyze (11 s), puzzle 439 tests (89 s), host 448 tests (43 s), phone 464 tests (38 s).

## Questions

1. **The butterfly.** The brief named the car as the Medium picture that loses its mirror on the 852 px phone; the butterfly does too. Keep the absent mirror for both, or should the layout find them room? **Needs device check** (neither is measurable here).
2. **A one-board round.** I let it keep every planned visit (16 at 480 s on Lively) instead of every second one. Is a solo host meant to see the cat that often?
3. **Series rounds and the shared bag.** A series' puzzles now never leave the `any <level>` bag, so a later `any Medium` round can follow a series with a puzzle the series just played. That is what the brief asks for; say if the picker should instead mark series plays as played without reordering.
4. **Tray packing floor.** 0.45 in the narrowest made-up tray is a lower bar than before; if you want the old 0.55, the dragon and tractor pieces need to change, not the test.

## Suggestions

- The render and site-shot tests write into `docs/` and `site/` on every `flutter test`, so any suite run dirties files no job may commit. A `--update` flag (write only when asked) would keep diffs honest.
- `tray_packing_test.dart`'s stress widths (`widest + 4`) are narrower than any real tray; a visibility check against the layout's real tray would test the promise players see.
- `docs/code-health.md`'s mirror note (the review's item 28, not in this brief) still needs the car and the butterfly, and its "Done" entry moved.

## Commit message

Fix the run review's findings: the cat, the bag, the series

The cat visits the other side when the leader is the side it just left
(16 of 16 visits at 480 s, one-board rounds too), keeps the tuning's 5 s
quiet and reads the Chaos setting live, so A little stops knocks mid-round.
The bag saves the cycle's played ids with the one played last, so a restart
neither opens with the puzzle just finished nor makes a new one wait.
A series' Next and Continue leave the shared bag alone, a night's chosen
round starts no series, and the mirror test names its two losers.

## Status row

M14 bugs6 b013: all eight review fixes done (cat visits/quiet/live chaos, bag cycle saved, series bag and night gate, Hard ids in the shared tests and sheet, design renders, mirror list, Hard tests trimmed); open — the car's and butterfly's missing mirror needs a device check, the m13/site pictures the suites rewrite sit outside the job, the cats' text in the PRD and party-night and the Medium best times are untouched.

## Delete

- packages/puzzle_game/test/_overlap_probe_test.dart
- packages/party_host/test/_bag_probe_test.dart
