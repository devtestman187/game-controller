## Summary

c2: ShellBack value object (canPop, onPopInvoked) added in game_screen_shell.dart; GameScreenShell now takes back, controls, focusNode, onKeyEvent, child. game_screen.dart builds it at the call (362 lines).
The worker wrote its own report to a wrong path (packages/party_host/docs/...), so the runner stopped with result 4; the driver applied the two lib files with tools/apply-job.sh (HAND-FIX c2, class: brief/environment: worker cwd) and wrote this report. Driver ran review.sh and game_screen tests (see run.log).


## Checks (driver, Nov 25)
- dart analyze on both lib files: No issues found. flutter test game_screen_test.dart and arena_back_test.dart: All tests passed. tools/review.sh: 0 fail, 2 notes (game_screen.dart 362 lines; _stageBody 42 lines, both pre-existing).

## Self-check (part A)
- A4: the worker wrote its report to packages/party_host/docs/briefs/m16/close/c2-report.md, outside its folder; that stray file stays in the kept worktree and was never applied (apply-job.sh took only the two allowed lib files).
- Status row: none (refactor). Files to delete: none.

## Commit message

m16 close c2: ShellBack value object for GameScreenShell
