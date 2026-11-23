# M16 identity1-fix ft: report

## Summary

- **Cause of the claude-worker-test failure:** not load. The "plain flash.sh" case runs `tools/flash.sh` with no `FLASH_WORKER` cleared. `claude-worker.sh` exports `FLASH_WORKER=claude`, so when the test runs from a claude-worker shell (as this job does) the case sees `worker: claude` and fails. It failed the same way in all four concurrent copies and when run alone; no other case failed in any run.
- **Fix:** `tools/tests/claude-worker-test.sh` line 87 adds `-u FLASH_WORKER` to the `env` call that already clears `FLASH_MODEL` and `FLASH_MAX_TURNS`. No timing limits, shared temp names or shared files were involved: each run uses its own `mktemp` folder.
- **check.sh:** the `tools` suite command is now `bash tools/selftest.sh -j 4` (line 58), and its description says "four at once".
- **dev-tools.md:** line 66 quotes the new command. HANDOFF.md:250 names `tools/check.sh tools`, not the command, so it is unchanged.
- **Not run:** the whole tools suite, as the brief says. `selftest.sh -j 4` itself was not run here; `check.sh tools` runs it at the next full check.

## Checks (run in this job)

| Command | Result |
|---|---|
| `bash tools/tests/claude-worker-test.sh` (before fix, alone) | FAIL 1 of 15: plain flash.sh case (`worker: claude`) |
| `bash tools/tests/claude-worker-test.sh` ×4 at once (before fix) | all four FAIL 1 of 15, the same case |
| `bash tools/tests/claude-worker-test.sh` (after fix, alone) | ok: 15 of 15 |
| `bash tools/tests/claude-worker-test.sh` ×4 at once (after fix, the load proof) | all four ok: 15 of 15, exit 0 |
| `bash tools/tests/check-scope-test.sh` | ok: 9 of 9 |
| `bash tools/tests/check-failfast-test.sh` | ok: 9 of 9 (its `--list` case shows 13 rows) |
| `bash tools/tests/selftest-test.sh` | ok: 18 of 18 |
| `bash tools/tests/selftest-limits-test.sh` | ok: 7 of 7 |
| `tools/check.sh format` | PASS (9s) |

Self-check (review-rules part A): this is a tools-only change with no host or look, so items 1, 2, 3 and 6 do not apply. Item 4: changed files are inside `allow:`. Item 5: nothing needed stopping for.

## Files changed

- `tools/check.sh`: `tools` suite runs `bash tools/selftest.sh -j 4`; description updated.
- `tools/tests/claude-worker-test.sh`: line 87 also clears `FLASH_WORKER` for the plain flash.sh case.
- `docs/dev-tools.md`: line 66 quotes the new `-j 4` command.

## Questions

1. Should `tools/selftest.sh` also unset `FLASH_WORKER` alongside `WORKER` and `NO_PUSH` (line 29)? Any test run from inside a claude-worker job would see it, not only this one. Not done here: the brief named only the test file.
2. Which other tests in `tools/tests/` call `flash.sh` without clearing `FLASH_WORKER`? I did not search; they may fail the same way from a claude-worker shell.

## Commit message — a draft

tools: run the tools suite four scripts at once

Check.sh's tools suite now runs selftest.sh -j 4. The claude-worker
test failed when run from a claude-worker shell: its plain flash.sh
case inherited FLASH_WORKER=claude and ran the Haiku worker, so the
case clears FLASH_WORKER as it already clears FLASH_MODEL and
FLASH_MAX_TURNS. Four concurrent runs pass 15 of 15 each.

## Status row

M16 identity1-fix ft: done: `check.sh tools` runs `selftest.sh -j 4`; claude-worker-test clears an inherited FLASH_WORKER, passes 15/15 alone and four at once. Open: the whole tools suite was not run in this job; other flash.sh tests may inherit FLASH_WORKER (question 2).

## Delete

- none
