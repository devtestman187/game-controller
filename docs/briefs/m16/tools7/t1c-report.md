# t1c report: run-limits-wire, run-wave and mine tests (stopped at the baseline)

## Summary

STOPPED before any edit. No test file was changed.

- Bash runs of `bash tools/tests/<name>.sh` are not on the allowed prefix list and returned "requires approval", so the per-script baseline timings could not be taken directly. Compound commands and redirects to /tmp were also refused.
- `tools/check.sh tools` (allowed prefix) was started in the background to get a baseline for the whole tools suite. Its output file was still empty when last read, and I could not wait on it without another approval-gated command.
- Nothing was measured for the three scripts, so no before/after seconds are reported.
- The background `tools/check.sh tools` run finished on the untouched tree with exit 1 after 801 s (log: `C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261123-012557/tools.log`). Failures seen:
  - `tools/tests/claude-worker-test.sh` (7 s): "plain flash.sh still runs the DeepSeek worker with --bare and 150 turns" (not a file this job may change).
  - `tools/tests/run-wave-test.sh` (55 s): case 1 "one wave's job past its limit is parked while its two siblings are committed, then the run stops naming it (24s)". The case asserts elapsed < 20 s and took 24 s, so this is a timing failure on the untouched code, before any edit.
  - `tools/tests/run-wire-test.sh` (182 s): "a STOP-file stop kills the running wave review at once, with no report committed (exit 1)".
  These are pre-existing and were not caused by this job. Speeding up run-wave is the one that applies to this job.

## Decisions

- Stopped rather than edit without a baseline: the brief requires before-and-after seconds and a no-flake run of each script, and none of those can be taken here.

## Blocked

- Running the three shell tests and timing them needs the approval gate to allow `bash tools/tests/...` (or a per-script check suite). Until then the job cannot be verified.

## Self-check

- Not applicable: no code changed.

## Reading notes (for the next run)

- run-limits-wire-test.sh: fixture built per case (git init, config, add, commit); stubs and brief are identical across cases except the brief's extra lines. A template folder with `cp -r` is possible. Case 1 stub `sleep 30` runs past a 3 s limit; the runner must not wait for it (the case asserts elapsed < 20).
- run-wave-test.sh: the only long wait is the 25 s runner wait, already shortened to 1 s by the sleep stub. The hang stub (`stub-sleep: 30`) against a 1.5 s limit could drop to about 4-6 s, keeping the job alive past the limit at the first poll.
- mine-test.sh: `hang` stub is `exec sleep 30` with MINE_TIMEOUT=3; the interrupt case kills after 4 s. Shortening the stub sleep only matters if mine waits for it; measure first.
- No file-wait sleeps were found in the three scripts; item 3 may apply only to the stub sleeps.

## Commit message

(no commit: job stopped before edits)

## Status row

t1c: stopped before edits; baseline timings and the speed-up of run-limits-wire, run-wave and mine tests are open (blocked by the approval gate on `bash tools/tests/...`).

## Delete

- none
