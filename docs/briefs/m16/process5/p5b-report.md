# p5b report: tools/job-metrics.sh, one metrics line per job from a batch's worker logs

## Summary

Changed, both new files inside `allow:` (tests first: the test was written and run before the
script existed; that run, `tools/check.sh tools`, failed with `FAIL tools (exit 1, 555s)` — see
"Tests first" below):
- New `tools/job-metrics.sh` (167 lines): for every `<batch dir>/flash-*.log` it prints one table
  row — job, worker, model, turns, in, out, cache (read + write), minutes (seconds / 60, one
  decimal), result — and with `--append` adds one `METRICS ...` line per job to the batch's
  run.log, skipping a job that already has one. Exit 0, or 2 for bad use / no logs. The header
  comment is the `--help` text.
- New `tools/tests/job-metrics-test.sh` (10 cases, 9 s): a four-log fixture batch in a temp folder
  (claude-model, deepseek, no-usage, empty) plus run.log copies for the worker line and the
  append, checking the columns, the `-` cases, the result's subtype, the worker override, the
  append and its idempotence, and exit 2 twice.

Checks: `tools/check.sh tools` → PASS (562 s, all 22 self-test scripts, 10/10 of my cases).
`tools/selftest.sh tools/tests` → PASS `job-metrics-test.sh (9s)`, `RESULT: ok: 22 script(s)`.

Values I computed for the expectations: 1234 s / 60 = 20.5666… → `20.6`; 1386 s / 60 = `23.1`;
cache read + write 50000 + 7000 = `57000` and 9000 + 1000 = `10000`; four logs → four rows and
four METRICS lines; a second `--append` → `appended 0 METRICS line(s)`.

Decisions (the brief left these open):
1. The run.log `worker:` line applies to every row and its **last** occurrence wins, because a
   restarted run may have switched workers. The runner writes it through `note()`, so a
   `YYYY-MM-DD HH:MM:SS ` prefix is stripped before matching; a bare `worker: <name>` line matches
   too (that is the form the fixture and the brief use).
2. In a METRICS line a missing value is `-` and a missing result is `result=-`: the table's
   `no result` holds a space and would break the key=value line. What the worker exited with (the
   `result <code>`) is the same number in both places; the model's own exit code is not used.
3. The JSON detail goes in the table's result cell only, as `4 (subtype=error_max_turns)` /
   with `terminal_reason` after a comma, so the METRICS line keeps the shape p5c greps. A missing
   JSON log (the usual case) adds nothing.
4. `--append` prints the table as well and ends with `appended <n> METRICS line(s) to <run.log>`;
   0 is printed on a second run rather than nothing, so a person sees that nothing happened. The
   runner ignores the output either way.
5. Column widths come from the widest cell: a fixed layout would clip `deepseek-v4-flash` or a
   long job name, and the table is under 120 columns for every real batch.

## Tests first (the brief's exemption)

The test was written first and `tools/check.sh tools` run while `tools/job-metrics.sh` did not
exist: it failed (`FAIL tools (exit 1, 555s)`), which can only be the new script's 10 cases, since
the other 21 pass now. Its per-case `FAIL` lines went into check.sh's temp log
(`…/thumbparty-check-20261122-174348/tools.log`) and this sandbox refuses reads outside the
workspace (`grep`/`Read` on that path are refused), so the report cannot quote them. Without the
script every case fails by construction: `bash tools/job-metrics.sh …` exits 127 with an empty
table, and each case asserts exit 0 plus an exact row or METRICS line.
It is the only proof I could produce: the sandbox also refuses to run the test on its own
(`bash tools/tests/job-metrics-test.sh` and `tools/tests/job-metrics-test.sh` need approval), so
every run of it here was through `tools/selftest.sh tools/tests` / `tools/check.sh tools` (558 s).

## Self-check (review-rules part A)

1. Every host setup: not affected — a shell tool, no host, phone or game code; the test that
   shows its behaviour is `tools/tests/job-metrics-test.sh`.
2. Kept state: the only state is the METRICS lines in run.log. They start on `--append`, nothing
   ends or rewrites them, and a job that already has one is skipped, so a second run adds nothing
   (`a second --append appends nothing`); a batch with no logs exits 2 and touches nothing.
3. Combining with other states: not affected — no pause menu, host away, player away, "Get
   ready", dropped link, results or leaving in this code.
4. Stay in the job's folder: `git status --short` shows my two files as new and nothing else of
   mine; the modified PNGs and `tv_test_app/windows/generated_*` listed there are the tools'
   known churn, not touched by this job.
5. Stop rather than overstep: nothing outside `allow:` was needed. The one thing I could not do
   as asked was show the tests-first FAIL lines (above); I did not work around it by temporarily
   deleting or renaming the script.
6. Every look: not affected — no UI, no look-sized widget.

## Tests

`tools/tests/job-metrics-test.sh`, 10 cases, all PASS (9 s):
1. the table's header names the nine columns and one row per flash-*.log (4 rows)
2. a claude-model log's row names the claude worker, its usage and the result's subtype
3. a deepseek log's row names the flash worker and sums cache read + write
4. a log with no usage line prints `-` for its numbers and `no result`
5. an empty log prints `-` for every field and falls back to the flash worker
6. a worker: line in run.log wins over the model's name
7. `--append` adds one METRICS line per job and keeps run.log's lines
8. a second `--append` appends nothing
9. no argument is bad use, exit 2
10. a folder with no flash-*.log is bad use, exit 2

## Questions and suggestions

1. The sandbox's allowlist refuses `bash tools/tests/<name>-test.sh` (flash.sh's own worker
   allowlist has `Bash(bash tools/tests/:*)`), so a 9-second test costs a 558-second suite run
   here. Wide, but it doubles the time of every tools job.
2. p5c should not read the table's stdout as data: the append's count line is on stdout too. The
   run.log lines are the machine-readable output, as the brief implies.

## Commit message

```
tools/job-metrics.sh: one metrics row per job from a batch's worker logs

Reads each flash-*.log of a batch (jobs, reviews, wave and run reviews) and
prints job, worker, model, turns, tokens in / out / cache, minutes and result;
the worker comes from the model, or from the run.log `worker:` line when the
runner wrote one. --append adds one METRICS line per job to run.log and skips a
job that already has one, so a batch's cost is logged once.
tools/tests/job-metrics-test.sh covers the columns, the `-` cases, the JSON
subtype, the worker line, the append and its idempotence, and exit 2.
```

## Status row

**p5b (process5, Nov 22):** `tools/job-metrics.sh <dir> [--append]` reads a batch's `flash-*.log` into a table (job, worker, model, turns, in/out/cache tokens, minutes, result) and appends one METRICS line per job to run.log, idempotent; 10 cases PASS, `tools/check.sh tools` PASS. Open: p5c calls it at the end of a run, p5d documents it.

## Delete

- none
