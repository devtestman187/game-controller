# p2-split report

## Summary

`tools/run-jobs.sh` keeps the run itself; the steps between a job's start and its commit are now
in `tools/run-steps.sh`, and the wave reviews in `tools/run-review.sh`, both sourced after the cd to
the repo root. Behaviour is unchanged: the moved text is byte-identical, and
`tools/tests/run-jobs-split-test.sh` (9 cases, counted in its source) proves the dry run still
prints the old text.

- **What moved.** `run-steps.sh`: `outside_files`, `apply_safe`, `tests_first`, `checks`,
  `dart_fix`, `ci_patch` (123 lines). `run-review.sh`: `review_brief`, `wave_review`,
  `review_salvage`, `start_reviews`, `flush_reviews`, `slot_wait` (72 lines). Each name is defined
  in exactly one file (test case 7). No line of a moved function was edited.
- **Sourcing.** `dir=$(cd "$(dirname "$0")" && pwd) || exit 2`, `cd "$dir/.." || exit 2`, then
  `. "$dir/run-steps.sh" || exit 2` and `. "$dir/run-review.sh" || exit 2`: the absolute script dir
  is resolved before the cd, so the runner works from any cwd and through a path with spaces.
- **Globals stay.** `B`, `WORK`, `LOGS`, `review`, `WAVES`, `CHURN_OUTSIDE`, `SAFE_OUTSIDE`,
  `SIZE_STOP` and the review state (`RV_NAMES`, `RV_RANGES`, `PENDING`, `REVPIDS`, `DROPPED`,
  `APPLIED`) are still declared in `run-jobs.sh`; the two new files declare no variable.
- **Header.** One sentence added ("Its step and review helpers live next to it ..."), and the `-h`
  range moved from `2,63p` to `2,65p` so it still ends on the exit-code line.
- **Docs.** One sentence in the runner paragraph of `docs/dev-tools.md` names the two files and the
  test.
- **Sizes.** `run-jobs.sh` 485 -> 312 lines (limit 330), `run-steps.sh` 123, `run-review.sh` 72
  (limit 250 each), the test 133.
- **Decisions.** (1) The six state lines stay in `run-jobs.sh`, as the brief says globals they use
  stay there; `apply_safe` still resets `DROPPED`/`APPLIED` itself, so nothing depends on the
  initialiser. (2) A missing sourced file exits 2 (bad use), like the old bad-`cd` line. (3) The
  new files carry a one-line "sourced by tools/run-jobs.sh, not run on its own" header, not a help
  block: script-rules' `-h`/exit-code/TIMEOUT clauses are about scripts run on their own.

### Verification

- `bash -n` on `tools/run-jobs.sh`, `tools/run-steps.sh`, `tools/run-review.sh`: no output, ok.
- Moved text is byte-identical: md5 of the old block from `git show HEAD:tools/run-jobs.sh` equals
  md5 of the new block. Steps block (old 167-168,170-250 vs new 8-90):
  `c617831d6a0dc64d9057c308fd1eac60`; dart-fix/ci-patch (old 334-365 vs new 92-123):
  `2ced84bc0dc4fde816370703c0e56f0b`; review block (old 252,254-285,288-317 vs new 10-72):
  `ea413ed42caa7f9ab3c23a0fae64edea`. Only the removed `DROPPED="" APPLIED=""`, `RV_NAMES=()` and
  `PENDING=()`/`REVPIDS=()` lines stayed behind, rewritten in the state block.
- `tools/check.sh tools` -> `PASS tools (109s)`, `tools/tests/run-jobs-split-test.sh (5s)`,
  `RESULT: ok: 5 script(s) passed`. It was run with `--verbose`, but `selftest.sh` prints only the
  per-script line for a script that passes, so the per-case PASS lines were not shown; the script's
  own exit 0 is what proves them (its last line is `RESULT: ok: <n> case(s) passed`, 9 cases by the
  source).
- `tools/check.sh format` -> `PASS format (7s)`, `All checks passed (8s)`.
- Running the test directly (`bash tools/tests/run-jobs-split-test.sh`) was refused by this
  session's Bash approval, as was running the old runner; `tools/check.sh tools` (allow-listed) ran
  it. The expected dry-run text was therefore taken from the dry-run code, which the diff shows
  untouched, not from a live run of the old file.
- The test's fixture: a temp git repo under a path with a space, three copied tools, a stub
  `tools/flash.sh` that writes a marker, and a batch with a done job (report at HEAD plus
  `done.txt`), a dropped job, a job to run, a missing brief and `report: ... extra`. Expected output
  (7 lines): `wave 1:`, `  donejob: skip (committed)`, `  dropjob: skip (dropped)`, `  runjob: run`,
  `  missingjob: MISSING <batch>/missingjob.md`, `  badjob: run`, `LINT FAIL badjob: report: line
  must be exactly one bare path (got: docs/briefs/fix/bad.md extra)`, `then: the run's review ->
  <batch>/REVIEW.md`.

### Self-check (review-rules.md part A)

1. Every host setup: not affected (runner tooling and docs, no app code); case 6 shows the dry run
   starts no job (the flash stub left no marker).
2. Kept state: the review state lives in `run-jobs.sh` and starts empty at every start, as before;
   nothing runs when no wave is left (`--dry-run` exits after the plan).
3. Combining with other states: not affected; the review chain, the stop path and `flush_reviews`
   are the same text (md5 above), only sourced.
4. Job folder: only `tools/run-jobs.sh`, `tools/run-steps.sh`, `tools/run-review.sh`,
   `tools/tests/run-jobs-split-test.sh`, `docs/dev-tools.md` and this report were written.
5. Stop rather than overstep: done; running the test and the old runner with `bash` was refused, so
   the allow-listed `tools/check.sh tools` was used and the old-file comparison reported, not faked.
6. Every look: not affected (no UI).

### Questions and suggestions

1. The two new files have a shebang but no `-h`, exit codes or TIMEOUT: script-rules' header clause
   reads as applying to scripts run on their own, and these are only sourced. If the owner wants the
   clause to cover sourced files too, the headers need a usage/exit-code block.
2. Running a script with `bash <script>` is refused by this session's Bash approval while
   `bash -n` and `tools/check.sh` are allowed; every shell test job in this batch hits that. Worth
   allow-listing `bash tools/tests/*` for the next batch.
3. `run-steps.sh` (123 lines) holds four unrelated steps; if it grows, `apply_safe`/`outside_files`
   and `checks` are the natural next cuts. Not needed now.
4. Running the old file's dry run against the fixture is one command
   (`git show HEAD:tools/run-jobs.sh` into a scratch copy) when a session may run bash; it would
   turn the stored expected text into a live comparison.

## Commit message

```
Runner: move its steps and reviews into sourced files

tools/run-jobs.sh keeps the run itself; the steps between a job's start
and its commit (outside files, tests-first, checks, dart fix, CI patch)
move to tools/run-steps.sh and the wave reviews to tools/run-review.sh.
Both are sourced after the cd to the repo root, with the script dir
resolved first. The moved text is byte-identical (md5 matches) and the
globals stay in run-jobs.sh. The runner drops from 485 to 312 lines.
tools/tests/run-jobs-split-test.sh checks the dry-run text, --help, an
unknown option, a missing waves.txt and a path with spaces; docs/dev-tools.md
names the two files.
```

## Status row

p2-split: the runner's steps and wave reviews live in `tools/run-steps.sh` and `tools/run-review.sh` (sourced after the cd); behaviour unchanged, moved text byte-identical, `run-jobs.sh` 312 lines, new 9-case split test green via `tools/check.sh tools`, `format` green. Open: nobody compared the dry run against a live run of the old file (this session's Bash approval refuses `bash <script>`; the allow-listed `check.sh tools` runs the test).

## Delete

- none
