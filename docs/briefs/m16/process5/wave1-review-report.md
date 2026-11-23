# m16 process5 wave 1 review — job-metrics (p5b)

## Summary

Verdict: **small fixes** — 7 findings: 0 must, 2 should, 5 could.

- should: the tests-first proof the brief asked for is not shown, only a suite-level `FAIL tools` (p5b-report.md:46).
- should: one `worker:` line in run.log overrides every row, so a mixed batch relabels earlier jobs (job-metrics.sh:105).
- could: the test never runs the `terminal_reason` branch (job-metrics-test.sh:49); the rest are `--help`'s fixed
  line range, the locale-dependent minutes, the unchecked `nousage` append line and the false 120-column claim.

## Findings

- **should** docs/briefs/m16/process5/p5b-report.md:46 the brief asked for the new test's FAIL lines from before the script existed, but the report cites only the suite-level `FAIL tools (exit 1, 555s)` and says the per-case lines are lost, so the exemption's evidence is not shown → run the test in a temp copy of the repo with `job-metrics.sh` absent and paste one FAIL line per case, or get Claude's acceptance of the suite-level proof.
- **should** tools/job-metrics.sh:105 the last `worker:` line in run.log overrides every row, so a batch restarted on another worker (p5c logs one per run) labels the earlier run's jobs with the new worker → scope the override to logs newer than that line's timestamp, or have the runner write the worker per job.
- **could** tools/tests/job-metrics-test.sh:49 the fixture JSON holds only `subtype`, so the `terminal_reason` branch at tools/job-metrics.sh:115-117 is never run → add `"terminal_reason":"completed"` and expect `0 (subtype=success, terminal_reason=completed)`.
- **could** tools/job-metrics.sh:44 `--help` prints fixed lines 2-32, so a header edit silently truncates or leaks the help, and no case covers it → derive the range from the header end and add a `--help` case that checks exit 0 and the usage line.
- **could** tools/job-metrics.sh:97 `awk` prints the minutes in the process locale, so a comma-decimal locale writes `min=20,6` and breaks p5c's key=value line → run that `awk` with `LC_ALL=C`.
- **could** tools/tests/job-metrics-test.sh:125 case 7 asserts four METRICS lines and the empty log's line but never the `nousage` line, so a wrong model or a missing dash there passes → assert `METRICS nousage worker=flash model=deepseek-v4-flash turns=- in=- out=- cache=- min=- result=-`.
- **could** docs/briefs/m16/process5/p5b-report.md:40 "under 120 columns for every real batch" is false once a result carries `terminal_reason`: a 10-char job name, the 16-char model and `4 (subtype=error_max_turns, terminal_reason=completed)` reach 121 columns (widths 59 + 8 spaces + 54) → drop the claim or wrap the result cell.

## Decisions to confirm

- tools/job-metrics.sh:159 a missing result is `result=-` in METRICS (report decision 2); p5c and p5d will consume this shape, so confirm the dash is the wanted token.
- docs/briefs/m16/process5/p5b-report.md:34 the report calls a missing JSON log the usual case, but flash.sh leaves the worker JSON at `$log` (tools/flash.sh:249, :541), so the result column will usually carry `(subtype=…)`; confirm that is wanted and correct the premise.
- tools/job-metrics.sh:157 a METRICS line is never rewritten, so an `--append` before a job finishes leaves `result=-` permanently; p5c calls it at the end — confirm no earlier call.
- docs/briefs/m16/process5/p5b-report.md:36 `--append` prints the table and `appended <n>` on stdout (decision 4); p5c ignores stdout — confirm no caller parses it.

## Could not check

- The report's PASS claims (tools/check.sh tools at 562 s; job-metrics-test at 9 s) were not re-run: this session's sandbox refuses `tools/job-metrics.sh` and `bash tools/tests/job-metrics-test.sh` (approval), and `tools/check.sh` was not run, so the tests were read, not executed.
- The tests-first per-case FAIL lines in `…/thumbparty-check-20261122-174348/tools.log` are outside the workspace (the report says unreadable there) and were not checked here.
- No batch with a `worker:` line or a surviving worker JSON was available (the identity1 log named in p5b.md is absent; process5's run.log has none yet), so those paths were checked from the fixture and `tools/flash.sh` only.
- `docs/briefs/m16/process5/run-findings.md` does not exist, so there are no entries about this job.

## Commit message

```
Review m16 process5 wave 1: job-metrics (p5b)

Two shoulds: the brief's tests-first FAIL lines are not quoted, and
the last run.log `worker:` line relabels every row in a mixed batch.
Coulds: the terminal_reason branch is untested, --help slices fixed
lines, minutes follow the locale, the append test skips the nousage
line, and the 120-column claim fails once terminal_reason is present.
```

## Status row

m16 process5 wave 1 reviewed (job-metrics): 7 findings (0 must, 2 should, 5 could) in docs/briefs/m16/process5/wave1-review-report.md; open: the tests-first proof, the worker override's scope, and five small test/format fixes.

## Delete

- none
