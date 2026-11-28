# tooling1 wave2 review: f2 and f1 against their briefs

## Summary

- Verdict: small fixes
- Counts: 2 must, 3 should, 2 could
- Top 3:
  1. Neither report has the part A self-check (f1-report.md:1, f2-report.md:1).
  2. f1-report.md:52-53 asks Claude to delete f1run1-4.log from the repo root; those files are not in the worktree.
  3. systest_support.dart:142 adds real-time Stopwatch polling in test support (guideline §9 says no real time).

## Findings

- **must** docs/briefs/m17/tooling1/f1-report.md:1 No part A self-check (host setups, kept state, state combinations, folder, stop, looks) is answered anywhere in the report → add the six one-line answers, each with its test or "not affected".
- **must** docs/briefs/m17/tooling1/f2-report.md:1 No part A self-check is answered anywhere in the report → add the six one-line answers; for a shell-only change most are "not affected".
- **should** docs/briefs/m17/tooling1/f1-report.md:52-53 The report says `f1run1.log` to `f1run4.log` are in the repo root and asks Claude to delete them; they do not exist in the worktree (`ls f1run*.log`: no such file) → remove the claim, or confirm the path and whether the files exist outside this worktree.
- **should** docs/briefs/m17/tooling1/f1-report.md:36 "Median of the three timed runs: 10 s" but the table at lines 31-34 lists four "After f1" runs → name which three runs the median uses, or list the fourth as a separate check.
- **should** packages/party_host/test/systest/systest_support.dart:142 The socket wait polls real time with a Stopwatch and `Future.delayed` (also :139, :146); guideline §9 says no real time in tests, and §2 bans delays that hide a race → record it in docs/code-health.md as a known exception with its owner, or move the socket wait behind a ready signal (tracked, not done here).
- **could** tools/verify-batch.sh:98 The negation list has `isn.t|wasn.t|won.t|can.t`, so the unapostrophe forms `isnt`, `wasnt`, `wont`, `cant` are still counted as open → make the apostrophe optional (`isn.?t`, `won.?t`, and so on) and add a test line for one of them.
- **could** tools/verify-batch.sh:98 The sed line is about 400 columns; the repo's 120-column rule is for Dart, but this line is hard to read → split the negation and closed-word parts into two variables, each with its own comment.

## Decisions to confirm

- f1, systest_support.dart:121: `time` became a named parameter, not the brief's positional one (the brief's signature does not compile). Safe: the only callers are in the same file (lines 153, 161). Confirm the named form.
- f1, systest_support.dart:145-146: each poll waits `min(10 ms, time left)`, stricter than the brief's fixed 10 ms. Safe; it caps the wait at 40 ms.
- f1, systest_support.dart:142: real time (`Stopwatch`) in test support. Needs an owner's decision, see the should finding above.
- f2, tools/verify-batch.sh:97-98: `grep -w` still closes on `x-fixed` (accepted in a comment); the `.` wildcard in `isn.t` and the new forms is kept. Confirm both.

## Could not check

- Timings for the systest suite: not re-run (the job reports 10 s, flutter's whole-second resolution). Only the reports were read.
- `dart analyze` on systest_support.dart: not run; the f1 report says mine.sh passed, and I did not re-check it.
- Whether f1run1-4.log exist in the main checkout: I checked only this worktree.
- The verify-batch test: ran `bash tools/tests/verify-batch-test.sh`; 0 FAIL lines and 19 PASS lines (counted in two runs).

## Commit message — a draft

Record the wave2 review of tooling1 f1 and f2

Review of the f1 (systest settle) and f2 (musts negation) jobs against
their briefs and the guidelines. Findings only: the reports lack the
part A self-check, f1 asks for deletion of log files that are not in
the worktree, and the systest real-time wait is a known exception that
needs an owner's decision. No code changed.

## Status row

tooling1 wave2 review: findings written for f1 and f2 (2 must, 3 should, 2 could). Open: Claude verifies the findings; f1 and f2 reports need the part A self-check.

## Delete

- none
