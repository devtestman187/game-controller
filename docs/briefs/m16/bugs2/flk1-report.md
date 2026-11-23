# M16 bugs2 flk1: live_stats_unmarked_test waits for the settled state

## Summary

Changed one test file, `packages/party_host/test/live_stats_unmarked_test.dart`:

- `waitFor` default timeout raised from 5 s to 30 s. It only bounds a failure; a passing run returns as soon as the condition holds.
- The two `waitFor` calls (first for `uploader.uploaded` to be non-empty, then for `skippedSessions` to contain the unmarked id) are replaced by one `waitFor` on the finished pass: `stats.state.uploaded == 1 && stats.state.waiting == 0 && skippedSessions contains _unmarkedId`.
- No `expect` changed. No lib code, no fixed sleeps.

Diagnosis (driver's cause, read from `live_stats.dart` `uploadNow` and `_refreshCounts`): files are processed in listing order. If the unmarked file is skipped first, both old waits pass while the marked upload is still running. Its `prefs` write (`uploadedSessions`) and the final `_refreshCounts` come after, so the asserts can see `uploadedSessions` null, `waiting` 1, and stale `saved`/`uploaded`. The new wait holds until `_refreshCounts` at the end of the pass has run.

Checks:

- `tools/mine.sh`: RESULT ok, 1 file formatted, 1 package analyzed, 1 package tested (`OK 1 tests packages/party_host`).
- `flutter test packages/party_host/test/live_stats_unmarked_test.dart`, 5 separate runs: 5 of 5 pass ("All tests passed!", 1 test each run).

Values in the test's expectations (unchanged, computed from the fixtures in the file):

- uploaded ids: `[new-marked]`; the single upload's players: `[new-a]`.
- `uploadedSessions`: `[new-marked]`; `skippedSessions`: `[old-unmarked]`.
- `state.waiting` 0; `state.saved` 2; `state.uploaded` 1 after the pass.
- Files on disk: 2 (`old-unmarked`, `new-marked`).

Self-check (review-rules part A, test-only change, no UI):

1. Host setups: not affected; the test uses `HostType.windows` only. Test: the existing single test, unchanged.
2. Kept state: `startStats` sets up and `addTearDown` disposes and settles; unchanged. Test: the same test run 5 times.
3. Combinations with pause, away, "Get ready", drop, results, leaving: not in scope of this test; no lib change.
4. Stayed inside `allow:`: only the test file and this report.
5. No stop needed.
6. Look: no UI in this test.

## Hand-over

- Not reproduced under CPU load. The 5 runs were unloaded, so the fix is verified to pass but the load-dependent failure itself was not reproduced. The driver's load run is the proof of the fix under load.
- `tools/mine.sh` reported `churn: reverted 3 generated file(s)`. The three files are `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and `generated_plugins.cmake`, which were already modified in the git status at the start of this job. The script reverted them; I did not touch them. Whoever owns those changes should check they are back as expected.
- `tools/check.sh` was not run by me, as the brief says; the script runs `tools/check.sh format` after the job.

## Commit message — a draft

Make the unmarked-session test wait for the finished pass

The test waited for the first upload and for the unmarked skip, but
files are handled in listing order: when the unmarked file is skipped
first, both waits pass while the marked upload is still running, and
the asserts see a half-finished pass. Wait instead for uploaded == 1,
waiting == 0 and the unmarked id in skippedSessions, with a 30 s
bound on failure. No assertion changed.

## Status row

flk1 done: live_stats_unmarked_test waits for the finished pass (uploaded 1, waiting 0, unmarked skipped); 5 of 5 unloaded runs pass. Open: no load run yet to prove the flake is gone under CPU load.

## Delete

- none
