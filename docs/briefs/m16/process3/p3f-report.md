# p3f report: the runner refuses a wave whose base does not compile

## Summary

- NEW `tools/run-base.sh` (sourced, 51 lines): `run_base_check <log>` runs
  `${RUN_BASE_CHECK_CMD:-bash tools/check.sh --fail-fast format analyze}` into `<log>`, under
  `RUN_BASE_CHECK_MAX_MIN` (5, unit `RUN_LIMIT_UNIT_S`; a 0 min limit is raised to 1 s), kills the
  check's whole tree on the limit, and returns 0 / 1 (failure) / 3 (limit) with one line in
  `RUN_BASE_WHY`: `does not compile: <the log's first failing line>` or
  `check passed its limit (RUN_BASE_CHECK_MAX_MIN=<n> min)`.
- `tools/run-jobs.sh`: 368 -> 376 lines (+8: one header line, one source line, five in the wave
  loop). Before every wave (wave 1 included) it logs `base check skipped (RUN_BASE_CHECK_SKIP)`
  when `RUN_BASE_CHECK_SKIP` is set, else runs the check and stops with
  `the base <WHY> (log <WORK>/run-base-check.log); no job of wave <n> was started` (the log is
  handed to `stop`, so `STOP.md` quotes it); sourced guarded like `run-limits.sh`, and the loop
  guards on `declare -F run_base_check`, so the older test fixtures that copy only the runner's
  files still behave as before.
- NEW `tools/tests/run-base-test.sh` (179 lines, 4 cases, 29 s whole; the slowest case prints its
  own 7 s): fail stub -> stop before the job, first error line only, `RESULT: STOPPED: the base
  does not compile: ...`, `STOP.md` quotes it, no job log and the worker never ran; pass stub ->
  wave starts, `RESULT: DONE: 1 jobs, 0 min`; `RUN_BASE_CHECK_SKIP=1` -> stub never called, note in
  `run.log`, job committed; sleep stub with `RUN_LIMIT_UNIT_S=1 RUN_BASE_CHECK_MAX_MIN=2` -> stops
  at 7 s (the stub would sleep 10 s, so the tree kill works) naming the limit.
- Tests-first proof: the new script run against the old runner printed 4 `FAIL` lines (see
  "Tests-first proof"); all 4 pass after the wiring.
- `docs/dev-tools.md`: the test list gains `run-base-test.sh`, the runner paragraph gains the base
  check (`RUN_BASE_CHECK_MAX_MIN`, the stop wording, `RUN_BASE_CHECK_SKIP`), and the helpers
  sentence names `tools/run-base.sh`.
- **STATUS: done.** `tools/check.sh tools` PASS (355 s, 14 of 14 scripts), `tools/review.sh` 0 fail
  0 note.

## Decisions

- `RUN_BASE_WHY` is a global that `run_base_check` leaves for the caller, because `stop` takes one
  cause string and the two reasons (a failing line vs the limit) must reach `STOP.md` in one form;
  the alternative (returning the line on stdout) would mix it with the check's own output.
- The helper is independent of `run-limits.sh` being sourced (its own validated default for
  `RUN_BASE_CHECK_MAX_MIN`, `${RUN_LIMIT_UNIT_S:-60}` read at call time), as the runner's fixtures
  may lack that file.
- `kill_tree` is used when it is defined (it is, by the time a wave runs) and a plain `kill`
  otherwise, so the helper, like `run-limits.sh`, can be sourced on its own.
- The base check runs before the "more than 3 jobs" guard and before the per-job skips: the brief
  says "before each wave starts", and a wave with nothing left to run also has no reason to run on
  a broken base.

## Files changed

| file | change |
|---|---|
| `tools/run-base.sh` | NEW: `run_base_check` and `run_base_why`, the limit, `RUN_BASE_WHY` (51 lines) |
| `tools/run-jobs.sh` | +8 lines: header line 59, the guarded source, the per-wave block; `-h` range 2,81 |
| `tools/tests/run-base-test.sh` | NEW: 4 cases on a temp repo with stub check and stub worker (179 lines) |
| `docs/dev-tools.md` | test list, runner paragraph, helpers sentence |

## Tests-first proof

`tools/selftest.sh tools/tests`, new test with the old `tools/run-jobs.sh` (before the wiring):

```
FAIL  tools/tests/run-base-test.sh (34s)
  FAIL a base with an analyze error stops before the job with its first failing line (no job started)
  FAIL a base that passes lets the wave start and the job finish with RESULT: DONE (exit 0)
  FAIL RUN_BASE_CHECK_SKIP=1 skips the base check, notes it in run.log and the wave runs
  FAIL a base check over RUN_BASE_CHECK_MAX_MIN (2 s) stops the run with the limit named (7s)
```

(the passing case fails there only because `$WORK/run-base-check.log` is never written: no base
check ran at all). With the wiring the same script passes in 29 s.

## Values computed for the expectations

- `stop_cause` (both cases): `the base does not compile: error: fake analyze error (log <work>/run-base-check.log); no job of wave 1 was started` and `the base check passed its limit (RUN_BASE_CHECK_MAX_MIN=2 min) (log <work>/run-base-check.log); no job of wave 1 was started`, where `<work>` is the case's `RUN_WORK`.
- The limit case: `RUN_BASE_CHECK_MAX_MIN=2`, `RUN_LIMIT_UNIT_S=1` -> 2 s; measured stop 7 s (the rest is fixture and runner start-up), the stub's `sleep 10` cut short.
- `RESULT: DONE: 1 jobs, 0 min` for the pass and skip cases; line counts: runner 368 -> 376, helper 51, test 179.

## Self-check (review-rules part A)

1. Hosts: not applicable, no app code; the runner cases are a fake repo and stub worker (`run-base-test.sh`).
2. Kept state: none; the only state is `$WORK/run-base-check.log` and `RUN_BASE_WHY`, both per call (cases 1 and 4).
3. Pause menu, host away, dropped link, results, leaving: not applicable, no app code.
4. Folder and allow list: only the five allowed paths changed (`git status` shows nothing else of mine).
5. Stop rather than overstep: nothing needed stopping; run-jobs.sh ends at 376 lines (cap 380) with 8 lines added as briefed.
6. Every look: not applicable; no widget changed.

## Hand-over

- The base check is format + analyze only, as briefed: a base whose suites fail but compile still
  starts the wave; the jobs' own checks cover the rest.
- The wave loop still runs the base check on a restart where every job is done (a full `analyze`
  of the last commit before "DONE"); worth a skip when a wave has nothing left to start (suggestion
  only, not done).
- `RUN_BASE_CHECK_CMD` is expanded unquoted, like `FLASH_CMD`, so a path with spaces cannot be used.

## Commit message

runner: refuse a wave whose base does not compile

tools/run-base.sh runs format and analyze of the last commit before every wave
(5 min, RUN_LIMIT_UNIT_S, tree killed on the limit) and leaves the reason in
RUN_BASE_WHY. run-jobs.sh calls it before wave 1 too and stops with "the base
does not compile: <first failing line> (log ...); no job of wave <n> was
started", so STOP.md names it; RUN_BASE_CHECK_SKIP=1 skips it with a run.log
line. New run-base-test.sh covers the failing, passing, skipped and over-limit
cases. From identity1 wave 1b: i1b's check could never pass on a base without
i1a2's fix and the job ran 60 min.

## Status row

p3f done: the runner refuses a wave whose base does not compile (tools/run-base.sh, wired into run-jobs.sh, 4-case test, dev-tools); open: nothing in p3f; the process3 batch's run review still to come.

## Delete

- none
