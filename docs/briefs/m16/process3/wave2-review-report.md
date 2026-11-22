# Wave2 review: p3d, p3e (process3)

## Summary

Verdict: **small fixes** — both jobs do what their briefs ask, stay inside `allow:`, and no functional bug turned up; the costs are a knob the docs offer and the code ignores, two uncommitted edits the green tool suite depends on, and three report statements the code contradicts.
Counts: 0 must, 6 should, 8 could.
1. **Should** tools/run-jobs.sh:98 — `RUN_TURN_CAP=120` overwrites any value in the environment, although docs/dev-tools.md:448 and the runner's header (:73) present it as a knob.
2. **Should** tools/tests/run-jobs-split-test.sh:177 — the 340->380 fix that makes the tools suite pass exists only as an uncommitted edit (run.log:21 HAND-FIX), so p3d's open item is closed on this PC and open in every commit.
3. **Should** docs/briefs/m16/process3/p3d-report.md:58 — Decision 2 says a computed backstop of 0 becomes 360 and that `RUN_EXPECT_DEFAULT_MIN` is deliberately not used; tools/run-jobs.sh:246 floors it to `RUN_EXPECT_DEFAULT_MIN` (20 min).

## Findings

- **should** tools/run-jobs.sh:98 `RUN_TURN_CAP=120` is a plain assignment, so a `RUN_TURN_CAP` in the environment is silently replaced by 120 although docs/dev-tools.md:448 and the header at :73 name it as a knob → `RUN_TURN_CAP=${RUN_TURN_CAP:-120}`, or list "a constant, not a knob" as a decision.
- **should** tools/tests/run-jobs-split-test.sh:177 the sizes case allows 380 only in the uncommitted working tree (run.log:21 records the HAND-FIX; `git show --stat 269882af` does not include the file), so on a fresh checkout `tools/check.sh tools` still fails p3d's 368-line runner → commit the 340->380 edit (and tools/run-limits.sh:40's 12->20 one), and say so in p3d-report.md:140 instead of "Blocked".
- **should** docs/briefs/m16/process3/p3d-report.md:58 Decision 2 says a computed backstop of 0 falls back to 360 and that `RUN_EXPECT_DEFAULT_MIN` was not used, while tools/run-jobs.sh:246 floors that value to `RUN_EXPECT_DEFAULT_MIN` and :243's comment says so → rewrite Decision 2 and Question 4 (:155) to describe the 20-min floor and why it is there.
- **should** docs/briefs/m16/process3/p3d-report.md:96 the row "this batch ... 219 min" is the all-six-undone figure; done.txt lists p3a-p3c, so the same call is 80 x 125% = 100 min (and 0 -> floored to 20 once p3d-p3f are done) → replace 219 with 100.
- **should** docs/briefs/m16/process3/REHEARSAL.md:20 run 6 cannot end in `STOPPED: TIMEOUT`: `run_backstop_min` gives (2 x 125 + 99) / 100 = 3 min for two `expected-min: 1` jobs, tools/run-jobs.sh:246 raises that to 20, tools/run-steps.sh:217 counts real minutes (20 x 60 s), and the 1 s job limit at tools/run-jobs.sh:315 fires first → expect `job r1 passed its limit (1 min, estimate 1)`, or give run 6 a long job limit so the run's own limit is what ends it.
- **should** docs/briefs/m16/process3/p3e-report.md:113 the tests-first line admits the test was never run against a tree without tools/fake-flash.sh ("reasoned from the script's calls, not run"), which the brief asked for → run `bash tools/tests/fake-flash-test.sh` from the base commit and quote its FAIL and RESULT lines.
- **could** tools/run-jobs.sh:74 the header (and docs/dev-tools.md:448's "Every run's last line is ...") promise a `RESULT:` line on every exit, but `--drop` exits at :115 and `--dry-run` at :217 with none → print one on both, or narrow the promise to "every run that starts".
- **could** docs/dev-tools.md:448 the backstop sentence has no minimum, so a restart whose jobs are all in done.txt logs "RUN_MAX_MIN=20 min" (tools/run-jobs.sh:246) although the sentence reads "the estimates of the jobs still to do, +25%" → add the floor.
- **could** docs/dev-tools.md:149 the tests list names ten scripts and omits `fake-flash-test.sh`, and no dev-tools section names `tools/fake-flash.sh` (only REHEARSAL.md:8 does) → a docs job adds the test and a paragraph on the stand-in.
- **could** docs/briefs/m16/process3/p3d-report.md:115 repeats wave1's "review.sh is not in this job's allow:, so I did not run it"; allow: bounds the files a job writes, not the commands it runs, and tools/review.sh only reads → drop the sentence or run it and report the result.
- **could** docs/briefs/m16/process3/REHEARSAL.md:17 run 3 expects `STOPPED: r1 used 121 turns, cap 120`; the runner prints `job r1 used 121 turns, over its cap of 120` (tools/run-jobs.sh:175) → put the runner's words in the row.
- **could** tools/tests/run-limits-wire-test.sh:155 `[ -f "$STUB_MARK" ]` cannot tell the preflight call from the job call (the stub appends the same `flash` line to both at :45), so the case name's "FLASH_CMD ran the preflight" is only implied by the note → have the stub record `$1` and assert two lines, `--preflight` and `--brief`.
- **could** tools/tests/fake-flash-test.sh:9 the header says "no case sees another's files", but the cases at :78 and :172 inspect the `report` fixture's folder → say that those two cases continue the first run.
- **could** tools/fake-flash.sh:58 `-h`/`--help` is not in the brief (it names `--brief` and `--preflight`) and no decision lists it → keep it and note it, or drop it.

## Decisions to confirm

- `RUN_TURN_CAP` is a constant in the code and a knob in the docs (finding 1): pick one before a rehearsal raises it.
- The computed backstop floors at `RUN_EXPECT_DEFAULT_MIN` (20 min) rather than 360, and it counts the estimates only: for this batch it is 100 min while one combined check alone takes about 12 min on this PC (run.log:41), so the run's limit may stop a healthy restart during the checks.
- A brief's `turns: <n>` replaces the cap, so `turns: 60` tightens a job (p3d's Decision 8) although the brief says "raises it".
- The DONE line counts the jobs written in `waves.txt` (dropped, done and skipped ones included), not those committed in the run (p3d's Decisions 6 and Question 3).
- `FLASH_CMD` is interpolated unquoted (tools/run-jobs.sh:272, :296), so a stand-in path with spaces cannot be used (p3d's Decision 9).
- tools/fake-flash.sh:88 defaults `FLASH_USAGE_LOG` to the real `~/.thumbparty/flash-usage.tsv`: a rehearsal that forgets the variable writes fake rows into the log `run_expected_min` reads.
- p3e writes `## Commit message`, `## Status row` and `## Delete` beyond the brief's two sections because the commit walk needs them — confirm the extras stay.

## Could not check

- Could not run any script: the harness refused `bash tools/tests/fake-flash-test.sh`, `bash tools/tests/run-limits-wire-test.sh`, `tools/check.sh` and sourcing tools/run-limits.sh, so every PASS/RESULT/time line in the two reports, and the 100-min figure for this batch, are theirs plus my arithmetic from done.txt and waves.txt, not a run. `bash -n` passes on tools/run-jobs.sh, tools/fake-flash.sh and tools/tests/run-limits-wire-test.sh.
- `docs/briefs/m16/process3/run-findings.md` does not exist, so there are no "passes on the old code" entries for these jobs; from reading the code, each of the four wire cases asserts a line or file the old runner lacks (the job limit, both turn-cap stops, the backstop log, `RESULT: DONE`), so none should pass on it.
- The 12-min combined check on this PC (run.log:41) and the two reports' suite times are not things I measured.

## Commit message

```
Review wave2 (p3d-p3e): 0 must, 6 should, 8 could, findings only

Read both briefs, both reports, run.log and the diff 9a7e5492..c013ff71
against docs/coding-guidelines.md and docs/review-rules.md.
No functional bug: the job limit, turn cap, RESULT line, FLASH_CMD and
the stand-in worker do what the briefs ask and stay inside allow:.
The shoulds: RUN_TURN_CAP cannot be set although docs call it a knob,
the 340->380 split-test fix is uncommitted, p3d's Decision 2 and its
219-min row differ from the code (20-min floor, 100 min), the stand-in
test was never run against the old tree, and REHEARSAL run 6 cannot
show TIMEOUT. No script could run here.
```

## Status row

**Wave2 review (Nov 22):** p3d and p3e reviewed against their briefs, the coding guidelines and review-rules part A; findings only (no code changed): 0 must, 6 should, 8 could. Open: `RUN_TURN_CAP` as a knob or a constant, committing the uncommitted split-test/`RUN_CHECK_MAX_MIN` edits, p3d-report's 360 fallback and 219-min row, the stand-in test's old-tree run, and REHEARSAL rows 3 and 6.

## Delete

- none
