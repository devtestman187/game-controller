# p4e report: estimate floors (usage median, fix jobs, run backstop)

## Summary

The estimates are now floors (owner, Nov 22):

- `run_expected_min <brief>` is the **higher** of the brief's `expected-min:` line and the job's
  usage median (last `RUN_RECENT_ROWS` rows); with neither it is `RUN_EXPECT_DEFAULT_MIN` (20),
  and a brief named `f<job>` is at least `RUN_FIX_FLOOR_MIN` (25).
- `run_backstop_min <waves.txt>` is the undone jobs' estimates +25% (rounded up) and at least
  `RUN_BACKSTOP_FLOOR_MIN` (45) while a job is left; still 0 with no `waves.txt`.
- A new helper `run_usage_median_min <brief>` holds the median (its rows and its "under a
  minute is none" rule), so the estimate reads as one comparison.
- Both new knobs go through `run_number` with their defaults and are named in the header, which
  now says what each helper prints (minutes, except the job limit in seconds).

Test counts I saw: `tools/tests/run-limits-test.sh` has 15 cases; against the old tool 11 passed
and 4 failed (below); with the new tool all 15 pass (the final `tools` run lists 14 of 15 scripts
passing and only `run-limits-wire-test.sh` failing, on a case this job may not edit — see
Blocked).

**Blocked by the allow list, not by the change:** `tools/tests/run-limits-wire-test.sh` case 4
(line 148-156) expects `RUN_MAX_MIN=25 min` for a one-job run whose brief has no line (20-min
default x1.25). The owner's backstop floor makes that run 45 min, which is exactly the case the
floor was asked for, so that expectation is stale. The file is outside `allow:`, so I did not
touch it; with it unedited `tools/check.sh tools` fails. The whole fix is that one case:

```sh
# 4. The run's limit without RUN_MAX_MIN: the backstop of the one job (20 min, its default,
#    x1.25 = 25, raised to the 45 min floor), logged once; the preflight runs through FLASH_CMD.
...
  logged "RUN_MAX_MIN=45 min" && [ -f "$STUB_MARK" ] && ! logged "RUN_MAX_MIN=360"; then r=0; else r=1; fi
report "the computed backstop is the logged RUN_MAX_MIN (one job, 20 min default -> 45 min, the floor) ..." "$r"
```

No other script reads the backstop or the estimates by value (`run-wire-test.sh` passes
`RUN_MAX_MIN=360`, `process3-fix1-test.sh`/`run-base-test.sh` leave it computed but assert only
on job limits and check order, and their jobs are over the floor or stopped by their own limit).

## What changed

`tools/run-limits.sh`

- `run_is_fix_job <brief>`: true when the brief's basename (without `.md`) matches `^f[0-9]+$`.
- `run_usage_median_min <brief>`: the old median block, now its own helper; it prints nothing
  when the job has no rows or when the median is under a minute (`m < 1` before rounding, so a
  40 s median no longer becomes "1 min").
- `run_expected_min`: brief line, then `max` with the median, then the 20 default, then the fix
  floor. The old rule "the brief line wins, the median is only a fallback" is gone.
- `run_backstop_min`: computed as before, then raised to `RUN_BACKSTOP_FLOOR_MIN` when at least
  one job is left (a run with every job done keeps 0: there is nothing to wait for).
- Header: four helpers described, `RUN_FIX_FLOOR_MIN 25` and `RUN_BACKSTOP_FLOOR_MIN 45` added
  to the knobs with the owner's date, and the median helper's "under a minute" rule stated.
  121 lines (was 85).

`tools/tests/run-limits-test.sh`

- Header now states the floors.
- Nine new cases (4-12), each a fixture of its own under `$tmp/floors`, `$tmp/one`,
  `$tmp/three` and one usage log, `$tmp/floors-usage.tsv`; the old cases 5 and 6 became 14 and
  15. 15 cases total (was 6).

## Computed values (reporting every expectation)

| Case | Input | Arithmetic | Want |
| --- | --- | --- | --- |
| 4 | brief20 line 20, rows 1800 s + 1800 s | median 30 > 20 | 30 |
| 5 | brief40 line 40, rows 600 s + 600 s | median 10 < 40 | 40 |
| 6 | nobrief no line, rows 720 s + 720 s | median 12, no brief line | 12 |
| 7 | f2.md line 10, no rows | 10 -> fix floor | 25 |
| 8 | f2b.md line 40 | 40 > floor 25 | 40 |
| 9 | fx.md line 10 | basename `fx` does not match `^f[0-9]+$` | 10 |
| 10 | one job, line 15 | 15 x 1.25 = 18.75 -> 19, floor | 45 |
| 11 | t1 t2 t3, 40 each | 120 x 1.25 | 150 |
| 12 | RUN_LIMIT_UNIT_S=1, brief20 + one 15-min job | minutes stay minutes | 20 and 45 |
| 1 (old) | a 10 + b 20 + e default 20 | 50 x 1.25 = 62.5 -> 63, over floor | 63 |
| 2 (old) | 10+20+4+6+20 | 60 x 1.25 | 75 |
| 3 (old) | f 7, g rows 600 s + 1200 s, h none | 7, median 900 s = 15, default | 7, 15, 20 |
| 13 (old) | a 10 x 150% in 60 s and 1 s units | 900 s; 15 | 900, 15 |

## Tests-first (exempt: shell tool)

The brief's `tests-first: exempt (shell tool)` applies. I extended the test first and ran the
suite against the old tool; `tools/check.sh --verbose tools` printed:

```
| FAIL  tools/tests/run-limits-test.sh (11s)
|   FAIL a brief line under the usage median is raised to the median (brief 20, median 30 -> 30)
|   FAIL an f<job> brief gets the fix floor whatever its line says (f2 brief 10 -> 25)
|   FAIL the run backstop has a floor for a one-job run (one 15-min job -> 45)
|   FAIL the minute helpers print minutes at RUN_LIMIT_UNIT_S=1 (estimate 20, backstop 45)
| RESULT: FAILED: 1 of 15 script(s) failed (14 passed, 404s)
```

(The other five new cases pass on the old tool too, because the old code happens to agree with
them: a brief over the median, the median alone, a fix brief over the floor, a non-fix name, and
three 40-min jobs.)

## Decisions

1. The backstop floor needs a job left (`total > 0`): a run where everything is done or dropped
   keeps its 0, so the runner is not given 45 min to wait for nothing.
2. "A median under a minute counts as none" is applied to the raw median (seconds / 60 < 1), not
   to the rounded one, so a 40 s median stays none instead of becoming 1 min; the job then uses
   its brief line, else the 20-min default. This is the one place I read the owner's wording more
   strictly than the old code.
3. The fix floor keys on the brief's basename only, so an `f<job>` whose brief is missing still
   gets 25 (the name is what the owner's rule matches).
4. `RUN_BACKSTOP_PCT` stays a plain constant: the owner named only the two new knobs, and every
   knob the header lists is still one a job may override.
5. The median moved into its own helper rather than staying inside `run_expected_min`: the new
   estimate needs it as a value to compare, and case 12 can then show it prints minutes at
   `RUN_LIMIT_UNIT_S=1`.

## Self-check (review-rules part A)

1. Host setup: not applicable, this is the runner's shell tooling; the runner cases that host a
   job (overlimit, turn cap, backstop) are the old cases 1-3 of run-limits-wire-test.sh, which
   still pass except case 4 (Blocked).
2. Kept state: none; `run-limits.sh` is sourced and sets variables only.
3. Pause menu, host away, player away, get ready, dropped link, results, leaving: not applicable
   (no game state).
4. Stayed inside `allow:`: only the two scripts and this report changed.
5. Stopped rather than overstepped: `tools/tests/run-limits-wire-test.sh:148-156` needs its
   25 -> 45 expectation; it is outside `allow:` and is why the check fails.
6. Looks: no UI, so neither look applies; no look-sized widget involved.

## Checks run

- `tools/check.sh tools` (old tool, extended test): FAIL tools, 404 s, run-limits-test 11 s with
  the four FAIL lines above.
- `tools/check.sh tools` (new tool): FAIL tools, 410 s, log at
  `.../thumbparty-check-20261122-115721/tools.log` (not readable from the job folder).
- `tools/check.sh --verbose tools` (new tool, the final check): FAIL tools, 408 s:

```
| FAIL  tools/tests/run-limits-wire-test.sh (35s)
|   FAIL the computed backstop is the logged RUN_MAX_MIN (one job, 20 min default -> 25 min) and FLASH_CMD ran the preflight
| RESULT: FAILED: 1 of 15 script(s) failed (14 passed, 407s)
```

  Run-limits-test.sh passed all 15 cases in that run. `tools/mine.sh` was not run: it formats,
  analyzes and tests the touched Dart files, and this job touches none.

## Questions

1. Who fixes `tools/tests/run-limits-wire-test.sh` case 4 (25 -> 45, comment and case name)?
   It needs a two-line edit and is the only thing between this change and a green `tools` check.
   It could ride in a tiny follow-up job, or be added to this job's allow list.
2. Should a run with every job done or dropped keep 0 (my choice) or also get the 45 floor? The
   runner exits in that case, so I kept 0.
3. `docs/dev-tools.md` does not name the two new knobs; that file is outside `allow:`, so a docs
   job should add them (with `RUN_FIX_FLOOR_MIN` and `RUN_BACKSTOP_FLOOR_MIN`).

## Commit message

```
runner: estimate floors from usage median, fix jobs, backstop

run_expected_min now takes the higher of the brief's expected-min: line and the job's
usage median, so brief estimates that came in low (p3f 15 hit 22, f1 30 hit 45) no longer
cut a job short. A brief named f<job> is at least RUN_FIX_FLOOR_MIN (25).
run_backstop_min keeps its +25% but never allows less than RUN_BACKSTOP_FLOOR_MIN (45)
while a job is left, so a one-job run is not cut at 20 min.
The median moved into run_usage_median_min, and the header names both new knobs.
tools/tests/run-limits-test.sh gains nine cases; all fifteen pass.
```

## Status row

M16 p4e: estimate floors (usage median, fix job 25 min, backstop 45 min) done and tested in
tools/run-limits.sh; open: tools/tests/run-limits-wire-test.sh case 4 still expects the old
25-min backstop, so `tools/check.sh tools` fails until that one case is updated.

## Delete

- none
