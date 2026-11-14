# b011-continue review

## Summary

Verdict: **small fixes**. must 0 · should 2 · could 4. The stop itself holds: review-rules A5 and guidelines §11 both say to stop when a needed file is outside `allow:`, and the three test files that pin the chosen round's card are outside it.
1. The report has no `## Questions`, though its Summary (line 31) says "1 and 2 block the job": the two questions Claude would act on are not written down anywhere.
2. The blocker rests on an unstated assumption: the results' first button holds the focus (puzzle_screen_widgets.dart:35-36), not on the brief, which fixes only the card's order. A card with Next puzzle and the Shuffle switch before Play again, focus left on Play again, may leave the three files green.
3. The plan (line 74) starts a series on a chosen round inside a party night too, though the design says outside a night only, and a night's card can never advance it.
Checks I ran: the three named test files 35/35 pass (so the report's 35 is right); `dart format --output=none --set-exit-if-changed .` in `packages/party_host` 0 changed, 188 files (the report's 186 plus b002's two new Dart files). No device, no code change.

## Findings

- **should** `docs/briefs/m14/bugs6/b011-continue-report.md:19` "A card built as designed fails at least those 5" is true only because the results' first button holds `_againFocus` (puzzle_screen.dart:87, puzzle_screen_widgets.dart:35-36), which the brief never says, so a card keeping the design's order and the focus on Play again may break none of the pinned assertions (80, 309, puzzle_screen_test.dart:75-76, host_focus_ring_test.dart:229-233 all pass) → name that assumption as the blocker, and say whether the focus may stay on Play again, since that variant needs no `allow:` change.
- **should** `docs/briefs/m14/bugs6/b011-continue-report.md:31` the Summary points to a "*Questions* (1 and 2 block the job; 3 and 4 are for the build)" section that the report does not contain, and the brief lists questions as a required part of the report → add the four questions as a `## Questions` section, or state the two blocking ones in the Summary itself.
- **could** `docs/briefs/m14/bugs6/b011-continue-report.md:74` the plan starts a series on any specific `choice.puzzleId`, and a night's round reaches the same picker with a chosen id (games_screen.dart:145-156, games_screen_widgets.dart:181-187), so a night would hold a series its single Next can never advance, against the design's "outside a night only" (brief line 8) → gate the series on no night running and say so in the plan.
- **could** `docs/briefs/m14/bugs6/b011-continue-report.md:17` "5 pinned assertions in 3 files" does not match the report's own list at line 23 (seven line numbers in `puzzle_results_test.dart` plus two ranges, about ten assertion sites) → give the count the list supports.
- **could** `docs/briefs/m14/bugs6/b011-continue-report.md:75` the plan makes two series-lifecycle choices the Decisions (lines 85-94) do not list: Play again keeps the series, and Change teams at :76-77 restarts it from the original pick, though the brief asks for every decision with one line of why → add both.
- **could** `docs/briefs/m14/bugs6/b011-continue-report.md:121` self-check item 3 cites "brief item 8" for the night's single Next, and the brief has four numbered design items and no item 8 → cite the brief's design line 8 ("outside a night only; a night keeps its single Next") instead.

## Decisions to confirm

- Whether Next puzzle must hold the results' focus (finding 1): if it must not, B-011 can land inside today's `allow:` with the design's card order and no test edits; if it must, the three test files have to move, as the report says.
- Whether a chosen round inside a party night starts a series at all (finding 3): the design says outside a night only; the plan's trigger does not check.
- Change teams' effect on the series (finding 5): the plan restarts it, so the played set is lost on a team change; the owner may expect the series to survive.
- The two unblock routes the report offers (three files in `allow:` or an owner OK for a different card) are Claude's to pick, and the report's own compromise ("Play again first and focused, the new buttons after Back") is the one variant it says keeps the old tests green; finding 1 is the cheaper one, since it keeps the design's order.

## Could not check

- Whether the focus-on-Play-again card really keeps the three files green: it was not built, and the design's `Wrap` may split the row on a phone-sized host and change up/down traversal (`puzzle_results_test.dart:163-179`), so no measurement exists.
- The whole `host` suite: neither the job nor this review ran it; I ran the three named test files and `dart format`, not `dart analyze`.
- The report's claim that it read `docs/briefs/m14/bugs5/pr-map-pick-report.md`: nothing in the diff shows it either way.

## Commit message

Review b011-continue: the stop holds, the report needs its questions

Read the b011-continue commit (a report only) against its brief, the guidelines and
review-rules A and B. The stop is right: the chosen round's results card and the
focus it holds are pinned by puzzle_results_test, puzzle_screen_test and
host_focus_ring_test, none of them in `allow:`, and all 35 of their tests pass.
Two shoulds: the report has no Questions section though its Summary points to one,
and the blocker rests on the first button's focus, which the brief never fixes.
Four coulds: the plan starts a series in a night, the pinned-assertion count, two
unlisted series choices, and a "brief item 8" that does not exist.

## Status row

B-011 review (bugs6 b011-continue-review) is done: verdict small fixes, no must; the job's stop stands (the chosen-round results card is pinned by three test files outside `allow:`, 35/35 pass). Open: Claude's call on whether Next must hold the results' focus (which would unblock the job inside today's `allow:`), the report's missing Questions section and its other small fixes, then the job itself.

## Delete

- none
