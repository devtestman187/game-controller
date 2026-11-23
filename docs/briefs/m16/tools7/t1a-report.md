# tools7 t1a report: split run-wire-test.sh, shared fixture lib, template repo, no fixed sleeps

## Summary

STATUS: done, with open items (timings not measured; see questions).

Files changed:
- `tools/tests/run-wire-lib.sh` (new, sourced, no exit): the stubs, `wire_init`, `run_wire_template` (one repo built once per script), `fixture` (a `cp -rp` copy of that template per case, plus the per-case knobs), and the helpers (`run_jobs`, `start_jobs`, `lock_pid`, `end_runner`, `logged`, `more_briefs`, `seed_report`, `stopmd`, `stop_committed`, `pass`, `fail`, `report`). The slow stub is unchanged.
- `tools/tests/run-wire-test.sh` (444 → 160 lines): cases 1-9, 12, 13 and 14 (dry run). Keeps the top `unset` block and the PASS/FAIL names. The header now says it is part 1 of 2.
- `tools/tests/run-wire2-test.sh` (new, 99 lines): cases 10 (TERM), 11 (INT), and the three review cases (waitreview, stopreview, reviewtimeout). Same top `unset` block. Its case numbers are 10, 11, 15, 16, 17; the original had duplicate 11s and 12s.

Decisions:
- Split by count, not by measured time: the harness refused to let me run the test scripts directly (approval denied), so I had no per-case times. Part 1 holds the runner-stop, churn, lock and dry-run cases; part 2 holds the signal and review-wait cases.
- Condition waits: I tried replacing the `sleep 0.3` in cases 10 and 11 with a wait on a "stub has left" marker. That made both fail in the first run, so I reverted to the original `sleep 0.3` and removed the marker. The other fixed waits (the 0.1 s polls in `lock_pid` and `end_runner`) were already condition loops. The 30 s guard sleeps and the 6 s review stubs are unchanged.
- The badreport cases commit their one extra brief line into their own copy, so the copy stays clean for the runner.

## Checks

- `tools/check.sh format`: PASS (after the final edit).
- `tools/check.sh tools` (runs `run-wire-test.sh`, `run-wire2-test.sh`, `run-gate-test.sh`, `run-jobs-split-test.sh`, `selftest-limits-test.sh` and the rest): run 2 (after the revert) FAIL only in `tools/tests/claude-worker-test.sh` ("plain flash.sh still runs the DeepSeek worker with --bare and 150 turns"). `run-wire-test.sh`, `run-wire2-test.sh`, `run-gate-test.sh`, `run-jobs-split-test.sh` and `selftest-limits-test.sh` all passed in that run. Run 1 also failed `run-wave-test.sh` (one case) and my two signal cases; run 2 passed `run-wave-test.sh`.
- Times: suite wall time 826 s (run 1) and 690 s (run 2), for the whole suite, not per script. Per-script times before and after were not measured.

## Questions

1. I could not read the run-1 log (read permission was denied), so the two signal-case failures are not diagnosed. The likely cause is that TERM/INT also kills the slow stub, so the "left" marker never appeared; the reverted `sleep 0.3` passed in run 2. Please confirm.
2. `claude-worker-test.sh` fails in run 2 and does not use the wire lib. Is it a known failure on main?
3. `run-wave-test.sh` failed in run 1 and passed in run 2. Looks flaky; not investigated.
4. Per-script wall times before and after are missing. Please run `tools/check.sh tools` with per-script timings, or grant permission to run `tools/tests/*.sh`, so the split can be balanced by measurement.
5. Stray files I created in the repo root by mistake: `orig-wire.tmp.sh`, `s1.tmp`, `s2.tmp`. They are untracked and outside the allowed list. My attempt to delete them was denied; they need removing by hand or by the script.
6. Not done: the stub-text diff against HEAD (`sed` needed approval). The tools run passing is the only check that the stubs were copied correctly.

## Commit message — a draft

Split run-wire-test.sh and share one fixture lib

Move the wire tests' stubs and helpers to run-wire-lib.sh. Build one
template repo per script and copy it per case instead of git init and
commit each time. Split the cases into run-wire-test.sh and
run-wire2-test.sh (the signal and review-wait cases). Every case keeps
its name and its check; the top unset blocks are kept.

## Status row

t1a: split and shared lib done (run-wire-lib.sh, run-wire-test.sh, run-wire2-test.sh; tools suite green except claude-worker-test.sh). Open: per-script timings not measured, and the claude-worker-test failure needs a main-branch check.

## Delete

- none
