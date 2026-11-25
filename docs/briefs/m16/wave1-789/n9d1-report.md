# n9d1 report: GameScreenShell extract

## Summary

- Moved the `build()` wrapper of `GameScreen` (RoundHold, ToyStillSky, PopScope, ControlsClaim, Focus, Scaffold with SafeArea) into the new public widget `GameScreenShell` in `game_screen_shell.dart`.
- `GameScreen.build()` now returns `GameScreenShell` with the same values: `canPop: _stage != _Stage.results`, `onPopInvoked: _leave`, the same `controls` expression, `focusNode: _screenFocus`, `onKeyEvent: _onKey`, `child: _stageBody(night)`.
- Behaviour is unchanged: the PopScope callback still calls `_leave(didPop)`, and the Focus and SafeArea nesting is the same.
- Removed the imports that the move left unused in `game_screen.dart` (`toy_look`, `controller_menus`) and added the `game_screen_shell.dart` import.
- Line counts: `game_screen.dart` was 379 lines and is now 363 lines. **The target of 355 or fewer is not met** (see Questions).
- `game_screen_shell.dart` is 64 lines.
- Tests-first: exempt, refactor. The existing tests stay unchanged.

Tests run:
- `tools/mine.sh`: format OK (2 files formatted), analyze OK (1 package), touched tests OK (1 test). Run once after the change, with no fix needed after it.
- `flutter test packages/party_host/test/arena_night_test.dart`: 8 tests, all passed (the file that reads `GameScreen`).

Self-check (docs/review-rules.md part A):
1. Host setups: the refactor does not change what each host shows; `arena_night_test.dart` covers the GameScreen flow (8 passed).
2. Kept state: none added. `_screenFocus` and the `_stage` state stay where they were in `GameScreen`.
3. Combination with the pause menu, away states, "Get ready", dropped link, results and leaving: the results still hold the pop (`canPop` false), `_leave` still runs from the shell's PopScope; covered by the same test file.
4. Writes only inside `allow:` (two lib files and this report).
5. No stop needed.
6. Looks: no look or layout values changed; the widget tree is the same, so the menu and TV looks are unchanged.

Decisions:
- `GameScreenShell` takes six inputs (`canPop`, `onPopInvoked`, `controls`, `focusNode`, `onKeyEvent`, `child`), as the brief lists. See Questions for the 5-parameter rule.
- The comments that explain the choices (results pop, menus versus game controls, arrow focus) stay at the call sites in `game_screen.dart`, where those decisions are made. The shell keeps a shorter comment about the frame.

## Hand-over

- `mine.sh` ran `churn: reverted 22 generated file(s)`. I did not look at what those were. They are outside my two allowed files, so please check the worktree status before committing.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

Extract GameScreenShell from GameScreen build

Move the build wrapper (RoundHold, ToyStillSky, PopScope, ControlsClaim,
Focus, Scaffold with SafeArea) into a public GameScreenShell widget so
game_screen.dart has room for later HUD work. Behaviour, strings, keys and
tests are unchanged; the existing arena night tests pass as they were.
game_screen.dart goes from 379 to 363 lines; the 355 target is still open.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 n9d1: GameScreenShell extracted from GameScreen build (behaviour-free; game_screen.dart 379 → 363 lines); open: the 355-line target and the 5-parameter limit on GameScreenShell.

## Questions

1. The line target is 355 or fewer, and `game_screen.dart` is at 363. Which further move should I make (for example, the `_leave` and `_next` night helpers, or the `_stageBody` switch), and may I touch a file outside `allow:` to do it?
2. `GameScreenShell` has six parameters, and the worker rule is at most five, with a value object beyond that. The natural value object (pop guard: `canPop` and `onPopInvoked`) would need a new file that is not in `allow:`. I kept the six the brief lists. Should I add the value object in a new file, or accept six?
3. `mine.sh` reported `churn: reverted 22 generated file(s)`. I don't know which files those were.

## Delete

- none
