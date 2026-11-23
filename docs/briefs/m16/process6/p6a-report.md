# p6a report: the combined check skips the tools suite when no tool changed; STOP.md names the failing suite

STATUS: stopped. The code is done and the new test passes, but `tools/run-steps.sh` is now 261 lines and the existing size gate in `tools/tests/run-jobs-split-test.sh` requires under 250. That is a decision for the owner (see Questions 1).

## Summary

- `tools/check.sh`: `CHECK_SKIP` (names separated by a space or a comma) prints `SKIPPED <name> (CHECK_SKIP)` for each named check, runs nothing of it, and is not a failure. An unknown name exits 2 with `Unknown check in CHECK_SKIP: <name>`. The `interesting` filter now keeps `^ *FAIL[ :]` lines, so a failed selftest prints its script and case lines. The header documents both.
- `tools/run-steps.sh`: new `check_scope`, called in `checks()` after `unchurn`. It sets `RUN_CHECK_SKIP=tools` and logs `combined check: the tools suite is skipped (no job changed a file under tools/)` when `git status --porcelain -- tools` is empty; otherwise `RUN_CHECK_SKIP=""` and logs `combined check: the tools suite runs (a job changed a file under tools/)`. `check_once` passes `CHECK_SKIP="${RUN_CHECK_SKIP:-}"`.
- `tools/run-stop.sh`: `INTERESTING` gets the same `^ *FAIL[ :]` alternative, so STOP.md lists `FAIL  <script>` and the case lines.
- `tools/tests/check-scope-test.sh` (new): 8 cases, listed below.

## Tests

Tests-first: exempt (shell tools). The brief's `bash tools/tests/...` runs need approval here and are not on the allowed prefix list, so every test ran through `tools/check.sh tools` (selftest), which runs every `tools/tests/*-test.sh`.

- Before the edits: `tools/check.sh tools` → `FAIL  tools (exit 1, 460s)`. The log is outside the allowed folders, so I could not read which case failed, and I have no FAIL lines for the new test from before the edits.
- After the edits: `tools/check.sh tools` → `FAIL  tools (exit 1, 462s)`, with these FAIL lines printed by the new filter:
  - `tools/tests/claude-worker-test.sh` (5s): `plain flash.sh still runs the DeepSeek worker with --bare and 150 turns`
  - `tools/tests/run-jobs-split-test.sh` (8s): `the sizes hold (runner 380 <= 380, wave 85, steps 261 and review 141 < 250)`
  - `tools/tests/run-wire-test.sh` (54s): 8 cases: `a failed check writes STOP.md with the cause and commits it`, `the STOP file writes STOP.md with its cause and commits it`, `result 4 with only generated churn ... is applied`, `result 4 with only churn outside and a patch that does not apply ...`, `result 4 with only churn outside and an empty patch ...`, `a stop waits for the running wave review and commits its report`, `a STOP-file stop kills the running wave review at once ...`, `RUN_MAX_MIN stops the run's stuck final review with STOPPED: TIMEOUT in 6s`
  - Not in the FAIL list, so they passed: `check-scope-test.sh`, `check-failfast-test.sh`, `run-stop-test.sh`. The selftest prints PASS lines only in its log, which I cannot read, so I have no per-case count for them.
- `tools/check.sh format` → `PASS  format (9s)`.

Computed value: `run-steps.sh` was 249 lines before the job and is 261 now (+12). The gate needs under 250.

Self-check (review-rules part A):
1. Host setups: not affected; shell tooling only.
2. Kept state: `RUN_CHECK_SKIP` is set in `checks()` each run and cleared by nothing; it is read only by `check_once` in the same run.
3. Combinations: a failed format or analyze still stops before the tools suite; `check_scope` runs before `check_once` only.
4. Files: only the allowed files plus this report.
5. Stopped on the size gate rather than trimming unrelated code in `run-steps.sh`.
6. Not applicable (no UI).

## Questions

1. `tools/run-steps.sh` is 261 lines and `run-jobs-split-test.sh` needs under 250 (it was 249). Which should it be: trim about 12 lines of `run-steps.sh` (unrelated code, which I did not touch), or move `check_scope` to another file (not in this job's allow list)?
2. The `run-wire-test.sh` and `claude-worker-test.sh` failures: are these pre-existing? I could not read their logs (outside the allowed folders), and I did not run them on the old code. The wire cases that involve `checks` ("a failed check writes STOP.md ...") go through `check_scope`, which only logs and sets `RUN_CHECK_SKIP`, so I do not expect my change to cause them, but I have not measured it.
3. The brief's `bash tools/tests/...` commands need approval in this session. Should the allow list include them?

## Suggestions

- `check.sh --verbose` prints the whole log; a `tools` run that fails could print only the FAIL lines, as this job now does.

## Commit message — a draft

Combined check skips the tools suite when no tool changed

The runner's combined check now skips the tools suite when no job changed a
file under tools/ (one log line says why). check.sh gets CHECK_SKIP, and its
FAIL lines, and run-stop.sh's STOP.md, now name the failing shell suite's
script and case instead of "none found". New tests in check-scope-test.sh.

## Status row

Done: `CHECK_SKIP` in check.sh, `check_scope` in run-steps.sh (tools suite skipped when clean), FAIL lines in check.sh and STOP.md, and check-scope-test.sh (8 cases). Open: run-steps.sh is 261 lines, over the split test's 250 limit (owner decision); run-wire-test and claude-worker-test fail in the tools suite, not yet traced to a cause.

## Delete

- none

Hand-fix (driver, Nov 23): p6a passed at attempt 1 (31 turns, 18 min). The combined check failed on the tools suite for two causes outside the job: run-steps.sh over the 250-line split gate (check_scope moved to tools/run-scope.sh) and run-wire-test.sh failing under the runner env (WORKER=claude leaked; tools/selftest.sh now unsets it, case added to check-scope-test.sh). tools suite passes on the tip with the leaked env.
