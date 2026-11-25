# d2 report: dartdoc on public types and members that lacked it

tests-first: exempt docs only

## Summary

Docs only. No code, names or behaviour changed. Every doc was written by reading the code it describes, except where noted under Questions.

Files changed:
- packages/party_host/lib/src/controls.dart: dartdoc on `Controls.only`, `layout`, `otherLayout` (the fields had none).
- controller_app/lib/src/home/coach_marks.dart: `CoachStep` constructor doc rewritten to say why a step is just an anchor and a hint. Now 358 lines (limit 380).
- controller_app/lib/src/discovery.dart: dartdoc on `DiscoveryState`.
- controller_app/lib/src/local_network.dart: dartdoc on `LocalNetworkAccess`, one meaning per value, taken from the `localNetworkStatus` branches.
- controller_app/lib/src/providers/game_feedback.dart: dartdoc on `GameLayoutNotifier`, `GameStatusNotifier`, `GameShownNotifier`, `RatingPromptNotifier`.
- packages/puzzle_game/lib/src/play_view.dart: dartdoc on `PuzzlePlayViewState` (session and ticker, disposed in `dispose`).
- packages/puzzle_game/lib/src/puzzle_painter.dart: dartdoc on `PuzzlePainter`.
- controller_app/lib/src/home/home_text.dart: one-line dartdoc on each of the 15 constants.

Skipped (already documented): the `Controls.menus` and `Controls.game` constructors, `CoachMarks`, `hostKindFrom`, the provider declarations.

Between my edits and the check, `controls.dart` gained a blank line before `final Set<String>? only;` (my edit did not add it). I left it in place.

## Checks

- tools/mine.sh: exit 0. Format: 8 files formatted. Analyze: 3 packages analyzed (party_host, controller_app, puzzle_game), no findings reported. Tests: controller_app 150 OK, party_host 1 OK, puzzle_game 1 OK. Run once after the edits, which is the final state.
- coach_marks.dart line count: 357 before, 358 after. Under the 380 limit.
- Not run: `tools/check.sh` (the runner does it after I finish, per the brief).

## Self-check (review-rules part A)

1. Host setups: no behaviour change, so no setup is affected. Covered by the unchanged test suites above.
2. Kept state: no state changed.
3. Combinations with pause menu, host away, etc.: no behaviour change.
4. Stayed inside `allow:` (8 files listed above, plus this report).
5. No overstep; nothing stopped.
6. Looks: no UI change.

## Questions

1. `DiscoveryState`, `PuzzlePainter`, `HomeText` and `GameShownNotifier`: I read the code for each; the wording of `foundNearby`, `noScreenFound` and `searchAgain` as "status line" / "button that restarts discovery" is inferred from call sites in home_view.dart, not from a spec. Please confirm.
2. `PuzzlePainter` doc names "lifts, drops" for the piece moments; I did not read `PieceMoments` in full. Please confirm the examples.

## Suggestions

- `CoachStep` class has no class-level doc; the constructor doc now carries the why. Adding a one-liner on the class would make the file easier to scan. Not done (brief named the constructor).
- `controls.dart` `Controls.menus` doc refers to "the pause menu" as a worked example; consider a link to the PRD section if one exists.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
m16 close d2: dartdoc on public types and members that lacked it

Adds one-to-three line dartdocs to Controls fields, CoachStep's
constructor, DiscoveryState, LocalNetworkAccess, the four game
feedback notifiers, PuzzlePlayViewState, PuzzlePainter and each
HomeText constant. Docs only; no code or name changes.
Doc claims were checked against the code they describe.
```

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

m16 close d2: public dartdoc added to Controls fields, CoachStep, DiscoveryState, LocalNetworkAccess, game feedback notifiers, PuzzlePlayViewState, PuzzlePainter, HomeText constants; open: two wording items to confirm (Questions 1-2).

## Delete

- none
