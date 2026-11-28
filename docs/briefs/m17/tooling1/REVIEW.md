# tooling1 run review (read-only)

## Summary

- Verdict: **one fix batch** (three jobs, no shared files, no phone-pinned files), plus two owner decisions.
- Counts: **0 must**, 9 should, 8 could (17 findings).
- Dropped as fixed at HEAD: the `isnt` / `wont` / `hasn't` false pass (verify-batch.sh:99 now blanks them), `cannot`,
  `been`/`be`, the literal 50 ms in `settle`, and the 20 chained 2 ms waits (systest_support.dart:139 is one 40 ms wait).
- The five that matter most:
  1. `tools/verify-batch.sh:99`: a curly apostrophe (`don’t fixed`) still closes an open must line.
  2. `tools/tests/verify-batch-test.sh:73-89`: bare `cant`, `dont`, `wasnt`, `arent`, `doesnt`, `hasnt` have no test line.
  3. `systest_support.dart:142`: the socket wait is real time; coding-guidelines.md:85 allows it only in connection tests; code-health.md has no entry.
  4. `systest_support.dart:146`: the 2 ms → 10 ms poll fix has an unmeasured cause: "Fixed, unverified: needs device check".
  5. `docs/test/system-test-plan.md:9,46` and `docs/driver-kit.md:149`: both describe the old rules.
- Fix jobs (no shared files, none phone-pinned): A = systest_support.dart, docs/code-health.md, a new systest test file (3);
  B = tools/verify-batch.sh and its tests, with the 120-column split in the same edit (3); C = docs/test/system-test-plan.md,
  docs/driver-kit.md (2); C2 = the report edits (f1-report.md has 5 findings, over the 3 limit, so Claude decides: one job or a note).
- Owner questions: keep ee2162aa's poll (the suite is no faster), and keep the real-time socket wait (Open questions 1, 2).

## Findings

- **should** tools/verify-batch.sh:99 `neg` uses `n.?t`, one byte in the C locale, so a curly `don’t fixed` (3-byte apostrophe) still closes the must; the wave3 review ran the sed and saw it stay unchanged (not re-run here) → accept `’` too, e.g. `n(’|'|)t` with `neg` in double quotes (from: wave3 review)
- **should** tools/tests/verify-batch-test.sh:73-89 the musts-negated lines (isnt at :86, count at :92) test `isnt`, `wont`, `hasn't`, `don't`, `wasn't`, `won't`, `can't`, `cannot`; bare `cant`, `dont`, `wasnt`, `arent`, `doesnt`, `hasnt` (in the verify-batch.sh:99 group) have no line, so breaking them still passes → add one must line per form and update the count at line 92 (17 → 23) (from: wave3 review)
- **should** packages/party_host/test/systest/systest_support.dart:139 and :146 with :142 the socket wait uses `Future.delayed` and a `Stopwatch`; coding-guidelines.md:85 says no real time in tests and real sockets only in connection tests, and :32 bans delays that hide a race; docs/code-health.md:138 writes down only the joinPhone exception → add a code-health entry with an owner for the socket wait, or replace it with a ready signal later (from: f1; across jobs)
- **should** docs/test/system-test-plan.md:9 and :46 still say "40 ms real wait in settle() at systest_support.dart:123" and "To-do: poll on a condition"; the poll exists, the no-`done` path still waits 40 ms at systest_support.dart:139 → rewrite both lines to the current state (from: across jobs)
- **should** docs/driver-kit.md:149 says a must line with no `fixed`, `closed` or `answered` FAILs; the script also FAILs a line with `not fixed`, and it counts only whole words → reword to the rule the script runs (from: across jobs)
- **should** docs/briefs/m17/tooling1/f1-report.md:1 and f2-report.md:1 have no part A self-check (grep finds no heading); f1-report.md has no `## Summary` either → add the six one-line answers, each with its test or "not affected"; add a Summary to f1 (from: wave2 review; run-findings.md)
- **should** docs/briefs/m17/tooling1/f1-report.md:52-53 asks Claude to delete `f1run1.log` to `f1run4.log` from the repo root; Glob finds none in this worktree → drop the claim (from: wave2 review)
- **should** tools/tests/verify-batch-test.sh:73-100 the musts-negated and musts-whole-words cases were appended to the existing file, and tl1 shows PASS only after its change (its brief exempted tests-first); G9 says new tests go in a new file → move the two cases to a new test file, and show them FAIL on the old script (from: tl1; wave2 review)
- **should** packages/party_host/test/systest/systest_support.dart:146 the 2 ms → 10 ms poll slice was made to remove a slowdown whose cause tl2 "did not measure" (tl2-report.md:37-42); f1 reruns read whole seconds (00:10 ×4) → mark "Fixed, unverified: needs device check" (from: tl2; f1)
- **could** tools/verify-batch.sh:102 the `om=` line is over 120 columns (the `.{121,}` grep matches it); the wave3 review's reason for the split is not met → same edit as the curly-apostrophe finding: put the sed program in its own variable with a comment (from: wave3 review)
- **could** packages/party_host/test/systest/systest_support.dart:144 `if (done()) return;` is not tested; no test passes `done` to `settle`/`until` (grep), so an early return could break without a failure → add a test in a new file that `done` true ends the wait early (from: tl2; wave2 review)
- **could** packages/party_host/test/systest/systest_support.dart:131-132 the doc says "as before the poll existed", which is history; the reason is that a socket reply needs real time → say why the no-`done` path waits one 40 ms delay (from: f1)
- **could** packages/party_host/test/systest/systest_support.dart:1 the file is 318 lines (296 before this run); the guideline is about 300, the lib limit 380, the test limit 500 → accept, or move `_waitForSocket` into its own support file when next touched (from: across jobs)
- **could** docs/briefs/m17/tooling1/f1-report.md:31-36 the table lists four "after f1" runs and the median says "the three timed runs"; 00:10 is whole seconds → name the runs the median uses (from: f1)
- **could** docs/briefs/m17/tooling1/f1-report.md:21-22 says the no-argument `t.settle()` calls in `live_stats_fixes_test.dart` still work; that file has its own `settle()` (live_stats_fixes_test.dart:35), and the only `Systest.settle()` caller is night_vote_phones_test.dart:80 → correct the sentence (from: f1)
- **could** docs/briefs/m17/tooling1/f3-report.md:16-23 gives six self-check lines; the f3 brief's item 3 asks for three, and the worker did not say which it followed (f3.md not re-read here) → say which one in the report (from: wave3 review)
- **could** tools/verify-batch.sh:97-103 `grep -w` closes on `bun fixed` and `x-fixed`; the script comment accepts it (the f2 comment) → keep; no change needed unless the owner says otherwise (from: tl1; f2)

## Open questions

1. Keep ee2162aa's poll (systest settle) or revert to one 40 ms wait? Suggested: revert. It saves no measured time (10 s before, 10 s after f1), and its commit subject claims a speed-up it did not get.
2. Is the real-time socket wait in the systest suite acceptable? Suggested: yes for now, if it is entered in docs/code-health.md with an owner (the systest_support.dart:142 finding); a ready signal is a later design change.
3. Accept `grep -w` closing on `bun fixed` and `x-fixed`? Suggested: yes (the last could-finding, verify-batch.sh:97-103).
4. Keep `settle`'s `time` as a named parameter (f1's deviation from the brief, also tl2's question 2)? Suggested: yes; the callers already use it.
5. Keep `.` in `n.?t`, which also accepts `is n t`? Suggested: tighten to `n['’]?t` in the same edit as the curly-apostrophe finding.
6. The runner's proc-sweep reported an orphaned `flutter_tester` (PID 59740, running about 8 h) at 09:16 and 09:37 (run.log). Nobody closed it. Suggested: the owner checks it and stops it if it is still there; this review did not touch it.
7. Should the run review use the closing sections the task asks for (Commit message, Status row, Delete) as well as the brief's five? Suggested: yes; the wave3 review did too.
8. Should the musts tests from tl1 move to a new file now (the tl1 finding, verify-batch-test.sh:73-100), or stay until the next test change? Suggested: move now; the file is 119 lines and the move is one edit.

## Numbers against targets

- systest suite (`flutter test packages/party_host/test/systest`, Windows, from the reports): before tl2 00:10; after tl2 00:19 and 00:18 (**missed**, 8–9 s slower); after f1 00:10 ×4 (**met**, f1 brief limit 11 s; whole-second resolution only).
- tl2 goal, a speed-up over the fixed 40 ms wait: **not achieved**; the suite is at the 10 s it was before the run.
- verify-batch tests: 17 PASS / 0 FAIL before tl1; 19 PASS / 0 FAIL after (tl1, f2, f3 reports; not re-run here). Met as reported.
- musts-negated expected open count: 8 (tl1), 13 (f2), 17 (f3). Matches the tests as they stand at HEAD by reading.
- verify-batch.sh:102 over 120 columns: **missed** (the 120-column rule).
- systest_support.dart: 296 → 318 lines; guideline ~300 (**over**, soft); under 380 (lib) and 500 (test) limits.
- Hand-fixes: `run.log` has no `HAND-FIX` line, so none to list. Tests-first: f2 and f3 show a FAIL on the old script (f2-report.md:17-21, f3-report.md:6); f1 and tl2 exempt in their briefs; tl1 exempt in its brief but adds to an existing file (its finding).

## Could not check

- The curly-apostrophe claim rests on the wave3 review's run and on reading `n.?t`; my own shell call to run the sed was refused by the approval step, so I did not run it.
- `tools/tests/verify-batch-test.sh` and the systest suite were not re-run; the counts and timings are the reports' own.
- Phone pins: a grep of controller_app for `systest`, `systest_support` and `verify-batch` found no file, so no finding is phone-pinned; behaviour pins were not checked.
- `docs/briefs/m17/tooling1/f3.md` was not re-read (the f3-report.md:16 finding).
- The orphaned `flutter_tester` (Q6) was not checked on this machine.
- REVIEW-round1.md and REVIEW-round2.md (earlier reviews of this same run, not in the `*-review-report.md` pattern) were read; their findings are re-checked above, and the stale ones are dropped.
- `REVIEW-VERDICTS.md`, `STATUS.md` and `*-review.md` brief files: none of the first two exists; the `-review.md` briefs were not read.

## Commit message — a draft

Record the run review of tooling1: one fix batch

Read-only review of the five tooling1 jobs (tl1, tl2, f1, f2, f3) and the wave reviews as one
change. Findings: a curly apostrophe still closes a must line; bare negated forms have no test;
the systest socket wait is real time and not in code-health.md; two docs describe the old rules;
the f1 settle fix's cause is unmeasured. No code changed.

## Status row

tooling1 run review: 0 must, 9 should, 6 could in REVIEW.md. Open: one fix batch (3 jobs: verify-batch curly apostrophe and tests, systest socket wait entry and tests, stale docs and reports); owner decides ee2162aa; device check of the systest settle fix.

## Delete

- none

## Verdicts (driver, Nov 28)
Round 1 and 2 musts (isnt/wont forms, f1/f2 self-check) were fixed by f2/f3 or are report-format only (REVIEW-round1.md, REVIEW-round2.md). Round 3: 0 must; max fix rounds reached.
- should: curly apostrophe, missing bare-form test lines, real-time socket wait, unmeasured cause, new-file test placement - code-health (docs/code-health.md, tooling1 entries).
- should: system-test-plan.md:9,46 and driver-kit.md:149 - trivial, fixed by hand.
- should: f1/f2 report self-check, f1 run-log claim - minor, noted in code-health; no f1run*.log exists in the tree.
- Owner questions: keep ee2162aa/f1 poll (suite no faster: 10 s both)? keep real-time socket wait (code-health entry)?
