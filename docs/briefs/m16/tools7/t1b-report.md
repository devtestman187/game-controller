# t1b report: load-tolerant, faster run-gate, wait-run, run-worker-switch and process3-fix1 tests

## Summary

STATUS: stopped. The four scripts are edited and pass `bash -n`, and `tools/check.sh format` passes.
None of the four scripts has been run: every run of a `tools/tests/*-test.sh` command was refused with
"This command requires approval", so the case results, the before/after seconds and the two-run flake check are open.
The selftest-limits-test.sh and run-jobs-split-test.sh runs are also not done.

Baselines (seconds, measured under load Nov 23, from the brief; not re-measured here):
run-gate 56 · wait-run 57 · run-worker-switch 59 · process3-fix1 42.
After-seconds: not measured (runs refused).

Decisions:
- run-gate: one template repo per kind (gate, nogate: the nogate kind has no run-gate.sh, as before), built once with
  git init and the base commit, then `cp -r` per case. The 25 s wave-gap stub now sleeps 0.1 s (was 1 s); the
  case order is what the cases read, not the timing.
- worker-switch: one template (plain) and one for the metrics case (adds tools/job-metrics.sh before the commit, as
  before). No sleep stub: the case's time is the runner's own, so only the git init and commit per case went.
- process3: one template for the script; the wave-gap stub 1 s to 0.1 s; the slow job's stub sleep 8 s to 4 s.
  The quick job keeps its 3 s sleep: at 1.5 s its limit is passed and the poll (1 s) must see it while slow still
  runs; a 2 s quick would finish before the poll sees it. Slow at 4 s outlives the parking (about 2 s) with room.
- wait-run: no git fixture exists here, so no template. Two fixed `sleep 1` waits for a waiter to start became a
  `wait_for_lock` poll (0.1 s steps, 50 at most; the case fails through `lock_seen` at the cap). The `timeout 3`
  locked case, the `--max 6` running and live cases, and the `--max 2` cases keep their limits: each asserts a
  time window or an exit code that the limit produces.
- RUN_POLL_S stays 1: run_number in run-limits.sh accepts whole numbers only.
- No shared helper added (t1a owns run-wire-lib.sh); each script keeps its own template function.
- No assertion changed; no timeout tightened.

## Summary of changes

- tools/tests/run-gate-test.sh: `template <kind> [nogate]` builds `$tmp/tpl-<kind>` once; `fixture` copies it with
  `cp -r`. The sleep stub's wave gap 25 s to 0.1 s. Header updated (the "about 15 s" claim removed).
- tools/tests/wait-run-test.sh: `wait_for_lock` helper; the `locked` and `live` cases poll for a waiter's lock
  instead of `sleep 1`, and fail on the cap (`lock_seen`). Locked case's `timeout 3` kept.
- tools/tests/run-worker-switch-test.sh: `template <kind>` (plain, metrics) built once; `fixture` copies it with
  `cp -r` and sets the case's env.
- tools/tests/process3-fix1-test.sh: `template` built once; `fixture` copies it. Gap stub 25 s to 0.1 s; slow
  job's stub sleep 8 s to 4 s; comments and header updated.

## Checks

- `tools/check.sh format`: PASS (run after the edits to run-gate, wait-run, run-worker-switch and process3; it
  reports `All checks passed (19s)`). Re-run at the end, see the summary.
- `bash -n` on the four scripts: no syntax errors.
- The four scripts, `selftest-limits-test.sh` and `run-jobs-split-test.sh`: NOT RUN. Bare `bash tools/tests/<name>`
  returned "This command requires approval" each time (run-gate twice, run-worker-switch once).
  The brief's bare-command runs and the two-run flake check need the user's approval for that command form.

## Questions

1. Approve the bare `bash tools/tests/<name>-test.sh` runs (the brief's own form): the permission check refused them
   here, so no case result, after-timing or flake check exists yet.
2. wait-run's floor is about 6 s (running) + 6 s (live) + 3 s (locked timeout) + 2 s x 3 (`--max 2` cases). Do you
   want the `timeout 3` in the locked case replaced by a TERM once the lock is seen? The case name says "TERM from
   timeout", so I kept it.
3. The brief's 'read' list names only the allowed scripts; the runner's own 25 s wave gap is a literal in
   tools/run-jobs.sh:315. A knob for it would let the tests set it instead of a stub; that is a runner change, not
   done here.

## Commit message

t1b: shorter run-gate, wait-run, worker-switch and process3 tests

Each script builds its fixture repo once and copies it per case (git init and
commit ran per case). Wave-gap stubs shorten the runner's 25 s wait to 0.1 s
in run-gate and process3; process3's slow stub sleep is 8 s to 4 s.
wait-run polls for the waiter's lock instead of sleeping 1 s; the case fails at
the cap. No assertion, name or timeout changed. Not yet run: approval needed.

## Status row

t1b: four test scripts edited (template repo per kind, 0.1 s wave gap, lock poll); format and bash -n pass; script runs and the 2-run flake check not done (approval refused); seconds after not measured. Open: run the four plus selftest-limits and run-jobs-split, record seconds.

## Delete

- none
