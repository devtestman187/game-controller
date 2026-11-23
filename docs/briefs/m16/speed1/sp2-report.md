# M16 speed1 sp2 report: tools/affected.sh

## Summary

- Added `tools/affected.sh`: maps paths (arguments, or `git status` against HEAD with renames and untracked files) to the
  check.sh test suites they can affect; `--not` prints the complement for CHECK_SKIP; `--deps <suite>` prints the folders
  of the suite's package and everything it depends on.
- The suite table comes from `bash tools/check.sh --list` (no copy); the graph from the relative `path:` entries of each
  suite folder's pubspec.yaml (dependencies, dev_dependencies, dependency_overrides), transitively, cycles allowed.
- Added `tools/tests/affected-test.sh`: 37 cases, all PASS (0 failed).
- Tests first: before `tools/affected.sh` existed, the new test printed 34 FAIL lines (for example
  `FAIL c changes reach a, b and c`, `FAIL tools/ maps to the tools suite`); the script was then written and the run was
  37 PASS.
- Computed values in the fake repo (a -> b -> c, d alone): c changes -> `a b c`; b -> `a b`; a -> `a`; d -> `d`;
  `tools/tests/foo-test.sh` -> `tools`; `packages/c/pubspec.yaml` -> every suite (`a b c d tools`); `docs/briefs/x.md` and
  `README.md` -> none; `assets/sounds/x.wav` -> every suite; `--not packages/c/lib/x.dart` -> `d tools`;
  `--deps a` -> `packages/a packages/b packages/c`; `--deps d` -> `packages/d`; rename across packages -> `a b c d`;
  untracked `tools/tests/new-test.sh` -> `tools`.
- Real-repo examples (run through the test's real-repo cases, all PASS):
  - controller_app change -> `phone` (no dependents)
  - `packages/protocol/lib/x.dart` -> `protocol connection metrics kit look arena puzzle host phone tv` (every dependent)
  - `tools/affected.sh` -> every test suite, `tools` included
  - `--deps host` -> the eight package folders `packages/protocol` ... `packages/party_host`
- Exit codes: 0 ok; 2 for an unknown option, an unknown suite, `--deps` with `--not` or paths, `--deps` without a name,
  or a failing `check.sh --list` / `git status`.
- I did not run `bash tools/affected.sh` on the real working tree directly: the tool asked for approval for each direct
  call. The git-status mode is covered by the fake-repo cases only.
- `tools/mine.sh` ran (format, analyze, tests: 0 files, 0 packages touched) and its churn step reverted 22 generated files
  in the working tree (see Hand-over).

## Self-check (docs/review-rules.md part A)

1. Host setups: N/A, a shell tool with no app code; no host set up is touched.
2. Kept state: none. The script keeps no state and writes nothing (test: `a clean tree gives no suite`).
3. Combinations with the pause menu, away host or player, "Get ready", dropped link, results, leaving: N/A (no app code).
4. Stayed in the job's folder and allow: list: `tools/affected.sh`, `tools/tests/affected-test.sh`, this report. The fake repo
   lives in a temp folder that is removed on exit.
5. Stops: none. Did not touch `tools/check.sh`, `tools/run-*.sh` or `docs/dev-tools.md`.
6. Every look: N/A (no UI).

## Decisions

- `--deps format` and `--deps analyze` exit 2: they are not test suites, and their folder is `.`.
- `--not` with every suite selected prints a blank line (an empty CHECK_SKIP skips nothing).
- A `path:` value must start with `.` to count as a dependency, so the hosted `path: ^1.9.1` package does not.
- An `assets/` dependency (party_host, tv_test_app point at `../assets`) is not a suite, so `--deps` does not list it.
- game_kit and test_game depend on each other through dev_dependencies (a cycle); the closure is built with a seen-set, so
  it terminates.

## Hand-over

- **Churn revert (please check):** `tools/mine.sh` ran `churn_revert`, which ran `git checkout --` on 22 generated paths
  that were modified in the working tree when the job started (`docs/design/*.png`, `docs/design/puzzles/*.png`,
  `site/shots/*.png`, `tv_test_app/windows/flutter/generated_plugin*`). They now match HEAD. The churn rule treats them as
  generated, but any uncommitted edits in them are gone and I could not recover them.
- **Scratch file (please delete):** `affected-out.tmp` in the repo root is my leftover from a test run. It is outside
  `allow:`, and my attempt to delete it was denied; it is not in the Delete section.
- Not run: `tools/check.sh` (the runner does it after the job, per the brief).

## Files changed

- `tools/affected.sh` (new): the mapping and `--deps` script described above.
- `tools/tests/affected-test.sh` (new): 37 cases; fake repo plus real-repo cases.
- `docs/briefs/m16/speed1/sp2-report.md` (new): this report.

## Commit message — a draft

Add tools/affected.sh: map changed paths to check.sh suites

Maps paths (or git status against HEAD) to the test suites they can
affect, from check.sh --list and the path: deps in each pubspec.yaml,
transitively. --not prints the CHECK_SKIP complement; --deps <suite>
prints the suite's package folders. Pubspecs, check.sh, affected.sh
select every suite; docs/ and top-level .md none; other paths all.
tools/tests/affected-test.sh covers 37 cases (fake repo plus the real
repo). No check.sh or runner changes.

## Status row

sp2 done: tools/affected.sh (suites for paths, --not, --deps) and tools/tests/affected-test.sh (37 PASS). Open: the 22 generated files reverted by mine.sh's churn step need a check; affected-out.tmp to delete; not yet wired into check.sh (CHECK_SKIP) by design.

## Delete

- none
