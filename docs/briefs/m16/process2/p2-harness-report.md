# p2-harness report: tools/selftest.sh and a "tools" check

## Summary

Added `tools/selftest.sh`, the runner for the shell tooling's own tests, and
wired it into `tools/check.sh` as the `tools` check after `tv`. Added
`tools/tests/selftest-test.sh`, 9 cases for selftest.sh's rules.

- `tools/selftest.sh [dir]` runs every `<dir>/*-test.sh` (default `tools/tests`)
  one at a time, each under `timeout` (`SELFTEST_TIMEOUT`, default 120 s).
  Prints `PASS  <script> (<n>s)`, `FAIL  ...` with the script's `FAIL` lines
  indented under it, or `TIMEOUT ...` plus `TIMEOUT: <script> exceeded <n>s`.
  Last line: `RESULT: ok|FAILED|TIMEOUT|BAD INPUT: ...`. Exit 0 all passed,
  1 any failed, 2 any timed out, 3 bad arguments/setup (missing folder,
  no `*-test.sh`, second copy on a live lock).
- A pid lock (`.dart_tool/selftest.lock`, `SELFTEST_LOCK` overrides it) refuses
  a second copy with exit 3 and replaces a stale one. `trap EXIT/INT/TERM`
  removes the lock and temp folder and kills the running child.
- Each script runs in the background and its pid is `wait`ed on, so a TERM
  trap runs at once instead of after a hung script finishes. Cleanup kills
  and reaps that child before removing the temp folder, because Windows won't
  delete a log file another process still has open.
- `tools/check.sh`: one checks entry `tools|.|bash tools/selftest.sh|...` after
  `tv`, and `tools` appended to the header's Checks line. Nothing else.
- The self-test: 9 cases (missing folder, empty folder, passing fixture,
  failing fixture with its FAIL line echoed, hanging fixture at
  `SELFTEST_TIMEOUT=2`, a folder path with spaces, a live lock refused, a stale
  lock replaced/removed, an interrupted run whose lock and temp files are gone).

Tests-first is exempt for shell tooling (brief); the new test file is the proof
and the runner executes it.

## Files changed

- `tools/selftest.sh` (new, 130 lines): the runner described above.
- `tools/tests/selftest-test.sh` (new, 130 lines): its self-test, 9 cases.
- `tools/check.sh`: `tools` check after `tv` (1 line) and the header list.
- `docs/briefs/m16/process2/p2-harness-report.md`: this report.

## Decisions

1. **`SELFTEST_LOCK` env knob.** The self-test itself runs under
   `tools/selftest.sh`, which holds the default lock; the cases point
   `SELFTEST_LOCK` inside their temp folder so they can start their own copies.
   It is documented in the header with the other knobs. Without it the
   "second copy refused" case could not run.
2. **Status line spacing.** `PASS  `/`FAIL  ` (two spaces, like check.sh) and
   `TIMEOUT ` (one space); the brief fixes the words, not the padding.
3. **The `TIMEOUT: <what> exceeded <n>s` line** from script-rules is printed in
   addition to the per-script `TIMEOUT <script> (<n>s)` line.
4. **A failure with no `FAIL` line** (a crash, say) prints
   `  (exit <rc>, no FAIL line)` so the cause isn't hidden.
5. **Bad input is one line**, `RESULT: BAD INPUT: <sentence>` (exit 3), which is
   both the plain message and the required last line. `-h` prints the usage
   block only (like check.sh/coverage.sh).
6. **Default lock is one file**, as script-rules says, not one per folder.

## Self-check (review-rules part A)

1. Every host setup: not affected; shell tooling only, no app, host or protocol code.
2. Kept state: the lock is written after the input checks, before the first script; it ends on every exit path (EXIT/INT/TERM cleanup), and a refused or bad-input run never takes it (bad input is checked first). Shown by the stale-lock and interrupted-run cases.
3. New state combines: not affected; no round, pause, menu or UI state, and nothing reads the lock besides selftest.sh.
4. Folder: only the four paths in `allow:` were written (the report included).
5. Stop rather than overstep: no stop needed. The only tension was COMMON.md's "end with ## Hand-over" against the task's three closing sections; the task's sections are used, with Hand-over immediately before them.
6. Every look: not affected; no UI.

## Computed values (what the self-test expects)

Planned output of `bash tools/selftest.sh` on `tools/tests` once the driver
runs it: one line `PASS  tools/tests/selftest-test.sh (~7s)` and
`RESULT: ok: 1 script(s) passed (~7s)`, exit 0 (2 s hang case + 4 s interrupt
case + eight short runs).

| case | expected |
| --- | --- |
| missing folder | exit 3, last line `RESULT: BAD INPUT: no such folder: <tmp>/no-such-folder` |
| empty folder | exit 3, last line `RESULT: BAD INPUT: no *-test.sh scripts in <tmp>/empty` |
| passing fixture | exit 0, `PASS  <tmp>/pass/ok-test.sh (0s)`, last `RESULT: ok: 1 script(s) passed (0s)` |
| failing fixture | exit 1, `FAIL  <...>/broken-test.sh (0s)`, indented `  FAIL the fixture's case that fails`, last `RESULT: FAILED: 1 of 1 script(s) failed (0 passed, 0s)` |
| hanging fixture, `SELFTEST_TIMEOUT=2` | exit 2 after 2 s, `TIMEOUT <...>/slow-test.sh (2s)`, `TIMEOUT: <...> exceeded 2s`, last `RESULT: TIMEOUT: 1 of 1 script(s) exceeded 2s (0 passed, 0 failed, 2s)` |
| folder with spaces | exit 0, `PASS  <tmp>/dir with spaces/spaced-test.sh (0s)` |
| live lock (test's own pid) | exit 3, one line `RESULT: BAD INPUT: another selftest.sh is running (pid <test pid>, lock <tmp>/lock)`, lock left untouched |
| stale lock (pid 999999) | exit 0, `RESULT: ok: ...`, lock file gone afterwards |
| interrupted run (`timeout 4` on a 30 s fixture) | outer `timeout` exit 124, `<tmp>/lock` gone, `$TMPDIR` folder left empty |

## Questions and suggestions

1. The self-tests were not run in this job (not allow-listed); `bash -n` passes
   on all three scripts and `tools/check.sh format` passes. The interrupted-run
   case is the one that depends on SIGTERM delivery in Git Bash — if the driver
   reports a failure, look there first.
2. `tools/check.sh` still requires `dart`/`flutter` on the PATH before any check,
   including `tools`; a machine with only bash can run `bash tools/selftest.sh`
   directly. Left unchanged because the brief says nothing else in check.sh.

## Hand-over

Nothing else is open in this job; the three sections below are the hand-over.

## Commit message

Add tools/selftest.sh and a tools check for shell self-tests

tools/selftest.sh runs every tools/tests/*-test.sh one at a time under
timeout (SELFTEST_TIMEOUT, default 120 s), prints PASS/FAIL/TIMEOUT per
script, the script's FAIL lines on failure, and a RESULT line last. A pid
lock (.dart_tool/selftest.lock) refuses a second copy and replaces a stale
one; traps remove the lock and temp files and kill the running child.
tools/check.sh gains the tools check after tv, so `tools/check.sh` now runs
the shell tooling's self-tests.
tools/tests/selftest-test.sh covers bad input, pass, fail, hang, paths with
spaces, live and stale locks, and an interrupted run (9 cases).

## Status row

**Process2 harness (Nov 21):** `tools/selftest.sh` runs `tools/tests/*-test.sh` one by one under a per-script timeout, reports PASS/FAIL/TIMEOUT and RESULT, and holds a pid lock that refuses a second copy and replaces a stale one; `tools/check.sh` has the new `tools` check after `tv`, and `tools/tests/selftest-test.sh` has 9 cases (not run in this job; `bash -n` and reading only, the driver runs it). Open: the other process2 jobs (run-stop, churn, lock/wire, split, docs) and the first driver run of the `tools` check.

## Delete

- none
