# b009-bag — every puzzle of a level once before any repeat

## Summary

Built B-009 as pr-shape proposed: a shuffled bag per level, saved on the host, so a level plays
every one of its puzzles once before any comes back, and a night's Shape Race rounds share it.
Before this, the pick avoided only the round just played on the rematch path: with the 6 Medium
puzzles a repeat by the fourth round was 36% there and 42% on the join path (pr-shape's numbers).

- New `packages/party_host/lib/src/puzzle_bag.dart` (187 lines): a value `PuzzleBag` (per level,
  the ids still to play, next first) and `PuzzleBagNotifier` over `prefsProvider`, saving
  `puzzleBag {level: [ids]}` beside `bestTimes`. A draw pops the next id; an empty bag refills with
  every id of the level, shuffled, the id just played moved to the end; ids a build no longer ships
  are dropped, ids it adds join the cycle shuffled; `avoidId` is the second guard. `Random` is
  passed in.
- `puzzle_screen.dart` (399 → 367 lines) draws once, as the screen opens, from its level's bag; a
  hand-picked puzzle does not draw but leaves the bag; the Look never touches it. The Look,
  night, pause, ready and away paths are untouched.
- New part `puzzle_pick.dart` (78 lines) holds the pick and the results' first button, moved, plus
  the async pick: a draw changes a provider, so it runs from `initState`, not from `build`
  (Riverpod rejects a provider change during build).
- Tests: 11 in `puzzle_bag_test.dart`, 3 in `puzzle_pick_test.dart`; both files fail on the code as
  it was (the bag file does not load; the three screen tests failed on prefs and on the played id).
- Numbers: 6 draws of a 6-puzzle level give its 6 ids; the 7th differs from the 6th; a 5-id level
  with `g` added covers all 6 in 2 + 4 draws; a saved bag of 3 + 3 draws is 6 different ids; a
  hand-picked `house` leaves `[rocket, tree, sun, fish, snowman]` and the next any round plays
  `rocket`; a full bag with `avoidId: 'a'` draws `b` and leaves `[c, d, e, f, a]`.
- Checks: `tools/check.sh format analyze host` — PASS, PASS, PASS (415 tests). No device was
  started; the owner-facing check is a device play (below), not measured here.
- Owner should try: 6 Medium rounds — 6 different boards, no repeat; play one, close the app,
  reopen and play on — the order carries on; pick Castle by hand, then "Any Medium" — not Castle.

Decisions, questions and the self-check follow; nothing outside `allow:` was touched.

## Decisions (low-usage mode)

- **The pick runs from `initState`, not `build`.** A draw sets the bag's provider, and Riverpod
  throws "Tried to modify a provider while the widget tree was building" (seen in the first
  version of the widget test). `_pickedPuzzle()` awaits `puzzleLibraryProvider.future` and
  `_showPuzzle` sets the state, which is also the state's own `setState` (an extension may not call
  a protected member). A round with no library still shows its spinner.
- **A hand-picked puzzle is recorded as played**, as the brief says: it leaves the bag and is the
  cycle's last played, so a refill does not open with it. It is not recorded when the library no
  longer has that id (nothing to leave).
- **`puzzle_pick.dart` is a part of `puzzle_screen.dart`** holding an extension on the screen's
  `State`: that is the only way to move `this`-bound members into a part without rewriting them
  into functions that take the state (the repo has no extensions before this, and 30 lines of
  `screen.` plumbing read worse). The move is otherwise pure: `_pick`, `_again`, `_rematch` and
  `_changeTeams` move as they were, `_next` and `_roundSettings` stay.
- **The saved shape is the brief's `{level: [ids]}`**, so the id played last and the cycle's played
  ids are memory only. Cost: after a restart a cycle may open with the puzzle just finished (the
  rematch's guard still covers the round just played), and an id a *build* adds after a restart
  waits for the next cycle instead of the current one. Both keep repeats out; see question 1.
- **`puzzleBagProvider` lives in `puzzle_bag.dart`**, like `bestTimesProvider` in
  `best_times.dart`, so `providers.dart` and the package's export list stay untouched; tests reach
  it as `package:party_host/src/puzzle_bag.dart`, as other tests reach `src/` files.
- **A bag that holds fewer ids than the level ships is a build that added puzzles**: those ids join
  the cycle shuffled. My first widget test seeded a partial bag and was therefore not
  deterministic (a new id could come first) — the tests now seed a whole level.

## Files changed

- `packages/party_host/lib/src/puzzle_bag.dart` — new: `PuzzleBag` (draw, withPlayed, waitingFor,
  toJson, fromJson) and `PuzzleBagNotifier` (`puzzleBagProvider`, key `puzzleBag`).
- `packages/party_host/lib/src/ui/puzzle_pick.dart` — new part: the pick (`_pickedPuzzle`,
  `_picked`) and the results' first button moved from the screen.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — 367 lines: draws from the bag, picks in
  `initState`, part added, the moved members removed, `_puzzle` documented.
- `packages/party_host/test/puzzle_bag_test.dart` — new: 11 tests, the brief's cases plus the
  rematch guard, no-puzzle level and per-level independence.
- `packages/party_host/test/puzzle_pick_test.dart` — new: 3 screen tests (draw, own level, chosen
  leaves the bag and the next round plays on).
- `providers.dart` — unchanged (not needed).

## Tests and the values they check

`puzzle_bag_test.dart` (all with made-up ids a–f and m1–m6, `Random` seeds named in the file):

1. six draws of a 6-id level → the level's 6 ids, once each.
2. the 7th draw ≠ the 6th (the new cycle pushes the finished one to the end), and the 6 draws of
   cycle 2 are all 6 ids.
3. an empty id list draws `null` and writes nothing to the prefs.
4. a 1-id level × 3 draws → that id 3 times.
5. 3 draws, then a second container over the same prefs: it reads the same 3 waiting ids, and the
   6 draws together are 6 different ids.
6. 5 ids, 2 draws, then 6 ids (g added), 4 draws → the 6 draws are all 6 ids: g comes inside the
   cycle.
7. a saved bag `[gone, a, b]` over ids `[a, b]` → the 2 draws are `{a, b}` (bag left empty);
   `gone` never comes.
8. 6 ids, 2 draws (4 waiting), choose `waiting[2]` by hand → 3 waiting in their order, and the next
   3 draws are exactly those: no draw was used.
9. choosing `c` before any draw → the next 5 draws never include `c`.
10. a full bag `[a…f]` drawn with `avoidId: 'a'` → `b`, leaving `[c, d, e, f, a]`.
11. Easy and Medium drawn 6 times each, interleaved → each level's own 6 ids.

`puzzle_pick_test.dart` (the shipped 6 easy and 6 medium ids, seed bag in the prefs):

1. seeded easy `[house, rocket, tree, sun, fish, snowman]` → the round plays `house`; the bag is
   left `[rocket, tree, sun, fish, snowman]`.
2. seeded both levels → a Medium round plays `boat`, and only the medium key moves.
3. chose `house` → it plays, the bag is left with the other 5 in order; after popping, the next
   "any easy" round plays `rocket`, not the choice again.

## Self-check (review-rules part A)

1. **Every host setup:** the bag is host-side prefs and nothing goes over the wire, so a TV, a
   phone on either setting and a joined phone draw from the same bag, and a phone one build older
   is unaffected (no protocol change). Shown by `puzzle_pick_test.dart` 1–3, which run the real
   screen inside the harness; the layout/one-build-old paths are unchanged code.
2. **When kept state starts and ends:** it starts on the first draw of a round screen, has no end
   (a prefs key), and reads nothing while no round runs; a level with no puzzles draws nothing and
   saves nothing (`puzzle_bag_test.dart` 10), and a saved bag reads back in order (4).
3. **How it combines with the others:** it pauses, hides and waits for nothing; the pick is one
   library read and one draw as the screen opens, and a rematch or a next round is a new screen
   that draws then (`puzzle_pick_test.dart` 3). Pause, away, ready and the results are untouched;
   the whole suite (415 tests) runs them over the new pick.
4. **This folder only:** the writes are the files in `allow:` above; nothing else changed.
5. **Stop rather than overstep:** nothing outside `allow:` was needed. The brief's "part file"
   wording is met by a part that holds an extension (decision 3).

## Questions

1. Is the saved shape allowed to grow so a restart keeps more? Saving the id played last (or the
   cycle's played ids) would stop a restart opening a new cycle with the puzzle just finished and
   would let a build's new puzzle join the current cycle; today both are memory only. Cost: a
   second key or a richer `puzzleBag`.
2. If the puzzles' files fail to load, the round keeps its spinner and logs one line, as before.
   Should it say something to the player instead?
3. For b011 (Next/Shuffle): should "Shuffle" reset the level's bag, or reshuffle what is left? The
   bag keeps the puzzle just played out of the next draw by itself; a reset would allow a repeat.

## Suggestions

- `docs/design/party-night.md` §2 could say the bag exists and that a night's rounds share one per
  level; today the rule lives in the code's dartdoc and this report.
- pr-shape's risk ("6 puzzles a level becomes recognisable after a full cycle") can be measured
  once B-012a's round tag and timings are in: a repeat should now cost a whole cycle.

## Commit message

B-009: play every puzzle of a level once before any repeat

Shape Race drew its next puzzle at random, so a level could repeat a board by the third round
(36% by the fourth on a rematch, 42% on the join path). Each level now has a shuffled bag, saved
on the host as `puzzleBag {level: [ids]}`: a draw pops the next id, an empty bag refills with
every id of the level and the puzzle just played goes last, a build's dropped ids leave the bag
and its new ones join the cycle shuffled, and `avoidPuzzleId` stays as the second guard. A
hand-picked puzzle does not draw but leaves the bag; the Look never touches it. The pick runs
once as the screen opens (`initState`), because a draw changes a provider. The screen drops from
399 to 367 lines by moving the pick and the results' button to a new part.

## Status row

B-009 (bugs6 b009-bag) is done: a per-level, host-saved puzzle bag decides each Shape Race round, a hand-picked puzzle leaves it without a draw, and 14 new tests plus the whole host suite (415) pass. Open: the owner's answer to question 1 (whether the last-played id is saved too), the device play, and b011's Next/Shuffle buttons.

## Delete

- none
