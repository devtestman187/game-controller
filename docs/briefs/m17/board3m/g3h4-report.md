# board3m g3h4 report: board-gate.sh limits, newline count, committed content

## Summary

What changed:

- `tools/tests/board-gate-test.sh`: 6 new cases, written before the fix. On the unchanged script 3 failed
  (no-final-newline, committed-small, committed-big); the other 3 pass on the base and pin behaviour.
- `tools/board-gate.sh`:
  - `lib_limit_lines=380` and `test_limit_lines=500` are named with their reason; `limit_of` uses them.
  - Line counts use `awk 'END { print NR }'`, so a file with no final newline counts its last line.
  - Sizes and layer checks read each file from `HEAD` (`git show HEAD:<path>`); a path with no HEAD copy
    (deleted) is skipped by `git cat-file -e`.
  - The default base is one variable, `default_base=m17`, with a comment.

Test counts seen in this job:

- Baseline on the unchanged script (with the new cases in place): `cases 17 failed 3`.
- After the fix: `cases 17 failed 0`.

Decisions:

1. The "reverse" case uses a committed 381-line file whose working copy is shrunk to 100 lines. A "clean" working
   tree is the same as the existing `size-over` case, so it would test nothing new.
2. Deleted paths are skipped (`cat-file -e` guard), because a deleted file has no HEAD copy to size.
3. The default base stays `m17`; it is now named in one variable with a comment. `--base` still overrides it.
4. The `unknown-base` case commits one file first, so the test shows no git noise.

Self-check (docs/review-rules.md part A):

1. Host setups: not applicable (shell tool, no app host). Covered by the shell test cases.
2. Kept state: none; each case builds its own temp repo and removes it on exit (`trap`).
3. Combinations: not applicable.
4. Stayed inside `allow:` (only `tools/board-gate.sh`, `tools/tests/board-gate-test.sh`, this report).
5. No stop needed.
6. Looks: not applicable.

## Test output

Output of `bash tools/tests/board-gate-test.sh` after the fix (warnings from git about CRLF removed):

```
PASS clean change in the board folders passes
PASS a controller_app path fails and is named
PASS a night/ path fails and is named
PASS a city/ lib file of 381 lines fails with its count
PASS a city/ lib file of 380 lines passes
PASS a 381-line city/ file with no final newline fails
PASS a lib file committed at 100 lines passes though its working copy has 381
PASS a lib file committed at 381 lines fails though its working copy has 100
PASS a city/ test file of 501 lines fails with its count
PASS a city/ test file of 500 lines passes
PASS a city/ file importing night/ fails
PASS night_adapter.dart importing night/ passes
PASS a city/ file importing package:flutter fails
PASS an unknown option exits 2
PASS --root without a value exits 2
PASS a root that is not a git repo exits 2
PASS --base with an unknown ref exits 2
cases 17 failed 0
```

Baseline, before the script change (the 3 new size/commit cases failed as the brief requires):

```
FAIL a 381-line city/ file with no final newline fails (exit 0, want 1)
FAIL a lib file committed at 100 lines passes though its working copy has 381 (exit 1, want 0)
FAIL a lib file committed at 381 lines fails though its working copy has 100 (exit 0, want 1)
cases 17 failed 3
```

Checks: `bash -n` on `tools/board-gate.sh` passes; `tools/board-gate.sh` is 84 lines; no line in either script is over
120 columns, except the existing line 102 of the test file (the 501-line expectation, pre-existing).

## Hand-over

- Files changed: `tools/board-gate.sh`, `tools/tests/board-gate-test.sh`, `docs/briefs/m17/board3m/g3h4-report.md`.
- Not run: `tools/mine.sh`. The brief says "never tools/mine.sh", while the job instructions say "check with
  tools/mine.sh only". I followed the brief and ran the test file and `bash -n`. `tools/check.sh format` is run by the
  script after the job.
- Findings closed: 14 (no-final-newline count), 15 (bare limits), 16 (base constant), 17 (test cases for the test
  limit and unknown base), plus open question 2 (committed content).

## Commit message — a draft

```
board-gate: size and layer checks read committed content

The gate listed changed paths from the commit but sized and scanned
the working copy, so an edit after commit could pass or fail the gate.
Sizes and imports now come from HEAD. Line counts use awk NR, so a
file with no final newline counts its last line. The lib and test
limits and the default base are named constants. Adds test cases for
the committed-content rule, the 500-line test limit, the no-final-newline
count and an unknown --base ref.
```

## Status row

board3m g3h4: board-gate.sh now checks committed content with named limits and counts a last line with no newline; 17 gate tests pass. Open: running the gate in the full check (check.sh format) after this job; the 121-column expectation at test line 102 is unchanged.

## Delete

- none
