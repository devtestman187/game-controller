# Rehearsal of the finished process3 tools: DRAFT (run after p3a-p3e are committed and `bash tools/check.sh tools` passes)

Purpose: prove the new limits, the STOP file, the RESULT line and wait-run's states end to end, in about 5 minutes, with no real worker and no usage cost.

## Setup (in a scratch copy of the repo or this worktree on a throwaway branch `rehearsal`; never on m16)
1. Folder `docs/briefs/rehearsal/` with two briefs `r1.md`, `r2.md` from `docs/briefs/templates/job.md`: `expected-min: 1`, `allow:` one new file `docs/briefs/rehearsal/r1-note.txt` (resp. `r2-note.txt`), `report:` `docs/briefs/rehearsal/r1-report.md`, `check: none`; `waves.txt` = `r1 r2` (one wave) . Commit them (the runner cuts from the last commit).
2. Environment for every run:
   `FLASH_CMD=tools/fake-flash.sh FAKE_FLASH_SLEEP_S=3 FAKE_FLASH_TURNS=10 FLASH_USAGE_LOG=<scratch>/usage.tsv PREFLIGHT_SKIP=1 NO_PUSH=1 RUN_LIMIT_UNIT_S=1 RUN_CHECK_MAX_MIN=20 RUN_REVIEW_MAX_MIN=20 RUN_POLL_S=1 WAIT_MAX_S=20 WAIT_POLL_S=2`
   (units: with RUN_LIMIT_UNIT_S=1 one "minute" is one second, so `expected-min: 1` x1.5 is a 1.5 s job limit when you want it to trip.)
   Start: `nohup bash tools/run-jobs.sh docs/briefs/rehearsal > /dev/null 2>&1 &` ; wait with `bash tools/wait-run.sh docs/briefs/rehearsal`.

## Runs and expected lines
| # | Change to the env | Expected in run.log | wait-run | RESULT |
|---|---|---|---|---|
| 1 | none (fake check: `tools/check.sh` stubbed via CHECK_DART/CHECK_FLUTTER stubs, or `check: none`) | `start r1`, `start r2`, `r1 finished: result 0 (10 turns, ...)`, `committed r1`, `committed r2`, `DONE: every job is committed` | exit 0 | `RESULT: DONE: 2 jobs, <n> min` |
| 2 | `FAKE_FLASH_SLEEP_S=6` and `expected-min: 1` in r1 (limit 1.5 s unit) | `STOPPED: job r1 passed its limit (...)` ; STOP.md written | first call exit 2 OVERRUN, second call exit 4/1 (reported once) | `RESULT: STOPPED: job r1 passed its limit ...` |
| 3 | `FAKE_FLASH_TURNS=121` | `STOPPED: job r1 used 121 turns, over its cap of 120` before any check | exit 1 | `RESULT: STOPPED: ...turn cap...` |
| 4 | stub check sleeps 30 s, `RUN_CHECK_MAX_MIN=3` | `STOPPED: the combined check passed RUN_CHECK_MAX_MIN=3`; wait-run during it prints `checking: the combined check for <n> min` | exit 1 | `RESULT: STOPPED: ...check...` |
| 5 | `touch docs/briefs/rehearsal/STOP` during the check of run 4 | `STOPPED: stop file` within RUN_POLL_S seconds, not after the check | exit 1 | `RESULT: STOPPED: stop file` |
| 6 | `FAKE_FLASH_HANG=1`, no RUN_MAX_MIN, 2 briefs of `expected-min: 1` | backstop = max((1+1) x 1.25, RUN_EXPECT_DEFAULT_MIN 20) = 20 units (logged at the start), so with RUN_LIMIT_UNIT_S=1 the job limit fires first: `STOPPED: job r1 passed its limit (1 min, estimate 1)` (set RUN_EXPECT_DEFAULT_MIN=2 to see TIMEOUT instead) | exit 1 | `RESULT: STOPPED: TIMEOUT...` |
| 7 | after a stop in run 3: `resume r1` (report present, uncommitted) | `resume r1 (applied by hand, ...)`; wait-run shows r1 as running until its commit | exit 4 then 0 | `RESULT: DONE: ...` |

After each run: delete `docs/briefs/rehearsal/STOP*`, `done.txt` and the run's work folder `.dart_tool/run-jobs/docs_briefs_rehearsal`, and `git reset --hard` the throwaway branch to its first commit. The usage log is the scratch one, so the real flash-usage.tsv gets no fake rows.
Pass: every row matches, no process left (`ps`), the real m16 branch untouched.
