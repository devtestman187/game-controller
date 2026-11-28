# tooling1 run review (read-only)

## Summary

- Verdict: one fix batch
- Counts: 2 must, 4 should, 6 could
- Five that matter most:
  1. **must** `tools/verify-batch.sh:98`: "isnt fixed", "wont be fixed", "hasn't been fixed" count as CLOSED (false pass). The wave2 review said "open"; it is the other way round.
  2. **must** `f1-report.md:1` and `f2-report.md:1`: neither report has the part A self-check; f1 also has no Summary block.
  3. **should** `systest_support.dart:139-146`: the socket wait is real time (`Future.delayed`, `Stopwatch`); guideline §9 and §2 apply, and it is not in code-health.md.
  4. **should** `systest_support.dart:135`: the systest settle fix's cause was never measured; the suite is 10 s again at whole-second resolution. Needs a device check.
  5. **should** `docs/test/system-test-plan.md:9,46` and `docs/driver-kit.md:149`: both describe the old behaviour (a 40 ms wait at line 123; "no fixed, closed or answered" anywhere on the line).
- Owner questions: see Open questions 1, 3, 5.

## Findings

- **must** `tools/verify-batch.sh:98` The negation group has `isn.t|wasn.t|won.t|can.t`, which need an apostrophe slot, so "isnt", "wasnt", "wont", "cant" and "hasn't", "aren't", "doesn't", "don't" are not blanked; `fixed` then matches `grep -w` and the must line is counted closed, so an open must passes the gate → make the apostrophe optional (`isn.?t`, `wasn.?t`, `won.?t`, `can.?t`), add `hasn.?t`, `aren.?t`, `doesn.?t`, `don.?t`, and add an `isnt fixed` line to `musts-negated` (from: f2; the wave2 review said "counted as open", which is wrong)
- **must** `docs/briefs/m17/tooling1/f1-report.md:1` No part A self-check and no Summary block in the report; `f2-report.md:1` has no part A self-check either → add the six self-check lines with their tests (or "not affected") to both reports, and a Summary block to f1 (from: f1, f2; wave2 review)
- **should** `packages/party_host/test/systest/systest_support.dart:139` `_waitForSocket` waits real time with `Future.delayed` (:139, :146) and a `Stopwatch` (:142); guideline §9 forbids real time and §2 forbids delays that hide a race, and the wait predates this run → record it in `docs/code-health.md` as a known exception with an owner, or replace the wait with a socket ready signal (from: f1; across jobs)
- **should** `systest_support.dart:135` `_socketPollSlice` went from 2 ms to 10 ms on the claim that 20 chained 2 ms delays are the slowdown; tl2 wrote "not measured", and f1 did not measure it either. The suite reads 00:10 at whole-second resolution, so it cannot show a change under 1 s → mark "Fixed, unverified: needs device check" (from: tl2, f1)
- **should** `docs/test/system-test-plan.md:9` and `:46` still call the 40 ms wait at `systest_support.dart:123` open, with "to-do: poll on a condition"; the poll is in, the line has moved, and the suite still waits 40 ms per socket settle → say what is true now (from: across jobs)
- **should** `docs/driver-kit.md:149` says a must line with no `fixed`, `closed` or `answered` on it FAILs; the script now uses whole words and blanks negated forms (tl1, f2) → reword the sentence to the rule the script runs (from: across jobs)
- **could** `tools/verify-batch.sh:98` The sed line is about 400 columns and hard to review → split the negation words and the closed words into two named variables, each with its comment (from: f2)
- **could** `systest_support.dart:131` The `_waitForSocket` doc says "as before the poll existed": history, which guideline §10 does not want → say why the no-`done` path waits one 40 ms delay (from: f1)
- **could** `packages/party_host/test/systest/systest_support.dart:1` The file is 318 lines (296 before this run), over the guideline's ~300; the test limit is 500, so it is not a breach → accept, or move the socket wait into its own file when it is next touched (from: across jobs)
- **could** `f1-report.md:31-36` The table lists four "after f1" runs, the median sentence says "the three timed runs"; 00:10 at whole-second resolution cannot show a ±1 s change → name the runs the median uses, and say the resolution (from: f1)
- **could** `f1-report.md:21-22` Says the no-argument `t.settle()` calls in `live_stats_fixes_test.dart` still work; that file has its own `settle()` (`live_stats_fixes_test.dart:35`), and the only `Systest.settle()` caller is `night_vote_phones_test.dart:80` → correct the report (from: f1)
- **could** `f1-report.md:52-53` Asks Claude to delete `f1run1.log` to `f1run4.log` from the repo root; none exist in this worktree (Glob finds none) → drop the claim, or confirm in the main checkout (from: f1; wave2 review)

## Open questions

1. The tl1 closing-rule note: REVIEW.md is not in tl1's allow. Suggested: no note in REVIEW.md; state the rule once, in `docs/driver-kit.md` (finding 6).
2. Should "x-fixed" and "bun fixed" close a must (grep -w)? Suggested: keep it, as f2's comment says.
3. Should the systest socket wait move to a ready signal now, or stay a timer with a code-health entry? Suggested: code-health entry now ("before a milestone"), since the signal is a design change in `connection`.
4. Keep `settle`'s `time` as a named parameter (f1's deviation from the brief)? Suggested: keep; the code already uses it that way.
5. Keep the `.` wildcard in `isn.t` and the other forms? Suggested: change to `.?` (finding 1); the `.` also matches any single character.
6. The runner's proc-sweep warned at 09:00 and 09:16 about an orphaned `flutter_tester` (PID 59740, running about 8 h). Nobody closed it in run.log. Suggested: the owner checks it and stops it if it is still there; this review did not touch it.

## Numbers against targets

- Hand-fixes: `run.log` has no `HAND-FIX` line. Reports exist for tl1, tl2, f1, f2 and the wave2 review. Tests-first: tl1 exempt (its brief); f2 has its failing run in the report (8 found, 13 expected); tl2 and f1 exempt (test-support refactor, suite as proof).
- systest suite (`flutter test packages/party_host/test/systest`), target from f1 brief: median ≤ 10 s + 1 s = 11 s. Before tl2: 00:10. After tl2: 00:19, 00:18 (**missed**: 8–9 s slower). After f1: 00:10 ×4 (**met**, whole-second resolution only).
- tl2 goal, a speed-up over the fixed 40 ms wait: **not achieved**; the suite is at the same 10 s as before the run.
- verify-batch tests: 17 PASS before tl1, 19 PASS / 0 FAIL after (f2's report, count as the wave2 review also counted it). **Met**, but the 19 cases do not include `isnt`, `hasn't` or `aren't`.
- musts-negated: the old script gave 8 open lines, the expected count is 13 (f2 report, tests-first). The new script's count on the 13 listed lines is 13 by reading the sed chain.

## Could not check

- Not re-run: `tools/tests/verify-batch-test.sh` (it builds temp git repos; the run is read-only), the systest suite, `dart analyze`, `tools/mine.sh`, and the full `tools/check.sh` on the tip. Results are as the reports state them.
- The `isnt`/`hasn't` false pass is from reading the grep and sed chain, not from running the script.
- Whether `f1run1-4.log` exist in the main checkout: only this worktree was checked.
- Timings were not re-measured; the suite numbers are the reports' own.
- The orphaned `flutter_tester` process (runner's proc-sweep) was not checked on this machine.

## Commit message — a draft

Record the run review of tooling1: one fix batch

Read-only review of the four jobs (tl1, tl2, f1, f2) and the wave2 review
as one change. Findings: the musts check counts "isnt fixed" and "hasn't
been fixed" as closed; f1 and f2 reports lack the part A self-check; the
systest socket wait is real time and not in code-health.md; two docs still
describe the old rules; the systest settle fix's cause is unverified.
No code changed.

## Status row

tooling1 run review: 2 must, 4 should, 6 could written to REVIEW.md. Open: one fix batch (musts check false pass, self-checks in f1/f2 reports, two stale docs, code-health entry for the socket wait); device check of the systest settle fix.

## Delete

- none
