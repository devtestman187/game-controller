# Wave1 review: p3a, p3b, p3c (process3)

## Summary

Verdict: **small fixes** — each job does what its brief asks, stays inside its `allow:` list and leaves no
functional bug I can find; the findings are one wrong number handed to p3d, two defaults that disagree, an
untested review limit, stale docs and leftovers.
Counts: 0 must, 7 should, 9 could.
1. **Should** docs/briefs/m16/process3/p3c-report.md:112 — the hand-over's "219 min for process3 today" is
   stale: with done.txt as it now stands the same call returns 100, and a p3d test copied from 219 fails.
2. **Should** tools/run-limits.sh:42 — the no-estimate default is 20 min here and 15 in tools/wait-run.sh:44,
   so wait-run warns OVERRUN at 22.5 min while p3d's job limit for the same job will be 30 min.
3. **Should** tools/run-review.sh:99 — the new review limit has no test at all.

## Findings

- **should** docs/briefs/m16/process3/p3c-report.md:112 the hand-over tells p3d "219 min for process3 today", but done.txt now lists p3a-p3c, so `run_backstop_min docs/briefs/m16/process3/waves.txt` returns 100 (p3d 45 + p3e 20 + p3f 15 = 80; (80 x 125 + 99) / 100 = 100), and a p3d case copied from 219 fails → give both numbers (219 with all six jobs undone, 100 after this wave) or drop the number.
- **should** tools/run-limits.sh:42 `RUN_EXPECT_DEFAULT_MIN` is 20 while tools/wait-run.sh:44 keeps `WAIT_EXPECT_DEFAULT_MIN` 15, so for a job with no `expected-min:` line and no usage rows the driver is told OVERRUN at 22.5 min while p3d's own job limit will be 30 min (20 x 150%), and the two tools now disagree about the same job → share one default (wait-run.sh calling run-limits.sh, as p3c-report.md:136 suggests) before p3d wires the job limit.
- **should** tools/run-review.sh:99 `review_over` and its `REVIEW TIMEOUT` stop have no test: nothing in tools/tests/run-limits-test.sh sources run-review.sh, so a typo in the limit or in the `RUN_LIMIT_UNIT_S` arithmetic ships uncaught → add a case with `RUN_REVIEW_MAX_MIN=1`, `RUN_LIMIT_UNIT_S=1` and a start time two seconds old that asserts `review_over` turns true and false at the boundary.
- **should** tools/run-limits.sh:32 `run_number` keeps the default for any malformed `RUN_*` value (a typo such as `RUN_CHECK_MAX_MIN=1O` silently gives 12), a fallback that is not in the p3c report's Decisions and contradicts tools/check.sh:32-39, which refuses a bad `CHECK_FAIL_FAST` with exit 2 → print the refused value and exit, or list the silent fallback as a decision.
- **should** docs/dev-tools.md:149 the tools docs still list seven self-tests (no wait-run3-test.sh, check-failfast-test.sh, selftest-limits-test.sh, run-limits-test.sh) and at :164-167 describe wait-run.sh's exit 2/4 text and `WAIT_STATE_DIR` without the overrun record, the checking sentence or the resume rule, while :40-46 and :150 omit `--fail-fast`, `CHECK_FAIL_FAST`, `CHECK_DART`, `CHECK_FLUTTER` and `SELFTEST_TIMEOUTS` even though tools/check.sh:4 says it is documented there → a docs job (outside all three `allow:` lists) should update those four passages.
- **should** tools/tests/wait-run3-test.sh:27 `fail()` (and `now()` at :53) are defined and never called, leftovers in a new file → delete both.
- **should** tools/tests/wait-run3-test.sh:79 the "a new run reports the same job's OVERRUN again" case passes on the old tool too (p3a-report.md:48 says so), so it proves nothing about the new record's reset → after the new run's exit 2, add a second call and assert exit 4 with `, overrun already reported`, which fails without the record.
- **could** tools/selftest.sh:36 the help range `2,20p` now stops one line before the header ends, so `-h` loses line 21 ("Works in Git Bash on Windows and bash on macOS/Linux"), which the old range `2,18p` kept → use `2,21p`.
- **could** tools/selftest.sh:53 a space after a comma (`SELFTEST_TIMEOUTS="a=5, b=6"`) makes the name " b", which matches no basename and is accepted silently, so that limit never applies → trim leading spaces or refuse whitespace in an entry.
- **could** tools/wait-run.sh:186 `seen_add` appends to the overrun file with no `2> /dev/null`, while `seen_reset` (:180) and `seen_has` (:184) discard their errors, so a read-only `WAIT_STATE_DIR` prints a shell error on every OVERRUN although p3a-report.md:72 claims that fallback is quiet → redirect it the same way.
- **could** tools/run-limits.sh:5 the header says "tools/run-jobs.sh and its helpers ... source it after the cd to the repo root", but tools/run-jobs.sh does not source it in this commit (p3d adds that) → name only run-steps.sh and run-review.sh until p3d lands.
- **could** tools/wait-run.sh:142 the anchored `rest ~ /^start /` (with the `resume`/`committed` matchers) also removes the bogus job a stopped line used to create, a fourth change outside the brief's three defects, and no case exercises the line it fixes → add a case whose run.log holds a `STOPPED: ... counted from the last 'start at' line` note, or list the fix as a decision.
- **could** tools/tests/wait-run3-test.sh:101 case 3 makes two calls of a full 2 s window (~4 s), over the brief's "each case under about 3 s" (the whole script is 18 s, under 20) → assert the commit line with a single call, or accept 4 s and say so.
- **could** tools/run-review.sh:111 the `note "start the run's review"` line is parsed as a job start by tools/wait-run.sh:142-146 (p3a's Question 1), so during the final review the exit-4 line says "the run's review for n min" and OVERRUN can fire on it, and the new `checking` sentence never shows then → skip that line in `unfinished_jobs`, or log the review as something the parser ignores.
- **could** docs/briefs/m16/process3/p3c-report.md:91 says `tools/review.sh` was not run because it is "not in the allow list", but `allow:` bounds the files a job writes, not the commands it runs, and review.sh only reads → run it next time and report the result (its `in_scope` at tools/review.sh:65-76 skips `.sh`, so the 0-fail claim is trivially true either way).
- **could** tools/check.sh:105 the PATH refusal is now two lines naming `CHECK_DART`/`CHECK_FLUTTER` instead of one naming docs/building.md, an output change no decision in p3b-report.md lists (only test case 8 asserts it) → add it to the report's Decisions, or keep the old sentence's shape.

## Decisions to confirm

- p3c's `run_job_limit_s` takes a brief path (p3c-report.md:37) where the brief listed it without an argument: p3d will call `run_job_limit_s "$B/$j.md"` — confirm the signature.
- The guarded source (tools/run-steps.sh:11, tools/run-review.sh:13) makes a tree without run-limits.sh run with no per-step limit and no warning, which is what keeps the two fixture tests green — confirm the silence and that p3d copies run-limits.sh into every new fixture.
- p3b's fail-fast also skips analyze and every later check when `format` fails (tools/check.sh:149-153), and exits 2 on a bad `CHECK_FAIL_FAST` — confirm both are wanted.
- p3a's fourth fix, the anchored log parsing (tools/wait-run.sh:136-146), is outside the brief's three defects — confirm it stays.
- Three knobs beyond the brief's five: `RUN_LIMIT_UNIT_S` (the test needs it), `RUN_RECENT_ROWS` and `FLASH_USAGE_LOG` (tools/run-limits.sh:44-46) — confirm the last two.
- p3a dropped the preflight case to stay under 20 s, so nothing now tests `preflight (no job started yet)` (tools/wait-run.sh:238-240) — confirm that is acceptable.
- Wave reviews still have no limit of their own (`start_reviews`, p3c's Question 2) — decide whether a stuck wave review may keep holding a slot.

## Could not check

- Could not run anything: `bash tools/tests/wait-run3-test.sh` (and the other three new scripts) and `bash tools/check.sh tools` were refused by the harness for approval, so every PASS/RESULT line quoted in the three reports (18 s, 8 s, 12 s, 7 s, 250-279 s) is their claim, not mine.
- Could not see the combined tree after the wave: run.log shows the three commits and no check PASS lines, so the 11-script `tools` suite is not evidenced anywhere I can read (the three workers each saw 8, 9 and 8 scripts, as their reports say).
- Could not judge how the three p3a states feel on a live batch (REHEARSAL rows 4 and 7); no batch ran here.
- `tools/review.sh` cannot see `.sh` files (tools/review.sh:65-76), so p3a's and p3b's "review.sh: 0 fail" statements carry no information about these diffs.

## Commit message

```
Review wave1 (p3a-p3c): 0 must, 7 should, 9 could, findings only

Read the three briefs, their reports and the diff 88bad26f..0eb48804
against docs/coding-guidelines.md and docs/review-rules.md.
No functional bug: the fixes do what the briefs ask and stay inside
their allow: lists. The shoulds: a stale 219-min backstop handed to
p3d (it is 100 now), two different no-estimate defaults (20 vs 15),
an untested review limit, a silent RUN_* typo fallback, stale
docs/dev-tools.md, two dead helpers and one case that passes on the
old code. No script could be run here, so PASS lines are the reports'.
```

## Status row

**Wave1 review (Nov 22):** p3a-p3c reviewed against their briefs, the coding guidelines and review-rules part A; findings only (no code changed): 0 must, 7 should, 9 could. Open: p3c-report.md:112's 219-min hand-over number (100 now), one shared no-estimate default before p3d, a test for the review limit, docs/dev-tools.md, and p3a's two leftovers in wait-run3-test.sh.

## Delete

- none
