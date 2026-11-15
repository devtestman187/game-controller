# M14 bugs11 b020-next-map: review

Job: `docs/briefs/m14/bugs11/b020-next-map-review.md`. Read-only: this report is the only file I wrote.
Change reviewed: `f11c4b1..d187a5b`, one file (`docs/briefs/m14/bugs11/b020-next-map-report.md`, +248); the
job wrote no code and no test, so no suite was run. Code claims were checked against the tree at `d187a5b`
and its parent `f11c4b1` ("a night's one player keeps the Arena's card", which landed after the report was
written: `docs/briefs/m14/bugs11/run.log` shows both jobs started at `b8638dd` and the report committed
second).

## Summary

**Verdict: small fixes.** 0 must, 3 should, 1 could.
The brief is answered in full and every figure is right for `b8638dd`, the report's run base — but
`f11c4b1` removed 6 lines from `game_screen.dart` before this commit, so the size arithmetic and every
cite from `:106` on are stale (finding 1). The plan also misses the phone test whose press order changes
when the button sits second (finding 2), and the design line that names the results card's three buttons
(finding 3). The one could: the results body goes to ten constructor parameters while the report rejects a
split for exceeding five (finding 4).

## Findings

- **should** docs/briefs/m14/bugs11/b020-next-map-report.md:134 the sizes ("379 lines, cap 380", 387 and 376) and every `game_screen.dart` cite from `:106` on (`_debugKeys` :31-41, `playedMap` :203, `_mapFor` :215-222, `_again` :227-238, `_changeMode` :242-248, `_next` :279-289, `_leave` :294-299, `ArenaResults(` :362-369) are the `b8638dd` file, while at this commit the file is 373 lines (`_debugKeys` :30-40, `playedMap` :197-198, `_mapFor` :212-216, `_again` :221-232, `_changeMode` :236-242, `_next` :273-283, `_leave` :288-293, `ArenaResults(` :356-363) and `_alone` (:106-109) is gone → re-derive in the next brief: 373 lines, 381 with the button alone, 370 with the `_debugKeys` move (the split is still needed, by one line).
- **should** docs/briefs/m14/bugs11/b020-next-map-report.md:187 the test list gives `menu_press_test.dart` only the new `onNextMap:` argument, but with the button placed second (:69) that harness's `dpadRight` walk at `menu_press_test.dart:61-64` lands on Next map and its `['again', 'again', 'mode', 'mode']` expectation fails → list that expectation's change (to `map`) beside the placement, or place the button after Change mode.
- **should** docs/briefs/m14/bugs11/b020-next-map-report.md:225 the hand-over job has no doc step, while `docs/design/party-night.md:107` names the results card's "Play again / Change mode / Back, or \"Next\" in a night" and goes stale the moment the fourth button lands → add `docs/design/party-night.md:107` to the follow-up job, as b020-solo-card updated `party-night.md:192` in its own job.
- **could** docs/briefs/m14/bugs11/b020-next-map-report.md:145 the seam is rejected for needing nine constructor arguments when §3 allows five, but the chosen change gives a tenth to `_ResultsBody` (`arena_results.dart:136-146`, nine today) and the "~318 lines" estimate counts one parameter → say how the body's buttons take their callbacks (a small `_ResultsButtons` widget or a value object) and count the pass-through in the estimate.

## Decisions to confirm

- **A fourth button on the owner-approved results card**, and the words "Next map" beside Shape Race's "Next puzzle": question 1 is the whole of B-020's second half, so it needs the owner's yes before the job is briefed (the mock-up rule, `party-night.md:5`).
- **"Next" = Surprise me, not the library's order**: safe and cheap, but a child who has played three maps may expect the next one in order; the owner may want the Shape Race behaviour instead (`host_text.dart:128`).
- **The button second, before Change mode**: it changes the phone's Right press on the results (today Change mode) for every player count; a placement after Change mode keeps that press as it is.
- **A night keeps its one Next**: backed by `party-night.md:60`, but B-020's row also asks for the game type in a night, which this proposal leaves out — worth a yes/no to the owner.
- **`settings.mode` is the mode a Next map plays** (`_start`, `game_screen.dart:189`): true today because `setMode` is called only from `arena_waiting_card.dart:220`; confirm nothing else starts writing the mode.
- **Moving `_debugKeys` to `game_debug_overlay.dart`**: a code-organisation call that changes `game_screen.dart`'s import list; fine with me, but it is Claude's seam to approve.

## Could not check

- No suite was run and none can fail: the commit holds only a report, so the planned tests are unverified plans.
- `docs/briefs/m14/bugs11/run-findings.md` does not exist, so there are no runner findings about this job.
- The owner's visual fit for a fourth button: I did not open `docs/design/look-mockups/m14-*.png`.
- The exact line count `_nextMap` will take (6 to 8 lines with its doc): all three keep the file at 368-370 with the split and at 379-381 without it, so finding 1's conclusion does not depend on it.

## Commit message

M14 bugs11: review of the B-020 next-map proposal

Reviewed f11c4b1..d187a5b, a report with no code: the brief is answered
and every figure is right for b8638dd, but the file is 373 lines after
b020-solo-card, so the sizes and line cites need re-deriving (373, 381
without the split, 370 with it). Two more shoulds: the phone test whose
Right press moves to Next map, and the design doc line that still names
three buttons. One could: the results body's tenth parameter.

## Status row

M14 b020 (Next map): proposal reviewed — small fixes: re-derive `game_screen.dart`'s lines and sizes at HEAD (373 → 381 with the button alone, 370 with the `_debugKeys` move), add the `menu_press_test.dart:61-64` press-order change and `docs/design/party-night.md:107` to the follow-up job; open: those three, the owner's OK on a fourth results button and its words, then the job after b020-solo-card.

## Delete

- none
