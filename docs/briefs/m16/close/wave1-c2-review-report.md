## Summary

small fixes
Counts: must 0 · should 2 · could 1
1. c2-report.md has no check results, no review-rules part A self-check, no STATUS row and no files-to-delete list.
2. The worker wrote its report outside its folder (packages/party_host/docs), and no self-check line records it.
3. ShellBack's constructor (game_screen_shell.dart:10) has no dartdoc, against guidelines §10.
The behaviour move looks right: the one GameScreenShell( call site is the only user, and PopScope gets the same canPop and onPopInvoked values as before.

## Findings

- **should** docs/briefs/m16/close/c2-report.md:1 The report lacks the sections guidelines §11 require: check results (format, analyze, flutter test), the part A self-check lines, the STATUS row and the files-to-delete list → add them, with the results of the checks actually run.
- **should** docs/briefs/m16/close/c2-report.md:4 The worker's report went to packages/party_host/docs/…, outside the job's folder and allow: (review-rules A4), and no self-check line records the breach → add an A4 line naming the stray path and say it was discarded or moved.
- **could** packages/party_host/lib/src/ui/game_screen_shell.dart:10 `ShellBack`'s constructor has no dartdoc, while guidelines §10 asks for one on every public member → add a one-line dartdoc, or accept the gap as the same as `GameScreenShell`'s constructor and say so.

## Decisions to confirm

- The driver, not the worker, wrote c2-report.md and applied both lib files with tools/apply-job.sh, so the test claims come from the driver's run.log rather than the worker; confirm that is accepted for a refactor.
- No other decisions were made beyond the brief: `ShellBack` stays in game_screen_shell.dart and is not exported, as the brief asked.

## Could not check

- Test and analyzer results: I ran nothing (review is read-only); the only evidence is run.log, which is not in the repo, so the game_screen test results are unverified.
- The stray report under packages/party_host/docs: the path does not exist in this worktree, so its content and removal can't be confirmed.
- Whether arena_back_test.dart covers the results-to-picker Back path: I did not read the test bodies.
- run-findings.md has one line, about t1, not c2; there is no c2 entry about tests that pass on the old code.
