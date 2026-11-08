# M12 bug 1108e — G4 report: "Play again" after an "any puzzle" round now says "Next puzzle"

Done at G4 ("stop: after it"), the gate the brief names. A round started from "Any <level> puzzle"
(`PuzzleChoice.puzzleId == null`) now shows "Next puzzle" with `Icons.skip_next` and the key `nextPuzzle` on the results,
in a solo round and in a race; the press does what it already did — another puzzle of that level, avoiding this one. A
round of one chosen puzzle is untouched: "Play again" solo, "Rematch" in a race, the replay icon, `playAgain` and
`rematch`. The `Results: ...` log line says whichever label the button shows. No other file was touched.

## Files changed

- `packages/party_host/lib/src/ui/puzzle_screen.dart` (254 → 270 lines) — new `_AgainButton get _again`: the results'
  first button, chosen by `widget.choice.puzzleId == null` (Next puzzle) then by the race (Rematch) or not (Play again);
  `_rematch` logs `'Results: ${_again.label}'` and its doc comment says the press's effect; the `_Results` call passes
  `again: _again`; the screen's class doc and `_rematch`'s doc cover Next puzzle.
- `packages/party_host/lib/src/ui/puzzle_screen_widgets.dart` (183 → 181 lines) — the private record
  `typedef _AgainButton = ({String label, IconData icon, String key, FocusNode focusNode, VoidCallback onPressed})`;
  `_Results` takes `again` instead of `againFocus` + `onAgain` (5 parameters, was 6), drops its own `race` local, and
  `_ResultButtons` draws the first button from the record (`Key(again.key)`, `again.label`, `again.icon`,
  `again.focusNode`, `again.onPressed`); both doc comments say Rematch, Play again or Next puzzle.
- `packages/party_host/test/puzzle_results_test.dart` (259 → 324 lines) — `openAnyPuzzle` (Home → Play → Shape Race →
  "Any Easy puzzle", then P1 joins and starts, a race when asked); two new tests, "an any-puzzle round says Next puzzle,
  and pressing it opens another easy puzzle" and "an any-puzzle race says Next puzzle"; the three existing tests that
  work the first results button now pin their choice to the house puzzle ("the house puzzle, chosen") and the race test
  also expects the label "Rematch".
- `packages/party_host/test/puzzle_screen_test.dart` (220 → 223 lines) — "a finished puzzle shows the time; Play again
  starts another" pins its choice to the house puzzle and expects the label "Play again".
- `packages/party_host/test/round_log_test.dart` (131 → 149 lines) — new "an any-puzzle round leaving the results for the
  next puzzle goes in the host log": the results say "Next puzzle" and the log says `Results: Next puzzle`.
- `docs/briefs/m12/bug-1108e-fix-report.md` — this report.

## The results' first button, by round

| Round played | Label | Icon | Key | Test |
| --- | --- | --- | --- | --- |
| any easy puzzle, solo | `Next puzzle` | `Icons.skip_next` | `nextPuzzle` | 'an any-puzzle round says Next puzzle, and pressing it opens another easy puzzle' |
| any easy puzzle, race | `Next puzzle` | `Icons.skip_next` | `nextPuzzle` | 'an any-puzzle race says Next puzzle' |
| the chosen house puzzle, solo | `Play again` | `Icons.replay` | `playAgain` | 'a finished puzzle shows the time; Play again starts another' (label added) |
| the chosen house puzzle, race | `Rematch` | `Icons.replay` | `rematch` | 'a race shows the winner, and Rematch keeps the teams…' (label added) |

- The press is unchanged: `_rematch` replaces the screen with `PuzzleScreen(choice: widget.choice, …, avoidPuzzleId:
  _puzzle?.id)`, so an any-puzzle round picks from the level's other puzzles. Change teams, Back, their keys, the
  order of the three buttons and the focus (`_againFocus.requestFocus()` after the results open) are as before.
- The log's words come from the same `_again.label`, so the log can't drift from the button (m12 bug 1107e's line).

## Tests, each failing first

Captured by running the three new tests before the fix (the label decision forced back to the old one for one run):

| Test | Before the fix | After |
| --- | --- | --- |
| results 'an any-puzzle round says Next puzzle…' | **failed** — `Expected: exactly one matching candidate` / `Actual: _TextWidgetFinder:<Found 0 widgets with text "Next puzzle": []>` (the results showed "Play again") | passes |
| results 'an any-puzzle race says Next puzzle' | **failed** — the same, the race showed "Rematch" | passes |
| log 'an any-puzzle round leaving the results for the next puzzle…' | **failed** — the same `Found 0 widgets with text "Next puzzle"` at the check before the tap | passes |
| results 'a race shows the winner, and Rematch keeps the teams…' | passed (guard: a chosen race must keep Rematch) | passes |
| screen 'a finished puzzle shows the time; Play again starts another' | passed (guard: a chosen solo must keep Play again) | passes |

The chosen-puzzle case cannot fail before the fix — it is the part that must not change — so it is the two existing
tests' new `find.text('Play again')` / `find.text('Rematch')` assertions, not a duplicate third test (Question 3).

Values the expectations were computed from:

- Solo any puzzle: the round before the results reads its board from `PuzzlePlayView.puzzle.id` (one of the three easy
  puzzles: house, tree, rocket); after tapping `nextPuzzle` the new screen's `puzzle.id` is a different id, and
  `testPuzzles().byId(next)?.level == Level.easy`. The level has 3 puzzles, so after avoiding the one just played there
  are 2 candidates, and the screen's own `Random()` picks one — the test only asserts a different easy one.
- The log's line for the same round: `Results: Next puzzle`, then `Round started: puzzle, solo, 1 player` from the new
  screen (seen in the test run's host log).
- Race: `Left wins!` with the left board locked by hand, and the log shows `Round ended: Left wins! (0.1 s)`; the first
  button is `nextPuzzle` and focused.
- Focus: `focused(tester, 'nextPuzzle')` is true right after the results open, so a phone's A and the remote's OK press
  the button at once (the focus moves from `_againFocus`, unchanged).
- Keys: `HostButton(key: Key(again.key))` builds a `ValueKey<String>`, equal to the tests' `const Key('…')` as before.

## Test counts, before and after

`tools/check.sh format analyze host phone tv` on this machine; the "before" run was all green at the start of the job:

| Check | Before | After |
| --- | --- | --- |
| host (`party_host`) | 138 | **141** (two results tests, one log test) |
| phone (`controller_app`) | 382 | 382 |
| tv | PASS | PASS |
| format, analyze | PASS | PASS |

## Checks run

- `tools/check.sh format analyze host phone tv` — PASS, all five (format 2 s, analyze 8 s, host 141 in 15 s, phone 382 in
  28 s, tv 8 s).
- `tools/review.sh` — `review: 0 fail, 0 note`.
- `tools/review.sh --strings` — 1 removed, 3 added: the old `'Results: … Rematch : Play again'` expression is gone;
  `'Next puzzle'` and `'nextPuzzle'` are new at `puzzle_screen.dart:153`, and `'Results: ${_again.label}'` at line 163.
  The three tests' new texts are in test files, which the script skips.
- The first analyze after the fix failed with two `unintended_html_in_doc_comment` infos (the `<level>` in two doc
  comments); both are in backticks now and analyze is green.
- `git status` still lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and
  `generated_plugins.cmake` as modified: a line-ending change from a Flutter tool run, outside `allow:` and not edited
  by this job.

## Questions

1. **A level with one puzzle.** The button follows the choice alone, as the brief says, so a level holding a single
   puzzle would say "Next puzzle" while `_pick` falls back to that same puzzle (`others.isEmpty ? all`). Today only
   medium holds one puzzle (boat) and hard none, so it can't happen yet; M13 adds more puzzles. If you want it to say
   "Play again" then, the screen would need the library at results time.
2. **Log wording.** Any-puzzle rounds now log `Results: Next puzzle` where they logged `Results: Play again` (solo) or
   `Results: Rematch` (race). That is rule 3 read literally (the button's label); a reader of the Diagnostics screen
   will see the new line.
3. **The third case is a guard.** "A chosen puzzle still shows Play again solo and Rematch in a race" passes before the
   fix, so I put its checks on the two existing chosen-puzzle tests rather than writing a duplicate test. Say if you
   want a test of its own.
4. **One structural change beyond the brief.** `_Results` took `result, teams, total, againFocus, onAgain,
   onChangeTeams` (6 parameters, past the guideline's 5). The choice has to reach the button, so the button's data and
   press travel together as `_AgainButton` (label, icon, key, focus node, press), and `_Results` is back to 5 with
   `_ResultButtons` at 2. Behaviour, focus and order are unchanged.

## Self-check (review rules, part A)

1. **Every host setup.** TV/PC and both phone hosts draw the same `_Results` on the host's screen whatever the layout
   target, so the label change reaches all of them; the any-puzzle tests run on the default (screen) host and the race
   one on a two-phone host, with the button focused so the phone's A presses it (`focused(tester, 'nextPuzzle')`); a
   joined phone's menu labels are untouched — 'on the results the phone works the menu: left/right, A and B…' still
   passes with A "OK" and B "Back"; a build one older: no message, field or protocol change, so nothing to test.
2. **When kept state starts and ends.** Nothing new is kept: the label is computed each build from
   `choice.puzzleId` and the result, with no timer or cache. `_againFocus` is still made in the state and disposed in
   `dispose()` (the race test starts a second round after `pumpWidget(const SizedBox())` and the focus works again);
   with no round there are no results and no first button.
3. **How a new state combines with the others.** No state is added; the results overlay, its three buttons, their order
   and the focus are as before (both new tests check the first button focused and the old key gone). Pairs: results and
   the pause menu or the host away — `Pausable(enabled: result == null)` is unchanged and 'the results end it' still
   passes; results and a player away — the away card still blocks Back through `_leaveForGames` and 'on the results B on
   the phone goes to the game picker' passes; results and leaving — 'on the results the Back button goes to the game
   picker' passes.
4. **Stay in the job's folder.** Five files under `packages/party_host` (`lib/src/ui` and `test`) plus this report;
   nothing else written. The `tv_test_app/windows/flutter/generated_*` changes were there before the job and are not
   mine.
5. **Stop rather than overstep.** No file outside `allow:`; the brief and the code agree. The judgement calls are in
   Questions 1–4 and were not acted on beyond the brief.

## Commit message

Shape Race: say Next puzzle after an any-puzzle round

- The results' first button says "Next puzzle" (icon `skip_next`, key `nextPuzzle`) when the round's puzzle came
  from "Any <level> puzzle", in a solo round and a race; the press still picks another puzzle of the level
  (m12 bug 1108e).
- A round of one chosen puzzle is unchanged: "Play again" solo, "Rematch" in a race, the replay icon and today's
  keys; the other buttons, their order and the focus are as before.
- The "Results: ..." host log line says the button's label, from the same record the button draws.
- `_rematch` and `_ResultButtons` doc comments say the same; two results tests and one log test fail first, then
  pass.

## Status row

Bug 1108e fixed at G4: an any-puzzle round's results say "Next puzzle" (skip icon, `nextPuzzle`) solo and in a race and
the press still opens another puzzle of the level, a chosen puzzle keeps "Play again"/"Rematch" and their keys, the
"Results: ..." log line follows the label, and three new host tests (host 138 → 141) are green.

## Delete

- none

## Claude's answers

1. Fixed by Claude: the button says Next puzzle only when the level holds another puzzle (it reads the library), so
   "Any Medium puzzle" (boat only today) says Play again. Test: 'an any-puzzle round of a level with one puzzle says
   Play again'. Host tests 142.
2. Fine: the log line is the button's label.
3. Fine, no duplicate test.
4. Approved: `_AgainButton` keeps `_Results` at five parameters.
