job: M16 process5 p5b: tools/job-metrics.sh, one metrics line per job from a batch's worker logs
pub: no
stop: after it. The script and its test only; the runner calls it in p5c, docs are p5d.
tests-first: exempt (new shell tool: run the new test before the script exists and show FAIL lines; say so in the report).
expected-min: 45
turns: 120
read: docs/briefs/templates/COMMON.md · docs/design/claude-only-model.md (table row job-metrics) · docs/briefs/m16/identity1/flash-i1g2.log (lines 14-16 and 95: the usage, worker exit and result lines) · docs/briefs/m16/identity1/run.log (lines 160-175) · tools/flash_usage.dart (print format) · tools/tests/run-base-test.sh (test layout)
changes: job-metrics
decisions (owner, Nov 22): usage comes from the lines flash.sh prints into each `<dir>/flash-<job>.log`: `---- flash usage: <t> turns, <s> s, input <i> + cache read <r> + cache write <w>, output <o> tokens`, `---- flash: worker exit <x>, model <m>, log <path>` and `---- flash: result <c>`. The JSON log named in the worker-exit line is rarely still there; if it is and holds subtype or terminal_reason, add that to the result column.
do:
1 NEW tools/job-metrics.sh <batch dir> [--append]: for every `flash-*.log` in the dir (job logs, `-review` and `wave<N>-review` logs included) print a table, one row per log: job, worker (claude when the model starts with claude-, else flash; a `worker: <name>` line in run.log, if present, wins), model, turns, tokens in / out / cache (cache read + write), minutes (seconds / 60, one decimal), result (the `result <c>` code, `no result` if absent). Missing fields print `-`. Header comment doubles as --help. Exit 0; 2 for bad use or no logs.
2 `--append` appends one line per job to `<dir>/run.log`: `METRICS <job> worker=<w> model=<m> turns=<t> in=<i> out=<o> cache=<c> min=<n> result=<r>`; a job that already has a METRICS line there is skipped (a second run appends nothing).
3 NEW tools/tests/job-metrics-test.sh with a fixture batch built in a temp dir (a claude-model log, a deepseek log, a log with no usage line, a run.log with a worker line): checks the table columns, the `-` cases, the append and its idempotence, exit 2. Under 30 s.
allow: tools/job-metrics.sh · tools/tests/job-metrics-test.sh · docs/briefs/m16/process5/p5b-report.md
check: tools
report: docs/briefs/m16/process5/p5b-report.md
rules: aim 70-100 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
