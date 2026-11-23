## Summary

Verdict: **small fixes**
Counts: must 2 · should 5 · could 1
1. `tools/tests/check-par-test.sh:146`: the six `-j`/`--jobs` argument cases exit 2 on HEAD too (HEAD says "Unknown option"), so they do not test the new validation.
2. `tools/tests/check-par-test.sh:172`: case 9 passes on HEAD's check.sh (serial path unchanged), so it is a guard, not a new behaviour test.
3. `tools/check-par.sh:55`: a suite that dies before its status file is written makes `reap_finished` poll forever (hang).

## Findings

- **must** tools/tests/check-par-test.sh:146 The `-j 0`, `-j x`, `--jobs x`, `-jx`, `-j -1`, `-j` and `--jobs` cases pass on HEAD for the wrong reason (unknown option, exit 2, no stub call); only the `CHECK_JOBS=0` part (line 151) fails on HEAD → assert the "job count must be a whole number" message for each argument and move `CHECK_JOBS=0` into its own case.
- **must** tools/tests/check-par-test.sh:172 Case 9 (serial run, protocol and kit) passes on HEAD's check.sh, and the review rules make a new test that passes on old code a must → state in its comment that it is a regression guard for the serial path, or drop it.
- **should** tools/check.sh:154 `--help` still prints `sed -n '2,20p'`; the header grew by three lines, so help now prints the `-j` lines and stops at the `SKIPPED` line, dropping the "to skip the tools suite" and `CHECK_DART` lines (the sp1 report says "one more header line") → change the range to the header's real end (2,23p) and check the help text.
- **should** tools/check-par.sh:55 The status file is written only on the normal path of the background subshell; if the subshell is killed or `mv` fails, `reap_finished` (line 65) waits forever → write the status from an EXIT trap in the subshell (line 51) so every exit writes it.
- **should** tools/tests/check-par-test.sh:122 Line 122 is 121+ columns, and line 46 too (checked with grep for 121+ characters) → wrap both to 120 columns.
- **should** docs/briefs/m16/speed1/sp1-report.md:16 The test-count section says the eight 1 s stub suites take "serial 12 s", but the status row (line 59) and the test's own bound (≥ 8 s) say 8 s → use the measured value and say which run it came from.
- **should** docs/briefs/m16/speed1/sp1-report.md:35 The report says `git status` now shows only the three files of this job; `git status --short` in this worktree still lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and `generated_plugins.cmake` as modified, and `docs/briefs/m16/speed1/run.log` → Claude to check which worktree the churn revert ran in before the report's claim is used.
- **could** tools/check-par.sh:25 The poll interval `sleep 0.2` (also line 32) is a bare magic number; the guidelines want a named tunable with its unit → name it (e.g. `POLL_S=0.2`, "why: fast enough for the stub timing test, cheap for real suites") and use it in both places.

## Decisions to confirm

- The timing cases (tools/tests/check-par-test.sh:110-111, 129; header lines 5-6) compare real seconds, which the test rule forbids; the brief asked for it, but the case can flake on a slow machine → keep as the brief says, or confirm the flake risk is accepted.
- The job polls the status files, not the pids as the brief says (tools/check-par.sh:31-34, 62-72); a sound choice, but the sp1 report does not list it as a decision.
- Under `-j N` the `tools` suite runs `selftest.sh -j 4` inside the pool (tools/check.sh:61), so the load is up to N×4 processes; the report does not mention it → confirm.

## Could not check

- `docs/briefs/m16/speed1/run-findings.md` does not exist (the folder listing shows none), so there were no runner findings to check.
- The serial output was not byte-diffed against HEAD (the report says so too); by reading the diff, the serial path runs the same selection, skip and print steps in the same order.
- The "8 of 9 cases FAIL on the old code" count is not verified; reading HEAD's check.sh, the `-j` cases fail on HEAD as expected.
- `docs/briefs/m16/speed1/run.log` has no lines matching `check-par`, `INFO serial` or `RESULT:`, so the runner's evidence for the 9-of-9 claim is missing.
- Whether `docs/dev-tools.md` lists the `-j` option was not checked (the job was told not to touch it, and the driver owns it).
- `docs/coding-guidelines.md` and `docs/review-rules.md` were not opened whole; the worker extract's rules were used.
- No tests were run (this review changes nothing); `awk` was denied, so the column check used grep.
