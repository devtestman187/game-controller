# Review of wave 2 job f3a (board3a fix round, commit 7afeeca8)

## Summary

- Verdict: needs Claude
- Counts: must 0 · should 2 · could 2
- 1. The job added a new public type `Board` (board.dart:48). The brief's read list showed no board type, so the brief did not match the code; the worker went on instead of stopping.
- 2. No runner evidence that the new stub test fails on the old code: run.log has no tests-first result line for f3a (run.log:78-79).
- 3. The board tests fail on the old code only by a compile error (board_test.dart:82), so the duplicate-id rule itself has never been shown to fail.

## Findings

- **should** packages/party_host/lib/src/city/board.dart:48 The job added the public type `Board`, which the brief never named; the brief's read list (board.dart:1-30 and 78-90) showed no board type, and the worker went on instead of stopping (review-rules A5, coding-guidelines §11) → Claude confirms the `Board` shape in a later brief, or the change is removed and the id check goes where the brief expects.
- **should** docs/briefs/m17/board3a/run.log:78-79 The f3a tests-first phase ran for 7 s and logged no "fails on the old code" line (the g3a and g3s runs did log one), so the report's claim that the stub test "failed on the code as it was" has no runner evidence → rerun `packages/party_host/test/city/stubs_test.dart` against 02931544 and log the result (expected: fails with no ArgumentError thrown, a behaviour failure, not a compile error).
- **could** packages/party_host/test/city/board_test.dart:82 The new `Board` group fails on the old code only because `Board` does not exist, so none of the four `refuses` tests shows its own rule failing → after `Board` is confirmed, check that the three `refuses` tests fail with `Board` built without its id loop (expected: no ArgumentError).
- **could** packages/party_host/lib/src/city/stubs.dart:11-12 The `RoundPlacing.placeRound` doc says nothing about duplicate ids, so the rule that the stub now throws on is only written on the implementation → add one line to the interface doc saying that a repeated id throws `ArgumentError`.

## Decisions to confirm

- `Board` (board.dart:45-62): a new public type with a validating constructor. Why: the brief's test needs something to build, and no board type existed. Confirm the shape, or drop the type.
- `tools/mine.sh` was used for the checks, though the brief's step 5 said not to use it (the worker's Question 1). Why: both ran format, analyze and the touched tests. Confirm that the brief's note is wrong, or require the brief's commands.
- Tile-id uniqueness is enforced only when `Board` is built, while the `Tile` doc (board.dart:7) says "[id] is unique on the board" without saying so. Why: a `District` can still be used outside a `Board`. Confirm whether that is acceptable for now.

## Could not check

- I did not run `dart format`, `dart analyze` or `flutter test` (read-only job). The "OK 20 tests" result in f3a-report.md is not in run.log; the count matches the files (board_test 11 + 4 new, stubs_test 4 + 1 new = 20), but the run itself is unverified.
- The worker's own log (`flash-f3a.log`) is not in the folder, so the f3a check output could not be read.
- DRIVER-NOTES.md:3 says the first f3a run failed on `live_stats_answer_kept_test.dart` (pause/resume) and the second run passed; the cause of the first failure is not in the files I read.
- Whether `Board` is a design change that belongs in docs/architecture.md (coding-guidelines §10) could not be judged from the PRD, which I did not read.

## Commit message — a draft

Not applicable: this is a review; no commit is made by this job.

## Status row

Not applicable: this is a review; the STATUS row is the designer's to write.

## Delete

- none
