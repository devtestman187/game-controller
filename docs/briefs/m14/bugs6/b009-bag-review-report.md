# b009-bag review

## Summary

Verdict: **small fixes**. must 0 · should 1 · could 3.
1. `puzzle_bag.dart:147` restores only the waiting ids, so after a restart a refill can open with the
   puzzle just finished, and an id a build adds waits a cycle: both are brief item 1's restart cases
   (the job lists this as decision 4 and question 1).
2. `puzzle_bag.dart:59` documents the avoid guard as moving the id "behind one other id"; the code
   moves it to the end of the bag.
3. No screen test opens a round with `match != null`, the one path that must not draw.
Checks I ran on the committed tree: `puzzle_bag_test.dart` + `puzzle_pick_test.dart` 14/14 pass,
`flutter test` (whole host suite) 415/415 pass, `dart format --set-exit-if-changed` 0 changed,
`flutter analyze` no issues. No device was started.

## Findings

- **should** `packages/party_host/lib/src/puzzle_bag.dart:147` `fromJson` returns `PuzzleBag._(waiting, const {}, const {})`, so after the app closes nothing remembers the id just played or the cycle's played ids: a refill then can open with the puzzle just finished, and an id a build adds is classed as played by `_cycleSoFar` (line 121) and waits a cycle, both against brief item 1 → save the last-played id (or the cycle's played ids) beside `{level: [ids]}`, as the job's question 1 proposes.
- **could** `packages/party_host/lib/src/puzzle_bag.dart:59` the doc says a shuffle that puts `avoidId` first "moves it behind one other id", but lines 91-93 remove it and append it, i.e. move it to the end of the bag (test 10 asserts `[c, d, e, f, a]`) → say "to the end of the bag".
- **could** `packages/party_host/test/puzzle_pick_test.dart:47` the three screen tests open rounds with a choice only, so nothing would notice a draw added on the `widget.match != null` path, which must leave the bag untouched → add a round opened with a `Match` and assert the `puzzleBag` prefs string is unchanged.
- **could** `docs/briefs/m14/bugs6/b009-bag-report.md:112` self-check item 2 cites `puzzle_bag_test.dart` 10 for the no-puzzle case and 4 for the reload, which are tests 3 and 5 in the report's own list → renumber.

## Decisions to confirm

- Decision 4 (the brief's `{level: [ids]}` shape): whether the two restart cases are acceptable, or the last-played id goes into a second key (report question 1); today the first round after a restart can repeat the last board of the previous session.
- Decision 1 (the pick runs from `initState`): the board paints one frame after the screen opens (a `CircularProgressIndicator` for that frame, where the old `_pick` drew in the first build), and a round opened and left before the board appears still draws and saves, so that puzzle is skipped for this cycle. Both follow from the choice; whether they are acceptable is Claude's.
- Decision 2 (a hand-picked puzzle is recorded as played): after picking one puzzle by hand, `Any <level>` will not play it again until the level's other puzzles have played. Safe, and worth one line in `docs/design/party-night.md` §2.

## Could not check

- The report's claim (line 23) that the three screen tests "failed on prefs and on the played id" on the old code: the committed `puzzle_pick_test.dart` imports `src/puzzle_bag.dart` at line 6, so on the old tree it cannot load without a stub that is not in the diff.
- The one-frame spinner and the skipped-id effect on a real device: needs a device check, not measured here.
- `docs/design/party-night.md` was not read, so the report's suggestion about §2 is unchecked.

## Commit message

Review b009-bag: bag sound, one restart gap plus doc and test fixes

Read the b009-bag diff against its brief, the coding guidelines and review-rules
A and B. The per-level bag, the `puzzleBag` prefs key, the initState pick and
the pure part move hold; the 14 new tests and the whole host suite (415) pass,
and format and analyze are clean.
One should finding: the saved shape keeps only the waiting ids, so after a
restart a cycle can open with the puzzle just finished and an added id waits a
cycle, against brief item 1.
Three coulds: a doc line that puts the avoided id "behind one other id" where
the code moves it to the end, no test for a round that must not draw, and two
mis-cited test numbers in the job's self-check.

## Status row

B-009 review (bugs6 b009-bag-review) is done: verdict small fixes, one should (the restart gap in the saved bag) and three could findings, no must. Open: Claude's verification of the should finding, its decision on the saved shape (job question 1), and the device play.

## Delete

- none
