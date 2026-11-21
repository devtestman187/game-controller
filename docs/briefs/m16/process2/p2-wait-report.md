# p2-wait — tools/wait-run.sh (wait for a run without polling)

## Summary

Adds `tools/wait-run.sh <briefs-dir> [--max <s>]` and its self-test, the replacement for the driver's
`for i in $(seq 5); do tail -n 3 run.log; sleep 30; done` loop (thumb-batch step 3, scriptable-work item 1).

- Blocks up to 170 s (default and cap; `--max` lowers it, a larger value prints a NOTE and uses 170), polls every
  5 s, prints only the run.log lines new since the last call, exits at once on a `DONE:` or `STOPPED:` line after
  the run's last `start at`.
- Position: byte offset in `.dart_tool/wait-run/<name>.pos`, moved back to the run's own `start at` line when a new
  run starts or when the stored value is garbage or too large; that line names the commit, so a first call shows it.
- Exit codes as the brief asks, last line always `RESULT: ...`: 0 `ok: DONE: <text>` · 1 `STOPPED: <why>` ·
  2 `STALLED: ...` / `OVERRUN: <job> has run <n> min, expected ~<m> (1.5 x is <k> min)` ·
  3 `BAD INPUT: <one sentence>` · 4 `running: <job> for <n> min (expected ~<m>)`.
- STALLED: run.log, the batch's `flash-*.log` files (plus a `--logs` folder named in `WAIT_LOGS`), and the run's work
  folder unchanged for `WAIT_STALL_MIN` (20) minutes, with no DONE/STOPPED and the run itself older than that.
- OVERRUN: a started job with no `finished` line running past 1.5 x its expected minutes — brief `expected-min:`,
  else the median minutes of its last 30 flash-usage rows, else 15.
- One waiter per briefs folder: pid lock under `.dart_tool/wait-run/`, a live pid is refused (exit 3), a stale or
  garbage lock is replaced, and EXIT/INT/TERM remove the lock and the stall marker.
- `tools/tests/wait-run-test.sh`: 19 cases, every rule above plus the brief's edge list, **all PASS**, 44 s inside
  `tools/check.sh tools` (script-rules' 60 s budget).

Four real bugs the self-test found, each now pinned by a case: awk's `-v` ate the backslashes of a Windows path so
the usage median never matched (the brief path now goes through `ENVIRON`); a Windows path with `\` or `:` made an
unwritable lock name (the name is `tr`-sanitised); the first call printed from *after* the `start at` line; a
refused waiter deleted the other waiter's marker.

Checks: `tools/check.sh format` PASS (5 s); `tools/check.sh tools` PASS (`wait-run-test.sh` 44 s,
`selftest-test.sh` 10 s). Plain `bash tools/wait-run-test.sh` — the command script-rules names — is refused by this
job's tool allow-list, so the test was run the only way available here: `tools/check.sh tools` → `tools/selftest.sh`
→ the script. Nothing asserts on a live batch: the process2 `run.log` was read (not written) to copy the real line
shapes.

## Decisions

1. The window end is exit 4 with `RESULT: running: ...`, not script-rules' generic `TIMEOUT: <what> exceeded <n>s`:
   the brief's exit table and result format replace it, and a window ending is normal, not a failure.
2. No git worktree check, although script-rules lists one. The script reads run.log, the briefs and the usage log
   only and runs no git command; a worktree check would also refuse the self-test's fixture folders.
3. A call prints from the run's `start at` line inclusive rather than the lines after it: the first call then shows
   which commit the run started from, which is what a driver needs after a restart.
4. `exit 4` names the **earliest** unfinished job, and OVERRUN the earliest job over its limit: a wave starts up to
   3 jobs at once, so "the current job" is a list, and the oldest one is the one whose minutes mean something.
5. With no job started yet (preflight), the result names `preflight (no job started yet)` and counts minutes from the
   `start at` line; its expected time is the 15-minute default, since no brief exists for it.
6. Two env knobs beyond the brief's list: `WAIT_LOGS` (the folder given to the runner as `--logs`, where its
   `flash-*.log` files are — the live process2 folder has none in `docs/briefs/m16/process2/`) and `WAIT_STATE_DIR`
   (so the self-test never writes into the repo's `.dart_tool/wait-run`).
7. Lock, position and marker share one name per briefs folder, sanitised with `tr -c 'A-Za-z0-9._-' '_'`, so
   `docs/briefs/m16/process2` becomes `docs_briefs_m16_process2` — the spelling tools/run-jobs.sh uses for its work
   folder. No new dependency; bash, GNU coreutils and awk only.
8. The 1.5x limit is computed in whole seconds (`elapsed > expected * 90`) and reported in minutes
   (`expected * 90 / 60`); the usage median is rounded half-up.

## Values computed for the tests

- still running, `--max 6`: deadline 6 s, returned after 6 s → `RESULT: running: c for 0 min (expected ~15)` (15 is
  the default: no brief, empty usage log); elapsed 6 s → 0 whole minutes.
- OVERRUN from a brief: `expected-min: 2` → limit 2 * 90 = 180 s = 3 min; start line 10 min (600 s) old → 600 > 180,
  text `e has run 10 min, expected ~2 (1.5 x is 3 min)`.
- OVERRUN from the usage log: rows of 60/120/180 s → 1/2/3 min → median 2 min → limit 180 s; 600 s elapsed → OVERRUN.
- STALLED: `WAIT_STALL_MIN=1` puts the marker at now-60 s; run.log mtime and `start at` 40 min (2400 s) old →
  STALLED on the first poll, under 5 s (the test asserts `< 5`).
- `WAIT_LOGS`: the same 40-minute-old run.log with a `flash-f.log` touched now → not stalled; `expected-min: 100`
  keeps OVERRUN away (limit 9000 s); `--max 2` → exit 4 with `f for 40 min (expected ~100)`.
- Timestamps come from the log text through `date -d`, so the 10/20/30/40-minute fixtures are exact and no test sleeps
  to age a file except the two `touch -d` cases.
- cap: `--max 999` → `NOTE: the wait window is capped at 170 s`, window 170.
- suite: 19 cases, 44 s; the deliberate waits are 6+2+2+2+3+6 = 21 s, the rest is about 1 s of Git Bash start-up per
  call (19 calls).

## Self-check (review-rules part A)

1. Host setups: not applicable — a shell tool, no TV/PC/phone role and no game state. Its inputs are the batch folder's
   run.log, the job briefs and the usage log; cases: "a missing folder is bad input", "a folder with no run.log is bad
   input", "a briefs folder whose path has spaces works".
2. Kept state starts and ends: the position is written after every print, the lock is taken before the first read and
   removed on every exit path (0/1/2/3/4 and TERM); with nothing going on a call prints nothing and exits 4 at the
   deadline. Cases: "a second call prints only the lines added since the first", "an interrupted waiter (TERM from
   timeout) leaves no lock and no marker", "a garbage position file is reset and the call still works".
3. How the new state combines with the rest: DONE and STOPPED end the wait at once with the runner's own words; a DONE
   from an earlier run does not ("a DONE before the last start at does not end the wait"); a new `start at` reprints
   from that line; STALLED and OVERRUN stop the wait on a wedged run. Cases: "a DONE line ends the wait at once",
   "a STOPPED line ends the wait (exit 1)", "a run.log 40 min old with no DONE is STALLED", "a brief's expected-min: 2
   makes a 10 min job OVERRUN", "a line appended during the wait is printed by that same call".
4. Stayed inside `allow:`: only `tools/wait-run.sh`, `tools/tests/wait-run-test.sh` and this report. `git status
   --short` also lists `docs/briefs/m16/process2/run.log` (the runner appends it) and four
   `tv_test_app/windows/flutter/` churn files — none touched by this job.
5. Stopped rather than overstepped: did not add `--logs` to tools/run-jobs.sh, did not edit
   `.claude/agents/thumb-batch.md` (where the loop lives), did not fix the same `awk -v` bug in run-jobs.sh `usage()`.
   All three are in Suggestions below.
6. Every look: not applicable — no widget and no look; the script prints plain text lines, one `RESULT:` line last.

## Questions

1. Should `tools/run-jobs.sh` write the log folder into run.log (e.g. `logs <dir>`), so the waiter finds the flash
   logs without `WAIT_LOGS`? The live process2 run has its flash logs outside the briefs folder.
2. Should the waiter report `HAND-FIX` lines differently (exit non-zero)? Today they are ordinary new lines and the
   wait continues; the runner's next DONE/STOPPED decides.
3. Is exit 4 the right answer for "window ended" when run.log has not grown at all since the previous call, or should
   that also be STALLED earlier than 20 minutes? I kept the brief's 20-minute rule unchanged.

## Suggestions (not acted on)

- `tools/run-jobs.sh` `usage()` uses `awk -v b="$1"` with a brief path; on a Windows-style path (`\`) the same
  `ENVIRON` fix applies. One line, but outside this job's allow list.
- `docs/briefs/templates/job.md` has no `expected-min:` line, so OVERRUN falls back to the usage median or 15 for
  every job; adding the line (one number, optional) would make OVERRUN predictable from the brief alone.
- The NEXT file from scriptable-work item 1 is not built; the waiter only reads run.log. If the runner wrote
  `<dir>/NEXT` (running / DONE / STOPPED plus the action) the exit-4 line could carry it too.
- thumb-batch step 3 could become the one-line loop `until tools/wait-run.sh <dir>; do :; done` (stop on 0/1); that
  file is outside this job's allow list.

## Hand-over

Nothing follows on from this job. The script and its 19 cases pass through the tools suite; it has not been pointed at
a live batch yet, so the first real use is the check that its window, its stop words and the lock behave under a running
runner. `tools/check.sh tools` picks the test up automatically (selftest runs `tools/tests/*-test.sh`).

## Commit message

Add tools/wait-run.sh so a driver stops polling run.log

tools/wait-run.sh <briefs-dir> [--max <s>] blocks up to 170 s, prints only the run.log lines new
since the last call, and exits on DONE or STOPPED after the last `start at`. STALLED (20 min of no
movement) and OVERRUN (1.5 x a job's expected minutes) stop a wait on a wedged run, with a
RESULT line each time; a pid lock keeps two waiters apart and a TERM cleans up. The byte position
lives under .dart_tool/wait-run, so a repeat call prints only what is new.
tools/tests/wait-run-test.sh covers all of it in 19 cases (44 s).

## Status row

- wait: `tools/wait-run.sh` blocks ≤170 s, prints only new run.log lines, exits DONE/STOPPED/STALLED/OVERRUN/running and locks per folder (19-case self-test) — done; open: no brief carries `expected-min:` yet and the runner does not record its `--logs` folder, so OVERRUN and the stall watch fall back to the usage median and `WAIT_LOGS`.

## Delete

- none
