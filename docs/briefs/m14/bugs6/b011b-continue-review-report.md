# b011b-continue review

## Summary

Verdict: **small fixes**. must 0 · should 1 · could 4.
1. The self-check (report line 44) calls Change teams a way the series "leaves behind", but the join screen carries the same chosen puzzle, so the next round starts a fresh series on it and the played ids are lost; Decisions do not list that choice.
2. The Summary's "pad walk is right, right, down, left (two rows) at 852×393" (line 20) is unmeasured: the 852×393 test only asserts no overflow, and the four-press walk runs at 960×540.
3. Every series Next/Continue passes a `puzzleId`, so `_picked` still writes its id into the shared `any` bag, though the decision at line 67 says the series does not use the bag.
Checks I ran on the committed tree: the five touched test files 51/51 pass; `flutter test` (whole host suite) 438/438, the report's number; `flutter analyze` no issues; `dart format --set-exit-if-changed` 0 changed in the ten files. No device started, no code changed.

## Findings

- **should** `docs/briefs/m14/bugs6/b011b-continue-report.md:44` "Back and Change teams leave it behind" hides a new series rule: `_changeTeams` (`puzzle_pick.dart:227`) opens `JoinScreen(choice: widget.choice)` and `_startedSeries` (`puzzle_pick.dart:47-51`) starts a series on that still-chosen puzzle, losing the played ids, and no Decision says so → add that choice to Decisions with its why, and correct the self-check line.
- **could** `docs/briefs/m14/bugs6/b011b-continue-report.md:20` the Summary's "pad walk … at 852×393" is not measured: `puzzle_continue_test.dart:225-237` only asserts `takeException()` is null at that size, while the four presses run at the harness's 960×540 (`puzzle_results_test.dart:85-97`, `host_focus_ring_test.dart:241-249`) → walk the pad at 852×393, or drop the size from the claim and leave it to the device check.
- **could** `packages/party_host/lib/src/ui/puzzle_pick.dart:170` each series Next and Continue (`:190`) passes the id as `PuzzleChoice.puzzleId`, so `_picked` (`:37`) records it in the shared `PuzzleBag`: after a series through a level, `Any <level>` skips those ids and refills once all have been "played", against the decision at report line 67 that the series does not use the bag → state that series rounds feed the bag, or record the id only for a pick made on the picker.
- **could** `packages/party_host/lib/src/ui/puzzle_continue.dart:141` the Shuffle switch disappears at the level-done prompt (report decision line 75), but no test asserts it: `puzzle_continue_test.dart:146-149` checks that Next puzzle is gone, not that Shuffle is → add `expect(find.byKey(const Key('shuffle')), findsNothing)` to the Continue test.
- **could** `packages/party_host/lib/src/ui/puzzle_results_widgets.dart:9-19` `_Results` now takes nine parameters (the job added `menu`), against guidelines §3's five → fold the card's menu options into one value object with the other card inputs.

## Decisions to confirm

- Where the card's Back goes: `resultsBack` pops through `_leaveForGames` to the games picker (`puzzle_results_test.dart:250-264`, `puzzle_screen.dart:302-309`), one screen above the puzzle list the design calls "the selection screen" (brief line 12); if the owner meant the puzzle list, the prompt's Back needs its own route.
- Change teams loses the played set and restarts the series on the same puzzle (finding 1): whether the owner expects the series to survive a team change.
- Series rounds feed the shared bag (finding 3): after a whole level walked by Next, `Any <level>` begins a new cycle and can repeat a board the series just played.
- On the last level the card keeps Change teams beside Play again and Back, where the design (line 12) says "only Back (and Play again) are offered".
- Shuffle is hidden once the level is done (report decision line 75): the owner's "it will end once all puzzles have been played" supports it, but it is the one switch state a player cannot undo before choosing Continue.

## Could not check

- Whether the commit touched only `allow:` files: `git diff` and `git status` were refused, so I read the ten files the report lists and took its "nothing outside it" as unverified.
- Whether each widget test fails on the old tree: `git show`/`checkout` were refused; the night test (`puzzle_continue_test.dart:195-223`) asserts only the old card's Next and would pass there, as the brief asked for it as a regression pin; the other ten use `PuzzleSeries` or the new keys, so the file cannot load on the old tree.
- The report's "383 → 380" for `puzzle_screen.dart` and the exact assertions kept in the three pinned test files: no diff available; the current files run green and every assertion quoted by the previous review is still present.
- The card's look and the pad's two-row walk on a phone host: not measured (the report leaves it to a device check).

## Commit message

```
Review b011b-continue: series sound, report and two tests to tighten

Read the b011b-continue diff against its brief, the coding guidelines and
review-rules A and B. The series value, the Next/Shuffle/prompt card, the
night gate and the level order from the enum hold; 51/51 in the touched test
files, 438/438 for the host suite, analyze and format clean.
One should: the self-check hides that Change teams starts a fresh series on
the chosen puzzle, a rule no Decision lists.
Four coulds: the 852x393 pad walk is unmeasured, series rounds still write
their ids into the shared any bag, the hidden Shuffle has no test, and
_Results grew to nine parameters.
```

## Status row

B-011 review (bugs6 b011b-continue-review) done: verdict small fixes, no must; the series, its card, the level-done prompt, the night gate and all 438 host tests check out. Open: the Change teams decision and self-check line, the 852×393 walk or the claim, the bag side effect, a hidden-Shuffle test, the `_Results` parameter count, and the owner's device check.

## Delete

- none
