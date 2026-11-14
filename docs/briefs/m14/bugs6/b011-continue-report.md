# b011-continue — blocked (report only)

Job: M14 bugs6 b011-continue (B-011). No code was changed: the brief's results-card design
contradicts three host test files that are not in `allow:`, and I may not edit them. The only
file written is this one.

## Summary

- **Planned and ready, not built:** the series (a specific pick starts it; it keeps the level's
  played ids in memory and the Shuffle toggle), Next puzzle in the library's order or a random
  unplayed one, the "You have played every `<level>` puzzle" prompt with Continue to the next
  level, the Wrap on the results card, and the new host texts. The plan is under
  *What I would have built* below, so a re-brief is a one-line change to `allow:`.
- **Why it stopped:** the design puts **Next puzzle first** on a chosen round's results, with a
  `Shuffle` switch beside it. Three test files that are not in `allow:` pin the card as it is
  today: after a **chosen** puzzle the first button is Play again/Rematch, it holds the focus,
  and the rows right of it are Change teams then Back. That is 5 pinned assertions in 3 files
  (`puzzle_results_test.dart`, `puzzle_screen_test.dart`, `host_focus_ring_test.dart`), and I
  ran them: 35 tests, all passing on the code as it is. A card built as designed fails at least
  those 5.
- **Numbers:** 6 puzzles a level (Easy house, rocket, tree, sun, fish, snowman; Medium boat,
  car, robot, train, castle, butterfly), so a series is 6 rounds before the prompt; the pinned
  assertions are `puzzle_results_test.dart:80,83,85,88,169,179,309`,
  `puzzle_screen_test.dart:71-80` and `host_focus_ring_test.dart:221-241`; `puzzle_screen.dart`
  is 367 of the 380-line limit, so the wiring would have stayed small and the logic gone to the
  new `puzzle_continue.dart`.
- **Decisions:** stop rather than ship a card the tests forbid; do not reorder the card to keep
  the old tests green (that is a workaround of a design problem, guidelines §2 and §11); do not
  deliver half the feature (the pure series with no way to reach it is dead code).
- **Owner on a device:** nothing to try yet; nothing changed.
- **Questions:** see *Questions* (1 and 2 block the job; 3 and 4 are for the build).

## Why it cannot land as written (Blocked)

The design (brief item 2) is: "The results card after a series round gets: Next puzzle, a
Shuffle toggle …, Play again, Change teams, Back", with the Wrap. A series round is exactly a
round the player picked a puzzle for, which is the round these tests build:

| file:line | what it asserts today | what the design does to it |
| --- | --- | --- |
| `puzzle_results_test.dart:80` | after a chosen house round the focus is on `playAgain` | the focus goes to `nextPuzzle` |
| `puzzle_results_test.dart:83,85,88` | right → `changeTeams`, right → `resultsBack`, left ×2 → `playAgain` | a `Shuffle` switch and Next puzzle sit in that row |
| `puzzle_results_test.dart:169,179` | up/down/right/left pushes always leave the focus on one of Play again, Change teams, Back; two lefts bring it back to Play again | any focusable above or beside the row (the switch, a wrapped button) can catch a push |
| `puzzle_results_test.dart:309` | a chosen **race** has `rematch` focused | the focus goes to `nextPuzzle` |
| `puzzle_screen_test.dart:71-80` | after a chosen round "Play again has the focus" (the remote's OK works at once) | the focus goes to Next puzzle |
| `host_focus_ring_test.dart:221-241` | a race from the chosen house puzzle: "Play again is ringed", then right reaches `changeTeams` then `resultsBack` | the first ringed button is Next puzzle |

`puzzle_screen_test.dart`, `puzzle_results_test.dart` and `host_focus_ring_test.dart` are not in
`allow:`, and the brief allows only `puzzle_continue_test.dart` and `host_text_test.dart`.
Weakening or editing them is a rejected diff (guidelines §2, "Weakened checks"), so the job stops
here.

The smallest honest unblock: add those three files to `allow:` (their focus expectations then
move to `nextPuzzle`/the Continue button, and the row order becomes the design's). The other
test files that name the buttons (`night_round_test.dart`, `round_log_test.dart`,
`lobby_music_test.dart`, `pause_menu_test.dart`, `round_music_test.dart`, `countdown_test.dart`)
only tap or count them and would still pass, since Play again, Change teams and Back stay on the
card.

A compromise card (Play again first and focused, Next puzzle and the switch after Back) keeps
every old test green, but it contradicts design item 2, puts the owner's new flow behind Back in
the remote's order, and is a workaround of a design problem. I did not build it.

## What I would have built (the plan I stopped at)

1. `puzzle_continue.dart`, a plain sibling library (not a `part`, per project-notes *Left for
   later*): an immutable `PuzzleSeries` — `level`, the played ids, `isShuffled` — with
   `start(level:, firstId:)`, `withPlayed(id)`, `withShuffled(on)`,
   `nextId(ids:, current:, random:)` (first unplayed id after `current` in list order, wrapping,
   or a random unplayed one when shuffled; null when the level is done) and
   `levelAfter(library, level)` (the next `Level.values` entry that has puzzles; null on the
   last). B-009's `PuzzleBag` needs no change: a series round is a chosen id, so the bag's own
   `played` call already keeps `any <level>` off it.
2. `PuzzleScreen`: an optional `series`; a specific `choice.puzzleId` starts one, `_showPuzzle`
   (and the test-injected match) records the round's id, Play again replays with the same series,
   Next/Continue build the next screen with the series and the id, Change teams restarts it (the
   join screen rebuilds the round from the original choice).
3. The results card: a `Wrap`; Next puzzle (or the prompt's "Continue to `<level>`" and the
   "You have played every `<level>` puzzle" line), the Shuffle switch, Play again, Change teams,
   Back; a night keeps its single Next.
4. `host_text.dart`: `shuffle`, `playedEvery(levelName)`, `continueTo(levelName)`.
5. `puzzle_continue_test.dart` (pure series rules plus the card on a phone-sized host) and the
   new rows in `host_text_test.dart`.

## Decisions (low-usage mode)

- **Stop, do not guess the card's order.** The chosen order is the owner's visible change; two
  answers (Next first, or Play again first) both work in code and I cannot pick for the owner.
- **Do not edit the three test files.** They are outside `allow:` and are the specification of
  today's card (guidelines §2 "Weakened checks", §11).
- **Do not ship the pure half.** A `PuzzleSeries` with no screen reaching it is dead code and a
  rejected diff ("No leftovers").
- **No `PuzzleBag` change.** The series' played ids are its own in-memory set, as the brief says;
  the bag already keeps `any <level>` off a hand-picked id.

## Blocked

- Needs three files in `allow:`: `packages/party_host/test/puzzle_results_test.dart`,
  `packages/party_host/test/puzzle_screen_test.dart`,
  `packages/party_host/test/host_focus_ring_test.dart` — or an owner decision that the series
  card keeps Play again first and the new buttons after Back (which I would then build as
  written, with a note that it differs from item 2).

## Checks

- `flutter test test/puzzle_results_test.dart test/puzzle_screen_test.dart
  test/host_focus_ring_test.dart` (in `packages/party_host`) — PASS, 35 tests, on the unchanged
  code: the assertions in the table above hold today.
- `dart format --output=none --set-exit-if-changed .` (in `packages/party_host`) — PASS,
  186 files, 0 changed.
- `dart analyze --fatal-infos .` (in `packages/party_host`) — PASS, no issues.
- `tools/check.sh format analyze host` was not run as one command (the shell refused the whole
  invocation); `host`'s full suite was not run because no code changed.

## Self-check (review-rules part A)

1. **Every host setup:** no code changed, so nothing differs; not run.
2. **When kept state starts and ends:** the series would start at a specific pick, end at Back
   or a new pick, and hold nothing while no round runs; not built, so not run.
3. **How a new state combines:** the series never pauses, hides or waits; only the results
   buttons change, and a night's card keeps its single Next (brief item 8); not built, not run.
4. **This folder only:** yes. The only write is this report; `git status` shows no change to any
   allowed file.
5. **Stop rather than overstep:** this report; the blocker is named with file:line and the fix.

## Commit message

M14 bugs6 b011: blocked — the series card contradicts three pinned tests

Report only, no code. B-011's design puts Next puzzle first on a chosen round's
results, with a Shuffle switch beside it. Three test files outside this job's
allow list pin that card as it is: after a chosen puzzle Play again/Rematch
takes the focus and Change teams, Back follow it (puzzle_results_test.dart:80-88,
:169-179, :309, puzzle_screen_test.dart:71-80, host_focus_ring_test.dart:221-241),
and all 35 of those tests pass on the unchanged code. The plan that is ready to
build, the assertions, and the two ways to unblock are in
docs/briefs/m14/bugs6/b011-continue-report.md.

## Status row

B-011 (Shape Race series: Next puzzle, a Shuffle toggle and the level-done prompt) is blocked before any code: its results card (Next puzzle first, a Shuffle switch) breaks five focus/layout assertions in three host test files that the brief does not allow editing (puzzle_results_test.dart, puzzle_screen_test.dart, host_focus_ring_test.dart — 35 tests pass on the unchanged code). Open: those three files in `allow:` (or the owner's OK for Play again first and the new buttons after Back), then the job, whose plan is written up in the report.

## Delete

- none
