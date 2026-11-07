# M12 step 3b — G4 report: Shape Race on a PuzzleSession

**Status: stopped at G4 — one `host` test can't pass without a change in `party_host`, which this job may not make.**
Shape Race runs on a `PuzzleSession`, the module and viewer are in, and 10 of the 11 checks pass (`format analyze
protocol connection metrics kit arena puzzle phone tv`); `puzzle` went 62 → 78 tests. `host` fails one of its 44:
`puzzle_results_test.dart:131` "on the results B on the phone goes back" (43 pass). A 1/60 s step makes the match
finish one drawn frame later than the old per-frame `update`, so the menus' first poll (16 ms later) sees the phone's
B already held and swallows it — by design ("a button already held when the menus come back has to be let go and
pressed again"). The fix is one extra `await tester.pump(const Duration(milliseconds: 16));` in that test, outside the
allow list (Q1). Nothing in `puzzle_game` can move the finish back a frame without overriding `GameSession.advance` or
the rules' `update` cadence, which contract §3 forbids.

## Files changed (line counts; **>300 flagged**, tests 500)

| File | Lines | Why |
| --- | --- | --- |
| `packages/puzzle_game/pubspec.yaml` | 32 | `game_kit: path: ../game_kit` (2 lines, alphabetical) |
| `packages/puzzle_game/lib/puzzle_game.dart` | 19 | exports `src/puzzle_module.dart` and `src/puzzle_session.dart` |
| `packages/puzzle_game/lib/src/play_view.dart` | 116 (was 340) | thin view: Ticker → `session.advance`, `setState`, post-frame `drawn`, `MatchView(session.current)`; dispose ends the view `finished` when the match ran to its end, else `quit` |
| `packages/puzzle_game/lib/src/puzzle_session.dart` | 161 | `PuzzleSession` (Q: follows `ArenaSession`), `puzzleGameName`, `puzzleLayout`, `puzzleWatchLayout` moved in |
| `packages/puzzle_game/lib/src/puzzle_events.dart` | 68 | `PuzzleEffects.apply`: the old `_onEvent` with its `_onSide`/`_haptic`/`_record` helpers |
| `packages/puzzle_game/lib/src/puzzle_report.dart` | 76 | `PuzzleReport.write`: the old `_report` (per-player metrics, winners, `round_end`, `frames`) |
| `packages/puzzle_game/lib/src/puzzle_status.dart` | 39 | `puzzleStatusFor`: the old `_statusFor`, unchanged in behaviour |
| `packages/puzzle_game/lib/src/puzzle_module.dart` | 112 | `shapeRaceSetup`, `shapeRaceModule` (id `shape_race`, `MatchSnapshot.version`), `ShapeRaceViewer`, `_LoadedPuzzle` (Q1) |
| `packages/puzzle_game/lib/src/snapshot.dart` | 254 (was 189) | `MatchSnapshot`/`PuzzleSnapshot` `implements GameSnapshot` with `toJson`, and `lerpTo` on both (+ `_lerpAngleDeg`); JSON unchanged |
| `packages/puzzle_game/test/snapshot_lerp_test.dart` | 127 | 7 tests (plan §5 + the Q8 pin) |
| `packages/puzzle_game/test/puzzle_session_test.dart` | 173 | 5 tests: report once, `view_start` setup, panels, watcher, `finished` vs `quit` |
| `packages/puzzle_game/test/puzzle_module_test.dart` | 90 | 3 tests: id/version/decode, setup type errors, load then draw |
| `packages/puzzle_game/test/frame_size_test.dart` | 53 | 1 test: a real 4-player split boat frame, prints its size |
| `packages/puzzle_game/test/view_test.dart` | 275 (was 269) | `pumpPlay` and `press` get one extra 16 ms pump each (see below); no expected value changed |
| `docs/briefs/m12/s3b-g4-report.md` | this file | the report |
| `pubspec.lock` | unchanged | `game_kit` is a path dependency, so no third-party change |

No file is over 300 (the longest is `snapshot.dart` at 254; the longest test is `view_test.dart` at 275). `game.dart`,
`view.dart`, `match.dart`, the rules and every snapshot's JSON are untouched.

## Shape Race on the session

`PuzzleSession` (contract §3, following `ArenaSession`):

- The public constructor takes `host`, `puzzle`, `teams`, `random`, `playtest` and an optional `match`, builds the
  match when none is passed and redirects to `PuzzleSession._`, which calls `super(module: shapeRaceModule,
  setup: shapeRaceSetup(match))`. The body records `round_start` (`puzzle`, `level`, `format`, `players`).
- `current`/`snapshot()` are the match's `MatchSnapshot`. `resumed()` clears the layout set, so the phones get the
  puzzle's buttons back after the pause menu, exactly as `didUpdateWidget` used to.
- `step(dt)` reads the playtest settings, gives every player the puzzle (or watch) layout once while the match runs,
  runs `match.update(dt, input(id), numbers:)` with the latched inputs, applies each event through `PuzzleEffects`,
  writes the report once (`_reported`) and calls `onFinished`, then sets every player's status panel.
- `dispose({finished})` hides the panels it showed and ends the view once. The view passes `finished:
  match.result != null`, so it *can* tell: the brief's alternative ("ends with `quit` and say so") wasn't needed.

`ShapeRaceViewer` decodes `MatchSnapshot` and draws `MatchView` from `setup['timeLimitS']` (Q2) and the puzzle found by
ID; `createViewer` checks every setup key with one generic `_field<T>` and names the key in the `FormatException`.
`_LoadedPuzzle` shares one `PuzzleLibrary.load()` future (`_puzzleLoad ??= …`), draws `SizedBox.shrink` until it
resolves and "Update the app to see this game" for an unknown ID (Q1).

`PuzzleSnapshot.lerpTo` lerps piece and dot positions and the piece angle the shortest way round
(`(to - from + 540) % 360 - 180`), takes every other field from `this`, pairs pieces and players by index and only
draws what `this` drew; `MatchSnapshot.lerpTo` does the same board by board (the seed and the pile order come from
`this`).

## Existing tests that had to change (brief item 5)

| Test | Old | New | Why |
| --- | --- | --- | --- |
| `view_test.dart` `pumpPlay` | one 16 ms pump | two 16 ms pumps | a step is 1/60 s = 16.67 ms, so the first 16 ms frame runs **no** step and the layout/status assertions after `pumpPlay` read nothing |
| `view_test.dart` `press` | two 16 ms pumps | three 16 ms pumps | the session latches a press until a step has seen the button up; with two frames the latched release still left the rules' `_aDown` set, so the next press's edge was swallowed (the "wrong drop" never happened) |

**No expected value changed:** the snapped/picked sounds, `dropReady`/`snap`/`wrong` order, `snaps 4`, `placed 4`,
`win 1`, `Done!`, the hidden panel on leave and the timer text are all the values the tests had before.

## Computed values (as the tests assert them)

| What | Value | Pinned by |
| --- | --- | --- |
| A 4-player split boat frame (2 boards × 6 pieces, all 4 holding) on the wire | **596 bytes** (< 2500) | `frame_size_test` prints it |
| 350° → 10° at t = 0.5 | 0° | `snapshot_lerp_test` |
| x 10 → 30 at t = 0.5 | 20 | `snapshot_lerp_test` |
| `view_start.setup` | `{puzzle: house, level: easy, timeLimitS: 120, teams: {p1: left, p2: left}}` | `puzzle_session_test` |
| The report | 1 `round_start`, 2 `player_result`, 1 `round_end`, 1 `frames`, one `success` sound, 100 more advances change nothing | `puzzle_session_test` |
| Status after 2 s of a 120 s match | `1:5x left` | `puzzle_session_test` |
| Session `statuses` on dispose | every one hidden, one `view_end` (`quit`), a second dispose is a no-op | `puzzle_session_test` |

## Checks

| Check | Before (G3 report) | After |
| --- | --- | --- |
| format | PASS | PASS |
| analyze | PASS | PASS |
| protocol | 102 | 102 (untouched) |
| connection | 223 | 223 (untouched) |
| metrics | 38 | 38 (untouched) |
| kit | 14 | **16** (no `game_kit` file changed; see Q5) |
| arena | 39 | 39 (untouched) |
| puzzle | 62 | **78** (7 lerp + 5 session + 3 module + 1 frame size) |
| host | 44 | **43 + 1 FAIL** (`puzzle_results_test.dart:131`, Q1) |
| phone | 262 | 262 (untouched) |
| tv | 22 | 22 (untouched) |

`tools/review.sh`: **0 fail, 7 note**. The notes are the moved code's style: the three haptic/tick/success literals
(`0.7`, `0.6`, `10`, `10`) and `360` in `_lerpAngleDeg` (moved magic numbers, unchanged), and two "function over 40
lines" notes on blocks of constants (`puzzleLayout`+`puzzleWatchLayout` counted as one 56-line block,
`PuzzleReport.write` at 50). No FAIL on a line of this job.

## What did not hold from plan §6 (R1–R8) and §5

- **R1** ("a release still has to reach a step before the next press, which holds in every test") — it does not hold
  for `view_test`'s `press`: with two 16 ms frames the latched release kept the rules' edge detector set and the next
  press was lost. Fixed by a third frame in the helper (above), as the plan intended the latch to cover.
- **§5 `puzzle_results_test.dart:14,75,131,162` "none"** — it does not hold: line 131's B press now lands on the
  menus' first poll (Q1). The other three tests in that file pass.
- **§5 `view_test.dart:187` "2/press"** — it does not hold for the *first* assertions: after one 16 ms pump no step
  has run, so `pumpPlay` needs a second.
- R2, R3, R5, R6, R7, R8 held: sounds are deduped per advance, the report fires once, the clock integrates `dt` and
  stops at the result, the keyboard player is untouched, 63 paused pumps move nothing, and frames before `startView`
  aren't sent (`puzzle_session_test` covers the first four).
- **R4** (rematch/change teams) is the same shape as before (the old view is disposed, so its session ends `quit` and
  the new screen starts one), but the file that proves it is the one failing at line 131; the other three tests in it
  pass.

## Questions and suggestions

1. **Blocker: `party_host/test/puzzle_results_test.dart:131` needs one more pump.** After `expect(find.text('Done!'))`
   add `await tester.pump(const Duration(milliseconds: 16));` before the B press: that tick activates the menus with
   the button up, and the B after it is a new press, so the screen pops. I may not change `party_host`; the fix is
   `party_host`'s to make. (Measured: the old per-frame `update` finished at the 516 ms tick, the fixed-step session at
   532 ms, and the menus' 16 ms poll runs just before the frame.)
2. **`frame.toJson()` doesn't exist** (`Message` has `toPayload()`; the codec adds `v`/`t`). The frame-size test
   measures `const MessageCodec().encode(frame)` in UTF-8 — the actual wire text — and prints that size (596 bytes).
   Say if you want the payload alone instead.
3. **Q1 in tests:** one `Future` made in one `testWidgets`' fake clock never resolves in the next test's clock, so the
   module test draws the known and the unknown puzzle in one test. Nothing changes in an app (one clock, one zone);
   worth remembering when `s3c` tests `FrameView`.
4. **`Goal!`-style styling of the status:** unchanged from before; `puzzleStatusFor` returns the same strings.
5. **`kit` counts 16 tests, not the 14 the G3 report quotes** (11 session + 3 registry = 14). No `game_kit` file is
   modified in `git status`, so the mismatch predates this job; the other counts match G3.
6. **`tv_test_app/windows/flutter/generated_plugin*`** show as modified with an empty `git diff` (line endings only);
   `s3b-g1-report.md` and `s3b-g3-report.md` record them dirty before this job. I touched none.
7. **Suggestion:** when `s3c` adds `FrameView`, give it a test that a phone drawing a finished match says "Done!" and
   stops asking for frames — the session already publishes `view_end(finished)` and `dispose` is tested here.

## Commit message

```
Run Shape Race on a PuzzleSession

- PuzzleSession (following ArenaSession) steps PuzzleMatch, gives the phones
  the puzzle's buttons and panels, plays its events, reports once and ends
  the view; play_view shrinks to a Ticker that draws session.current.
- The session's effects, report and status move out of the view into
  puzzle_events.dart, puzzle_report.dart and puzzle_status.dart.
- shapeRaceModule plus ShapeRaceViewer: one cached puzzle load, an unknown
  puzzle says to update the app, setup keys are checked and named.
- Both snapshots implement GameSnapshot and lerpTo (angle shortest way
  round); 16 new tests, no expected value changed.
```

## Status row

| 3 Sessions, frames, playout, stages | s3b G4: Shape Race runs on `PuzzleSession` (`packages/puzzle_game/lib/src/puzzle_session.dart`, with `puzzle_events.dart`, `puzzle_report.dart`, `puzzle_status.dart`, `puzzle_module.dart`; thin `play_view.dart` 340 → 116; `MatchSnapshot`/`PuzzleSnapshot` `lerpTo`; 78 puzzle tests). 10 of 11 checks pass; `host` fails its "on the results B" test because a fixed 1/60 s step finishes the match one drawn frame later than the old per-frame update, so the menus' first poll swallows the test's B press — needs one extra `pump(16)` in `party_host/test/puzzle_results_test.dart` (out of this job's scope). Next: fix that pump, then s3c (FrameView and the phone app) |

## Delete

- none
