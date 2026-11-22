# p3d report: per-job limits, the computed backstop, the turn cap, RESULT, FLASH_CMD

## Summary

- `tools/run-jobs.sh` (368 lines, was 326; the brief allows 370) now sources `tools/run-limits.sh`
  (guarded), takes `RUN_MAX_MIN` from `run_backstop_min "$B/waves.txt"` when the environment gives
  none (logged once), watches each job against `run_job_limit_s "$B/$j.md"` and stops with
  `job <j> passed its limit (<n> min, estimate <m>)`, checks the usage row's turns against
  `RUN_TURN_CAP` (120; a brief's `turns: <n>` raises it) right after the job and before the checks,
  ends every path with a printed and logged `RESULT: DONE: <n> jobs, <m> min` /
  `RESULT: STOPPED: <cause>` line, and starts the preflight and every job with
  `${FLASH_CMD:-tools/flash.sh}`.
- NEW `tools/tests/run-limits-wire-test.sh`: four cases, about 30 s in all (each well under the
  20 s the brief asks for), with a stub `FLASH_CMD` worker that sleeps 1-30 s and writes the
  report; all four FAILED on the old runner (the tests-first proof, below) and all four pass now.
- `docs/dev-tools.md`: the two test-list entries and the runner paragraph (`RUN_MAX_MIN` default,
  the job limit, the turn cap, `RESULT:`, `FLASH_CMD`).
- **STATUS: stopped.** `tools/check.sh tools` FAILS on one case outside this job's `allow:`:
  `tools/tests/run-jobs-split-test.sh` asserts the runner is at or under **340** lines — "the sizes
  hold (runner 368 <= 340, steps 242 and review 141 < 250)" — while this brief's own rule is 370
  and p3f adds lines after me. The five items cannot fit in 326 + 14 lines (a deliberately dense
  version of my additions measured about +20, i.e. 346). The fix is one number in that test (340 ->
  380, in the condition, the comment and the case name); that file is not mine to change.
  Everything else passes: 11 of 12 scripts (`run-wire-test` 121 s, `run-limits-test` 8 s,
  `run-limits-wire-test` 28-33 s, the rest as before).

## Files changed

| file | change |
|---|---|
| `tools/run-jobs.sh` | the six items below; 326 -> 368 lines; the `-h` range moves to `2,80` |
| `tools/tests/run-limits-wire-test.sh` | NEW: the four cases (162 lines) |
| `docs/dev-tools.md` | the test list gains `run-limits-test.sh` and `run-limits-wire-test.sh`; the runner paragraph's `RUN_MAX_MIN` sentence becomes the limits, turn cap, `RESULT:` and `FLASH_CMD` text |

`tools/run-jobs.sh`, item by item:

1. `[ -f "$dir/run-limits.sh" ] && . "$dir/run-limits.sh"` after the other sources (p3c's
   hand-over asked for it; `run-steps.sh` already sources the file, and a second source is the same
   assignments). The computed default:
   `if [ -z "$RUN_MAX_MIN" ] && declare -F run_backstop_min > /dev/null; ... note "RUN_MAX_MIN=$N min
   (computed backstop of the jobs still to do)"`, then `[ -n "$RUN_MAX_MIN" ] || RUN_MAX_MIN=360`.
2. The job's start records `since+=("$(date +%s)")`; the wait loop polls at `RUN_POLL_S` (5) and
   stops with the brief's exact wording when `now - since >= run_job_limit_s`; the limit's minutes
   are `limit_s / RUN_LIMIT_UNIT_S`, so a 180 s limit prints "3 min" in production and "3" in a
   test with 1 s units.
3. `turn_cap <job>`: the turns are `usage`'s line (`sed` takes the leading number), the cap is the
   brief's `turns:` line or `RUN_TURN_CAP=120`; the call sits right after the job's "finished" note
   and before `apply_safe`/`checks`.
4. `result()` prints without the timestamp and tees to `run.log`; `stop()` calls it after the
   children are killed and before `save_stop`, so the committed `run.log` ends with it; the end
   calls it before the final `save` for the same reason.
5. `${FLASH_CMD:-tools/flash.sh}` for the preflight and for every job start.

## Decisions

1. **An explicit `RUN_MAX_MIN` still wins, and 0 still means "stop at once".** The computed backstop
   is used only when the variable is empty, so `run-wire-test.sh`'s `RUN_MAX_MIN=0` cases (12, 13,
   14) keep working: they passed.
2. **A computed backstop of 0 falls back to 360, not 0.** `run_backstop_min` returns 0 when every
   job of the batch is in `done.txt`/`dropped.txt`; a 0-minute limit would stop a restart before its
   final review. I did not use one job's time (`RUN_EXPECT_DEFAULT_MIN`) because that couples the
   run's limit to the estimate knob; the comment says "no job left keeps one job's time" — it says
   360 in the code, and the comment is the one thing I would reword (see Questions 2).
3. **The wait poll is `RUN_POLL_S`, not a bare 5.** It is the runner's documented poll (p3c), the
   default is 5 so production is unchanged, and it is what keeps the new test at seconds.
4. **The job-limit check is inline in the wait loop, not a `check_stop` hook.** `check_stop` is also
   called outside a wait (before a wave, before a commit) where no job is running; an inline test
   with two variables keeps the "which job" question local. Cost: the loop grew from 1 to 6 lines.
5. **The cause texts are exactly the brief's words** — `job <j> passed its limit (<n> min, estimate
   <m>)` and `job <j> used <t> turns, over its cap of <cap>` — because they end up in `STOP.md`, in
   `RUN.log` and in the `RESULT:` line. `run-stop.sh` classifies both as `other` (it has no class
   for them and is outside `allow:`).
6. **The DONE line's count is the batch's job count** (the words of `waves.txt`), not the jobs
   committed in this run; minutes are wall clock from `RUN_START_S`, floored. A one-job batch that
   takes 2 s prints `RESULT: DONE: 1 jobs, 0 min`.
7. **No usage row means no cap.** `usage` prints nothing for a stand-in worker (`tools/flash.sh`
   leaves `FLASH_USAGE_LOG` empty in a fixture), so `turn_cap` returns without a stop rather than
   treating a missing row as 0 turns; the same rule the estimate helpers use (a median of nothing is
   no estimate).
8. **`turns: <n>` replaces the cap for that job** (the brief says "raises it"); a `turns:` line of
   0 or no line keeps `RUN_TURN_CAP`.
9. **`FLASH_CMD` stays unquoted** as the other call sites in `run-steps.sh`/`run-review.sh` have it
   (p3c), so an unset value behaves exactly as today and a path with spaces would need quoting at
   every site together.

## Computed test values (`tools/tests/run-limits-wire-test.sh`)

Every case uses `RUN_LIMIT_UNIT_S=1` (one "minute" is 1 s) and `RUN_POLL_S=1`.

| case | computed | arithmetic |
|---|---|---|
| 1. a job over its limit | **3 s**, message `(3 min, estimate 2)`, stopped after ~4 s | 2 min x 150 x 1 / 100 = 3 s; 3 / 1 = 3 min; the stub sleeps 30 s, so only the limit can end it |
| 2. the 120-turn cap | stop, `job runjob used 130 turns, over its cap of 120` | the usage row's turns 130 > 120; the row's 1200 s also make the estimate 20 min, so the limit is 30 s and cannot race the 1 s job |
| 3. a brief's `turns: 140` | DONE, `RESULT: DONE: 1 jobs, 0 min` | 130 <= 140, so the job runs on to its checks and commit |
| 4. the computed backstop | `RUN_MAX_MIN=25 min`, logged once | 20 min (the default, no `expected-min:`) x 125 = 2500; (2500 + 99) / 100 = 25 |
| this batch, `docs/briefs/m16/process3` | **219 min** | p3c's arithmetic for the same `waves.txt`: 175 min of estimates, (21875 + 99) / 100 |

The script runs in 28-33 s in the suite; the slowest case is 1 (about 4 s of polling plus the 25 s
`slot_wait` interval only when a second job is in the wave, which these have not).

## Checks

- Tests-first proof, on the old `tools/run-jobs.sh` (326 lines), from `tools/check.sh tools`:
  `FAIL tools/tests/run-limits-wire-test.sh (30s)` with all four cases FAIL:
  `FAIL a job over its limit (2 min x1.5 = 3 s) stops the run with the RESULT: STOPPED line (8s)`,
  `FAIL a job at 130 turns stops on the 120-turn cap before its checks, with the RESULT: STOPPED line (exit 1)`,
  `FAIL a brief's turns: 140 raises the cap and 130 turns finishes with RESULT: DONE (exit 0)`,
  `FAIL the computed backstop is the logged RUN_MAX_MIN (one job, 20 min default -> 25 min) and FLASH_CMD ran the preflight`.
  (The old runner has no `FLASH_CMD`, so `tools/flash.sh` does not exist in the fixture and every
  case ends in a failed job.)
- `tools/check.sh tools` with the change: **FAIL, 330 s** — 11 of 12 scripts pass, including
  `run-wire-test.sh` (121 s, all its cases), `run-limits-test.sh` (8 s) and the new
  `run-limits-wire-test.sh`. The one failing script is `run-jobs-split-test.sh`, one case:
  `FAIL the sizes hold (runner 368 <= 340, steps 242 and review 141 < 250)`.
- `tools/review.sh` scans `.dart` files only; the four changed files are shell and Markdown, so it
  cannot produce a FAIL line for them, and it is not in this job's `allow:` — I did not run it.
- Two earlier runs of my own test failed on its own arithmetic, both fixed here and worth naming:
  the usage row's 60 s made the job's *estimate* 1 min, hence a 1 s limit that fired before the
  turn check (the row now says 20 min), and case 2's expected `RESULT:` line lacked the cause's
  trailing parenthetical (the cause text was shortened instead).

## Self-check (docs/review-rules.md part A)

1. Host setups (TV, PC, phone variants, joined phone, older peer): not applicable, no app code; the
   runner's own paths are covered by `run-wire-test.sh` (13 cases, pass) and the new test's four.
2. Kept state: no game state; `RUN_*` are set once at the start, the computed `RUN_MAX_MIN` is
   logged once (case 4), and each exit path writes the `RESULT:` line last (cases 1-3). A batch with
   nothing to do gets 360 min and no job limit (no job is waited for).
3. Combinations: a stop still writes `STOP.md` first (case 1 checks the cause inside it), a failed
   job still goes through `apply_safe` and the stop that names it (unchanged, `run-wire-test` pass),
   the STOP file still wins at every poll (its case passes), and the resume/dropped/done paths are
   untouched (the split test's dry run and `run-wire-test` cases 5-7 pass).
4. Stayed inside `allow:`: the four files in the table; nothing else was edited.
5. Stopped rather than overstepped: `tools/tests/run-jobs-split-test.sh`'s 340-line assertion is the
   gate that fails and I did not edit it (it is not in `allow:`); see Questions 1.
6. Every look (menu and TV): not applicable, no widget or layout changed.

## Blocked

`tools/tests/run-jobs-split-test.sh`, "the sizes hold": the condition `[ "$runner_lines" -le 340 ]`,
its comment "the runner at or under 340 lines" and the case name. With the brief's five items the
runner is 368 (the brief allows 370, and p3f adds more), so any faithful p3d fails this case. The
one-line repair is 340 -> 380 in all three places.

## Questions

1. Should the split test's runner limit become 380 (or a named constant next to `SIZE_STOP`)? It is
   the only thing between this job and a green `tools/check.sh tools`, and it is outside `allow:`.
2. A job-limit or turn-cap stop lands in `run-stop.sh`'s `other` class, whose repair text is
   generic ("read the cause ..."); a `job-limit` class (and a `turn-cap` one) would say "the job is
   too big: split its brief, or raise `expected-min:`/`turns:`". `run-stop.sh` is outside `allow:`.
3. The DONE line's `<jobs>` is the batch's job count. If "jobs committed in this run" is meant, it
   is a one-line change (`${#ok[@]}` accumulated over the waves).
4. My comment on the computed backstop says "no job left keeps one job's time" while the code falls
   back to the fixed 360; I chose 360 to keep the run's limit independent of the estimate knob, but
   the wording (or the value) should be settled.

## Suggestions

- Give the split test's size limit a name (`RUNNER_MAX_LINES`), so raising it is one edit and the
  `SIZE_STOP` (380, lib files) and runner numbers stop drifting apart.
- `tools/wait-run.sh` could read the new `RESULT:` line instead of watching for DONE/STOPPED words
  in `run.log`; it is the line both sides would then share.

## Hand-over

- p3f: `tools/run-jobs.sh` is at 368 of the brief's 370 lines, so its additions need the split
  test's 340 raised first (or a helper moved out).
- The new test copies `tools/run-limits.sh` into its fixture, as p3c's hand-over asked.

## Commit message

```
tools: per-job limits, a turn cap and a RESULT line in the runner

run-jobs.sh sources tools/run-limits.sh (guarded) and defaults RUN_MAX_MIN to
the computed backstop (the undone jobs' estimates +25%), logged once; an
explicit RUN_MAX_MIN still wins, and 0 still stops at once.
Each job is watched against its own limit (expected-min: x1.5) and, once it
finishes, against RUN_TURN_CAP turns (a brief's turns: line raises it) before
its checks. Every exit ends with RESULT: DONE/STOPPED, printed and in run.log,
and FLASH_CMD starts the preflight and every job.
New tools/tests/run-limits-wire-test.sh proves all of it in about 30 s and
failed on the old runner; docs/dev-tools.md updated.
tools/check.sh tools fails only on run-jobs-split-test.sh's stale 340-line
runner limit (the brief allows 370), a file outside this job's allow list.
```

## Status row

p3d done: the runner's per-job limit, computed `RUN_MAX_MIN` backstop, 120-turn cap with a brief `turns:` line, the `RESULT: DONE/STOPPED` line on every path and `FLASH_CMD` (preflight and jobs), with `tools/tests/run-limits-wire-test.sh` (4 cases, all passing) and the docs; open: `tools/tests/run-jobs-split-test.sh` still caps the runner at 340 lines (it is 368, the brief allows 370), so `tools/check.sh tools` fails on that one case, and `run-stop.sh` has no class for a job-limit or turn-cap stop.

## Delete

- none
