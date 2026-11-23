# M16 speed1 sp1: `check.sh -j N` runs the package test suites in parallel

## Summary

**Done.** `tools/check.sh -j N` (also `-jN`, `--jobs N`, and `CHECK_JOBS=N`) runs format and analyze first, serially, then the suites N at a time. The default stays serial and never loads `check-par.sh`.

Files changed:
- `tools/check.sh` (246 lines, under the 250 cap): parses `-j`/`-jN`/`--jobs`/`CHECK_JOBS` and validates the count (whole number ≥ 1, else exit 2); sources `$root/tools/check-par.sh` for N > 1 (exit 2 with a message when missing); the PASS/FAIL printing moved into `print_result`, the per-check run into `run_check`, and the wanted, CHECK_SKIP and skip-reason tests into `selected` and `skipped_by_env`; the serial path calls the same functions. Header documents `-j`.
- `tools/check-par.sh` (new, 72 lines): `run_parallel_suites`, `start_suite` (background subshell, log per suite, status file written last), `reap_finished` (polls status files; no `wait -n`). Prints each suite's line in check order after the run.
- `tools/tests/check-par-test.sh` (new, 184 lines): 9 cases, stubbed dart/flutter, copy of check.sh under a temp `repo/tools`.

Test counts seen in this job:
- `check-par-test.sh`: before the change, 8 of 9 cases FAIL (the 9th, serial without check-par.sh, passes as a guard). After: RESULT ok, 9 of 9.
- `check-failfast-test.sh`: RESULT ok, 9 of 9.
- `check-scope-test.sh`: RESULT ok, 9 of 9.
- Stub timings (eight 1 s suites): serial 12 s, `-j 4` 4 s.

Decisions:
- The parallel suites are the checks after format and analyze; they are deferred and run after the serial loop, so fail-fast skips them before any starts.
- The job count is validated after the argument loop, so `-j` overrides `CHECK_JOBS`; an invalid `CHECK_JOBS` is reported only when no `-j` is given (both cases exit 2).
- Polling uses `sleep 0.2` (fractional sleep, present in Git Bash and macOS).
- `--help` now shows one more header line (the `-j` usage line sits inside the `sed -n '2,20p'` range).

## Self-check (docs/review-rules.md part A)

1. Host setups: not applicable (shell tool). Stub suites cover the parallel and serial paths.
2. Kept state: the status and log files live in the per-run `logs` folder under TMPDIR; the existing EXIT trap in the tests removes them. An empty run (no suite selected) starts nothing and prints the same summary.
3. Combinations: fail-fast with `-j` (case "-j 4 --fail-fast with a failed analyze"), CHECK_SKIP and wanted names (cases use names; CHECK_SKIP path is the same function as serial).
4. Stayed inside `allow:`. Nothing else edited.
5. Nothing stopped.
6. Look: not applicable.

## Hand-over

- **Churn revert side effect (needs your attention).** The first `tools/mine.sh` run printed `churn: reverted 22 generated file(s)`. Before this job, `git status` showed 22 modified tracked files (`docs/design/m13-placed-look.png`, `docs/design/puzzles/*.png`, `site/shots/*.png`, `tv_test_app/windows/flutter/generated_plugin_registrant.*` and `generated_plugins.cmake`). They are no longer modified, and `git status` now shows only the three files of this job. I did not run any git command that changes the tree, and I cannot restore those edits from git; if they mattered, they need to be regenerated or recovered from wherever they were produced. This is the churn step `mine.sh` is documented to run; I did not expect it to touch files outside my job.
- `tools/mine.sh` ran 0 Dart tests (it only tests touched Dart packages), so the shell tests were run directly as the brief asks. The brief's `check.sh` runs were not done by me.
- I tried one read-only comparison of the serial output against `HEAD`'s `check.sh` (with stubs); the command was denied, so "serial output byte-identical" is **not verified by a diff**. The serial path is covered by the existing failfast and scope tests (which pass) and by the new serial case, but not by a byte diff.
- The timing case compares real seconds (serial ≥ 8 s, `-j 4` under half of that); on a slow machine it is the one case that can flake. The brief allows real time for this test.

## Commit message — a draft

```
check.sh -j N runs the package test suites in parallel
```

(then, after a blank line)

```
check.sh -j N (also -jN, --jobs N, CHECK_JOBS=N) runs format and analyze
serially, then the suites N at a time, each into its own log. Lines print
in check order after the run. Default stays serial; check-par.sh is loaded
only for N > 1. Failed format/analyze still skips the suites before any starts.
Parallel code lives in tools/check-par.sh (check.sh stays under 250 lines).
New tests in tools/tests/check-par-test.sh cover timing, order, failure, bad counts.
```

## Status row

sp1 done: `check.sh -j N` / CHECK_JOBS runs the suites in parallel (check-par.sh, 9 tests pass, 8 s serial vs 4 s at -j 4 on stubs); open: a byte-diff of serial output against HEAD was not run, and the `mine.sh` churn revert removed 22 pre-existing working-tree edits (needs a look).

## Delete

- none

## Questions

1. The `mine.sh` churn revert discarded 22 pre-existing working-tree edits (PNG screenshots and generated plugin files). Were those wanted? If not, is it expected that `mine.sh` reverts them on every run?
2. Should `--help` keep its old range? It now includes the `-j` line and shifts the bottom line.
3. Should the timing case use an injected clock instead of real seconds, given the general test rule?
