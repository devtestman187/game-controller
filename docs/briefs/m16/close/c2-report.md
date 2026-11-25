## Summary

c2: ShellBack value object (canPop, onPopInvoked) added in game_screen_shell.dart; GameScreenShell now takes back, controls, focusNode, onKeyEvent, child. game_screen.dart builds it at the call (362 lines).
The worker wrote its own report to a wrong path (packages/party_host/docs/...), so the runner stopped with result 4; the driver applied the two lib files with tools/apply-job.sh (HAND-FIX c2, class: brief/environment: worker cwd) and wrote this report. Driver ran review.sh and game_screen tests (see run.log).

## Commit message

m16 close c2: ShellBack value object for GameScreenShell
