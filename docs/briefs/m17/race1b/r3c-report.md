# r3c report: the present wired into the match, the knock on Wild only

## Summary

What changed:
- `cat_chaos.dart` `_mayKnock`: the knock now also needs `settings.catPreset == CatPreset.wild`; the doc says why (owner Q4).
- `match.dart`: a `PresentRules _present` field, a stored `_settings` (set in the ctor and in `set settings`), and `present` getter. In `update()`, each `snap` event calls `_present.onSnap(side)`, then `_present.update(dt, enabled: PresentRules.enabled(_settings), oneBoard: !format.split)` while the round runs. `_decide()` calls `_present.end()` after `_cat.endRound()`. `snapshot()` passes `present:`.
- `present_match_test.dart` (new, 5 tests): knock on Calm/Lively vs Wild; present timing; no present on Off, Wild or one board; holder snap moves the present; the fuse pops and placed counts stay equal.
- Existing knock tests that expected a knock on the default Lively preset now run on Wild: `cat_test.dart` (2 minute knock, one-knock 40 s, older-piece) and `cat_review_test.dart` ("A little mid-round"). The last one's plan count moved from 3 to 4 visits (Wild, 2 minute round).

Tests-first: before the lib change, the Calm knock test failed on the base: a placed piece was knocked on Calm at 40.858 s (piece `b`, side left). The present tests failed as expected (no present). After the change: `tools/mine.sh` reports `OK 28 tests packages/puzzle_game`; analyze is clean.

Computed values used in expectations:
- Start delay `PresentRules.startDelayS` = 20 s: no present at 19 s, present out at 21 s.
- First present held by left (`presents == 0`); a left snap bats it to right; a second left snap leaves it with right.
- Fuse `startFuseMs` = 12000 ms; the pop is seen by `until` within the 2000-frame default.
- Placed counts before the pop: left 1, right 1 (one piece each placed in setup); unchanged after the pop.
- Wild, 2 minute round: 4 visits (`cat_tuning_test` plan 4 / 3 knocks); the A little test saw 4 starts.

Self-check (review-rules part A):
1. Host setups: this is match logic only, no host UI; covered by `present_match_test.dart` (Calm, Lively, Wild, Off, one board).
2. Kept state: the present starts at `_present` (no state) and ends in `_decide` via `end()`; the `present no present on Off, Wild, one board` test shows the nothing-going-on case.
3. Combinations: a snap by the non-holder does nothing (test 4); `end()` after the result (`_result == null` gate on update); pause, host away, dropped links: not touched by this job.
4. Files: only files in `allow:`; `lib/src/present_rules.dart` and `present.dart` were used, not changed.
5. Stop: none needed.
6. Looks: no look or widget changed.

## Hand-over

- `match.dart` is 328 lines (was 309): the growth is 19 lines, over the brief's 14-line target (the 380-line limit is met). Trimming would mean dropping the field's doc comment or merging the snap loop.
- Team checks: `tools/mine.sh` (format, analyze, touched tests) only; no `tools/check.sh` run.

## Commit message — a draft

B10 r3c: the present on Calm and Lively, the cat's knock on Wild only

Wires the hot-potato present into PuzzleMatch: a snap by the holder bats it on, and
the present runs on the round's clock each tick (off on one board, Off and Wild).
CatChaos only knocks a placed piece on Wild; Calm and Lively have the present instead
(owner Q4). The present never changes a side's placed count. Existing knock tests run
on Wild; present_match_test covers the new rules.

## Status row

M17 race1b r3c: present wired into the match (Calm/Lively); cat knock on Wild only; done with tests. Open: match.dart at 328 lines (14-line growth target missed), a shared preset helper in test/support (not in allow), painter and host UI (later jobs).

## Delete

- none
