# wave5 review: i1g2 (Shape Race workers, score bars, Cat Chaos path)

## Summary

Verdict: **small fixes**. Counts: 1 must, 2 should, 2 could.
- **must**: `score_bar_identity_test.dart:71` asserts behaviour that is unchanged by the diff, so it passes on the old code and proves nothing new.
- **should**: `play_view.dart` now holds two public widgets (`PuzzlePlayView:31`, `MatchView:215`), against guideline §3's one public type per file.
- **should**: `MatchPainter`'s `characters` forwarding (`match_painter.dart:140,189`) has no test; every new worker test takes the single-board `PuzzlePainter` branch.

## Findings

- **must** packages/party_host/test/score_bar_identity_test.dart:71 the second test passes on the pre-change code (old fill was `colors.player(row.number)` at score_row.dart:259 of the parent commit, the same value as `ToyCharacter.forPlayer(1).colourIn(colors)`), so it proves no new behaviour and the brief did not ask for it → keep it only as a stated default guard, or fold its assertion into the first test and say it is not evidence.
- **should** packages/puzzle_game/lib/src/play_view.dart:215 moving `MatchView` here leaves two public widgets in one file (`PuzzlePlayView` at :31, `MatchView` at :215, 363 lines), against guideline §3 "one public type per file" → give `MatchView` its own `src/` file in a follow-up (with `slot_paint.dart`'s marks, if that file becomes allowed), or record an exception in the brief.
- **should** packages/puzzle_game/lib/src/match_painter.dart:140 `characters` is forwarded on both boards here and at :189, but no test paints a split or phones-camera match with a non-default character (the new worker tests draw one board through `PuzzlePainter`) → add one worker test with a two-board split snapshot in both looks, asserting the chosen colour on each board.
- **could** packages/party_host/test/puzzle_screen_test.dart:177 the comment says "Robo, who never chooses, its next free number's", but the test only puts p1 and p2 in the room (`neutral(tester, fake, ['p1', 'p2'])`, no Robo) and asserts two entries → drop the Robo clause or assert Robo's entry.
- **could** packages/party_host/test/puzzle_screen_test.dart:174 the new TV test was added to an existing file although the job's rules ask for new tests in a NEW file; the brief's `allow:` does list that file → move it into its own host test file with the harness it uses, or record why it stays.

## Decisions to confirm

- `MatchView` in `play_view.dart` (report's decision 1): the size rule forced a move and `slot_paint.dart` was outside `allow:`, but the resulting two-public-types file needs your yes; the alternative is a follow-up job that moves `MatchView` to `match_view.dart`.
- `PuzzleView` left without `characters` (decision 4): the report's reason "drawn only by tests and pictures" is not right for pictures — the results photos capture the live `MatchView` boundary, and `PuzzleView` has no `lib/` caller at all (only `test/cat_paint_test.dart:109`); the decision itself is safe.
- `_charactersOf` (puzzle_module.dart:21) inserts a default for every roster entry, so the painter's missing-entry fallback (worker_painter.dart:83) is never exercised on the phone path; confirm that is what you want rather than leaving the map sparse.
- The bar moved to a new `score_row_bar.dart` instead of `score_row_parts.dart` (decision 2): both are in `allow:`; no action needed unless you want the parts file to keep every row part.
- The mirror's dots stay on player 2's colour (`mirror_painter.dart:128,214`, outside `allow:`): confirm the milestone accepts dots, not workers, as unidentifiable.

## Could not check

- `docs/briefs/m16/identity1/run-findings.md` does not exist, so there were no recorded "passes on the old code" entries to add to the findings.
- The runner's tests-first proof (run.log) covers the two new test files only; the new test in `puzzle_screen_test.dart` has no fail-on-old proof of its own.
- I ran the three touched test files, not the full `puzzle` and `host` suites, and ran nothing on a device or TV; `tools/review.sh` was not run.

## Commit message

m16 identity1 review: i1g2 workers and score bars

Found one must (the score bar's default test passes on the old code), two should
(the moved MatchView leaves two public widgets in play_view.dart; the split
MatchPainter path has no character test) and two could (a Robo claim in a test
comment; a new test in an existing file). Nothing was changed outside this
report; the job's allow: list, line counts and test results checked out.

## Status row

i1g2 reviewed: findings written (1 must, 2 should, 2 could); open: play_view.dart's two public widgets, a split-path character test, the score-bar default test, the Robo comment.

## Delete

- none
