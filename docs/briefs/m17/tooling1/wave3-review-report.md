# wave3 review of f3 (musts negation)

## Summary

- Verdict: **small fixes**
- Counts: 0 must, 2 should, 2 could
- Ran `bash tools/tests/verify-batch-test.sh`: 19 PASS, no FAIL line. Commit 6adf8b3a diff is 3 files, all in the job's `allow:`.
- Top findings:
  1. should: `neg` misses a curly apostrophe: `don’t fixed` still closes (checked by running the sed).
  2. should: `cant`, `dont`, `wasnt`, `arent`, `doesnt` are accepted by the new group but have no test line.
  3. could: the sed line (verify-batch.sh:102) is over 120 columns, though the brief wanted it short.
- No `must`. No leftovers (print, TODO, commented code, scratch files) in the diff.

## Findings

- **should** tools/verify-batch.sh:99 `neg` matches the apostrophe with `.?`, which is one byte, so a curly `’` (3 bytes) is not matched and `don’t fixed` still closes (run: the sed leaves `don’t fixed` unchanged) → accept it as well, e.g. `n(’|'|)t` in a double-quoted assignment (`'` cannot sit in this single-quoted string); the `isn.t` it replaces had the same gap.
- **should** tools/tests/verify-batch-test.sh:86 the four new lines test `isnt`, `wont`, `hasn't`, `don't`, but the group at verify-batch.sh:99 also accepts bare `cant`, `dont`, `wasnt`, `arent`, `doesnt`, `hasnt`, which no line tests, so breaking those alternatives passes the suite → add one must line per form and update the count and line list at verify-batch-test.sh:92 (17 becomes 23).
- **could** tools/verify-batch.sh:102 the line is over 120 columns (the grep `.{121,}` matches it), and the job's stated reason for the split ("so the line is short") is not met → put the sed script in its own variable, or continue the pipeline over lines with `\`.
- **could** docs/briefs/m17/tooling1/f3-report.md:16 the self-check has six R part A lines, while f3.md item 3 asks for three; the worker did not flag the conflict → say which one it followed in the report; the worker extract requires the six.

## Decisions to confirm

- `(is|was|wo|ca|has|are|does|do)n.?t` lets any one character stand for the apostrophe, so `is n t` also matches; this is inherited from `isn.t`, and keeping it is a choice → keep, or tighten to `n['’]?t`.
- The `wo`, `ca`, `has`, `are`, `does`, `do` groups cover more than the four tested lines; the f3 `changes:` line asked for them, so the job followed the brief → confirm, and see the second finding for the test gap.
- The closing sections below are included because the task that started this review asked for them; f3.md asks for "nothing else" in this report. The job's brief and the task disagree → confirm.

## Could not check

- The tests-first FAIL (f3-report.md:6, "14 open ... 1 2 ... 13 17"): not re-run, because running the old script needs a scratch file. Read from the old regex: lines 14, 15 and 16 are closed, so 14 open (1–13 and 17), which matches the quote.
- f3-report.md:21 "run.log was already modified before the job started": `git status` is clean now, so this cannot be confirmed.
- f3-report.md:9 `tools/mine.sh` result: not run (reviewer scope); the report says it covers Dart only.
- Docs: a grep for `musts` in `docs/` gave more hits than shown (limit 20); none that I read names the negation list, but I did not check all of them.
- The Dart rules in coding-guidelines.md (layers, sizes, dispose) do not apply to this shell-only change; the shell style was checked by reading only.

## Commit message

Review of wave3 f3 (musts negation): findings in the report

Reads the f3 change to verify-batch.sh and verify-batch-test.sh against its brief and
the review rules. Two shoulds: the negation group misses a curly apostrophe, and the
bare forms cant, dont, wasnt, arent, doesnt, hasnt have no test line. No code changed.
The suite runs 19 PASS, 0 FAIL.

## Status row

tooling1 wave3 review (f3): done, small fixes (0 must, 2 should, 2 could). Open for Claude: the curly-apostrophe miss in the musts negation, and the untested bare contractions.

## Delete

- none
