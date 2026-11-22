# p3a report: tools/wait-run.sh three fixes

job: M16 process3 p3a: tools/wait-run.sh three fixes (OVERRUN once, "checking" state, resume as a job start)
tests-first: exempt (shell tool) — the new test ran against the OLD tool first and showed the FAIL lines quoted below.

## Summary

Fixed the three defects the owner named, only in `tools/wait-run.sh` (331 lines, was 280); the runner and
every other file are untouched.

1. **OVERRUN once per job.** The call that first finds a job past 1.5 x its expected minutes still exits 2
   with the same `OVERRUN:` line; it records the job in `WAIT_STATE_DIR/<name>.overrun`. A later call of
   the same run skips that job in `overrun()`, waits its whole window and ends with
   `RESULT: running: <job> for <n> min (expected ~<m>), overrun already reported` (exit 4). A later
   `start at` line (a restart) resets the record, so the job is reported again once in the new run.
2. **"checking" state.** With no unfinished job but at least one job line, the exit-4 result now says
   `RESULT: running: checking: the combined check for <n> min`, `<n>` counted from the run's last
   `<job> finished: result` or `committed <job>:` line. With no job line yet it still says
   `preflight (no job started yet)`.
3. **resume = job start.** `unfinished_jobs` now records a `resume <job> (applied by hand, not committed
   yet)` line as that job's start (its own timestamp) and ends a job at its `finished: result` or
   `committed <job>:` line, so a resumed job shows as running (and can OVERRUN) until its commit.

Also: the job parsing is now anchored after the runner's timestamp (`rest`), so a `STOPPED: TIMEOUT: ...
counted from the last 'start at' line` line no longer registers a bogus job named after the whole line.

New test `tools/tests/wait-run3-test.sh` (4 cases, 124 lines): OVERRUN once then acknowledged and the
window really waited; a new run reports it again; the checking text after the last job's commit line; a
resume shown running then turning to checking at its commit line. Whole script 18 s (windows of 2 s,
poll 1 s, no longer sleeps).

Decision: `checking` counts from the last job **line** (finished or committed), because the runner logs no
"check started" line; the commit line is the last thing before `checks` (tools/run-jobs.sh:301,293) and a
resumed job has no other end. Decision: the acknowledgement is a suffix on the exit-4 sentence
(`, overrun already reported`), so the `<job> for <n> min (expected ~<m>)` text and its readers stay valid.

## Checks run

Tests-first proof (the new script on the unchanged tool, from `tools/check.sh --verbose tools`): 5 cases
then, 3 failed as they should, the other 7 tools scripts (`wait-run-test.sh` included) passed.

```
FAIL OVERRUN is reported once (exit 2), then the next call says so and waits the window (2s, exit 4) (rc=2, last: RESULT: OVERRUN: e has run 10 min, expected ~2 (1.5 x is 3 min))
FAIL after the last job's commit line the result says the combined check for 26 min (exit 4) (rc=4, last: RESULT: running: preflight (no job started yet) for 30 min (expected ~15))
FAIL a resume line shows its job running for 12 min (expected ~9), then its commit line turns to checking (rc=4, last: RESULT: running: preflight (no job started yet) for 12 min (expected ~15))
```

The two cases covering unchanged behaviour passed on the old tool too: "a new run reports the same job's
OVERRUN again" (expected) and the preflight case, since dropped for the 20 s limit (see Questions 2).

After the fix:

- `tools/check.sh tools` — **PASS** on the final tree (279 s), 8 scripts, including the changed
  `wait-run-test.sh` (49 s, all cases pass) and the new `wait-run3-test.sh` (18 s, 4 of 4 cases; an earlier
  verbose run took 261 s and printed every script's PASS line).
- `tools/review.sh` (working diff) — `review: 0 fail, 0 note`.

Computed values the tests assert: OVERRUN at `ago 10` with `expected-min: 2` → elapsed 600 s > 1.5 x 120 s;
`1.5 x is 3 min`; the acknowledged call really waits (measured 2 s window, allowed 2-9 s); checking `26 min`
from a line at `ago 26`; resume `12 min` from `ago 12` with `expected-min: 9` (720 s < 1.5 x 540 s, so no
OVERRUN interference) and `1 min` from `ago 1`; preflight default `expected ~15` (WAIT_EXPECT_DEFAULT_MIN).
Case count: 4 cases, 4 passed.

## Self-check (docs/review-rules.md part A)

1. **Host setups** — not affected: a shell tool that reads run.log, no app code, no UI.
2. **Kept state** — the overrun record `WAIT_STATE_DIR/<briefs-dir, / as _>.overrun` (first line
   `run <start at line number>`, then one job name per line): created/reset on a call's first look at the
   run (`seen_reset` before the loop and at each loop top); cleared for good when a later `start at` line
   moves the run on; with no overrun it holds only the header line. Tests: "OVERRUN is reported once ..."
   (no second exit 2), "a new run reports the same job's OVERRUN again" (header reset). The position file
   is unchanged. A read-only state folder leaves the old behaviour (OVERUN every call), since the record
   is an aid, not a contract.
3. **New state x other states** — not affected (no pause menu, host away, players, links); the analogous
   race is a job finishing while the waiter naps: `run_ended` is checked before `running_text` every loop,
   covered by "a DONE line ends the wait at once (exit 0)" in `wait-run-test.sh`.
4. **Stay in the job's folder** — only `tools/wait-run.sh`, `tools/tests/wait-run3-test.sh` and this
   report changed (`git status --short`: those two plus the pre-existing tv_test_app generated churn).
5. **Stop rather than overstep** — the runner (`tools/run-jobs.sh`) would need no change for these fixes,
   and none was made; no file outside `allow:` was touched.
6. **Every look** — not affected (no widgets).

## Questions / suggestions (for Claude; not acted on)

1. `note "start the run's review"` (tools/run-review.sh:100) is parsed as a job start too, so during the
   final review the exit-4 line names `the run's review for <n> min (expected ~15)` and OVERRUN can fire on
   it. Out of this brief's three defects; a one-line exclusion in `unfinished_jobs` (or a `start review`
   wording the parser skips) would fix it, with a test.
2. No automated case now guards the `preflight (no job started yet)` branch: keeping it pushed the script
   to 21 s against the brief's 20 s limit, so it was dropped. Worth one if the limit grows or the windows
   shrink.
3. The checking window includes the commit of the last job (and of a resumed job), so a slow commit reads
   as checking; if the runner ever logs a check start, counting from it would be more exact.
4. The harness refused `bash tools/tests/wait-run3-test.sh` and `bash tools/selftest.sh` (approval), so both
   test runs went through `tools/check.sh tools`, whose log carries one PASS/FAIL line per script and the
   failing script's lines. Nothing was run outside it.

## Hand-over

Unverified: how it feels on a live batch (the REHEARSAL.md rows 4 and 7 are the ones to watch: the checking
line during a long combined check, and `resume r1` shown as running until its commit). Nothing in the
runner changed, so no other job is affected. Next in this milestone: p3b-p3f.

## Commit message

```
wait-run: OVERRUN once per job, a checking result, resume as a start

OVERRUN is now recorded in WAIT_STATE_DIR after its first exit 2, so the
next call waits the window and says "overrun already reported" (exit 4); a
new start at line forgets the record. With no unfinished job the exit-4 line
says "checking: the combined check for <n> min" (from the last job's
finished/committed line) instead of "preflight (no job started yet)".
unfinished_jobs now takes a "resume <job>" line as the job's start and a
"committed <job>:" line as its end, and only matches job lines right after
the timestamp. New tools/tests/wait-run3-test.sh (4 cases, 18 s) fails on
the old tool and passes now; wait-run-test.sh unchanged and green.
```

## Status row

**process3 p3a (Nov 22):** wait-run.sh fixed and tested (OVERRUN once per job then acknowledged via WAIT_STATE_DIR; exit 4 says `checking: the combined check for <n> min` after the last job; a `resume <job>` line counts as a start to its `committed` line); new tools/tests/wait-run3-test.sh, `tools/check.sh tools` green (8 scripts, 279 s), review.sh 0 fail. Open: not yet seen on a live batch (REHEARSAL rows 4 and 7); p3b-p3f not started.

## Delete

- none
