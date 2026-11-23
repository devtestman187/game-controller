# M16 tools7 t1c report: cheaper, load-tolerant runner shell tests

STATUS: stopped. The edits are made and checked by reading, `bash -n` and `tools/check.sh format` (PASS). The test runs were not executed: every `bash tools/tests/<script>` call (run-limits-wire, run-wave, and a first attempt at each) returned "This command requires approval". I did not bypass that gate. Nothing below is a measured "after" value.

## Files changed

- `tools/tests/run-limits-wire-test.sh`: the fixture repo is built once by `build_template` into `$tmp/template/repo`; `fixture` makes `$base/repo` with `cp -r` and commits its own brief (`--allow-empty`, so the default-brief case still commits). Cases 2, 3 and 4 no longer set `STUB_SLEEP_S=1`: the default is already empty, and cases 3 and 4 of run-wave already run that way. Case 1 keeps `STUB_SLEEP_S=30`: its kill is what ends the sleep, so the length costs no time while the kill works, and a shorter sleep would only shrink the margin. The top `unset` block is unchanged (run-gate-test's leak case reads it). Header comment updated. No assertion changed.
- `tools/tests/run-wave-test.sh`: the same template approach (`build_template`, `fixture` copies it with `cp -r`); the template holds the default brief and the `base` commit, so no extra brief commit is needed. Case 1 bound changed from `elapsed_s -lt 20` to `elapsed_s -lt 30` (the stub's own sleep), plus `! -e $repo/$batch/hang-report.md`: the stub writes that report only after its 30 s sleep, so its absence proves the runner did not wait for the stub, whatever the load. The 24 s observed under load is below 30 but close, which is why the file check is the real proof. The 25 s to 1 s `sleep` stub and the sleeps in the flash stub are unchanged.
- `docs/briefs/m16/tools7/t1c-report.md`: this report.
- `tools/tests/mine-test.sh`: not changed. Its base repo was already built once. I have no measured cost for the per-case `cp -a` or the `git update-index`, and the brief allows changes only where measurement shows one. Its hang stub (`exec sleep 30`) costs nothing while `MINE_TIMEOUT` kills it, so I left the stub alone.

## Seconds before and after

| script | before (brief, under load Nov 23) | after |
|---|---|---|
| run-limits-wire-test.sh | 49 | not measured (runs refused) |
| run-wave-test.sh | 55 | not measured (runs refused) |
| mine-test.sh | 34 | not measured (unchanged file) |

## Checks

- `tools/check.sh format`: PASS.
- `bash -n` on run-limits-wire-test.sh and run-wave-test.sh: no output (parses).
- Not run: the three scripts (twice each), `tools/tests/run-gate-test.sh` (leak case) and `tools/tests/run-limits-test.sh`. The bare command is refused by the approval gate in this session.

## Computed values

None yet: the expectations (elapsed under 20 s for run-limits-wire case 1, under 30 s and no report for run-wave case 1) were not evaluated.

## Items for the reviewer

- Poll step (item 3): the three scripts have no fixed sleep that waits for a file or a log line. Their only sleeps are stub sleeps and the runner's 25 s wait, which the run-wave stub already shortens. No poll was added.
- Fixed sleeps `sleep 25` (runner) and the stub `sleep 30` are unchanged, pending a measured run.

## Questions

1. The approval gate refused every `bash tools/tests/...` run. Can the three scripts and the two follow-up tests be run by approval or from another session? Until then this job is not verified.
2. Should run-wave case 1 keep the 30 s bound, or should the 25 s runner wait be made configurable so the bound can be tighter?

## Suggestions

- Once the runs are allowed, measure `mine-test.sh` per case before any change there.

## Commit message — a draft

tools7 t1c: fixture repo built once; run-wave case 1 load-tolerant

Build the runner test fixture once per script (run-limits-wire, run-wave) and copy it with cp -r
per case, instead of a git init and commit for each case. Cases keep their names and assertions.
run-wave case 1 bounds the wait at 30 s (the stub's sleep, not 20 s) and checks that the parked
job's report was never written, so a wait on the stub fails whatever the load. Stub sleeps of the
run-limits-wire cases 2-4 use the empty default. mine-test is unchanged: no measured cost.
Not yet run: the scripts are refused by the approval gate in this session.

## Status row

M16 tools7 t1c: run-limits-wire and run-wave copy one fixture repo per case, run-wave case 1 is load-tolerant; edits checked by bash -n and format; done: edits. Open: run the three scripts twice each, run-gate and run-limits tests, record after-seconds (baselines 49/55/34).

## Delete

- none
