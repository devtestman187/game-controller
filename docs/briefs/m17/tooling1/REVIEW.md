## Summary

Verdict: **one fix batch** (two small jobs, no phone files), plus one owner decision on commit ee2162aa.

Counts: must 0 · should 4 · could 4.

The five that matter most:
1. The tl2 change (ee2162aa) made the systest suite slower: 10 s before, 18–19 s after (two runs). Its commit subject and doc comment say the opposite ("as before, so no test gets shorter or flakier"). Owner decides: revert, or tune it first.
2. `verify-batch.sh` negation regex misses "not been fixed", "wasn't fixed", "won't be fixed" and "cannot be fixed": those open must lines still close. Found by reading the regex (the sed could not be run here).
3. tl1 appended its two new cases to an existing test file and shows no run on the old code, so it does not show the tests fail first.
4. `_waitForSocket` waits a nominal 2 ms per step; real time per step is not measured (tl2 says timer granularity is a guess).
5. No test pins the early return of `settle` when `done()` holds.

Questions only the owner can answer: see `## Open questions`.

No HAND-FIX lines in run.log. No per-job review reports, run-findings.md, STATUS.md or REVIEW-VERDICTS.md exist, so nothing is carried over.

## Findings

- **should** packages/party_host/test/systest/systest_support.dart:133 `_waitForSocket` loops 20 times over a nominal 2 ms slice, so with no `done` the wait is 20 `Future.delayed` calls instead of one 40 ms delay; measured suite 10 s → 18–19 s → restore one `Future.delayed(40 ms)` when `done` is null, and tune the slice (or wait on elapsed real time) when it is given, then re-time the suite (from: tl2).
- **should** docs/briefs/m17/tooling1 (commit ee2162aa, subject "Systest settle: poll for a known condition instead of a fixed 40 ms") promises a speed-up that was measured as a slowdown; the doc comment at systest_support.dart:128–129 says "no test gets shorter or flakier" → owner decides revert or keep; if kept, fix the doc comment to match the timing (from: across jobs).
- **should** tools/verify-batch.sh:97 the sed alternation `(not|never|isn.t|un)` does not match "has not been fixed", "wasn't fixed", "won't be fixed" or "cannot be fixed" (the `not` in "cannot" fails the `[^[:alnum:]]` lead), so grep -w closes these open musts → add `wasn.t|won.t|cannot` and an optional `been|be` word to the group, and add cases for these four lines to tools/tests/verify-batch-test.sh (from: tl1).
- **should** tools/tests/verify-batch-test.sh:72–91 the `musts-negated` and `musts-whole-words` cases were appended to an existing file, and the tl1 report shows PASS only after the change → if G9 applies to shell tests, move them to a new test file, and show they FAIL on the old script (run before the edit) (from: tl1).
- **could** packages/party_host/test/systest/systest_support.dart:151 `settle(const Duration(milliseconds: 50), done)` repeats the 50 ms default as a bare literal → name the step once (a shared constant) and pass that (from: tl2).
- **could** packages/party_host/test/systest/systest_support.dart:148–153 nothing tests the early return when `done()` holds; the suite passing does not prove it; the tests-first exemption is not stated in tl2-report.md → add a test in a new file that a `done` returning true ends `settle` before the full wait, or state the exemption (from: tl2).
- **could** packages/party_host/test/systest/systest_support.dart:308 file grew from 288 to 308 lines this run (under the 380 limit) → split the socket wait into its own support file when the file is next touched (from: across jobs).
- **could** tools/verify-batch.sh:97 `grep -w` closes on "fixed" after any non-word character, so "bun fixed" and "x-fixed" close (tl1 Q2) → accept as is; note it in the script comment if the owner agrees (from: tl1).

Fix sizing (for Claude's wave): job A = systest_support.dart findings 1, 5, 6 (party_host tests only, no phone pin expected); job B = tools/verify-batch.sh and tools/tests/verify-batch-test.sh findings 3, 4 (shell only). A and B share no files; they can run in one wave. Finding 2 is an owner decision, not a fix job.

## Open questions

1. Keep ee2162aa (suite 10 s → 18–19 s) or revert it? Suggested answer: revert, or keep only after the single-40-ms no-callback path is restored and the suite is re-timed.
2. Should `settle`'s `done` be a named parameter (`done:`) as the tl2 `changes` line says, not positional? Suggested answer: yes, named; callers are only in systest_support.dart and one test file that uses the default.
3. Should `settle` wait on the socket's ready event instead of a timer (tl2 Q3)? Suggested answer: no, not in this milestone; a timer with a bound is enough.
4. Should a REVIEW.md template note be added for the closing rule (tl1 Q1)? Suggested answer: no; the rule lives in the script, and REVIEW.md is not in tl1's allow list.
5. Accept `grep -w` closing on "bun fixed" (tl1 Q2)? Suggested answer: yes, accept it.

## Numbers against targets

- systest suite (`flutter test packages/party_host/test/systest`, Windows): 10 s before; 19 s and 18 s after. Target: faster (the job's goal). **Missed**, by about 8–9 s, and the commit lands it anyway.
- verify-batch-test.sh: 17 PASS / 0 FAIL before; 19 PASS / 0 FAIL after (tl1). No numeric target; all pass.
- systest_support.dart: 308 lines (limit 380 for a touched lib file; tests 500). Within limit.

## Could not check

- Timer granularity on this machine: not measured (tl2 guess). The cause of the slowdown is unverified; it needs a measurement before any fix claims a speed-up. Mark any fix "Fixed, unverified: needs device check" until then.
- The sed negation regex: a Bash call to run it was refused by the approval step, so findings 2 and the "regex misses" claims rest on reading the pattern, not a run.
- Whether any controller_app (phone) test pins tools/verify-batch.sh or systest_support.dart: not checked; I assume none, which needs a grep to confirm.
- docs/code-health.md: not read; findings here are not yet entered there.
- Per-job `*-review-report.md`, run-findings.md, STATUS.md and REVIEW-VERDICTS.md: none exist in the folder, so there was nothing to carry over.
