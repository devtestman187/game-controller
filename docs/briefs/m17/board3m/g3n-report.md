# board3m g3n: board-line merge gate script

## Summary

- Added `tools/tests/board-gate-test.sh` first (tests-first: new files, exempt). Run before the script existed: 12 of 12 FAIL (exit 127).
- Added `tools/board-gate.sh` (77 lines, plain bash, no stdin reads, no coverage run).
- Ran `bash tools/tests/board-gate-test.sh` after the script: `cases 12 failed 0`.

Test output (PASS lines, the `warning: ... CRLF` lines are git noise from the throw-away repos):

```
PASS clean change in the board folders passes
PASS a controller_app path fails and is named
PASS a night/ path fails and is named
PASS a city/ lib file of 381 lines fails with its count
PASS a city/ lib file of 380 lines passes
PASS a city/ test file of 501 lines fails with its count
PASS a city/ file importing night/ fails
PASS night_adapter.dart importing night/ passes
PASS a city/ file importing package:flutter fails
PASS an unknown option exits 2
PASS --root without a value exits 2
PASS a root that is not a git repo exits 2
cases 12 failed 0
```

Values computed for expectations: lib limit 380 (380 passes, 381 fails), test limit 500 (501 fails).

## Decisions

- Limits: `packages/party_host/lib/src/city/*.dart` and `tools/sim/*.dart` (not `_test`) get 380; `packages/party_host/test/city/*.dart` and `tools/sim/*_test.dart` get 500.
- The layer checks read the working-tree file (same as HEAD after the change commit). Deleted files are skipped.
- `night_adapter.dart` is matched by its exact path, not its basename.
- The Flutter check matches `package:flutter` followed by `/`, `'` or `"`, so `package:flutter_x` does not match.
- Default `--base` is `m17`; the default `--root` is the script's own repo.

## Self-check (review-rules part A)

1. Host setups: n/a (shell gate, no host app). Covered by the gate test only.
2. Kept state: none; the script writes nothing and keeps no state.
3. Combinations with other states: n/a.
4. Files: only the two allowed files plus this report.
5. Nothing overstepped.
6. Looks: n/a.

## Checks not run

- `tools/mine.sh`: not run. The brief's `stop:` says "never tools/mine.sh", but the job's instructions say to check with `tools/mine.sh`. I followed the brief. See the question below.
- `tools/check.sh`: not run (the job forbids it; the script runs `check: format` after the job).
- `dart analyze`: no Dart files changed.

## Questions

1. The brief's `stop:` line says "never tools/mine.sh", but the job instructions say to check with `tools/mine.sh` only. I did not run it. Please confirm which one wins.
2. The gate test prints git CRLF warnings (from `core.autocrlf` on Windows) into its output. Harmless; adding `-c core.autocrlf=false` to the test's git calls would silence them if wanted.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

board3m g3n: merge gate script for the board line

Adds tools/board-gate.sh, the merge gate for the board line: it fails a
changed path outside city/, test/city/, tools/sim/, tools/tests/, the gate
itself, or docs/; a lib file under city/ or tools/sim/ over 380 lines (tests
500); and a city/ file importing night/ (night_adapter.dart excepted) or
package:flutter. Adds tools/tests/board-gate-test.sh with 12 cases on
throw-away repos (all PASS).

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- board3m g3n: done — board-gate.sh path/size/layer merge gate + 12-case test (PASS); open: tools/mine.sh not run (brief says never; job says run), merge-gate wiring into the driver not in this job.

## Delete

- none
