# Wave 4 review: r3h, r3h2, r3h3 (read-only)

## Summary

Verdict: **small fixes**
Counts: 3 must, 3 should, 4 could.

1. Line 132 of `present_pop_widgets.dart` is over 120 columns (a new line in this wave).
2. Two new tests pass on the base code or were never shown to fail there: the one-board golden test and the confetti dispose test. The fuse_skill checks have no base run either.
3. `_present.dispose()` in `puzzle_screen.dart` has no test, and removing it fails none.

## Findings

- **must** packages/party_host/lib/src/ui/present_pop_widgets.dart:132 The new `depth` line is 121+ columns, over the 120-column rule → wrap the expression (e.g. a local for `_confettiDepthLevels - 1`) so it fits 120.
- **must** packages/party_host/test/present_pop_widgets_test.dart:80 The confetti dispose test checks `PresentConfetti` code this wave did not change (its listener removal and dispose are outside the diff), so it likely passes on the base, and the r3h2 report records no base run → run it on the base and record the result, or have Claude accept it as an exempt pin test.
- **must** packages/puzzle_game/test/golden_slot_test.dart:75 The one-board test is new and passes on the base, which the r3h report says ("they pin behaviour that was already correct"); the rule makes that a must, though the brief asked for the case → Claude decides: keep it as a labelled pin test or drop it.
- **should** packages/puzzle_game/test/fuse_skill_test.dart:97 The two new simulation checks (`no snap raises…` at :97, `no present reaches…` at :104) have no base run; r3h3 records one only for the present_rules test → run both on the base and record the counts; if either passes there it is a must.
- **should** packages/puzzle_game/test/present_rules_test.dart:53 The new tests sit in existing files (also `present_pop_widgets_test.dart:67` and `golden_slot_test.dart:75`), but the guidelines say new tests go in a new file; the briefs' allow lists named the existing files → Claude decides: move them to a new file (widen allow) or confirm the exception.
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:182 `_present.dispose()` has no test: removing the line fails no test (r3h2 Q3 says the same) → add a test that the screen's dispose frees the tracker, or record it as a decision.
- **could** packages/puzzle_game/test/fuse_skill_test.dart:75 The `_breaksSnapRule` doc says a snap takes the fuse "no lower than the floor, unless already under the floor", but the code also forbids a snap from lowering an under-floor fuse (`afterMs < min(beforeMs, floor)`) → state that rule in the doc.
- **could** packages/puzzle_game/test/golden_slot_test.dart:24 `game.player(id)!` in `misplace` has no proof on the line before (the same applies at :27) → look the player up once, check it with `fail(...)` as the file does for slots, or pass the player in.
- **could** packages/puzzle_game/lib/src/golden_slot.dart:9 `GoldenInputs` has no dartdoc on its constructor (a public member) → add a one-line dartdoc.
- **could** packages/puzzle_game/lib/src/golden_slot.dart:68 A line in a touched file is over 120 columns but is not from this wave (it is in the diff's context) → rewrap it when next touched; no change needed in this job.

## Decisions to confirm

- r3h, `puzzle_points.dart:49`: a wrong re-snap pays 1 point, not the 2 the brief's item 3 gave; item 2 of the same brief says "normal points", which is 1. The worker chose 1 and flagged it. Confirm 1.
- r3h, `puzzle_points.dart:43`: a piece the cat knocked out counts as a try again (`wronged`), so it no longer claims the slot. This follows the owner's wording; confirm the cat case.
- r3h3, `present_rules.dart:77`: a fuse can now run below the floor between snaps (the run-down has no floor; only a snap is limited). Confirm this is intended (the worker's Q2).
- r3h3, `fuse_skill_test.dart:26`: the bat cap (50) is kept as a safety stop and is never reached; the doc now says so. Keep or remove.
- r3h2, `puzzle_screen.dart:84`: the Shuffle doc comment was reworded (it drops the `_showPuzzle` reference) to keep net growth 0, though the brief said to move a line out and the r3h2 stop rule says "no change to wording". Accept, or restore the comment and move another line.
- r3h2: the test count differs (`tools/mine.sh` 10, direct run 9); the report does not say which test is extra. Not a defect in the code; the number is unexplained.

## Could not check

- Whether the new fuse_skill checks and the confetti dispose test fail on the base code: no base run is recorded, and this job runs no tests (read-only).
- Whether `dart format` accepts line 132 as it is: the r3h2 report says format passed; I did not run it.
- `run-findings.md` has no entries for r3h, r3h2 or r3h3 (grep found none), so nothing there could be checked against.
- The menu and tv looks: no look was run; the held-line and confetti tests are read only.
- The match path and the cat path were judged from the code; the golden wrong-re-snap test was not run.

## Commit message — a draft

Review of wave 4 (r3h, r3h2, r3h3): findings only

Read-only review of the golden slot, host pop widget and fuse commits
against their briefs and the coding guidelines. Findings: one 121-column
line, one test that likely passes on the base, two new checks with no base
run, one untested dispose call. Decisions for Claude: a wrong re-snap pays 1,
cat knock-outs are try agains, a fuse may run under the floor between snaps.
This job changes no code.

## Status row

wave4 review: done (read-only): 3 must, 3 should, 3 could; open: the must fixes in r3h2 and r3h (line 132 length, two tests to run on the base) and the decisions above.

## Delete

- none
