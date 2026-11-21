# runner-lean report

## Summary

`tools/run-jobs.sh` now skips the per-wave review when the plan is a single wave, and lints every
brief's `report:` line before the first job starts; `docs/dev-tools.md` describes both.

- **Wave review skip** (`wave_review`): with `review=1`, `${#WAVES[@]} -eq 1` and at least one job
  in `RV_NAMES`, `WREV` stays empty and the run logs `wave review skipped: wave 1 is the whole run,
  the run review covers it`. Two or more waves behave as before. The hand-fixed branch calls the
  same function, so it skips too. In a one-wave run the function is reached at most once, so the
  line is logged once; a restart logs it again in its own attempt (as every other progress line).
- **Brief lint**: `report_bad <job>` names the problem (no `report:` line, two `report:` lines, or
  a value that is not one token); `brief_lint` walks every job in `waves.txt` that is neither
  dropped nor done. `--dry-run` prints `LINT FAIL <job>: report: line must be exactly one bare path
  (got: <text>)` per finding and still exits 0. A real run, before the preflight, logs
  `STOPPED: brief lint: <job>: ... (got: <text>)` per finding, saves `run.log` with the existing
  stop/save pattern and exits 1 with no job started.
- The bare-path test is `REPORT_BARE='^[^[:space:]`"'\'']+$'`: no whitespace anywhere (so no second
  word and no trailing text), and no backtick, double quote or single quote. A job whose brief file
  is missing is left to the wave loop's existing `no brief` stop, so the message is not doubled.
- An empty value reports `nothing after report:`; more than one `report:` line reports
  `two report: lines` (three included).
- The header gained one line per change; `-h` now prints `sed -n '2,63p'` (the old `2,58p` range
  already cut off the `NO_PUSH` and exit-code lines; it now covers the whole header).
- `tools/run-jobs.sh` is 485 lines (limit 520); `wave_review` is 11 lines, `report_bad` 9,
  `brief_lint` 14.
- Decisions: (1) lint sits just before the preflight, after `start at` and the left-over review
  report commit, so its STOPPED line has the usual run.log context; (2) the lint reads only `^report:`
  lines at column 0, like the rest of the header parsing; (3) dropped and done jobs are skipped so a
  batch that stopped earlier can still be fixed and restarted without editing unrelated briefs.

### Verification

- `bash -n tools/run-jobs.sh` -> `SYNTAX-OK`.
- `tools/check.sh format` -> `PASS  format (8s)`, `All checks passed (9s)`.
- `bash tools/run-jobs.sh .dart_tool/lint-scratch --dry-run` (and the same without `bash`) could
  **not** be run: the session's Bash approval refused both forms ("This command requires approval").
  The scratch batch is still in `.dart_tool/lint-scratch/` (gitignored; `rm` is denied here) and
  holds `waves.txt` with one wave `good bad noreport two quoted`, a good brief, and four bad
  cases (`report: a.md b.md`, no `report:`, two `report:` lines, a backticked value). Running the
  dry run there is the first thing to do when the next real batch starts.
- Wave-review skip has no run-time check either (a dry run never calls `wave_review`, and a real
  run was not allowed). It is syntax-checked and read through; the one-wave guard only empties
  `WREV`, which the caller already treats as "no review".

### Self-check (review-rules.md part A)

1. Every host setup: not affected (runner and docs only, no app code).
2. Kept state: not affected; the runner holds no new state, `WREV` is per wave as before.
3. Combining with other states: not affected; a one-wave skip leaves the run review and the
   `--no-review` path unchanged.
4. Job folder: only `tools/run-jobs.sh`, `docs/dev-tools.md` and this report were written; the
   scratch batch lives in gitignored `.dart_tool/`.
5. Stop rather than overstep: done; the dry-run check was blocked, reported rather than worked around.
6. Every look: not affected (no UI).

### Questions and suggestions

1. The dry run is unverified by execution. The scratch folder is ready for it; if the approval issue
   is only in this session, delete the folder afterwards.
2. `docs/flash-digest.md` line 19 already documents the lint, but its Run section does not mention the
   single-wave skip; it is outside this job's `allow:` list.
3. Suggest a later job adding the same lint to the `--drop` path? A dropped brief is skipped by the
   lint by design, since it never runs.

## Commit message

```
Run jobs: skip wave review on a one-wave run, lint report lines

A plan with a single wave no longer starts a per-wave worker review;
the run's own review covers it, and runs of 2+ waves are unchanged.
Before the preflight, every brief still to run must have exactly one
report: line whose value is a single bare path. Otherwise the runner
logs a STOPPED line per finding, saves run.log and exits before any
job starts. --dry-run prints LINT FAIL <job>: ... for the same checks
and exits 0. The header help range now covers the whole header, and
docs/dev-tools.md describes both changes.
```

## Status row

runner-lean: single-wave runs skip the per-wave review (the run review covers it) and the preflight now lints every to-run brief's `report:` line (one bare path; `--dry-run` prints LINT FAIL, a real run stops before wave 1); `bash -n` and `format` green. Open: the dry run on the scratch batch could not be executed (Bash approval denied) and should be run when the next batch starts; `.dart_tool/lint-scratch/` is left for it.

## Delete

- none
