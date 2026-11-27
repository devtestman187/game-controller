## Summary

Job: night2c t2, mine.sh must not report a green "0 files" for untracked folders.

Changed files:
- `tools/tests/mine-test.sh`: two new cases at the end (written first, failed on the base: 2 of 17).
  - "a new untracked folder's .dart file is formatted and counted, not a green 0 files": fixture
    `app/lib/fresh/fresh.dart`; expects `format app/lib/fresh/fresh.dart` in the stub log and
    `RESULT: ok: 1 file(s) formatted`. Base printed `RESULT: ok: 0 file(s) formatted`.
  - "an untracked folder git lists as one entry (a nested repository) fails loudly (exit 1)": fixture
    `app/lib/nested/` as its own `git init`; expects exit 1, `FAILED untracked folder app/lib/nested/`,
    and `RESULT: FAILED:`. Base printed a green RESULT.
- `tools/mine.sh`:
  - `read_changes`: `git status --porcelain -z --untracked-files=all`, so each new file is its own entry.
  - `collect`: a change-list entry ending in `/` prints `FAILED untracked folder <path>`, adds one to
    `failed`, and the run exits 1 with `RESULT: FAILED:`.

Checks run:
- `bash tools/tests/mine-test.sh`: before the fix `RESULT: FAILED: 2 of 17 case(s) failed`
  (the two new cases); after the fix `RESULT: ok: 17 case(s) passed`.
- `tools/mine.sh` (on the worktree, after the fix): `RESULT: ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested`.
  The change list holds only shell files and `docs/briefs/m17/night2c/run.log`, so no .dart file is touched.

Self-check (docs/review-rules.md part A):
1. Host setups: not applicable; a tool change with no app UI.
2. Kept state: none; the lock and temp files are unchanged (existing "interrupted run" case still passes).
3. Combinations: the untracked-folder case runs with the existing renamed/deleted/churn cases, all still PASS.
4. Only `tools/mine.sh` and `tools/tests/mine-test.sh` (plus this report) changed.
5. No stop needed.
6. Look: not applicable.

Decisions:
- "Never print a green 0 files when untracked files exist" is read as: every untracked file is listed (so
  its .dart files are counted) and a folder entry fails. A new untracked non-.dart file (for example a `.md`)
  still gives `0 file(s) formatted`, which is correct because no .dart file was touched.
- The folder failure is in `collect` (the same place other change-list handling lives), not in `read_changes`.

Note on the job: the brief says `dart analyze` on changed files; no .dart file was changed, so none was run.

## Hand-over

Questions:
1. Should a new untracked non-.dart file (such as a `.md`) also turn a run into a non-green output? Current behaviour: no, it prints `ok: 0 file(s) formatted`, the same as a tracked .md change.
2. The `git status` call now lists every file in an untracked folder. On a large untracked tree (such as a fresh `build/`) that is slower; `.dart_tool/` and `build/` are gitignored, so this should be small in practice.

Suggestions:
- The header comment in `tools/mine.sh` does not mention the folder failure; add a line to the exit-code list if this is wanted.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

mine.sh: list untracked files one by one, fail on a folder entry

mine.sh read git status without --untracked-files=all, so a new
untracked folder showed as one "dir/" entry: its .dart files were
skipped and the run printed a green "0 file(s) formatted".
Now every untracked file is listed, and a folder entry that remains
(a nested repository) fails the run. mine-test.sh gains two cases:
a new untracked .dart file is formatted and counted, and a nested
repository fails loudly.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2c t2: mine.sh lists untracked files individually and fails on an untracked folder entry; selftest 17/17. Open: whether a new untracked non-.dart file should also flag the run.

## Delete

- none
